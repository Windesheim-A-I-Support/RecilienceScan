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
    print(f"[SEARCH] Searching for Excel files in: {DATA_DIR}")

    for pattern in FILE_PATTERNS:
        search_path = os.path.join(DATA_DIR, pattern)
        matches = glob.glob(search_path)

        if matches:
            # Sort by modification time (most recent first)
            matches.sort(key=os.path.getmtime, reverse=True)
            selected_file = matches[0]
            print(f"[OK] Found data file: {selected_file}")
            if len(matches) > 1:
                print(f"   (Found {len(matches)} files matching '{pattern}', using most recent)")
            return selected_file

    print(f"[ERROR] No Excel files found in {DATA_DIR}")
    return None


def load_excel_file(file_path):
    """
    Load Excel file with intelligent format detection.
    Supports .xlsx and .xls formats.
    Includes robust error handling for common issues.
    """
    print(f"\n📂 Loading Excel file: {file_path}")
    file_ext = Path(file_path).suffix.lower()

    df = None

    if file_ext in ['.xlsx', '.xls']:
        print(f"   Format detected: Excel ({file_ext})")
        try:
            # Check if file is accessible (not locked by another program)
            try:
                with open(file_path, 'rb') as f:
                    f.read(1)
            except PermissionError:
                print(f"   [ERROR] File is locked - please close it in Excel or other programs")
                return None
            except Exception as e:
                print(f"   [ERROR] Cannot access file: {e}")
                return None

            # Try loading with appropriate engine
            if file_ext == '.xlsx':
                try:
                    df = pd.read_excel(file_path, engine='openpyxl', header=None)
                    print("   [OK] Loaded with openpyxl engine")
                except ImportError:
                    print("   [WARNING]  openpyxl not installed, trying default engine...")
                    df = pd.read_excel(file_path, header=None)
                    print("   [OK] Loaded with default engine")
            else:
                try:
                    df = pd.read_excel(file_path, engine='xlrd', header=None)
                    print("   [OK] Loaded with xlrd engine")
                except ImportError:
                    print("   [WARNING]  xlrd not installed, trying default engine...")
                    df = pd.read_excel(file_path, header=None)
                    print("   [OK] Loaded with default engine")

            # Validate loaded data
            if df is None or df.empty:
                print("   [ERROR] File loaded but contains no data")
                return None

            if df.shape[0] < 2:
                print("   [ERROR] File must have at least 2 rows (header + data)")
                return None

            if df.shape[1] < 3:
                print("   [ERROR] File must have at least 3 columns")
                return None

        except FileNotFoundError:
            print(f"   [ERROR] File not found: {file_path}")
            return None
        except PermissionError:
            print(f"   [ERROR] Permission denied - file may be locked by another program")
            return None
        except Exception as e:
            print(f"   [ERROR] Excel load failed: {type(e).__name__}: {e}")
            print(f"   [TIP] Tip: Make sure the file is a valid Excel file and not corrupted")
            return None
    else:
        print(f"   [WARNING]  Unsupported file extension: {file_ext}")
        print(f"   [TIP] Supported formats: .xlsx, .xls")
        return None

    return df


def detect_header_row(df, max_rows_to_check=10):
    """
    Intelligently detect which row contains the actual header.
    Looks for rows with column-like content.
    More robust detection with multiple criteria.
    """
    print("[SEARCH] Detecting header row...")

    header_keywords = ['company', 'name', 'email', 'submitdate', 'up -', 'in -', 'do -']

    for idx in range(min(max_rows_to_check, len(df))):
        try:
            row_values = df.iloc[idx]

            # Convert to string safely, handling NaN and other types
            row_strings = []
            for val in row_values:
                if pd.isna(val):
                    row_strings.append('')
                else:
                    row_strings.append(str(val).lower())

            # Check if this row contains header-like keywords
            keyword_matches = sum(
                any(keyword in row_str for keyword in header_keywords)
                for row_str in row_strings
            )

            # Additional checks for header-like rows:
            # 1. More text than numbers
            text_count = sum(1 for s in row_strings if s and not s.replace('.', '').replace('-', '').isdigit())
            # 2. Not mostly empty
            non_empty = sum(1 for s in row_strings if s)

            if keyword_matches >= 3:  # At least 3 header keywords found
                print(f"[OK] Detected header at row {idx + 1} (index {idx})")
                print(f"   Found {keyword_matches} header keywords, {non_empty}/{len(row_strings)} non-empty cells")
                return idx
            elif text_count > len(row_strings) * 0.7 and non_empty > len(row_strings) * 0.5:
                # Looks like a header (mostly text, mostly filled)
                print(f"[OK] Detected likely header at row {idx + 1} (index {idx})")
                print(f"   {text_count} text cells, {non_empty}/{len(row_strings)} non-empty cells")
                return idx
        except Exception as e:
            print(f"   [WARNING]  Error checking row {idx}: {e}")
            continue

    print("[WARNING]  Using default header row (index 0)")
    return 0


def clean_column_names(columns):
    """
    Clean and standardize column names.
    Converts to lowercase, replaces spaces with underscores, removes special characters.
    More robust handling of edge cases.
    """
    cleaned = []

    for i, col in enumerate(columns):
        try:
            # Handle None, NaN, and other non-string types
            if pd.isna(col) or col is None or str(col).strip() == '':
                # Generate a default name for empty/invalid columns
                col_name = f'column_{i+1}'
            else:
                # Convert to string and clean
                col_name = (
                    str(col)
                    .strip()
                    .lower()
                    .replace(' ', '_')
                    .replace('-', '')
                    .replace(':', '')
                    .replace('(', '')
                    .replace(')', '')
                    .replace('[', '')
                    .replace(']', '')
                )
                # Remove any remaining special characters except underscore
                import re
                col_name = re.sub(r'[^\w_]', '', col_name)

                # Ensure it starts with a letter or underscore (valid Python identifier)
                if col_name and col_name[0].isdigit():
                    col_name = f'col_{col_name}'

                # If cleaning resulted in empty string, use default
                if not col_name:
                    col_name = f'column_{i+1}'

            cleaned.append(col_name)
        except Exception as e:
            print(f"   [WARNING]  Error cleaning column {i}: {e}, using default name")
            cleaned.append(f'column_{i+1}')

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
    More robust handling of edge cases and errors.
    """
    if not Path(OUTPUT_PATH).exists():
        print("[INFO]  No existing cleaned_master.csv found - creating new file")
        # Add reportsent column as False for all new records
        if 'reportsent' not in new_df.columns:
            new_df['reportsent'] = False
        return new_df

    print("\n[UPDATE] Updating existing cleaned_master.csv...")

    try:
        # Load existing data with error handling
        try:
            existing_df = pd.read_csv(OUTPUT_PATH, encoding='utf-8')
        except UnicodeDecodeError:
            print("   [WARNING]  UTF-8 decode failed, trying latin-1 encoding...")
            existing_df = pd.read_csv(OUTPUT_PATH, encoding='latin-1')
        except Exception as e:
            print(f"   [ERROR] Could not read existing file: {e}")
            print("   [INFO]  Creating new file instead")
            new_df['reportsent'] = False
            return new_df

        print(f"   Existing records: {len(existing_df)}")
        print(f"   New records from Excel: {len(new_df)}")

        # Validate existing data
        if existing_df.empty:
            print("   [WARNING]  Existing file is empty - creating new file")
            new_df['reportsent'] = False
            return new_df

        # Create backup before updating
        create_backup(OUTPUT_PATH)
    except Exception as e:
        print(f"   [ERROR] Error processing existing file: {e}")
        print("   [INFO]  Creating new file instead")
        new_df['reportsent'] = False
        return new_df

    # Standardize column names for matching
    existing_df.columns = existing_df.columns.str.lower().str.strip()
    new_df.columns = new_df.columns.str.lower().str.strip()

    # Check if reportsent column exists in old file
    if 'reportsent' not in existing_df.columns:
        print("   [WARNING]  No 'reportsent' column in existing file - creating new")
        existing_df['reportsent'] = False

    # Identify key columns for matching
    key_columns = []
    potential_keys = ['company_name', 'name', 'email_address']

    for col in potential_keys:
        if col in existing_df.columns and col in new_df.columns:
            key_columns.append(col)

    if not key_columns:
        print("[WARNING]  No common key columns found - replacing entire file")
        new_df['reportsent'] = False
        return new_df

    print(f"   Using key columns for matching: {', '.join(key_columns)}")

    # Create composite key for matching
    existing_df['_merge_key'] = existing_df[key_columns].fillna('').astype(str).agg('||'.join, axis=1)
    new_df['_merge_key'] = new_df[key_columns].fillna('').astype(str).agg('||'.join, axis=1)

    # Build a dictionary of old reportsent values
    reportsent_map = dict(zip(existing_df['_merge_key'], existing_df['reportsent']))

    # Update new_df with reportsent values from old file
    print("   [EMAIL] Preserving email tracking status...")
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

    print(f"   [DATA] Update analysis:")
    print(f"      - Preserved 'reportsent' status: {preserved_count} records")
    print(f"      - New records (not sent): {new_count} records")
    print(f"      - Total records in updated file: {len(new_df)}")

    return new_df


def convert_and_save():
    """
    Main function: Find Excel file, convert to CSV format, merge with existing data.
    """
    print("=" * 70)
    print("[IMPORT] DATA CONVERSION - EXCEL TO CSV")
    print("=" * 70)

    # Step 1: Find the Excel file
    source_file = find_data_file()
    if not source_file:
        print("\n[ERROR] FAILED: No Excel file found")
        print(f"   Please place an Excel file (.xlsx or .xls) in: {DATA_DIR}")
        return False

    # Step 2: Load the Excel file
    df_raw = load_excel_file(source_file)
    if df_raw is None:
        print("\n[ERROR] FAILED: Could not load Excel file")
        return False

    print(f"\n[DATA] Raw data shape: {df_raw.shape[0]} rows × {df_raw.shape[1]} columns")

    # Step 3: Detect header row
    header_row_idx = detect_header_row(df_raw)

    # Step 4: Extract header and data
    header_row = df_raw.iloc[header_row_idx].tolist()
    data_rows = df_raw.iloc[header_row_idx + 1:]

    print(f"[SAMPLE] Using row {header_row_idx + 1} as header")
    print(f"📦 Data rows: {len(data_rows)}")

    # Step 5: Create dataframe with proper headers
    df_converted = pd.DataFrame(data_rows.values, columns=header_row)

    # Step 6: Clean column names
    print("\n[CLEAN] Cleaning column names...")
    original_cols = df_converted.columns.tolist()
    cleaned_cols = clean_column_names(original_cols)
    df_converted.columns = cleaned_cols
    print(f"   [OK] Cleaned {len(cleaned_cols)} column names")

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
        # Ensure output directory exists
        output_dir = os.path.dirname(OUTPUT_PATH)
        if output_dir:  # Only create if there's a directory component
            try:
                os.makedirs(output_dir, exist_ok=True)
            except PermissionError:
                print(f"   [ERROR] Permission denied: Cannot create directory {output_dir}")
                print(f"   [TIP] Tip: Check folder permissions or run as administrator")
                return False
            except Exception as e:
                print(f"   [ERROR] Cannot create directory: {e}")
                return False

        # Check if we can write to the output file
        if Path(OUTPUT_PATH).exists():
            try:
                # Test if file is writable
                with open(OUTPUT_PATH, 'a'):
                    pass
            except PermissionError:
                print(f"   [ERROR] File is locked: {OUTPUT_PATH}")
                print(f"   [TIP] Tip: Close the file if it's open in Excel or another program")
                return False

        # Validate dataframe before saving
        if df_final.empty:
            print("   [WARNING]  Warning: Dataframe is empty, but saving anyway")

        # Save to CSV with error handling
        df_final.to_csv(OUTPUT_PATH, index=False, encoding='utf-8')

        # Verify the file was created and is readable
        if not Path(OUTPUT_PATH).exists():
            print(f"   [ERROR] File was not created: {OUTPUT_PATH}")
            return False

        # Try to read it back to verify
        try:
            verification_df = pd.read_csv(OUTPUT_PATH, nrows=1)
            if verification_df.empty and not df_final.empty:
                print(f"   [WARNING]  Warning: File created but appears empty")
        except Exception as e:
            print(f"   [WARNING]  Warning: Could not verify saved file: {e}")

        print(f"   [OK] Saved successfully!")
        print(f"   [DATA] Final shape: {df_final.shape[0]} rows × {df_final.shape[1]} columns")

        # Show sample of converted data (with error handling)
        try:
            if len(df_final) > 0 and len(df_final.columns) > 0:
                print("\n[SAMPLE] Sample of converted data (first 3 rows, first 5 columns):")
                sample_cols = min(5, len(df_final.columns))
                sample_rows = min(3, len(df_final))
                print(df_final.iloc[:sample_rows, :sample_cols].to_string())
        except Exception as e:
            print(f"   [WARNING]  Could not display sample: {e}")

        print("\n" + "=" * 70)
        print("[OK] SUCCESS: Data converted to CSV!")
        print("=" * 70)
        print("\n[INFO]  Next step: Run 'Clean Data' to fix any data quality issues")

        return True

    except PermissionError as e:
        print(f"\n[ERROR] FAILED to save: Permission denied")
        print(f"   [TIP] Tip: Close {OUTPUT_PATH} if it's open in another program")
        print(f"   Error details: {e}")
        return False
    except Exception as e:
        print(f"\n[ERROR] FAILED to save: {type(e).__name__}: {e}")
        print(f"   [TIP] Tip: Check that you have write permissions to the /data folder")
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
