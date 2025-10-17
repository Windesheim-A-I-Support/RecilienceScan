import pandas as pd
import os
import glob
from pathlib import Path

# Configuration
DATA_DIR = "./data"
OUTPUT_PATH = "./data/cleaned_master.csv"

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

    # Step 8: Save to output
    print(f"\n💾 Saving cleaned data to: {OUTPUT_PATH}")

    try:
        os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
        df_clean.to_csv(OUTPUT_PATH, index=False, encoding='utf-8')

        print(f"   ✅ Saved successfully!")
        print(f"   📊 Final shape: {df_clean.shape[0]} rows × {df_clean.shape[1]} columns")

        # Show sample of cleaned data
        print("\n📋 Sample of cleaned data (first 3 rows, first 5 columns):")
        print(df_clean.iloc[:3, :5].to_string())

        print("\n" + "=" * 70)
        print("✅ SUCCESS: Data cleaning completed!")
        print("=" * 70)

        return True

    except Exception as e:
        print(f"\n❌ FAILED to save: {e}")
        return False


if __name__ == "__main__":
    success = clean_and_save()
    exit(0 if success else 1)
