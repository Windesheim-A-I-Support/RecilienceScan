import pandas as pd
import os
import glob
from pathlib import Path
from datetime import datetime
import shutil

# Configuration
DATA_DIR = "./data"
OUTPUT_PATH = "./data/cleaned_master.csv"
BACKUP_DIR = "./data/backups"

# Supported file patterns (in priority order)
FILE_PATTERNS = [
    "Resilience - MasterDatabase*.xlsx",
    "Resilience - MasterDatabase*.xls",
    "MasterDatabase*.xlsx",
    "MasterDatabase*.xls",
    "*.xlsx",
    "*.xls",
]


def find_data_file():
    """
    Search for Excel data file in the data directory.
    Returns the first matching file based on priority patterns.
    Excludes master_data.csv and cleaned_master.csv from search.
    """
    print(f"🔍 Searching for Excel files in: {DATA_DIR}")

    for pattern in FILE_PATTERNS:
        search_path = os.path.join(DATA_DIR, pattern)
        matches = glob.glob(search_path)

        if matches:
            # Sort by modification time (most recent first)
            matches.sort(key=os.path.getmtime, reverse=True)
            selected_file = matches[0]
            print(f"✅ Found data file: {selected_file}")
            if len(matches) > 1:
                print(f"   (Found {len(matches)} files matching '{pattern}', using most recent)")
            return selected_file

    print(f"❌ No Excel files found in {DATA_DIR}")
    return None


def load_excel_file(file_path):
    """
    Load Excel file with intelligent format detection.
    Supports .xlsx and .xls formats.
    """
    print(f"\n📂 Loading Excel file: {file_path}")
    file_ext = Path(file_path).suffix.lower()

    df = None

    if file_ext in ['.xlsx', '.xls']:
        print(f"   Format detected: Excel ({file_ext})")
        try:
            if file_ext == '.xlsx':
                df = pd.read_excel(file_path, engine='openpyxl', header=None)
                print("   ✅ Loaded with openpyxl engine")
            else:
                df = pd.read_excel(file_path, engine='xlrd', header=None)
                print("   ✅ Loaded with xlrd engine")
        except Exception as e:
            print(f"   ❌ Excel load failed: {e}")
            return None
    else:
        print(f"   ⚠️  Unsupported file extension: {file_ext}")
        return None

    return df


def detect_header_row(df, max_rows_to_check=10):
    """
    Intelligently detect which row contains the actual header.
    Looks for rows with column-like content.
    """
    print("🔍 Detecting header row...")

    header_keywords = ['company', 'name', 'email', 'submitdate', 'up -', 'in -', 'do -']

    for idx in range(min(max_rows_to_check, len(df))):
        row_values = df.iloc[idx].astype(str).str.lower()

        # Check if this row contains header-like keywords
        keyword_matches = sum(any(keyword in str(val) for keyword in header_keywords) for val in row_values)

        if keyword_matches >= 3:  # At least 3 header keywords found
            print(f"✅ Detected header at row {idx + 1} (index {idx})")
            return idx

    print("⚠️  Using default header row (index 0)")
    return 0


def clean_column_names(columns):
    """
    Clean and standardize column names.
    Converts to lowercase, replaces spaces with underscores, removes special characters.
    """
    cleaned = (
        pd.Series(columns)
        .astype(str)
        .str.strip()
        .str.lower()
        .str.replace(' ', '_', regex=False)
        .str.replace('-', '', regex=False)
        .str.replace(':', '', regex=False)
        .str.replace(r'[^\w_]', '', regex=True)
    )

    # Handle duplicate column names
    seen = {}
    final_names = []
    for name in cleaned:
        if name in seen:
            seen[name] += 1
            final_names.append(f"{name}_{seen[name]}")
        else:
            seen[name] = 0
            final_names.append(name)

    return final_names


def create_backup(file_path):
    """Create a timestamped backup of a file."""
    if not Path(file_path).exists():
        return None

    os.makedirs(BACKUP_DIR, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    filename = Path(file_path).stem
    ext = Path(file_path).suffix
    backup_path = os.path.join(BACKUP_DIR, f"{filename}_{timestamp}{ext}")

    shutil.copy2(file_path, backup_path)
    print(f"📦 Backup created: {backup_path}")
    return backup_path


def merge_with_existing(new_df):
    """
    Update existing cleaned_master.csv with new data.
    Preserves ONLY the 'reportsent' column from existing file.
    Everything else is updated from the new Excel source.
    """
    if not Path(OUTPUT_PATH).exists():
        print("ℹ️  No existing cleaned_master.csv found - creating new file")
        # Add reportsent column as False for all new records
        if 'reportsent' not in new_df.columns:
            new_df['reportsent'] = False
        return new_df

    print("\n🔄 Updating existing cleaned_master.csv...")

    # Load existing data
    existing_df = pd.read_csv(OUTPUT_PATH)
    print(f"   Existing records: {len(existing_df)}")
    print(f"   New records from Excel: {len(new_df)}")

    # Create backup before updating
    create_backup(OUTPUT_PATH)

    # Standardize column names for matching
    existing_df.columns = existing_df.columns.str.lower().str.strip()
    new_df.columns = new_df.columns.str.lower().str.strip()

    # Check if reportsent column exists in old file
    if 'reportsent' not in existing_df.columns:
        print("   ⚠️  No 'reportsent' column in existing file - creating new")
        existing_df['reportsent'] = False

    # Identify key columns for matching
    key_columns = []
    potential_keys = ['company_name', 'name', 'email_address']

    for col in potential_keys:
        if col in existing_df.columns and col in new_df.columns:
            key_columns.append(col)

    if not key_columns:
        print("⚠️  No common key columns found - replacing entire file")
        new_df['reportsent'] = False
        return new_df

    print(f"   Using key columns for matching: {', '.join(key_columns)}")

    # Create composite key for matching
    existing_df['_merge_key'] = existing_df[key_columns].fillna('').astype(str).agg('||'.join, axis=1)
    new_df['_merge_key'] = new_df[key_columns].fillna('').astype(str).agg('||'.join, axis=1)

    # Build a dictionary of old reportsent values
    reportsent_map = dict(zip(existing_df['_merge_key'], existing_df['reportsent']))

    # Update new_df with reportsent values from old file
    print("   📧 Preserving email tracking status...")
    preserved_count = 0
    new_count = 0

    reportsent_values = []
    for key in new_df['_merge_key']:
        if key in reportsent_map:
            reportsent_values.append(reportsent_map[key])
            preserved_count += 1
        else:
            reportsent_values.append(False)  # New record - not sent yet
            new_count += 1

    new_df['reportsent'] = reportsent_values

    # Remove merge key
    new_df = new_df.drop('_merge_key', axis=1)

    print(f"   📊 Update analysis:")
    print(f"      - Preserved 'reportsent' status: {preserved_count} records")
    print(f"      - New records (not sent): {new_count} records")
    print(f"      - Total records in updated file: {len(new_df)}")

    return new_df


def convert_and_save():
    """
    Main function: Find Excel file, convert to CSV format, merge with existing data.
    """
    print("=" * 70)
    print("📥 DATA CONVERSION - EXCEL TO CSV")
    print("=" * 70)

    # Step 1: Find the Excel file
    source_file = find_data_file()
    if not source_file:
        print("\n❌ FAILED: No Excel file found")
        print(f"   Please place an Excel file (.xlsx or .xls) in: {DATA_DIR}")
        return False

    # Step 2: Load the Excel file
    df_raw = load_excel_file(source_file)
    if df_raw is None:
        print("\n❌ FAILED: Could not load Excel file")
        return False

    print(f"\n📊 Raw data shape: {df_raw.shape[0]} rows × {df_raw.shape[1]} columns")

    # Step 3: Detect header row
    header_row_idx = detect_header_row(df_raw)

    # Step 4: Extract header and data
    header_row = df_raw.iloc[header_row_idx].tolist()
    data_rows = df_raw.iloc[header_row_idx + 1:]

    print(f"📋 Using row {header_row_idx + 1} as header")
    print(f"📦 Data rows: {len(data_rows)}")

    # Step 5: Create dataframe with proper headers
    df_converted = pd.DataFrame(data_rows.values, columns=header_row)

    # Step 6: Clean column names
    print("\n🧹 Cleaning column names...")
    original_cols = df_converted.columns.tolist()
    cleaned_cols = clean_column_names(original_cols)
    df_converted.columns = cleaned_cols
    print(f"   ✅ Cleaned {len(cleaned_cols)} column names")

    # Show sample transformations
    changed_cols = [(orig, clean) for orig, clean in zip(original_cols, cleaned_cols) if orig != clean]
    if changed_cols:
        print(f"   Sample transformations (first 5):")
        for orig, clean in changed_cols[:5]:
            print(f"      '{orig}' → '{clean}'")

    # Step 7: Remove completely empty rows
    initial_rows = len(df_converted)
    df_converted = df_converted.dropna(how='all')
    removed_rows = initial_rows - len(df_converted)

    if removed_rows > 0:
        print(f"\n🗑️  Removed {removed_rows} empty rows")

    # Step 8: Update existing CSV or create new (preserves 'reportsent' column only)
    df_final = merge_with_existing(df_converted)

    # Step 9: Save to output
    print(f"\n💾 Saving to: {OUTPUT_PATH}")

    try:
        os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
        df_final.to_csv(OUTPUT_PATH, index=False, encoding='utf-8')

        print(f"   ✅ Saved successfully!")
        print(f"   📊 Final shape: {df_final.shape[0]} rows × {df_final.shape[1]} columns")

        # Show sample of converted data
        print("\n📋 Sample of converted data (first 3 rows, first 5 columns):")
        print(df_final.iloc[:3, :5].to_string())

        print("\n" + "=" * 70)
        print("✅ SUCCESS: Data converted to CSV!")
        print("=" * 70)
        print("\nℹ️  Next step: Run 'Clean Data' to fix any data quality issues")

        return True

    except Exception as e:
        print(f"\n❌ FAILED to save: {e}")
        return False


if __name__ == "__main__":
    # Set UTF-8 encoding for Windows console
    import sys
    if sys.platform == 'win32':
        import io
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
        sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')

    success = convert_and_save()
    exit(0 if success else 1)
