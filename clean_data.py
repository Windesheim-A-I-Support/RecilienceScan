import pandas as pd
import os
import glob
import shutil
from pathlib import Path
from datetime import datetime

# Configuration
DATA_DIR = "./data"
OUTPUT_PATH = "./data/cleaned_master.csv"
BACKUP_DIR = "./data/backups"

# Merge configuration
MERGE_KEY_FIELDS = ['company_name', 'name', 'email_address']  # Fields to identify duplicates
# If submitdate exists, we'll use it for versioning

# Supported file patterns (in priority order)
FILE_PATTERNS = [
    "Resilience - MasterDatabase*.csv",
    "Resilience - MasterDatabase*.xlsx",
    "Resilience - MasterDatabase*.xls",
    "MasterDatabase*.csv",
    "MasterDatabase*.xlsx",
    "MasterDatabase*.xls",
    "*.xlsx",
    "*.xls",
    "*.csv",
]

def find_data_file():
    """
    Search for data file in the data directory.
    Returns the first matching file based on priority patterns.
    """
    print(f"🔍 Searching for data files in: {DATA_DIR}")

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

    print(f"❌ No data files found in {DATA_DIR}")
    return None


def detect_header_row(df, max_rows_to_check=10):
    """
    Intelligently detect which row contains the actual header.
    Looks for rows with column-like content (e.g., contains keywords like 'Company', 'Name', etc.)
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


def load_file_smart(file_path):
    """
    Load file with intelligent format detection and error handling.
    Supports CSV (comma, semicolon, tab), Excel (.xlsx, .xls), and other formats.
    """
    print(f"\n📂 Loading file: {file_path}")
    file_ext = Path(file_path).suffix.lower()

    df = None

    # Try Excel formats first
    if file_ext in ['.xlsx', '.xls']:
        print(f"   Format detected: Excel ({file_ext})")
        try:
            # Try openpyxl engine for .xlsx
            if file_ext == '.xlsx':
                df = pd.read_excel(file_path, engine='openpyxl', header=None)
                print("   ✅ Loaded with openpyxl engine")
            else:
                # Try xlrd for .xls
                df = pd.read_excel(file_path, engine='xlrd', header=None)
                print("   ✅ Loaded with xlrd engine")
        except Exception as e:
            print(f"   ❌ Excel load failed: {e}")
            return None

    # Try CSV formats with multiple strategies
    elif file_ext == '.csv':
        print("   Format detected: CSV")

        encodings = ['utf-8', 'latin1', 'cp1252', 'iso-8859-1']
        delimiters = [',', ';', '\t', '|']

        for encoding in encodings:
            for delimiter in delimiters:
                try:
                    df = pd.read_csv(
                        file_path,
                        encoding=encoding,
                        delimiter=delimiter,
                        header=None,
                        on_bad_lines='skip',
                        engine='python'
                    )

                    # Validate: Check if we got reasonable number of columns
                    if df.shape[1] > 10:  # Expect at least 10 columns for resilience data
                        print(f"   ✅ Loaded with encoding={encoding}, delimiter='{delimiter}'")
                        print(f"      Shape: {df.shape[0]} rows × {df.shape[1]} columns")
                        break
                    else:
                        df = None

                except Exception as e:
                    continue

            if df is not None:
                break

        if df is None:
            print("   ❌ All CSV loading strategies failed")
            return None

    else:
        print(f"   ⚠️  Unsupported file extension: {file_ext}")
        print("   Attempting to load as CSV...")

        # Try as CSV anyway
        encodings = ['utf-8', 'latin1', 'cp1252']
        for encoding in encodings:
            try:
                df = pd.read_csv(file_path, encoding=encoding, header=None, on_bad_lines='skip', engine='python')
                print(f"   ✅ Loaded as CSV with encoding={encoding}")
                break
            except Exception as e:
                continue

    return df


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
    """
    Create a timestamped backup of the specified file.
    Returns the backup file path or None if backup failed.
    """
    if not os.path.exists(file_path):
        return None

    try:
        # Create backup directory if it doesn't exist
        os.makedirs(BACKUP_DIR, exist_ok=True)

        # Generate backup filename with timestamp
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        file_name = Path(file_path).stem
        file_ext = Path(file_path).suffix
        backup_filename = f"{file_name}_backup_{timestamp}{file_ext}"
        backup_path = os.path.join(BACKUP_DIR, backup_filename)

        # Copy file to backup location
        shutil.copy2(file_path, backup_path)

        print(f"   💾 Backup created: {backup_path}")
        return backup_path

    except Exception as e:
        print(f"   ⚠️  Backup failed: {e}")
        return None


def merge_dataframes(df_existing, df_new):
    """
    Intelligently merge existing data with new data.

    Strategy:
    - New companies/respondents: append
    - Existing companies/respondents with new period: append (new response)
    - Exact duplicates: keep most recent
    - New columns: add to all records (fill existing with NaN)

    Args:
        df_existing: DataFrame with existing data
        df_new: DataFrame with new data

    Returns:
        Merged DataFrame
    """
    print("\n🔄 Merging data...")
    print(f"   Existing data: {len(df_existing)} rows × {len(df_existing.columns)} columns")
    print(f"   New data:      {len(df_new)} rows × {len(df_new.columns)} columns")

    # Identify merge key fields that actually exist in both dataframes
    available_key_fields = [field for field in MERGE_KEY_FIELDS
                           if field in df_existing.columns and field in df_new.columns]

    if not available_key_fields:
        print("   ⚠️  No common key fields found, performing simple append")
        print(f"      Available in existing: {list(df_existing.columns[:5])}...")
        print(f"      Available in new: {list(df_new.columns[:5])}...")
        print("      Using simple concatenation instead")
        df_merged = pd.concat([df_existing, df_new], ignore_index=True)
    else:
        print(f"   🔑 Using merge keys: {available_key_fields}")

        # Add all new columns to existing dataframe (if any)
        new_columns = set(df_new.columns) - set(df_existing.columns)
        if new_columns:
            print(f"   ➕ Adding {len(new_columns)} new columns: {list(new_columns)[:5]}...")
            for col in new_columns:
                df_existing[col] = pd.NA

        # Add all existing columns to new dataframe (if any)
        missing_columns = set(df_existing.columns) - set(df_new.columns)
        if missing_columns:
            print(f"   ➕ Adding {len(missing_columns)} missing columns to new data: {list(missing_columns)[:5]}...")
            for col in missing_columns:
                df_new[col] = pd.NA

        # Ensure columns are in the same order
        df_new = df_new[df_existing.columns]

        # Concatenate dataframes
        df_combined = pd.concat([df_existing, df_new], ignore_index=True)

        # Remove exact duplicates based on key fields (keep last = most recent)
        initial_rows = len(df_combined)
        df_merged = df_combined.drop_duplicates(subset=available_key_fields, keep='last')
        duplicates_removed = initial_rows - len(df_merged)

        if duplicates_removed > 0:
            print(f"   🗑️  Removed {duplicates_removed} duplicate records (kept most recent)")

    print(f"   ✅ Merged result: {len(df_merged)} rows × {len(df_merged.columns)} columns")

    # Show merge summary
    new_records = len(df_merged) - len(df_existing)
    if new_records > 0:
        print(f"   📊 Net new records: +{new_records}")
    elif new_records < 0:
        print(f"   📊 Net change: {new_records} (duplicates removed)")
    else:
        print(f"   📊 No net change (updates only)")

    return df_merged


def clean_and_save():
    """
    Main function: Find data file, load it, clean it, and save to standardized format.
    """
    print("=" * 70)
    print("🚀 RESILIENCE DATA CLEANING SCRIPT")
    print("=" * 70)

    # Step 1: Find the data file
    source_file = find_data_file()
    if not source_file:
        print("\n❌ FAILED: No data file found")
        print(f"   Please place a data file in: {DATA_DIR}")
        print(f"   Supported formats: CSV, XLSX, XLS")
        return False

    # Step 2: Load the file
    df_raw = load_file_smart(source_file)
    if df_raw is None:
        print("\n❌ FAILED: Could not load data file")
        return False

    print(f"\n📊 Raw data shape: {df_raw.shape[0]} rows × {df_raw.shape[1]} columns")

    # Step 3: Detect header row
    header_row_idx = detect_header_row(df_raw)

    # Step 4: Extract header and data
    header_row = df_raw.iloc[header_row_idx].tolist()
    data_rows = df_raw.iloc[header_row_idx + 1:]

    print(f"📋 Using row {header_row_idx + 1} as header")
    print(f"📦 Data rows: {len(data_rows)}")

    # Step 5: Create cleaned dataframe
    df_clean = pd.DataFrame(data_rows.values, columns=header_row)

    # Step 6: Clean column names
    print("\n🧹 Cleaning column names...")
    original_cols = df_clean.columns.tolist()
    cleaned_cols = clean_column_names(original_cols)
    df_clean.columns = cleaned_cols

    print(f"   ✅ Cleaned {len(cleaned_cols)} column names")

    # Show sample of column name transformations
    print("\n   Sample transformations:")
    for i in range(min(5, len(original_cols))):
        if original_cols[i] != cleaned_cols[i]:
            print(f"      '{original_cols[i]}' → '{cleaned_cols[i]}'")

    # Step 7: Remove completely empty rows
    initial_rows = len(df_clean)
    df_clean = df_clean.dropna(how='all')
    removed_rows = initial_rows - len(df_clean)

    if removed_rows > 0:
        print(f"\n🗑️  Removed {removed_rows} empty rows")

    # Step 8: Check for existing data and merge if necessary
    df_final = df_clean

    if os.path.exists(OUTPUT_PATH):
        print(f"\n📚 Existing database found at: {OUTPUT_PATH}")

        try:
            # Load existing data
            df_existing = pd.read_csv(OUTPUT_PATH, encoding='utf-8')
            print(f"   ✅ Loaded existing data: {len(df_existing)} rows")

            # Create backup before merging
            backup_path = create_backup(OUTPUT_PATH)
            if backup_path:
                print(f"   ✅ Backup completed")
            else:
                print(f"   ⚠️  Proceeding without backup")

            # Merge dataframes
            df_final = merge_dataframes(df_existing, df_clean)

        except Exception as e:
            print(f"   ⚠️  Could not load existing data: {e}")
            print(f"   ⚠️  Will overwrite with new data (no merge)")
            df_final = df_clean
    else:
        print(f"\n📝 No existing database found - creating new one")

    # Step 9: Save to output
    print(f"\n💾 Saving final data to: {OUTPUT_PATH}")

    try:
        os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
        df_final.to_csv(OUTPUT_PATH, index=False, encoding='utf-8')

        print(f"   ✅ Saved successfully!")
        print(f"   📊 Final shape: {df_final.shape[0]} rows × {df_final.shape[1]} columns")

        # Show sample of final data
        print("\n📋 Sample of final data (first 3 rows, first 5 columns):")
        print(df_final.iloc[:3, :min(5, len(df_final.columns))].to_string())

        print("\n" + "=" * 70)
        print("✅ SUCCESS: Data cleaning and merging completed!")
        print("=" * 70)

        return True

    except Exception as e:
        print(f"\n❌ FAILED to save: {e}")
        return False


if __name__ == "__main__":
    success = clean_and_save()
    exit(0 if success else 1)
