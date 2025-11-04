# Manual Testing Guide

## Overview
This guide provides step-by-step instructions for manually testing all new features to ensure nothing broke and all features work as expected.

**Automated Validation Status:** ✅ All 12 automated tests passed
- Data quality dashboard script works
- Data cleaner script works
- All parameters configured correctly
- GUI checkboxes and buttons present
- Email priority fallback configured

**Now test these features manually in the GUI:**

---

## Test 1: Existing Functionality (Baseline Test)

**Purpose:** Verify nothing broke in existing features

### Steps:
1. Launch GUI: `python ResilienceScanGUI.py`
2. Go to **Data** tab
3. Click **Load Data** - verify 467 records load
4. Go to **Reports** tab
5. Select company: **Abbott**
6. Select person: **Lisa Daly**
7. **DO NOT** check Debug Mode or Demo Mode
8. Click **Generate Single Report**

### Expected Results:
- ✅ Report generates successfully without errors
- ✅ PDF opens automatically
- ✅ Report shows correct company name: Abbott
- ✅ Report shows correct person name: Lisa Daly
- ✅ Report does NOT have debug table at end
- ✅ Scores match data from CSV

### Validation Check:
Open `data/cleaned_master.csv` and verify Abbott - Lisa Daly scores match report.

---

## Test 2: Debug Mode Feature

**Purpose:** Verify debug mode adds raw data table to end of report

### Steps:
1. In GUI, still on **Reports** tab
2. Company: **Abbott**
3. Person: **Lisa Daly**
4. ✅ **CHECK** "Debug Mode (show raw data table at end of report)"
5. ❌ **UNCHECK** Demo Mode
6. Click **Generate Single Report**

### Expected Results:
- ✅ Report generates successfully
- ✅ Report has a new page at the very end
- ✅ New page titled: "Debug: Raw Score Values"
- ✅ Table shows:
  - Company: Abbott | Person: Lisa Daly
  - All 15 raw scores (up__r, up__c, up__f, up__v, up__a, in__r, etc.)
  - Average values for Upstream, Internal, Downstream
  - Overall SCRES score
- ✅ Values in debug table match CSV data exactly

### What This Proves:
- Debug mode parameter is passed correctly
- Conditional rendering works
- Correct person's data is being used
- No impact on report when debug mode is off

---

## Test 3: Demo Mode Feature

**Purpose:** Verify demo mode generates report with synthetic data

### Steps:
1. In GUI, still on **Reports** tab
2. Company: **Any company** (doesn't matter)
3. Person: **Any person** (doesn't matter)
4. ❌ **UNCHECK** Debug Mode
5. ✅ **CHECK** "Demo Mode (use synthetic test data)"
6. Click **Generate Single Report**

### Expected Results:
- ✅ Report generates successfully
- ✅ Report shows synthetic/random data (NOT real CSV data)
- ✅ All charts render properly
- ✅ No errors or crashes
- ✅ Values are reasonable (between 0-5)

### What This Proves:
- Demo mode parameter is passed correctly
- Report can generate without depending on CSV data
- Useful for testing template changes without real data

---

## Test 4: Both Modes Together

**Purpose:** Verify debug and demo modes work together

### Steps:
1. In GUI, **Reports** tab
2. Company: **Any**
3. Person: **Any**
4. ✅ **CHECK** "Debug Mode"
5. ✅ **CHECK** "Demo Mode"
6. Click **Generate Single Report**

### Expected Results:
- ✅ Report generates with synthetic data
- ✅ Debug table appears at end showing the synthetic values used
- ✅ No errors

### What This Proves:
- Both parameters can be active simultaneously
- Debug table shows synthetic data when demo mode is on

---

## Test 5: Quality Dashboard Button

**Purpose:** Verify quality dashboard button generates analysis

### Steps:
1. Go to **Data** tab
2. Verify data is loaded (467 records)
3. Click **🔍 Run Quality Dashboard** button
4. Wait for processing

### Expected Results:
- ✅ Output text box fills with quality analysis:
  - Missing values analysis
  - Value distribution analysis
  - Out of range values check
  - Completion rate analysis
  - Overall quality score (0-100)
- ✅ Popup appears showing PNG file location
- ✅ PNG file created in `data/quality_reports/`
- ✅ PNG shows 4-panel dashboard:
  - Missing values chart
  - Score distribution histogram
  - Completion rate distribution
  - Score distribution by pillar (boxplots)

### What This Proves:
- Quality dashboard button works
- Script runs in background thread
- Visual dashboard generated correctly
- Data quality monitoring is functional

---

## Test 6: Data Cleaner Button

**Purpose:** Verify data cleaner button processes data correctly

### Steps:

**Setup - Create test data with invalid values:**
1. Open `data/cleaned_master.csv` in Excel
2. Find Abbott - Lisa Daly row
3. Change `up__r` value to `?`
4. Change `up__c` value to `N/A`
5. Save file

**Run cleaner:**
6. In GUI, **Data** tab
7. Click **🧹 Run Data Cleaner** button
8. Wait for processing

### Expected Results:
- ✅ Backup created in `data/backups/` with timestamp
- ✅ Output shows cleaning report:
  - "up__r: 1 invalid value(s) (e.g., '?')"
  - "up__c: 1 invalid value(s) (e.g., 'N/A')"
  - "Total invalid values replaced: 2"
- ✅ Alert popup appears mentioning replacements
- ✅ File created: `data/value_replacements_log.csv`
- ✅ Log shows:
  - Row number
  - Company: Abbott
  - Person: Lisa Daly
  - Column: up__r, up__c
  - Original values: ?, N/A
  - Action: set_to_NaN_then_2.5
- ✅ Data auto-reloads in GUI
- ✅ Opening `data/cleaned_master.csv` shows values now 2.5

**Cleanup:**
9. Restore original CSV from backup or reload from source

### What This Proves:
- Data cleaner detects invalid values
- Replacements are logged with full details
- Backups are created before changes
- Auto-reload works after cleaning

---

## Test 7: Batch Generation with Person Parameter

**Purpose:** Verify batch generation uses individual person data

### Steps:
1. Go to **Reports** tab
2. ❌ **UNCHECK** both Debug Mode and Demo Mode
3. Click **Start All Reports** (batch generation)
4. Wait for completion

### Expected Results:
- ✅ All reports generate successfully
- ✅ Each person gets their own unique report
- ✅ Check 2-3 reports from same company (e.g., Abbott):
  - Abbott - Lisa Daly: Shows Lisa's unique scores
  - Abbott - Harold Rietveld: Shows Harold's unique scores
  - Scores are DIFFERENT between these two reports
- ✅ No errors in generation log

### Validation Check:
Compare 2 reports from Abbott:
- Lisa Daly vs Harold Rietveld
- Their Upstream/Internal/Downstream averages should be different
- This proves person parameter is working

---

## Test 8: Email Priority Fallback

**Purpose:** Verify email sending uses correct account priority

### Steps:
1. Generate a report for any person
2. Go to **Send Email** tab
3. Select the generated report
4. Enter recipient: **your.test@email.com**
5. Click **Send Selected Emails**
6. **READ THE LOG OUTPUT CAREFULLY**

### Expected Results:
Log should show one of these:
- ✅ `[OK] Using priority account: info@resiliencescan.org` (ideal)
- ✅ `[OK] Using priority account: r.deboer@windesheim.nl` (fallback 1)
- ✅ `[OK] Using priority account: cg.verhoef@windesheim.nl` (fallback 2)
- ✅ `[INFO] No priority account available, using: [some.other@account.com]` (fallback 3)
- ✅ `[INFO] Outlook not available, using SMTP...` (final fallback)

### What This Proves:
- Email priority system works
- System tries accounts in correct order
- Fallback logic is functional
- User is informed which method was used

---

## Test 9: Invalid Data Handling in Report

**Purpose:** Verify report doesn't crash with bad data

### Steps:

**Setup - Create test data:**
1. Open `data/cleaned_master.csv`
2. Find Abbott - Lisa Daly
3. Change several scores to: `?`, `N/A`, `3,5` (European comma), blank
4. Save file

**Generate report WITHOUT cleaning:**
5. In GUI, **Reports** tab
6. Select Abbott - Lisa Daly
7. ✅ **CHECK** Debug Mode (to see what values are used)
8. Click **Generate Single Report**

### Expected Results:
- ✅ Report generates successfully (NO CRASH!)
- ✅ Invalid values replaced with 2.5 automatically
- ✅ European comma `3,5` converted to `3.5`
- ✅ Debug table shows final cleaned values (2.5 where invalid, 3.5 for comma)
- ✅ Report looks normal, just uses 2.5 for missing data

**Cleanup:**
9. Run data cleaner or restore from backup

### What This Proves:
- Robust data cleaning in ResilienceReport.qmd works
- Report never crashes from bad data
- Bad values replaced with neutral midpoint (2.5)
- European number formats handled

---

## Test 10: Validation Script

**Purpose:** Verify validation script still detects errors correctly

### Steps:
1. Generate report for Abbott - Lisa Daly (normal mode, no debug/demo)
2. Open command prompt in project folder
3. Run: `python validate_single_report.py "reports\[report_filename].pdf" Abbott "Lisa Daly"`

### Expected Results:
- ✅ Script extracts scores from PDF
- ✅ Compares against CSV data
- ✅ Shows validation result: PASS or FAIL with details
- ✅ If scores match: "Validation PASSED"
- ✅ If scores differ: Shows expected vs actual values

### What This Proves:
- Validation still works after all changes
- Report data accuracy can be verified
- Person parameter fix is working (each person has unique data)

---

## Summary Checklist

After completing all tests, verify:

- [ ] Test 1: Existing functionality works (baseline)
- [ ] Test 2: Debug mode adds table at end
- [ ] Test 3: Demo mode uses synthetic data
- [ ] Test 4: Both modes work together
- [ ] Test 5: Quality dashboard button generates analysis
- [ ] Test 6: Data cleaner button processes invalid data
- [ ] Test 7: Batch generation gives each person unique data
- [ ] Test 8: Email priority fallback works
- [ ] Test 9: Report handles invalid data gracefully
- [ ] Test 10: Validation script still works

---

## Troubleshooting

### If a test fails:

1. **Check logs:**
   - `gui_log.txt` - GUI errors
   - `data/cleaning_report.txt` - Data cleaner output
   - Console output when running scripts

2. **Check generated files:**
   - `data/value_replacements_log.csv` - Data corrections
   - `data/quality_reports/*.png` - Quality dashboards
   - `test_reports/validation_report_*.txt` - Automated test results

3. **Common issues:**
   - **Report won't generate:** Check Quarto is installed, check data loaded
   - **Debug table not showing:** Verify checkbox was checked before generation
   - **Wrong person data:** Check person parameter is being passed (see Test 7)
   - **Email fails:** Check Outlook is running, check account exists

---

## Automated Tests Already Passed

✅ Data file exists (467 records)
✅ Quality dashboard script runs
✅ Data cleaner script runs
✅ Debug mode parameter configured
✅ Demo mode parameter configured
✅ Person parameter configured
✅ Robust data cleaning implemented
✅ GUI checkboxes configured
✅ GUI quality buttons configured
✅ GUI passes all parameters to Quarto
✅ Generate_all_reports passes person parameter
✅ Email priority fallback configured

**All 12 automated tests passed** - Now complete manual tests above!

---

## Next Steps After Testing

1. If all tests pass → System is ready for production use
2. If any test fails → Review error logs and fix issues
3. Document any additional issues found
4. Train users on new features (debug mode, quality dashboard, data cleaner)

---

**Testing Date:** ____________
**Tester Name:** ____________
**Overall Status:** [ ] PASS  [ ] FAIL
**Notes:** ________________________________
