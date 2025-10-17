# Root Cause Analysis

**Date:** 2025-10-17
**Analyst:** Claude (AI Assistant)

---

## Investigation Process

### Step 1: Understanding the Workflow

The RecilienceScan project has this workflow:

```
CSV Data → clean_data.py → cleaned_master.csv → example_3.qmd (via generate_all_reports.py) → PDF Reports
```

### Step 2: Analysis of Each Component

#### 2.1 File: `clean_data.py`

**Purpose:** Convert raw CSV to cleaned format

**Issue Found:**
- Line 13: `lines = list(csv.reader(f, delimiter=";"))`
- **WRONG DELIMITER!** The CSV uses commas (`,`), not semicolons (`;`)

**Result:**
- Script fails to parse the CSV correctly
- `cleaned_master.csv` is NEVER created
- File doesn't exist in `/data/` directory

**Evidence:**
```bash
$ ls -la data/
-rw-rw-r--  1 chris chris  469482 okt 17 11:41 Resilience - MasterDatabase(MasterData).csv
# Notice: NO cleaned_master.csv file!
```

#### 2.2 File: `example_3.qmd`

**Purpose:** Generate PDF report with radar charts

**Issue Found:**
- Lines 640-1301: Data loading code is wrapped in `eval=params$data_guide_mode`
- This means data is ONLY loaded when guide mode is enabled
- `generate_all_reports.py` does NOT enable guide mode
- Therefore, NO real data is ever loaded

**Fallback Behavior (Lines 1338-1352):**
```r
if (is.null(dashboard_data)) {
  set.seed(abs(sum(utf8ToInt(company_name))))
  base_score <- runif(1, 2.2, 4.3)
  variations <- runif(15, -0.9, 0.9)
  scores <- pmax(0.5, pmin(4.8, base_score + variations))
  # These SYNTHETIC scores are used in radar charts!
}
```

**Result:**
- System generates FAKE random scores
- Uses company name as seed (so always same fake values per company)
- Radar charts display these synthetic values, not real CSV data

#### 2.3 Radar Chart Code (Lines 1516-1544)

**Code:**
```r
create_radar <- function(prefix, title, color) {
  scores <- c(
    dashboard_data[[paste0(prefix, "__r")]][1],
    dashboard_data[[paste0(prefix, "__c")]][1],
    dashboard_data[[paste0(prefix, "__f")]][1],
    dashboard_data[[paste0(prefix, "__v")]][1],
    dashboard_data[[paste0(prefix, "__a")]][1]
  )
  # Creates radar from dashboard_data (which contains synthetic data!)
}
```

**Result:**
- Radar charts pull from `dashboard_data`
- `dashboard_data` contains synthetic/random values
- Real CSV values are never used

---

## Root Causes Identified

### Primary Root Cause 1: clean_data.py Delimiter Bug
- **File:** `clean_data.py:13`
- **Issue:** Uses semicolon delimiter for comma-delimited CSV
- **Impact:** `cleaned_master.csv` never created

### Primary Root Cause 2: Conditional Data Loading
- **File:** `example_3.qmd:640-1301`
- **Issue:** Data loading only happens in guide mode (never enabled)
- **Impact:** Real data never loaded, falls back to synthetic data

### Secondary Issues:
- No validation that cleaned_master.csv exists before running reports
- No warning messages when synthetic data is used
- No file format auto-detection in clean_data.py
- Hard-coded semicolon delimiter assumption

---

## Data Flow Visualization

### CURRENT (BROKEN) FLOW:
```
CSV (commas)
    ↓
clean_data.py (expects semicolons) → FAILS ❌
    ↓
cleaned_master.csv → DOESN'T EXIST ❌
    ↓
example_3.qmd → data_guide_mode=FALSE (default)
    ↓
NO DATA LOADED ❌
    ↓
Fallback: Generate synthetic random data
    ↓
Radar charts show FAKE VALUES ❌
```

### EXPECTED (CORRECT) FLOW:
```
CSV (any format)
    ↓
clean_data.py (auto-detect delimiter) → SUCCESS ✅
    ↓
cleaned_master.csv → CREATED ✅
    ↓
example_3.qmd → ALWAYS load real data
    ↓
REAL DATA LOADED ✅
    ↓
Radar charts show CORRECT VALUES ✅
```

---

## Conclusion

The radar charts show incorrect values because:

1. **clean_data.py can't parse the CSV** (wrong delimiter)
2. **cleaned_master.csv is never created**
3. **example_3.qmd only loads data in guide mode** (which is never enabled)
4. **System falls back to generating synthetic random data**
5. **Radar charts display the fake synthetic data**

This explains why ALL companies show wrong values - they're all getting synthetic data seeded by their company name.

---

## Next Steps

See `02_SOLUTION_IMPLEMENTED.md` for the fix.
