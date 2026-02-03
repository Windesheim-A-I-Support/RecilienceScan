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
    if not Path(file_path).exists():
        return None

    os.makedirs(BACKUP_DIR, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    filename = Path(file_path).stem
    ext = Path(file_path).suffix
    backup_path = os.path.join(BACKUP_DIR, f"{filename}_{timestamp}{ext}")

    shutil.copy2(file_path, backup_path)
    print(f"[BACKUP] Backup created: {backup_path}")
    logger.info(f"Backup created: {backup_path} (source: {file_path})")
    return backup_path


def safe_upsert_merge(existing_df, incoming_df, primary_key=PRIMARY_KEY):
    """
    Merge incoming data into existing using primary key matching.
    NEVER overwrites non-empty values. Only fills empty fields.
    New rows are appended. No rows are ever deleted.
    Returns merged DataFrame.
    """
    stats = {"rows_added": 0, "rows_updated": 0, "rows_unchanged": 0}

    # Handle None/empty inputs gracefully
    if existing_df is None or existing_df.empty:
        if incoming_df is None or incoming_df.empty:
            logger.info("safe_upsert_merge: both DataFrames empty, returning empty")
            return pd.DataFrame()
        logger.info(
            f"safe_upsert_merge: no existing data, returning incoming ({len(incoming_df)} rows)"
        )
        stats["rows_added"] = len(incoming_df)
        return incoming_df.copy()

    if incoming_df is None or incoming_df.empty:
        logger.info("safe_upsert_merge: no incoming data, returning existing unchanged")
        return existing_df.copy()

    # Drop all-NaN rows from incoming before merge
    incoming_df = incoming_df.dropna(how="all").reset_index(drop=True)

    # Fall back to append-only if primary key missing from either DataFrame
    if primary_key not in existing_df.columns or primary_key not in incoming_df.columns:
        print(
            f"[WARNING]  Primary key '{primary_key}' not found in both DataFrames "
            f"— falling back to append-only mode"
        )
        logger.warning(
            f"Primary key '{primary_key}' missing, using append-only merge. "
            f"Existing cols: {list(existing_df.columns)}, "
            f"Incoming cols: {list(incoming_df.columns)}"
        )
        result = pd.concat([existing_df, incoming_df], ignore_index=True)
        stats["rows_added"] = len(incoming_df)
        return result

    # Work on copies to avoid mutating originals
    merged = existing_df.copy()

    # Build index of existing primary key values for fast lookup
    existing_keys = set(merged[primary_key].dropna().astype(str))

    # Separate incoming rows into matched (update) and unmatched (new)
    new_rows = []
    for _, incoming_row in incoming_df.iterrows():
        key_val = incoming_row.get(primary_key)

        # Skip rows with empty primary key
        if pd.isna(key_val) or str(key_val).strip() == "":
            new_rows.append(incoming_row)
            continue

        key_str = str(key_val)

        if key_str in existing_keys:
            # Matched row: fill only empty fields in existing with non-empty incoming values
            mask = merged[primary_key].astype(str) == key_str
            row_updated = False

            for col in incoming_row.index:
                if col == primary_key:
                    continue
                if col not in merged.columns:
                    continue

                incoming_val = incoming_row[col]
                # Skip if incoming value is empty/NaN
                if pd.isna(incoming_val) or str(incoming_val).strip() == "":
                    continue

                # Only fill where existing value is empty/NaN
                existing_vals = merged.loc[mask, col]
                for idx in existing_vals.index:
                    existing_val = merged.at[idx, col]
                    if pd.isna(existing_val) or str(existing_val).strip() == "":
                        merged.at[idx, col] = incoming_val
                        row_updated = True

            if row_updated:
                stats["rows_updated"] += 1
            else:
                stats["rows_unchanged"] += 1
        else:
            # New row: append
            new_rows.append(incoming_row)

    # Append new rows
    if new_rows:
        new_df = pd.DataFrame(new_rows)
        merged = pd.concat([merged, new_df], ignore_index=True)
        stats["rows_added"] = len(new_rows)

    logger.info(
        f"safe_upsert_merge: {stats['rows_added']} added, "
        f"{stats['rows_updated']} updated, {stats['rows_unchanged']} unchanged"
    )
    print(
        f"[DATA] Upsert merge: {stats['rows_added']} new rows, "
        f"{stats['rows_updated']} updated, {stats['rows_unchanged']} unchanged"
    )

    return merged


def evolve_schema(master_df, incoming_df):
    """
    Add new columns from incoming_df to master_df (schema superset tracking).
    Backfills existing rows with empty values for new columns.
    Returns (updated_master_df, list_of_added_columns).
    """
    # Handle None/empty inputs gracefully
    if master_df is None or master_df.empty:
        if incoming_df is None or incoming_df.empty:
            logger.info("evolve_schema: both DataFrames empty, no schema changes")
            return pd.DataFrame(), []
        logger.info(
            f"evolve_schema: no existing master, adopting incoming schema "
            f"({len(incoming_df.columns)} columns)"
        )
        return master_df if master_df is not None else pd.DataFrame(), list(incoming_df.columns)

    if incoming_df is None or incoming_df.empty:
        logger.info("evolve_schema: no incoming data, schema unchanged")
        return master_df.copy(), []

    # Identify new columns in incoming that are not in master
    master_cols = set(master_df.columns)
    incoming_cols = set(incoming_df.columns)
    new_cols = sorted(incoming_cols - master_cols)

    if not new_cols:
        logger.info("evolve_schema: no new columns to add")
        return master_df.copy(), []

    # Work on a copy to avoid mutating the original
    result = master_df.copy()

    # Add each new column to master with pd.NA for existing rows
    for col in new_cols:
        result[col] = pd.NA
        logger.info(f"Schema evolution: added new column '{col}'")

    logger.info(
        f"evolve_schema: added {len(new_cols)} new column(s): {new_cols}"
    )

    return result, new_cols


def log_ingestion(stats):
    """
    Write structured audit entry to logs/ingestion.log via Python logging.
    Stats dict should include: source, format, encoding, rows_added,
    rows_updated, columns_added.
    """
    os.makedirs(LOG_DIR, exist_ok=True)

    source = stats.get("source", "unknown")
    fmt = stats.get("format", "unknown")
    encoding = stats.get("encoding", "unknown")
    rows_loaded = stats.get("rows_loaded", 0)
    rows_added = stats.get("rows_added", 0)
    rows_updated = stats.get("rows_updated", 0)
    rows_unchanged = stats.get("rows_unchanged", 0)
    columns_added = stats.get("columns_added", [])
    total_rows = stats.get("total_rows", 0)
    total_columns = stats.get("total_columns", 0)
    status = stats.get("status", "success")
    error = stats.get("error", None)

    logger.info(
        f"INGESTION | source={source} | format={fmt} | encoding={encoding} | "
        f"rows_loaded={rows_loaded} | rows_added={rows_added} | "
        f"rows_updated={rows_updated} | rows_unchanged={rows_unchanged} | "
        f"columns_added={len(columns_added)} | "
        f"total_rows={total_rows} | total_columns={total_columns} | "
        f"status={status}"
    )

    if columns_added:
        logger.info(f"New columns added: {columns_added}")

    if error:
        logger.error(f"Ingestion error for {source}: {error}")


def ingest_file(file_path):
    """
    Ingest a single file through the full pipeline:
    detect format -> load -> normalize -> evolve schema -> upsert merge -> save -> log.
    Returns summary stats dict.
    """
    file_path = str(file_path)
    stats = {
        "source": Path(file_path).name,
        "format": None,
        "encoding": None,
        "rows_loaded": 0,
        "rows_added": 0,
        "rows_updated": 0,
        "rows_unchanged": 0,
        "columns_added": [],
        "total_rows": 0,
        "total_columns": 0,
        "status": "failed",
        "error": None,
    }

    print(f"\n{'=' * 70}")
    print(f"[IMPORT] Ingesting: {file_path}")
    print(f"{'=' * 70}")
    logger.info(f"Starting ingestion of {file_path}")

    # Step 1: Validate file exists
    if not os.path.exists(file_path):
        msg = f"File not found: {file_path}"
        print(f"[ERROR] {msg}")
        logger.error(msg)
        stats["error"] = msg
        log_ingestion(stats)
        return stats

    # Step 2: Detect format
    fmt = detect_format(file_path)
    if fmt is None:
        msg = f"Unsupported or undetectable format: {file_path}"
        print(f"[ERROR] {msg}")
        stats["error"] = msg
        log_ingestion(stats)
        return stats
    stats["format"] = fmt

    # Step 3: Load file based on format
    df = None
    try:
        if fmt in ("xlsx", "xls"):
            df = load_xlsx(file_path)
            stats["encoding"] = "binary"
        elif fmt in ("csv", "tsv"):
            df = load_csv_tsv(file_path)
            # Try to detect encoding used from the cascade
            try:
                _, enc = read_with_encoding_cascade(file_path)
                stats["encoding"] = enc
            except Exception:
                stats["encoding"] = "unknown"
        else:
            msg = f"No loader available for format: {fmt}"
            print(f"[ERROR] {msg}")
            stats["error"] = msg
            log_ingestion(stats)
            return stats
    except Exception as e:
        msg = f"Load failed: {type(e).__name__}: {e}"
        print(f"[ERROR] {msg}")
        logger.error(f"Load failed for {file_path}: {msg}")
        stats["error"] = msg
        log_ingestion(stats)
        return stats

    if df is None or df.empty:
        msg = f"No data loaded from {file_path}"
        print(f"[WARNING]  {msg}")
        stats["error"] = msg
        log_ingestion(stats)
        return stats

    stats["rows_loaded"] = len(df)
    print(f"[OK] Loaded {len(df)} rows, {len(df.columns)} columns")

    # Step 4: Normalize column names
    try:
        df = normalize_columns(df)
        print(f"[OK] Column names normalized")
    except Exception as e:
        msg = f"Column normalization failed: {type(e).__name__}: {e}"
        print(f"[ERROR] {msg}")
        logger.error(msg)
        stats["error"] = msg
        log_ingestion(stats)
        return stats

    # Step 5: Load existing master_database.csv if it exists
    master_df = None
    if os.path.exists(MASTER_DB_PATH):
        try:
            master_df = pd.read_csv(MASTER_DB_PATH, encoding="utf-8")
            print(f"[OK] Loaded existing master_database.csv ({len(master_df)} rows, {len(master_df.columns)} columns)")
            logger.info(f"Loaded existing master: {len(master_df)} rows, {len(master_df.columns)} columns")
        except Exception as e:
            print(f"[WARNING]  Could not load existing master_database.csv: {e}")
            logger.warning(f"Could not load master_database.csv: {e}")
            master_df = None

    # Step 6: Evolve schema — add new columns to master
    if master_df is not None and not master_df.empty:
        master_df, new_cols = evolve_schema(master_df, df)
        if new_cols:
            stats["columns_added"] = new_cols
            print(f"[DATA] Schema evolved: added {len(new_cols)} new column(s): {new_cols}")
    else:
        # No existing master — all columns are "new"
        stats["columns_added"] = list(df.columns)

    # Step 7: Backup cleaned_master.csv if it exists
    if os.path.exists(OUTPUT_PATH):
        try:
            create_backup(OUTPUT_PATH)
        except Exception as e:
            print(f"[WARNING]  Backup failed: {e}")
            logger.warning(f"Backup of {OUTPUT_PATH} failed: {e}")

    # Step 8: Upsert merge into cleaned_master
    existing_cleaned = None
    if os.path.exists(OUTPUT_PATH):
        try:
            existing_cleaned = pd.read_csv(OUTPUT_PATH, encoding="utf-8")
            print(f"[OK] Loaded existing cleaned_master.csv ({len(existing_cleaned)} rows)")
            logger.info(f"Loaded existing cleaned_master: {len(existing_cleaned)} rows")
        except Exception as e:
            print(f"[WARNING]  Could not load existing cleaned_master.csv: {e}")
            logger.warning(f"Could not load cleaned_master.csv: {e}")
            existing_cleaned = None

    try:
        merged_df = safe_upsert_merge(existing_cleaned, df, PRIMARY_KEY)
    except Exception as e:
        msg = f"Upsert merge failed: {type(e).__name__}: {e}"
        print(f"[ERROR] {msg}")
        logger.error(msg)
        stats["error"] = msg
        log_ingestion(stats)
        return stats

    # Calculate merge stats
    if existing_cleaned is not None and not existing_cleaned.empty:
        stats["rows_added"] = max(0, len(merged_df) - len(existing_cleaned))
        # rows_updated is approximate — count rows that existed before
        stats["rows_updated"] = min(len(existing_cleaned), len(df))
    else:
        stats["rows_added"] = len(merged_df)
        stats["rows_updated"] = 0

    stats["total_rows"] = len(merged_df)
    stats["total_columns"] = len(merged_df.columns)

    # Step 9: Save both CSVs (UTF-8, no index)
    os.makedirs(DATA_DIR, exist_ok=True)

    try:
        # Save master_database.csv (schema superset)
        if master_df is not None and not master_df.empty:
            # Merge master schema with merged data
            master_merged = safe_upsert_merge(master_df, df, PRIMARY_KEY)
            # Ensure master has all columns from merged_df too
            for col in merged_df.columns:
                if col not in master_merged.columns:
                    master_merged[col] = pd.NA
            master_merged.to_csv(MASTER_DB_PATH, index=False, encoding="utf-8")
        else:
            merged_df.to_csv(MASTER_DB_PATH, index=False, encoding="utf-8")

        print(f"[SAVE] Saved master_database.csv")
        logger.info(f"Saved master_database.csv")
    except Exception as e:
        msg = f"Failed to save master_database.csv: {type(e).__name__}: {e}"
        print(f"[ERROR] {msg}")
        logger.error(msg)
        stats["error"] = msg
        log_ingestion(stats)
        return stats

    try:
        # Save cleaned_master.csv (working dataset)
        merged_df.to_csv(OUTPUT_PATH, index=False, encoding="utf-8")
        print(f"[SAVE] Saved cleaned_master.csv ({len(merged_df)} rows, {len(merged_df.columns)} columns)")
        logger.info(f"Saved cleaned_master.csv: {len(merged_df)} rows, {len(merged_df.columns)} columns")
    except Exception as e:
        msg = f"Failed to save cleaned_master.csv: {type(e).__name__}: {e}"
        print(f"[ERROR] {msg}")
        logger.error(msg)
        stats["error"] = msg
        log_ingestion(stats)
        return stats

    # Step 10: Log ingestion
    stats["status"] = "success"
    log_ingestion(stats)

    print(f"\n[OK] Ingestion complete: {stats['rows_loaded']} rows loaded, "
          f"{stats['rows_added']} added, {stats['total_rows']} total rows")

    return stats


def ingest_directory(dir_path=DATA_DIR, pattern="*"):
    """
    Ingest all supported files matching pattern in a directory.
    Calls ingest_file() for each. Returns aggregated stats dict.
    """
    dir_path = str(dir_path)

    print(f"\n{'=' * 70}")
    print(f"[SEARCH] Scanning directory: {dir_path} (pattern: {pattern})")
    print(f"{'=' * 70}")
    logger.info(f"Starting directory ingestion: {dir_path} (pattern: {pattern})")

    # Validate directory exists
    if not os.path.isdir(dir_path):
        msg = f"Directory not found: {dir_path}"
        print(f"[ERROR] {msg}")
        logger.error(msg)
        return {
            "total_files": 0,
            "successful": 0,
            "failed": 0,
            "total_rows_added": 0,
            "total_rows_updated": 0,
            "total_columns_added": [],
            "errors": [msg],
            "file_results": [],
        }

    # Find all matching files
    search_path = os.path.join(dir_path, pattern)
    all_files = glob.glob(search_path)

    # Filter to supported extensions only
    supported_files = [
        f for f in all_files
        if Path(f).suffix.lower() in SUPPORTED_EXTENSIONS
        and os.path.isfile(f)
    ]

    # Exclude output files from ingestion
    exclude_names = {"cleaned_master.csv", "master_database.csv"}
    supported_files = [
        f for f in supported_files
        if Path(f).name not in exclude_names
    ]

    # Sort by modification time (most recent first) for consistent ordering
    supported_files.sort(key=os.path.getmtime, reverse=True)

    if not supported_files:
        msg = f"No supported files found in {dir_path} (pattern: {pattern})"
        print(f"[WARNING]  {msg}")
        logger.warning(msg)
        return {
            "total_files": 0,
            "successful": 0,
            "failed": 0,
            "total_rows_added": 0,
            "total_rows_updated": 0,
            "total_columns_added": [],
            "errors": [],
            "file_results": [],
        }

    print(f"[OK] Found {len(supported_files)} supported file(s)")
    for f in supported_files:
        print(f"   - {Path(f).name}")
    logger.info(f"Found {len(supported_files)} supported files in {dir_path}")

    # Aggregate stats
    aggregate = {
        "total_files": len(supported_files),
        "successful": 0,
        "failed": 0,
        "total_rows_added": 0,
        "total_rows_updated": 0,
        "total_columns_added": [],
        "errors": [],
        "file_results": [],
    }

    # Process each file
    for i, file_path in enumerate(supported_files, 1):
        print(f"\n[INFO]  Processing file {i}/{len(supported_files)}: {Path(file_path).name}")
        logger.info(f"Processing file {i}/{len(supported_files)}: {file_path}")

        try:
            result = ingest_file(file_path)
            aggregate["file_results"].append(result)

            if result.get("status") == "success":
                aggregate["successful"] += 1
                aggregate["total_rows_added"] += result.get("rows_added", 0)
                aggregate["total_rows_updated"] += result.get("rows_updated", 0)
                new_cols = result.get("columns_added", [])
                if new_cols:
                    aggregate["total_columns_added"].extend(new_cols)
            else:
                aggregate["failed"] += 1
                error = result.get("error", "Unknown error")
                aggregate["errors"].append(f"{Path(file_path).name}: {error}")
        except Exception as e:
            aggregate["failed"] += 1
            msg = f"{Path(file_path).name}: {type(e).__name__}: {e}"
            aggregate["errors"].append(msg)
            logger.error(f"Unexpected error ingesting {file_path}: {e}")
            print(f"[ERROR] Unexpected error: {e}")

    # Deduplicate columns_added list
    aggregate["total_columns_added"] = sorted(set(aggregate["total_columns_added"]))

    # Print summary
    print(f"\n{'=' * 70}")
    print(f"[DATA] Directory ingestion summary:")
    print(f"   Files processed: {aggregate['total_files']}")
    print(f"   Successful: {aggregate['successful']}")
    print(f"   Failed: {aggregate['failed']}")
    print(f"   Total rows added: {aggregate['total_rows_added']}")
    print(f"   Total rows updated: {aggregate['total_rows_updated']}")
    if aggregate["total_columns_added"]:
        print(f"   New columns: {len(aggregate['total_columns_added'])}")
    if aggregate["errors"]:
        print(f"   Errors:")
        for err in aggregate["errors"]:
            print(f"      - {err}")
    print(f"{'=' * 70}")

    logger.info(
        f"Directory ingestion complete: {aggregate['successful']}/{aggregate['total_files']} "
        f"succeeded, {aggregate['total_rows_added']} rows added, "
        f"{len(aggregate['total_columns_added'])} new columns"
    )

    return aggregate


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
