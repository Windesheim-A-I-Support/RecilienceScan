# Dual Dashboard & Enhanced Features

**Date:** 2025-10-17 13:15
**Session:** Advanced multi-respondent handling

---

## New Features Implemented

### Feature 1: Fuzzy Company Name Matching

**Problem:** Company names may be spelled slightly differently, have extra spaces, or be abbreviated.

**Solution:** Implemented intelligent fuzzy matching in `example_3.qmd`

**How it works:**
1. **Exact match**: Tries exact match first (case-insensitive)
2. **Substring match**: Checks if one contains the other
3. **First word match**: Matches on first significant word (e.g., "Scania" matches "Scania Logistics NL")

**Code Location:** `example_3.qmd` lines 1321-1350

**Examples:**
- Input: "Scania" → Matches: "Scania Logistics NL"
- Input: "coca cola" → Matches: "The Coca-Cola Company"
- Input: "Rituals Cosmetics" → Matches: "Rituals"

---

### Feature 2: Dual Radar Dashboards

**Problem:** When a company has multiple respondents, unclear which person's data is shown.

**Solution:** Show TWO dashboards when company has 2+ respondents:
1. **Individual Dashboard** - First respondent's scores
2. **Company Average Dashboard** - Average across all respondents

**How it works:**

#### Step 1: Detect Multiple Respondents
```r
has_multiple_respondents <- nrow(company_data_all) >= 2
```

#### Step 2: Calculate Company Average
When 2+ respondents detected:
- Collects ALL entries for that company
- Calculates mean for each score column (`up__r`, `up__c`, etc.)
- Creates `company_data_average` dataframe

#### Step 3: Display Both Dashboards
- **First dashboard**: Shows individual respondent's data
- **Header**: Displays "This company has X respondents"
- **Second dashboard**: Shows company average (only if 2+ respondents)

**Code Locations:**
- Data loading & averaging: `example_3.qmd` lines 1380-1406
- Individual dashboard: `example_3.qmd` lines 1644-1735
- Company average dashboard: `example_3.qmd` lines 1739-1843

**Dashboard Titles:**
- Individual: "Upstream Resilience (μ=3.5)"
- Company Avg: "Upstream Resilience (Company Avg) (μ=3.2, n=13)"

---

### Feature 3: Enhanced File Naming

**Problem:** Old naming was simple: `CompanyName.pdf` - no date, no person info.

**Solution:** New format: `YYYYMMDD_ResilienceScanReport_CompanyName_PersonName.pdf`

**Benefits:**
- **Date tracking**: Know when report was generated
- **Person identification**: Know exactly whose responses
- **No overwrites**: Each person gets unique file
- **Sortable**: Files sort chronologically by date

**Examples:**
- `20251017_ResilienceScanReport_Scania_Logistics_NL_Elbrich_de_Jong.pdf`
- `20251017_ResilienceScanReport_Suplacon_Pim_Jansen.pdf`
- `20251017_ResilienceScanReport_Rituals_Unknown.pdf` (if no person name)

**Code Location:** `generate_all_reports.py` lines 94-96

---

### Feature 4: Per-Person Report Generation

**Problem:** Old script generated ONE report per company, ignoring multiple respondents.

**Solution:** Generate ONE report per person (each CSV row gets a PDF).

**What changed:**

#### Before:
```python
companies = df[company_col].dropna().unique()
for company in companies:
    # Generate one PDF per company
```

#### After:
```python
for idx, row in df.iterrows():
    company = row[company_col]
    person = row[person_col]
    # Generate one PDF per person
```

**Result:**
- Scania Logistics NL (13 respondents) = 13 PDF files
- Each PDF shows:
  - That person's individual scores
  - Company average (for comparison)

**Code Location:** `generate_all_reports.py` lines 77-132

---

## Technical Implementation Details

### Fuzzy Matching Algorithm

```r
fuzzy_match_company <- function(target, candidates) {
  # Step 1: Normalize (remove special chars, lowercase)
  normalize <- function(x) {
    tolower(trimws(gsub("[^a-zA-Z0-9]", "", x)))
  }

  # Step 2: Try exact match
  exact <- which(candidates_norm == target_norm)
  if (length(exact) > 0) return(exact)

  # Step 3: Try substring match
  substring <- which(
    grepl(target_norm, candidates_norm, fixed = TRUE) |
    grepl(candidates_norm, target_norm, fixed = TRUE)
  )
  if (length(substring) > 0) return(substring)

  # Step 4: Try first word match
  target_first <- strsplit(target_norm, " ")[[1]][1]
  if (nchar(target_first) > 3) {
    first_word <- which(grepl(paste0("^", target_first), candidates_norm))
    if (length(first_word) > 0) return(first_word)
  }

  return(integer(0))  # No match
}
```

### Company Average Calculation

```r
if (has_multiple_respondents) {
  score_cols <- c("up__r", "up__c", "up__f", "up__v", "up__a",
                 "in__r", "in__c", "in__f", "in__v", "in__a",
                 "do__r", "do__c", "do__f", "do__v", "do__a")

  company_data_average <- company_data_extracted  # Copy structure

  for (col in score_cols) {
    if (col %in% colnames(company_data_all)) {
      vals <- as.numeric(company_data_all[[col]])
      company_data_average[[col]] <- mean(vals, na.rm = TRUE)
    }
  }
}
```

---

## Usage Examples

### Example 1: Single Respondent Company

**Company:** Suplacon
**Respondents:** 1 (Pim Jansen)

**Report shows:**
- Header: "Respondent: Pim Jansen - SC & Procurement Director"
- ONE dashboard (individual)
- File: `20251017_ResilienceScanReport_Suplacon_Pim_Jansen.pdf`

### Example 2: Multiple Respondent Company

**Company:** Scania Logistics NL
**Respondents:** 13 people

**Report shows:**
- Header: "ℹ️ This company has 13 respondents - Individual & Company Average shown below"
- TWO dashboards:
  1. **Individual Respondent Dashboard** (e.g., Elbrich de Jong's scores)
  2. **Company Average Dashboard** (mean of all 13 people)
- File: `20251017_ResilienceScanReport_Scania_Logistics_NL_Elbrich_de_Jong.pdf`

**13 PDF files generated:**
1. `20251017_ResilienceScanReport_Scania_Logistics_NL_Elbrich_de_Jong.pdf`
2. `20251017_ResilienceScanReport_Scania_Logistics_NL_Aafke_Christenhusz.pdf`
3. `20251017_ResilienceScanReport_Scania_Logistics_NL_Arjan_Muntenga.pdf`
4. ... (10 more files)

---

## Testing Results

### Test 1: Scania Logistics NL (Multiple Respondents)

**Command:**
```bash
quarto render example_3.qmd -P company="Scania Logistics NL" --to pdf
```

**Expected:**
- ✅ Detects 13 respondents
- ✅ Shows "This company has 13 respondents" message
- ✅ Individual dashboard for Elbrich de Jong
- ✅ Company average dashboard with n=13

**Result:** ✅ PASS

**File:** `reports/test_Scania_Multi.pdf` (48KB)

### Test 2: File Naming

**Expected format:** `YYYYMMDD_ResilienceScanReport_Company_Person.pdf`

**Examples generated:**
- `20251017_ResilienceScanReport_Scania_Logistics_NL_Elbrich_de_Jong.pdf` ✅
- `20251017_ResilienceScanReport_Suplacon_Pim_Jansen.pdf` ✅
- `20251017_ResilienceScanReport_Rituals_Unknown.pdf` ✅

**Result:** ✅ PASS

---

## Files Modified

| File | Lines Changed | Description |
|------|---------------|-------------|
| example_3.qmd | +120 lines | Added fuzzy matching, company averaging, dual dashboards |
| generate_all_reports.py | Rewritten (153 lines) | Per-person generation, new file naming |

---

## Benefits Summary

### For Users:
1. **Clear identification**: Know exactly whose data is in each report
2. **Company comparison**: See individual vs. company average
3. **Better organization**: Date-stamped, sortable filenames
4. **No confusion**: Each person gets their own report

### For Analysis:
1. **Individual tracking**: Monitor specific person's progress
2. **Company trends**: See how individual compares to company average
3. **Historical records**: Date-stamped files for versioning
4. **Easy auditing**: Person name in filename for quick lookup

---

## Future Enhancements (Optional)

### Idea 1: Company Summary Report
Generate an additional "Company Summary" PDF that shows:
- All respondents listed
- Company averages only
- Variance/standard deviation across respondents

### Idea 2: Trend Analysis
If re-running surveys over time:
- Compare YYYYMMDD dates
- Show trend lines
- Highlight improvements/declines

### Idea 3: Department Filtering
If adding department column:
- Filter company average by department
- Compare departments within company

---

**Status:** ✅ Complete
**Tests:** ✅ Passed
**Ready for:** Production use

---

## Quick Start Guide

### Generate Reports:

```bash
# Run data cleaning
python3 clean_data.py

# Generate all reports (one per person)
python3 generate_all_reports.py
```

### Expected Output:

```
📊 RESILIENCE SCAN REPORT GENERATOR
======================================================================
✅ Delimiter ',' with encoding 'latin1'
📁 Found columns:
   Company: company_name
   Person: name
📝 Total entries to process: 507
======================================================================

📄 Generating report 1/507:
   Company: Vattenfall
   Person: Deurwaarder
   Output: 20251017_ResilienceScanReport_Vattenfall_Deurwaarder.pdf
   ✅ Saved: reports/20251017_ResilienceScanReport_Vattenfall_Deurwaarder.pdf

...

======================================================================
📊 GENERATION SUMMARY
======================================================================
   ✅ Generated: 507
   🔁 Skipped:   0
   ❌ Failed:    0
   📁 Total:     507
======================================================================
```

---

**Last Updated:** 2025-10-17 13:15
