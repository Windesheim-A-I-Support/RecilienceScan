# ResilienceScan Pipeline Execution Order

**Analysis Date:** 2024-02-09
**Subtask:** subtask-1-2
**Analyst:** Claude Code

---

## Executive Summary

The ResilienceScan system has two pipeline implementations:

1. **Legacy CLI Pipeline** - Standalone Python scripts for manual execution
2. **Web Application Pipeline** - FastAPI-based web interface with integrated pipeline orchestration

Both pipelines follow the same conceptual flow but with different implementations.

---

## Canonical Pipeline Flow

The canonical execution order for processing resilience scan data is:

```
1. DATA CONVERSION    (Excel → CSV)
2. DATA CLEANING      (Validation & Fixes)
3. DATA VALIDATION    (Optional Integrity Check)
4. REPORT GENERATION  (CSV → PDF Reports)
5. EMAIL SENDING      (Email Reports to Recipients)
```

---

## Legacy CLI Pipeline

### 1. Data Conversion: `convert_data.py`

**Purpose:** Convert Excel master database to standardized CSV format

**Input:**
- Excel file in `./data/` directory
- Supported patterns (priority order):
  - `Resilience - MasterDatabase*.xlsx`
  - `Resilience - MasterDatabase*.xls`
  - `MasterDatabase*.xlsx`
  - `MasterDatabase*.xls`
  - `*.xlsx`, `*.xls`

**Process:**
1. Search for Excel file (most recent match)
2. Load Excel with format detection (openpyxl/xlrd engines)
3. Detect header row (looks for keywords: 'company', 'name', 'email', 'submitdate', 'up -', 'in -', 'do -')
4. Clean column names (lowercase, remove special chars, standardize)
5. Map column name variations to standard names:
   - `email_id`, `email`, `e-mail` → `email_address`
   - `company`, `organization` → `company_name`
   - `respondent`, `participant` → `name`
   - `date`, `submit_date` → `submitdate`
6. Validate required columns exist:
   - Core: `company_name`, `name`, `email_address`
   - Scores: `up__r`, `up__c`, `up__f`, `up__v`, `up__a`, `in__r`, `in__c`, `in__f`, `in__v`, `in__a`, `do__r`, `do__c`, `do__f`, `do__v`, `do__a`
7. Remove completely empty rows
8. Merge with existing CSV (if exists):
   - Preserves ONLY the `reportsent` column from existing data
   - Updates all other data from new Excel source
   - Adds new records, updates existing records
9. Format date columns (convert Excel serial dates to `YYYY-MM-DD HH:MM:SS`)
10. Create backup in `./data/backups/` (timestamped)

**Output:**
- `./data/cleaned_master.csv`

**Execution:**
```bash
python convert_data.py
```

---

### 2. Data Cleaning: `clean_data.py`

**Purpose:** Fix data quality issues and validate data sufficiency

**Input:**
- `./data/cleaned_master.csv`

**Process:**
1. Create backup of input file
2. Validate required columns exist (`company_name`, `name`)
3. Validate recommended columns exist (`email_address`, `submitdate`, `sector`)
4. Fix company names:
   - Remove rows with empty/null company names
   - Remove rows with invalid values ('-', 'unknown')
   - Trim whitespace
5. Fix person names:
   - Trim whitespace
   - Track empty names (will use 'Unknown' in reports)
6. Fix email addresses:
   - Trim whitespace
   - Validate format with regex: `^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$`
   - Remove rows without valid email addresses
7. Remove duplicate records (same company, name, email)
8. Fix numeric columns:
   - Convert score columns to numeric (coerce errors to NaN)
   - Score columns: `up__*`, `in__*`, `do__*`, `overall_*`
9. Validate data sufficiency:
   - Check for companies with only 1 respondent
   - Check for missing dimension data (>50% missing)
10. Generate cleaning report

**Output:**
- `./data/cleaned_master.csv` (updated in-place)
- `./data/backups/cleaned_master_YYYYMMDD_HHMMSS.csv` (backup)
- Console report of cleaning actions

**Execution:**
```bash
python clean_data.py
```

---

### 3. Data Validation: `validate_data_integrity.py` (Optional)

**Purpose:** Verify data integrity between Excel source and cleaned CSV

**Input:**
- Excel file in `./data/` (same as convert_data.py)
- `./data/cleaned_master.csv`

**Process:**
1. Load original Excel file (same detection logic as convert_data.py)
2. Load cleaned CSV
3. Sample random records (default: 10, configurable)
4. For each sample:
   - Create unique key (company || name || email)
   - Find matching record in CSV
   - Compare all fields (basic fields + score columns)
   - Track perfect matches, acceptable matches (>90%), mismatches
5. Generate integrity report:
   - Statistics (total records, samples validated, accuracy)
   - Detailed sample results
   - Verdict (OK, acceptable, issues detected)

**Output:**
- `./data/integrity_validation_report.txt` (human-readable)
- `./data/integrity_validation_report.json` (detailed JSON log)

**Execution:**
```bash
python validate_data_integrity.py [num_samples]
# Example: python validate_data_integrity.py 20
```

**Note:** This step is diagnostic/optional - not required for normal pipeline operation.

---

### 4. Report Generation

#### Option A: Generate All Reports: `generate_all_reports.py`

**Purpose:** Generate individual PDF reports for ALL entries in CSV

**Input:**
- `./data/cleaned_master.csv`
- `ResilienceReport.qmd` (Quarto template)

**Process:**
1. Load cleaned CSV with encoding/delimiter detection
2. Find required columns (`company_name`, `name`)
3. For each row with valid company name:
   - Get company name and person name (fallback to 'Unknown')
   - Create safe filename: `YYYYMMDD ResilienceScanReport (Company Name - Person Name).pdf`
   - Skip if report already exists
   - Execute Quarto render:
     ```bash
     quarto render "ResilienceReport.qmd" \
       -P company="Company Name" \
       -P person="Person Name" \
       --to pdf \
       --output "temp_Company_Person.pdf"
     ```
   - Move to final location
   - Handle timeouts (120 seconds per report)
4. Generate summary (generated, skipped, failed counts)

**Output:**
- `./reports/YYYYMMDD ResilienceScanReport (Company - Person).pdf` (one per entry)

**Execution:**
```bash
python generate_all_reports.py
```

#### Option B: Generate Single Report: `generate_single_report.py`

**Purpose:** Generate PDF report for ONE specific company/person

**Input:**
- Company name (required, via command line)
- Person name (optional, via command line)
- `ResilienceReport.qmd` (Quarto template)

**Process:**
- Same as generate_all_reports.py but for single entry
- Template reads data from CSV internally using provided company/person parameters

**Output:**
- `./reports/YYYYMMDD ResilienceScanReport (Company - Person).pdf`

**Execution:**
```bash
python generate_single_report.py "Company Name" "Person Name"
# Example: python generate_single_report.py "Suplacon" "Pim Jansen"
```

---

### 5. Email Sending: `send_email.py`

**Purpose:** Email PDF reports to recipients

**Input:**
- `./data/cleaned_master.csv`
- `./reports/*.pdf` (generated reports)

**Process:**
1. Load cleaned CSV
2. Validate required columns (`company_name`, `email_address`, `name`)
3. Scan reports folder for available PDF files
4. Connect to email service:
   - **Primary:** Outlook COM (win32com.client)
     - Tries accounts in order: info@resiliencescan.org, r.deboer@windesheim.nl, cg.verhoef@windesheim.nl, any available
   - **Fallback:** SMTP (smtp.office365.com:587)
5. For each row with valid email:
   - Find matching PDF report using naming convention
   - Skip if no report found (only send emails for completed reports)
   - Build email:
     - Subject: `Your Resilience Scan Report – {company}`
     - Body: Personalized message with attachment
   - Send to recipient (or TEST_EMAIL if TEST_MODE=True)
   - Track sent/failed counts
6. Update `reportsent` column in CSV (planned, not yet implemented)

**Output:**
- Emails sent to recipients
- Console summary (sent, failed counts)

**Execution:**
```bash
python send_email.py
```

**Configuration:**
- `TEST_MODE = True` - Send all emails to TEST_EMAIL instead of real recipients
- `TEST_EMAIL` - Target email for test mode
- `SMTP_SERVER`, `SMTP_PORT`, `SMTP_FROM`, `SMTP_USERNAME`, `SMTP_PASSWORD` - SMTP settings

---

## Web Application Pipeline

### Architecture

Located in `./app/web/`, the web application provides a FastAPI-based interface for pipeline execution.

### Components

1. **pipeline_orchestrator.py** - Orchestrates pipeline execution
2. **run_tracker.py** - Tracks pipeline execution runs
3. **file_handler.py** - Manages file uploads
4. **routes/pipeline.py** - API endpoints for pipeline control

### Pipeline Functions

#### Ingestion: `run_ingestion(filename)`

**Purpose:** Execute P2 ingestion pipeline (replaces convert_data.py + clean_data.py)

**Process:**
1. Create run record in tracker
2. Import `app.ingest.ingest_file` module
3. Find file in `/data/incoming/` (or use specified filename)
4. Execute ingestion
5. Update run status (success/failed)
6. Return run_id and stats

**Implementation:**
```python
from app.ingest import ingest_file
stats = ingest_file(str(file_path))
```

**Note:** The `app.ingest` module appears to be a newer implementation that combines conversion and cleaning.

#### Rendering: `run_rendering(company_name, person_name, output_format)`

**Purpose:** Execute P3 rendering pipeline (uses generate_single_report.py)

**Process:**
1. Create run record in tracker
2. Import `generate_single_report` function
3. Execute rendering with parameters
4. Update run status (success/failed)
5. Return run_id and report_path

**Implementation:**
```python
from generate_single_report import generate_single_report
report_path = generate_single_report(company_name, person_name, output_format)
```

### Web UI Flow

```
User Upload → /data/incoming/ → run_ingestion() → app.ingest.ingest_file()
                                                         ↓
                                                   /data/cleaned_master.csv
                                                         ↓
User Request → run_rendering() → generate_single_report() → /reports/*.pdf
```

---

## Key Dependencies Between Steps

### convert_data.py → clean_data.py
- **Output of convert_data.py is input to clean_data.py**
- Both operate on `./data/cleaned_master.csv`
- clean_data.py expects standardized column names from convert_data.py

### clean_data.py → generate_*_reports.py
- **Reports read the cleaned CSV**
- Required columns: `company_name`, `name`, score columns
- Invalid rows are removed in clean_data.py, so reports only process valid entries

### generate_*_reports.py → send_email.py
- **Email sending depends on reports being generated**
- Emails are only sent for entries with existing PDF reports
- Naming convention must match: `YYYYMMDD ResilienceScanReport (Company - Person).pdf`

### Merge Strategy (convert_data.py)
- **Preserves `reportsent` column across conversions**
- This allows re-running conversion without losing email tracking
- All other data is updated from Excel source

---

## Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    RESILIENCE SCAN PIPELINE                     │
└─────────────────────────────────────────────────────────────────┘

    Excel File                   Step 1: CONVERSION
    (./data/*.xlsx)              convert_data.py
         │                            │
         │                            ├─ Find Excel file
         │                            ├─ Load & detect header
         │                            ├─ Clean column names
         │                            ├─ Map name variations
         │                            ├─ Validate required columns
         │                            ├─ Remove empty rows
         │                            ├─ Merge with existing (preserve reportsent)
         │                            └─ Format dates
         ▼
    cleaned_master.csv           Step 2: CLEANING
    (./data/)                    clean_data.py
         │                            │
         │                            ├─ Create backup
         │                            ├─ Validate columns
         │                            ├─ Fix company names (remove invalid)
         │                            ├─ Fix person names (trim)
         │                            ├─ Fix emails (validate, remove invalid)
         │                            ├─ Remove duplicates
         │                            ├─ Fix numeric columns
         │                            ├─ Validate sufficiency
         │                            └─ Generate report
         ▼
    cleaned_master.csv           Step 3: VALIDATION (Optional)
    (validated)                  validate_data_integrity.py
         │                            │
         │                            ├─ Load Excel source
         │                            ├─ Load cleaned CSV
         │                            ├─ Sample random records
         │                            ├─ Compare fields
         │                            └─ Generate integrity report
         ▼
    ┌──────────────────────┐
    │ cleaned_master.csv   │     Step 4: REPORT GENERATION
    │ ResilienceReport.qmd │     generate_all_reports.py
    └──────────────────────┘     OR generate_single_report.py
         │                            │
         │                            ├─ Load cleaned CSV
         │                            ├─ For each entry:
         │                            │   ├─ Create safe filename
         │                            │   ├─ Render Quarto template
         │                            │   └─ Save PDF report
         │                            └─ Generate summary
         ▼
    PDF Reports                  Step 5: EMAIL SENDING
    (./reports/*.pdf)            send_email.py
         │                            │
         │                            ├─ Load cleaned CSV
         │                            ├─ Scan for PDF reports
         │                            ├─ Connect to email service
         │                            ├─ For each entry with report:
         │                            │   ├─ Find matching PDF
         │                            │   ├─ Build email
         │                            │   └─ Send to recipient
         │                            └─ Track sent/failed
         ▼
    Email Recipients
    (Delivered Reports)
```

---

## Common Execution Patterns

### Full Pipeline (Manual)

```bash
# 1. Convert Excel to CSV
python convert_data.py

# 2. Clean and validate data
python clean_data.py

# 3. (Optional) Validate integrity
python validate_data_integrity.py 10

# 4. Generate all reports
python generate_all_reports.py

# 5. Send emails (test mode first!)
# Edit TEST_MODE in send_email.py before running
python send_email.py
```

### Incremental Update

```bash
# 1. Update Excel file in ./data/
# 2. Re-run conversion (preserves reportsent)
python convert_data.py

# 3. Re-clean data
python clean_data.py

# 4. Generate only new reports (existing reports are skipped)
python generate_all_reports.py

# 5. Send only new emails (reportsent tracking prevents duplicates)
python send_email.py
```

### Single Report Generation

```bash
# 1. Ensure cleaned_master.csv is up to date
python convert_data.py
python clean_data.py

# 2. Generate single report
python generate_single_report.py "Company Name" "Person Name"
```

---

## Error Handling & Recovery

### convert_data.py Failures

**Common Issues:**
- Excel file not found → Check `./data/` directory
- Excel file locked → Close file in Excel
- Missing required columns → Check EXPECTED_CSV_FORMAT.md
- Permission denied → Check folder permissions

**Recovery:**
- Fix source Excel file
- Re-run convert_data.py

### clean_data.py Failures

**Common Issues:**
- cleaned_master.csv not found → Run convert_data.py first
- Missing required columns → Re-check conversion step

**Recovery:**
- Backup is created automatically
- Can restore from `./data/backups/`

### generate_reports.py Failures

**Common Issues:**
- Quarto not installed → Install Quarto
- Timeout (120s) → Slow system or complex template
- Missing data for company → Check cleaned_master.csv

**Recovery:**
- Failed reports can be regenerated individually
- Already-generated reports are skipped (idempotent)

### send_email.py Failures

**Common Issues:**
- Outlook COM not available → Use SMTP fallback
- SMTP credentials missing → Configure SMTP settings
- Report file not found → Generate reports first

**Recovery:**
- Failed emails can be re-sent
- TEST_MODE allows safe testing

---

## Configuration Files

### convert_data.py

```python
DATA_DIR = "./data"
OUTPUT_PATH = "./data/cleaned_master.csv"
BACKUP_DIR = "./data/backups"
```

### clean_data.py

```python
INPUT_PATH = "./data/cleaned_master.csv"
REQUIRED_COLUMNS = ['company_name', 'name']
RECOMMENDED_COLUMNS = ['email_address', 'submitdate', 'sector']
```

### generate_all_reports.py

```python
ROOT = Path(__file__).resolve().parent
TEMPLATE = ROOT / "ResilienceReport.qmd"
DATA = ROOT / "data" / "cleaned_master.csv"
OUTPUT_DIR = ROOT / "reports"
COLUMN_MATCH_COMPANY = "company_name"
COLUMN_MATCH_PERSON = "name"
```

### send_email.py

```python
CSV_PATH = "data/cleaned_master.csv"
REPORTS_FOLDER = "reports"
TEST_MODE = True
TEST_EMAIL = "cg.verhoef@windesheim.nl"
SMTP_SERVER = "smtp.office365.com"
SMTP_PORT = 587
SMTP_FROM = "info@resiliencescan.org"
```

---

## Future Considerations

### Current State
- **Dual implementations:** Legacy CLI + Web app
- **Partial integration:** Web app uses generate_single_report.py but has own ingestion
- **Email tracking:** `reportsent` column exists but not fully utilized

### Recommendations
1. **Consolidate ingestion:** Merge `convert_data.py` + `clean_data.py` logic into `app.ingest`
2. **Batch processing in web app:** Add bulk report generation to web interface
3. **Email integration:** Integrate send_email.py into web app
4. **Email tracking:** Implement `reportsent` column updates in send_email.py
5. **Pipeline status:** Add real-time progress tracking for long-running operations

---

## Conclusion

The ResilienceScan pipeline follows a clear 5-step process:
1. **Convert** (Excel → CSV)
2. **Clean** (Fix quality issues)
3. **Validate** (Optional integrity check)
4. **Generate** (Create PDF reports)
5. **Email** (Deliver reports)

Each step is idempotent and can be re-run safely. The pipeline preserves email tracking across conversions and skips already-completed work where appropriate.
