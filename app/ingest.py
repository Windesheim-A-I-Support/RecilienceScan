import pandas as pd
import os
import glob
import csv
import re
import logging
import shutil
from pathlib import Path
from datetime import datetime

# Configuration
DATA_DIR = "./data"
OUTPUT_PATH = "./data/cleaned_master.csv"
MASTER_DB_PATH = "./data/master_database.csv"
BACKUP_DIR = "./data/backups"
LOG_DIR = "./logs"
LOG_PATH = "./logs/ingestion.log"

# Encoding cascade order
ENCODING_CASCADE = ["utf-8", "utf-8-sig", "cp1252", "latin1"]

# Supported file extensions
SUPPORTED_EXTENSIONS = {".xlsx", ".xls", ".csv", ".tsv"}

# Primary key for upsert merge
PRIMARY_KEY = "company_name"

# Header detection keywords (from convert_data.py pattern)
HEADER_KEYWORDS = ["company", "name", "email", "submitdate", "up -", "in -", "do -"]

# Setup logging (file handler for structured audit trail)
os.makedirs(LOG_DIR, exist_ok=True)

logger = logging.getLogger("ingestion")
logger.setLevel(logging.INFO)

# Avoid adding duplicate handlers on re-import
if not logger.handlers:
    file_handler = logging.FileHandler(LOG_PATH, encoding="utf-8")
    file_handler.setLevel(logging.INFO)
    file_formatter = logging.Formatter(
        "%(asctime)s | %(levelname)s | %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )
    file_handler.setFormatter(file_formatter)
    logger.addHandler(file_handler)


def detect_format(file_path):
    """
    Detect file format by extension and content inspection.
    Returns format string: 'xlsx', 'xls', 'csv', 'tsv', or None.
    """
    file_path = str(file_path)
    ext = Path(file_path).suffix.lower()

    if ext not in SUPPORTED_EXTENSIONS:
        print(f"[WARNING]  Unsupported file extension: {ext}")
        print(f"[INFO]  Supported formats: {', '.join(sorted(SUPPORTED_EXTENSIONS))}")
        logger.warning(f"Unsupported file extension: {ext} for file {file_path}")
        return None

    if not os.path.exists(file_path):
        print(f"[ERROR] File not found: {file_path}")
        logger.error(f"File not found: {file_path}")
        return None

    # Map extension to format string
    ext_map = {".xlsx": "xlsx", ".xls": "xls", ".csv": "csv", ".tsv": "tsv"}
    fmt = ext_map.get(ext)

    # For CSV files, inspect content to detect if it's actually TSV
    if fmt == "csv":
        try:
            with open(file_path, "rb") as f:
                sample = f.read(8192)
            # Decode sample for sniffing
            try:
                text = sample.decode("utf-8")
            except UnicodeDecodeError:
                text = sample.decode("latin1")
            try:
                dialect = csv.Sniffer().sniff(text)
                if dialect.delimiter == "\t":
                    fmt = "tsv"
                    print(f"[INFO]  File has .csv extension but tab-delimited — treating as TSV")
                    logger.info(f"File {file_path} has .csv extension but detected as TSV")
            except csv.Error:
                pass  # Keep original csv format
        except Exception as e:
            logger.warning(f"Content inspection failed for {file_path}: {e}")

    print(f"[INFO]  Detected format: {fmt} for {Path(file_path).name}")
    logger.info(f"Detected format: {fmt} for {file_path}")
    return fmt


def read_with_encoding_cascade(file_path):
    """
    Try reading a text file with multiple encodings in order:
    utf-8 -> utf-8-sig -> cp1252 -> latin1.
    Returns (content_string, encoding_used) or raises on total failure.
    """
    file_path = str(file_path)

    if not os.path.exists(file_path):
        print(f"[ERROR] File not found: {file_path}")
        logger.error(f"File not found: {file_path}")
        raise FileNotFoundError(f"File not found: {file_path}")

    errors = []
    for encoding in ENCODING_CASCADE:
        try:
            with open(file_path, "r", encoding=encoding) as f:
                content = f.read()
            print(f"[OK] Read file with encoding: {encoding}")
            logger.info(f"Successfully read {file_path} with encoding: {encoding}")
            return content, encoding
        except UnicodeDecodeError as e:
            print(f"[WARNING]  Encoding {encoding} failed, trying next...")
            logger.warning(f"Encoding {encoding} failed for {file_path}: {e}")
            errors.append((encoding, str(e)))
        except PermissionError:
            print(f"[ERROR] File is locked — please close it in other programs")
            logger.error(f"Permission denied reading {file_path}")
            raise
        except Exception as e:
            print(f"[ERROR] Unexpected error reading with {encoding}: {e}")
            logger.error(f"Unexpected error reading {file_path} with {encoding}: {e}")
            errors.append((encoding, str(e)))

    # All encodings failed
    error_summary = "; ".join(f"{enc}: {err}" for enc, err in errors)
    msg = f"All encodings failed for {file_path}: {error_summary}"
    print(f"[ERROR] {msg}")
    logger.error(msg)
    raise UnicodeDecodeError(
        "multi", b"", 0, 1,
        f"All encoding attempts failed for {file_path}. Tried: {', '.join(ENCODING_CASCADE)}"
    )


def _detect_header_row(df, max_rows_to_check=10):
    """
    Intelligently detect which row contains the actual header.
    Looks for rows with column-like content using keyword matching.
    Returns the index of the header row.
    """
    for idx in range(min(max_rows_to_check, len(df))):
        try:
            row_values = df.iloc[idx]

            # Convert to string safely, handling NaN and other types
            row_strings = []
            for val in row_values:
                if pd.isna(val):
                    row_strings.append("")
                else:
                    row_strings.append(str(val).lower())

            # Check if this row contains header-like keywords
            keyword_matches = sum(
                any(keyword in row_str for keyword in HEADER_KEYWORDS)
                for row_str in row_strings
            )

            # Additional checks for header-like rows
            text_count = sum(
                1
                for s in row_strings
                if s and not s.replace(".", "").replace("-", "").isdigit()
            )
            non_empty = sum(1 for s in row_strings if s)

            if keyword_matches >= 3:
                print(f"[OK] Detected header at row {idx + 1} (index {idx})")
                logger.info(
                    f"Header detected at row {idx + 1} with {keyword_matches} keyword matches"
                )
                return idx
            elif (
                text_count > len(row_strings) * 0.7
                and non_empty > len(row_strings) * 0.5
            ):
                print(f"[OK] Detected likely header at row {idx + 1} (index {idx})")
                logger.info(
                    f"Likely header at row {idx + 1}: {text_count} text cells, "
                    f"{non_empty}/{len(row_strings)} non-empty"
                )
                return idx
        except Exception as e:
            logger.warning(f"Error checking row {idx} for header: {e}")
            continue

    print("[WARNING]  Using default header row (index 0)")
    logger.warning("Could not detect header row, defaulting to index 0")
    return 0


def load_xlsx(file_path):
    """
    Load an Excel (.xlsx/.xls) file with header detection, file lock check,
    and validation. Returns DataFrame with proper headers or None on failure.
    """
    file_path = str(file_path)
    file_ext = Path(file_path).suffix.lower()
    print(f"\n[LOAD] Loading Excel file: {file_path}")
    logger.info(f"Loading Excel file: {file_path}")

    # Check if file exists
    if not os.path.exists(file_path):
        print(f"[ERROR] File not found: {file_path}")
        logger.error(f"File not found: {file_path}")
        return None

    # Check if file is accessible (not locked by another program)
    try:
        with open(file_path, "rb") as f:
            f.read(1)
    except PermissionError:
        print(f"[ERROR] File is locked — please close it in Excel or other programs")
        logger.error(f"File is locked by another process: {file_path}")
        return None
    except Exception as e:
        print(f"[ERROR] Cannot access file: {e}")
        logger.error(f"Cannot access file {file_path}: {e}")
        return None

    # Load with appropriate engine
    df = None
    try:
        if file_ext == ".xlsx":
            try:
                df = pd.read_excel(file_path, engine="openpyxl", header=None)
                print(f"   [OK] Loaded with openpyxl engine")
            except ImportError:
                print(f"   [WARNING]  openpyxl not installed, trying default engine...")
                logger.warning("openpyxl not available, falling back to default engine")
                df = pd.read_excel(file_path, header=None)
                print(f"   [OK] Loaded with default engine")
        else:
            try:
                df = pd.read_excel(file_path, engine="xlrd", header=None)
                print(f"   [OK] Loaded with xlrd engine")
            except ImportError:
                print(f"   [WARNING]  xlrd not installed, trying default engine...")
                logger.warning("xlrd not available, falling back to default engine")
                df = pd.read_excel(file_path, header=None)
                print(f"   [OK] Loaded with default engine")
    except FileNotFoundError:
        print(f"[ERROR] File not found: {file_path}")
        logger.error(f"File not found during load: {file_path}")
        return None
    except PermissionError:
        print(f"[ERROR] Permission denied — file may be locked by another program")
        logger.error(f"Permission denied during load: {file_path}")
        return None
    except Exception as e:
        print(f"[ERROR] Excel load failed: {type(e).__name__}: {e}")
        print(f"[INFO]  Tip: Make sure the file is a valid Excel file and not corrupted")
        logger.error(f"Excel load failed for {file_path}: {type(e).__name__}: {e}")
        return None

    # Validate loaded data
    if df is None or df.empty:
        print("[ERROR] File loaded but contains no data")
        logger.error(f"File loaded but empty: {file_path}")
        return None

    if df.shape[0] < 2:
        print("[WARNING]  File must have at least 2 rows (header + data)")
        logger.warning(f"File has fewer than 2 rows: {file_path}")
        return None

    if df.shape[1] < 3:
        print("[WARNING]  File must have at least 3 columns")
        logger.warning(f"File has fewer than 3 columns: {file_path}")
        return None

    # Detect header row
    header_idx = _detect_header_row(df)

    # Set header and remove rows above it
    header_values = df.iloc[header_idx]
    df = df.iloc[header_idx + 1 :].reset_index(drop=True)
    df.columns = header_values.values

    # Drop completely empty rows
    df = df.dropna(how="all").reset_index(drop=True)

    print(f"[OK] Loaded {len(df)} rows, {len(df.columns)} columns from {Path(file_path).name}")
    logger.info(
        f"Successfully loaded {len(df)} rows, {len(df.columns)} columns from {file_path}"
    )
    return df


def load_csv_tsv(file_path):
    """
    Load a CSV or TSV file with encoding cascade and delimiter auto-detection.
    Returns DataFrame or None on failure.
    """
    file_path = str(file_path)
    file_ext = Path(file_path).suffix.lower()
    print(f"\n[LOAD] Loading CSV/TSV file: {file_path}")
    logger.info(f"Loading CSV/TSV file: {file_path}")

    # Check if file exists
    if not os.path.exists(file_path):
        print(f"[ERROR] File not found: {file_path}")
        logger.error(f"File not found: {file_path}")
        return None

    # Read raw content with encoding cascade
    try:
        content, encoding_used = read_with_encoding_cascade(file_path)
    except PermissionError:
        print(f"[ERROR] File is locked — please close it in other programs")
        logger.error(f"Permission denied: {file_path}")
        return None
    except (FileNotFoundError, UnicodeDecodeError) as e:
        print(f"[ERROR] Could not read file: {e}")
        logger.error(f"Could not read file {file_path}: {e}")
        return None
    except Exception as e:
        print(f"[ERROR] Unexpected error reading file: {type(e).__name__}: {e}")
        logger.error(f"Unexpected error reading {file_path}: {type(e).__name__}: {e}")
        return None

    # Check for empty content
    if not content or not content.strip():
        print("[WARNING]  File is empty — skipping")
        logger.warning(f"File is empty: {file_path}")
        return None

    # Auto-detect delimiter using csv.Sniffer
    delimiter = "\t" if file_ext == ".tsv" else ","
    try:
        # Use first 8KB for sniffing
        sample = content[:8192]
        dialect = csv.Sniffer().sniff(sample)
        delimiter = dialect.delimiter
        if delimiter == "\t":
            print(f"[INFO]  Detected tab-delimited format")
        elif delimiter == ",":
            print(f"[INFO]  Detected comma-delimited format")
        else:
            print(f"[INFO]  Detected delimiter: {repr(delimiter)}")
        logger.info(f"Detected delimiter {repr(delimiter)} for {file_path}")
    except csv.Error:
        # Fall back to extension-based detection
        if file_ext == ".tsv":
            delimiter = "\t"
            print(f"[WARNING]  Sniffer failed, using tab delimiter for .tsv file")
        else:
            delimiter = ","
            print(f"[WARNING]  Sniffer failed, using comma delimiter for .csv file")
        logger.warning(f"csv.Sniffer failed for {file_path}, using default delimiter {repr(delimiter)}")

    # Load into DataFrame using pandas
    df = None
    try:
        from io import StringIO
        df = pd.read_csv(
            StringIO(content),
            sep=delimiter,
            header=None,
            dtype=str,
            keep_default_na=False,
        )
    except Exception as e:
        print(f"[ERROR] CSV/TSV parse failed: {type(e).__name__}: {e}")
        print(f"[INFO]  Tip: Check that the file is a valid CSV/TSV and not corrupted")
        logger.error(f"CSV/TSV parse failed for {file_path}: {type(e).__name__}: {e}")
        return None

    # Validate loaded data
    if df is None or df.empty:
        print("[WARNING]  File loaded but contains no data")
        logger.warning(f"File loaded but empty: {file_path}")
        return None

    if df.shape[0] < 2:
        print("[WARNING]  File must have at least 2 rows (header + data)")
        logger.warning(f"File has fewer than 2 rows: {file_path}")
        return None

    if df.shape[1] < 3:
        print("[WARNING]  File must have at least 3 columns")
        logger.warning(f"File has fewer than 3 columns: {file_path}")
        return None

    # Restore proper NaN handling (we used keep_default_na=False to preserve encoding)
    df = df.replace("", pd.NA)

    # Detect header row
    header_idx = _detect_header_row(df)

    # Set header and remove rows above it
    header_values = df.iloc[header_idx]
    df = df.iloc[header_idx + 1 :].reset_index(drop=True)
    df.columns = header_values.values

    # Drop completely empty rows
    df = df.dropna(how="all").reset_index(drop=True)

    print(
        f"[OK] Loaded {len(df)} rows, {len(df.columns)} columns "
        f"from {Path(file_path).name} (encoding: {encoding_used})"
    )
    logger.info(
        f"Successfully loaded {len(df)} rows, {len(df.columns)} columns "
        f"from {file_path} (encoding: {encoding_used}, delimiter: {repr(delimiter)})"
    )
    return df


def normalize_columns(df):
    """
    Normalize all column names to canonical form:
    strip, lowercase, underscores, remove special chars, handle NaN/dupes.
    Returns DataFrame with cleaned column names.
    """
    if df is None or df.empty:
        logger.warning("normalize_columns called with empty or None DataFrame")
        return df

    cleaned = []
    for i, col in enumerate(df.columns):
        try:
            # Handle None, NaN, and other non-string types
            if col is None or (isinstance(col, float) and pd.isna(col)) or str(col).strip() == "":
                col_name = f"column_{i + 1}"
            else:
                # Convert to string and clean following convert_data.py pattern
                col_name = (
                    str(col)
                    .strip()
                    .lower()
                    .replace(" ", "_")
                    .replace("-", "_")
                    .replace(":", "")
                    .replace("(", "")
                    .replace(")", "")
                    .replace("[", "")
                    .replace("]", "")
                )
                # Remove any remaining non-alphanumeric characters (except underscore)
                col_name = re.sub(r"[^\w]", "", col_name)
                # Collapse multiple underscores into one
                col_name = re.sub(r"_+", "_", col_name)
                # Strip leading/trailing underscores
                col_name = col_name.strip("_")

            # Handle empty result after cleaning
            if not col_name:
                col_name = f"column_{i + 1}"

            # Prefix columns that start with a digit
            if col_name[0].isdigit():
                col_name = f"col_{col_name}"

            cleaned.append(col_name)
        except Exception as e:
            logger.warning(f"Error cleaning column {i} ({col}): {e}")
            cleaned.append(f"column_{i + 1}")

    # Handle duplicate column names by appending numeric suffix
    seen = {}
    deduped = []
    for name in cleaned:
        if name in seen:
            seen[name] += 1
            deduped.append(f"{name}_{seen[name]}")
        else:
            seen[name] = 0
            deduped.append(name)

    original_cols = list(df.columns)
    df = df.copy()
    df.columns = deduped

    logger.info(
        f"Normalized {len(deduped)} column names"
    )
    return df


def create_backup(file_path):
    """
    Create a timestamped backup of a file in the backups directory.
    Returns backup path or None if source doesn't exist.
    """
    raise NotImplementedError("create_backup not yet implemented")


def safe_upsert_merge(existing_df, incoming_df, primary_key=PRIMARY_KEY):
    """
    Merge incoming data into existing using primary key matching.
    NEVER overwrites non-empty values. Only fills empty fields.
    New rows are appended. No rows are ever deleted.
    Returns (merged_df, stats_dict).
    """
    raise NotImplementedError("safe_upsert_merge not yet implemented")


def evolve_schema(master_df, incoming_df):
    """
    Add new columns from incoming_df to master_df (schema superset tracking).
    Backfills existing rows with empty values for new columns.
    Returns (updated_master_df, list_of_added_columns).
    """
    raise NotImplementedError("evolve_schema not yet implemented")


def log_ingestion(stats):
    """
    Write structured audit entry to logs/ingestion.log via Python logging.
    Stats dict should include: source, format, encoding, rows_added,
    rows_updated, columns_added.
    """
    raise NotImplementedError("log_ingestion not yet implemented")


def ingest_file(file_path):
    """
    Ingest a single file through the full pipeline:
    detect format -> load -> normalize -> evolve schema -> upsert merge -> save -> log.
    Returns summary stats dict.
    """
    raise NotImplementedError("ingest_file not yet implemented")


def ingest_directory(dir_path=DATA_DIR, pattern="*"):
    """
    Ingest all supported files matching pattern in a directory.
    Calls ingest_file() for each. Returns aggregated stats dict.
    """
    raise NotImplementedError("ingest_directory not yet implemented")


if __name__ == "__main__":
    import sys

    # Windows UTF-8 console fix
    if sys.platform == "win32":
        import io

        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
        sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8")

    print("=" * 70)
    print("[IMPORT] DATA INGESTION - UNIVERSAL LOADER")
    print("=" * 70)

    # Default: process data/ directory
    if len(sys.argv) > 1:
        target = sys.argv[1]
        if os.path.isfile(target):
            result = ingest_file(target)
        elif os.path.isdir(target):
            result = ingest_directory(target)
        else:
            print(f"[ERROR] Path not found: {target}")
            sys.exit(1)
    else:
        result = ingest_directory(DATA_DIR)

    print("\n" + "=" * 70)
    print("[OK] Ingestion complete")
    print("=" * 70)

    sys.exit(0 if result else 1)
