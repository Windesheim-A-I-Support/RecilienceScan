# P2 Data Ingestion Rules & Architecture

## Overview

The P2 Data Ingestion system (`app/ingest.py`) is a format-agnostic, crash-resistant
data pipeline that replaces the Excel-only `convert_data.py` workflow. It normalizes
all input data into canonical UTF-8 CSV format, implements safe upsert logic that never
overwrites non-empty values, handles schema evolution gracefully, and provides a
comprehensive audit trail.

This is pure data infrastructure — no business logic, scoring, or validation rules
beyond schema normalization are applied.

---

## Architecture

### Module Structure

```
app/
  __init__.py          # Package init
  ingest.py            # Universal ingestion module (primary entry point)

data/
  master_database.csv  # Schema superset — every column ever seen
  cleaned_master.csv   # Normalized working dataset for downstream use
  backups/             # Timestamped backups before mutations

logs/
  ingestion.log        # Structured audit trail (Python logging module)

outputs/
  architecture/
    P2_data_ingestion_rules.md  # This file
```

### Data Flow

```
Input File (.xlsx/.csv/.tsv)
  |
  v
detect_format()            -- Extension check + csv.Sniffer content inspection
  |
  v
load_xlsx() / load_csv_tsv()
  |  - Encoding cascade (utf-8 -> utf-8-sig -> cp1252 -> latin1)
  |  - Header row detection (keyword matching)
  |  - Empty row/column validation
  |
  v
normalize_columns()        -- Canonical column name cleaning
  |
  v
evolve_schema()            -- Add new columns to master_database.csv
  |
  v
create_backup()            -- Timestamped backup of cleaned_master.csv
  |
  v
safe_upsert_merge()        -- Merge into cleaned_master.csv using primary key
  |
  v
Save both CSVs (UTF-8, no index)
  |
  v
log_ingestion()            -- Structured audit entry to logs/ingestion.log
```

---

## Ingestion Rules

### 1. Supported Formats

| Extension | Format  | Engine / Method                         |
|-----------|---------|-----------------------------------------|
| `.xlsx`   | Excel   | `pandas.read_excel()` with `openpyxl`   |
| `.xls`    | Excel   | `pandas.read_excel()` with `xlrd`       |
| `.csv`    | CSV     | `pandas.read_csv()` with Sniffer        |
| `.tsv`    | TSV     | `pandas.read_csv()` with tab delimiter  |

- Files with `.csv` extension but tab-delimited content are automatically detected
  as TSV via `csv.Sniffer`.
- Unsupported extensions are rejected with a warning.

### 2. Encoding Cascade

Text-based files (CSV/TSV) are read using a strict fallback order:

1. `utf-8`
2. `utf-8-sig` (handles BOM-prefixed files)
3. `cp1252` (Windows Western European)
4. `latin1` (ISO 8859-1, never fails for single-byte)

Each fallback attempt is logged. If all four fail, an error is raised.
Excel files are read as binary and do not use the encoding cascade.

### 3. Header Detection

The system uses intelligent header row detection borrowed from `convert_data.py`:

- Scans up to the first 10 rows for header-like content.
- **Keyword matching**: Rows containing 3+ matches from the keyword list
  (`company`, `name`, `email`, `submitdate`, `up -`, `in -`, `do -`) are
  identified as headers.
- **Heuristic fallback**: Rows where >70% of cells are text and >50% are non-empty
  are treated as likely headers.
- **Default**: If no header is detected, row 0 (the first row) is used.

### 4. Column Name Normalization

All column names are transformed to a canonical form:

```
"  Company Name (HQ) " -> "company_name_hq"
"Submit-Date"         -> "submit_date"
"Up - Security"       -> "up_security"
"3rd Party Risk"      -> "col_3rd_party_risk"
```

Rules applied in order:
1. Convert to string, strip whitespace
2. Lowercase
3. Replace spaces, hyphens with underscores
4. Remove colons, parentheses, brackets
5. Remove all remaining non-alphanumeric characters (except underscore)
6. Collapse multiple underscores into one
7. Strip leading/trailing underscores
8. Prefix digit-leading names with `col_` (e.g., `3rd_party` -> `col_3rd_party`)
9. Generate `column_{n}` for empty or NaN column names
10. Deduplicate by appending `_1`, `_2`, etc. for repeated names

### 5. Upsert Merge Logic

The merge uses `company_name` as the primary key and follows append-only semantics:

| Scenario                        | Behavior                                          |
|---------------------------------|---------------------------------------------------|
| New row (key not in master)     | Appended to dataset                               |
| Existing row, empty field       | Filled with incoming non-empty value               |
| Existing row, non-empty field   | **NEVER overwritten** — existing value preserved   |
| Row with empty/NaN primary key  | Appended as new row (no matching possible)         |
| Primary key column missing      | Falls back to append-only mode (no upsert)         |
| All-NaN incoming rows           | Dropped before merge                               |
| Existing rows not in incoming   | **Never deleted** — append-only philosophy          |

### 6. Schema Evolution

When incoming data contains columns not present in `master_database.csv`:

1. New columns are added to the master schema.
2. Existing rows are backfilled with empty values (`pd.NA`) for new columns.
3. All column additions are logged to both console and `logs/ingestion.log`.
4. `master_database.csv` always maintains the superset of all columns ever seen.

### 7. Dual Master Dataset

Two canonical CSV files are maintained:

| File                    | Purpose                                                |
|-------------------------|--------------------------------------------------------|
| `master_database.csv`   | Schema superset — contains every column ever ingested  |
| `cleaned_master.csv`    | Normalized working dataset for downstream consumption  |

Both are saved as UTF-8 CSV without row indices.

### 8. Backup Strategy

Before any mutation of `cleaned_master.csv`, a timestamped backup is created:

```
data/backups/cleaned_master_20260203_153000.csv
```

- Backups use `shutil.copy2()` to preserve metadata.
- The `data/backups/` directory is created automatically if missing.

---

## Programmatic API

### `ingest_file(file_path: str) -> dict`

Ingest a single file through the full pipeline. Returns a summary stats dictionary:

```python
from app.ingest import ingest_file

result = ingest_file("./data/survey_results.xlsx")
# Returns:
# {
#     "source": "survey_results.xlsx",
#     "format": "xlsx",
#     "encoding": "binary",
#     "rows_loaded": 150,
#     "rows_added": 120,
#     "rows_updated": 30,
#     "rows_unchanged": 0,
#     "columns_added": ["new_column_a", "new_column_b"],
#     "total_rows": 500,
#     "total_columns": 45,
#     "status": "success",
#     "error": None
# }
```

### `ingest_directory(dir_path: str, pattern: str) -> dict`

Ingest all supported files in a directory. Returns aggregated stats:

```python
from app.ingest import ingest_directory

result = ingest_directory("./data", pattern="*.xlsx")
# Returns:
# {
#     "total_files": 3,
#     "successful": 3,
#     "failed": 0,
#     "total_rows_added": 450,
#     "total_rows_updated": 50,
#     "total_columns_added": ["col_a", "col_b"],
#     "errors": [],
#     "file_results": [...]  # Per-file result dicts
# }
```

### CLI Usage

```bash
# Ingest all supported files in ./data/
python app/ingest.py

# Ingest a specific file
python app/ingest.py ./data/survey.xlsx

# Ingest a specific directory
python app/ingest.py ./incoming/
```

---

## Logging

### Console Output

Uses bracketed prefixes consistent with the existing codebase pattern:

| Prefix       | Usage                                    |
|--------------|------------------------------------------|
| `[OK]`       | Successful operation                     |
| `[ERROR]`    | Failure requiring attention              |
| `[WARNING]`  | Non-fatal issue, operation continues     |
| `[INFO]`     | Informational status update              |
| `[LOAD]`     | File loading started                     |
| `[SAVE]`     | File save operation                      |
| `[BACKUP]`   | Backup creation                          |
| `[SEARCH]`   | Directory scanning                       |
| `[IMPORT]`   | Ingestion pipeline started               |
| `[DATA]`     | Data operation summary                   |
| `[CLEAN]`    | Column/data normalization                |

### Audit Log (`logs/ingestion.log`)

Structured entries written via Python's `logging` module:

```
2026-02-03 15:30:00 | INFO | INGESTION | source=survey.xlsx | format=xlsx |
encoding=binary | rows_loaded=150 | rows_added=120 | rows_updated=30 |
rows_unchanged=0 | columns_added=2 | total_rows=500 | total_columns=45 |
status=success
```

Each ingestion run produces a complete audit entry including:
- Timestamp
- Source filename
- Detected format and encoding
- Row counts (loaded, added, updated, unchanged)
- Column additions
- Final dataset size
- Success/failure status

---

## Edge Case Handling

| Edge Case                        | Behavior                                              |
|----------------------------------|-------------------------------------------------------|
| Empty file                       | Log warning, skip file, return empty stats (no crash) |
| Headers only, no data rows       | Log warning, skip (require at least 2 rows)           |
| File locked by Excel             | Catch `PermissionError`, log clear tip to close Excel |
| Duplicate column names           | Append numeric suffix (`_1`, `_2`)                    |
| All-NaN rows                     | Dropped before merge                                  |
| Primary key column missing       | Fall back to append-only mode, log warning            |
| Mixed types in column            | Coerced to string for safety                          |
| File with BOM                    | Handled by `utf-8-sig` in encoding cascade            |
| TSV with `.csv` extension        | `csv.Sniffer` detects tab delimiter transparently     |
| Fewer than 3 columns             | Rejected with warning                                 |
| Output files in data directory   | Excluded from directory ingestion scan                 |

---

## Configuration Constants

Defined at the top of `app/ingest.py`:

```python
DATA_DIR = "./data"
OUTPUT_PATH = "./data/cleaned_master.csv"
MASTER_DB_PATH = "./data/master_database.csv"
BACKUP_DIR = "./data/backups"
LOG_DIR = "./logs"
LOG_PATH = "./logs/ingestion.log"

ENCODING_CASCADE = ["utf-8", "utf-8-sig", "cp1252", "latin1"]
SUPPORTED_EXTENSIONS = {".xlsx", ".xls", ".csv", ".tsv"}
PRIMARY_KEY = "company_name"
HEADER_KEYWORDS = ["company", "name", "email", "submitdate", "up -", "in -", "do -"]
```

---

## Dependencies

| Package    | Version   | Purpose                           |
|------------|-----------|-----------------------------------|
| `pandas`   | >= 2.0.0  | DataFrame operations              |
| `openpyxl` | >= 3.0.0  | XLSX file reading                 |
| `numpy`    | >= 1.24.0 | Numeric operations (via pandas)   |

No additional dependencies beyond the existing project requirements.

---

## Integration Notes

- `app/ingest.py` is designed to be imported by the GUI (`ResilienceScanGUI.py`) and
  other modules in later phases.
- The module does not modify `convert_data.py` or `clean_data.py` — those continue to
  operate independently.
- All paths use relative references (`./data/`, `./logs/`) consistent with the existing
  codebase convention.
- The Windows UTF-8 console fix is included in the `if __name__ == "__main__"` block.
