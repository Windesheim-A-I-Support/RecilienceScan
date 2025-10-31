# ResilienceScan Test Scenarios

## Overview
This document outlines comprehensive test scenarios for the ResilienceScan report generation pipeline to ensure data accuracy, visual consistency, and proper email delivery.

## Test Data Requirements

### Sample Test Companies
Create test data with known expected values for verification:

1. **Perfect Score Company** - All dimensions = 5.0
2. **Average Company** - All dimensions = 3.0
3. **Low Score Company** - All dimensions = 1.5
4. **Mixed Performance Company** - Varying scores across dimensions
   - Upstream: R=2.6, C=3.3, F=3.5, V=2.3, A=3.3 (Expected avg: 2.8)
   - Internal: R=3.2, C=3.4, F=3.1, V=3.0, A=3.2 (Expected avg: 3.18)
   - Downstream: R=2.8, C=3.0, F=2.9, V=2.7, A=3.1 (Expected avg: 2.9)
   - Overall SCRES: 2.96

5. **Company with Missing Data** - Some NA values to test handling
6. **Company with Question Marks** - Survey responses with "?" to verify conversion

---

## Test Scenario 1: Data Conversion & Cleaning

### Objective
Verify that Excel data is correctly converted to CSV and cleaned properly.

### Steps
1. Place test Excel file in `./data/` folder
2. Run `python convert_data.py`
3. Verify `./data/cleaned_master.csv` is created
4. Run `python clean_data.py`
5. Check backup is created in `./data/backups/`

### Expected Results
- ✅ CSV file created with correct encoding (UTF-8)
- ✅ All column names cleaned and standardized (lowercase, underscores)
- ✅ `reportsent` column exists and defaults to False
- ✅ Rows without company_name are removed
- ✅ Rows without email_address are removed
- ✅ Duplicate records removed
- ✅ Score columns converted to numeric (? → NA)
- ✅ Backup created with timestamp

### Validation Checks
```python
import pandas as pd
df = pd.read_csv('./data/cleaned_master.csv')

# Check required columns exist
assert 'company_name' in df.columns
assert 'name' in df.columns
assert 'email_address' in df.columns
assert 'reportsent' in df.columns

# Check no empty companies
assert df['company_name'].notna().all()
assert (df['company_name'].astype(str).str.strip() != '').all()

# Check no empty emails
assert df['email_address'].notna().all()

# Check score columns are numeric
score_cols = [col for col in df.columns if col.startswith(('up__', 'in__', 'do__'))]
for col in score_cols:
    assert pd.api.types.is_numeric_dtype(df[col])
```

---

## Test Scenario 2: Report Generation - Chart Values

### Objective
Verify that radar charts display correct individual dimension scores.

### Test Company: "Mixed Performance Company"
**Expected Upstream Values:**
- Redundancy (R): 2.6
- Collaboration (C): 3.3
- Flexibility (F): 3.5
- Visibility (V): 2.3
- Agility (A): 3.3

### Steps
1. Create test data row with known values
2. Run `python generate_all_reports.py`
3. Open generated PDF for Mixed Performance Company
4. Inspect Upstream Resilience radar chart

### Expected Results
- ✅ Chart shows R=2.6 (not 3.0 or other default value)
- ✅ Chart shows C=3.3
- ✅ Chart shows F=3.5
- ✅ Chart shows V=2.3
- ✅ Chart shows A=3.3
- ✅ All 5 dimensions have different values (not all identical)

### Visual Verification
- Chart axes labeled correctly
- Values plotted at correct positions
- No "NaN" displayed anywhere

**Related Issue:** [I004 - Chart values incorrect](https://github.com/Windesheim-A-I-Support/RecilienceScan/issues/70)

---

## Test Scenario 3: Report Generation - Chart Dimension Order

### Objective
Verify that radar charts display dimensions in clockwise order: R-C-F-V-A starting from top.

### Steps
1. Generate report for any test company
2. Open PDF and examine all 4 radar charts (Upstream, Internal, Downstream, Overall)

### Expected Results for Each Chart
Starting from **12 o'clock position** and moving **clockwise**:
- ✅ Position 1 (Top): **Redundancy (R)**
- ✅ Position 2 (Right-top): **Collaboration (C)**
- ✅ Position 3 (Right-bottom): **Flexibility (F)**
- ✅ Position 4 (Bottom): **Visibility (V)**
- ✅ Position 5 (Left): **Agility (A)**

### Current Bug
Charts currently show order: R - A - V - F - C (incorrect)

**Related Issue:** [I005 - Chart order incorrect](https://github.com/Windesheim-A-I-Support/RecilienceScan/issues/71)

---

## Test Scenario 4: Report Generation - Average Calculations

### Objective
Verify that pillar averages (μ) are calculated and displayed correctly.

### Test Company: "Mixed Performance Company"
**Expected Calculations:**
- Upstream μ = (2.6 + 3.3 + 3.5 + 2.3 + 3.3) / 5 = **2.8**
- Internal μ = (3.2 + 3.4 + 3.1 + 3.0 + 3.2) / 5 = **3.18**
- Downstream μ = (2.8 + 3.0 + 2.9 + 2.7 + 3.1) / 5 = **2.9**

### Steps
1. Generate report for Mixed Performance Company
2. Check chart titles for each pillar

### Expected Results
- ✅ Upstream chart title shows: "Upstream Resilience (μ=2.8)"
- ✅ Internal chart title shows: "Internal Resilience (μ=3.2)" or "μ=3.18"
- ✅ Downstream chart title shows: "Downstream Resilience (μ=2.9)"
- ✅ NO "NaN" values displayed

### Common Bugs to Check
- Displaying NaN instead of calculated average
- Showing wrong decimal precision
- Using default values (2.5, 3.0) instead of actual calculations

**Related Issue:** [I006 - Average incorrect](https://github.com/Windesheim-A-I-Support/RecilienceScan/issues/72)

---

## Test Scenario 5: Report Generation - Overall SCRES

### Objective
Verify that the Overall SCRES (Supply Chain Resilience Score) is calculated correctly.

### Test Company: "Mixed Performance Company"
**Expected Calculation:**
Overall SCRES = (Upstream μ + Internal μ + Downstream μ) / 3
= (2.8 + 3.18 + 2.9) / 3
= **2.96** or **3.0/5.0** (rounded)

### Steps
1. Generate report for Mixed Performance Company
2. Check the Overall SCRES displayed in report

### Expected Results
- ✅ Overall SCRES shows: **2.96/5.00** or **3.0/5.0**
- ✅ NOT showing incorrect value like 2.75/5.00

### Validation Points
- Check if calculation is mean of 3 pillars
- Verify question marks (?) in data are handled as NA
- Confirm rounding method matches requirements

**Related Issue:** [I007 - Overall SCRES incorrect](https://github.com/Windesheim-A-I-Support/RecilienceScan/issues/73)

---

## Test Scenario 6: Report Generation - Highest/Lowest Contributors

### Objective
Verify that text about highest and lowest performing dimensions is displayed.

### Steps
1. Generate report for Mixed Performance Company
2. Locate "Detailed Analysis" or similar section
3. Check for contributor text

### Expected Results
- ✅ Text identifies **highest scoring dimension** (e.g., "Flexibility")
- ✅ Shows specific items contributing to high score (bullet points)
- ✅ Text identifies **lowest scoring dimension** (e.g., "Visibility")
- ✅ Shows specific items for improvement (bullet points)
- ✅ NOT showing only "NA" or blank content

### Example Expected Output
```
Items that contribute to a high level of Flexibility are:
- Alternative transportation options available
- Alternative suppliers available
- Flexible production capacity

Areas for improvement in Visibility include:
- Limited real-time supply chain tracking
- Insufficient data sharing with partners
```

**Related Issue:** [I002 - Missing contributor text](https://github.com/Windesheim-A-I-Support/RecilienceScan/issues/68)

---

## Test Scenario 7: Report Layout - Logo Positioning

### Objective
Verify that logos are positioned correctly according to design requirements.

### Expected Layout
1. **Top of page**: NEXT Gen Resilience logo (centered)
2. **Bottom or stacked vertically**:
   - Windesheim logo
   - Involvation logo
   - RUG (University of Groningen) logo

### Steps
1. Generate any report
2. Open first page of PDF
3. Inspect logo positioning

### Expected Results
- ✅ NEXT Gen Resilience logo is centered at top
- ✅ Win/Inv/RUG logos arranged vertically (under each other)
- ✅ OR Win/Inv/RUG logos at very bottom of page
- ✅ Logos properly sized and aligned
- ✅ Professional, clean appearance

**Related Issue:** [I001 - Logo layout](https://github.com/Windesheim-A-I-Support/RecilienceScan/issues/67)

---

## Test Scenario 8: Email Delivery - Sender Address

### Objective
Verify emails are sent from the correct address: contact@resiliencescan.org

### Steps
1. Configure email settings in `send_email.py`
2. Set `TEST_MODE = True`
3. Set `TEST_EMAIL` to your test email address
4. Run `python send_email.py`
5. Check received email

### Expected Results
- ✅ Email received successfully
- ✅ **From address**: contact@resiliencescan.org
- ✅ NOT from: personal Outlook account or wrong address
- ✅ Subject line correct
- ✅ PDF attachment included
- ✅ Email body formatted correctly

### Test Mode Verification
- Email should indicate "[TEST MODE]" in body
- Should show "originally intended for: [real_email]"
- Sent to TEST_EMAIL address, not production address

**Related Issue:** [I003 - Wrong sender address](https://github.com/Windesheim-A-I-Support/RecilienceScan/issues/69)

---

## Test Scenario 9: Email Delivery - Correct Recipients

### Objective
Verify that each company receives the correct report.

### Test Data Setup
Create 3 test companies with different emails:
1. Company A - email_a@example.com
2. Company B - email_b@example.com
3. Company C - email_c@example.com

### Steps
1. Generate reports for all 3 companies
2. Run email script in TEST_MODE
3. Verify TEST_EMAIL receives 3 emails

### Expected Results
- ✅ 3 emails received (one per company)
- ✅ Each email has correct company name in subject
- ✅ Each email has correct PDF attachment for that company
- ✅ Email body mentions correct company name
- ✅ Test mode indicates correct original recipient

### Validation
Check PDF filename matches email recipient:
- Email 1: "YYYYMMDD ResilienceScanReport (Company A - Person Name).pdf"
- Email 2: "YYYYMMDD ResilienceScanReport (Company B - Person Name).pdf"
- Email 3: "YYYYMMDD ResilienceScanReport (Company C - Person Name).pdf"

---

## Test Scenario 10: End-to-End Integration Test

### Objective
Complete workflow from Excel to email delivery.

### Steps
1. **Data Conversion**: Place test Excel file with 5 test companies
2. **Run Conversion**: `python convert_data.py`
3. **Clean Data**: `python clean_data.py`
4. **Generate Reports**: `python generate_all_reports.py`
5. **Send Emails**: `python send_email.py` (TEST_MODE=True)

### Expected Results at Each Stage

**After convert_data.py:**
- ✅ CSV created in ./data/cleaned_master.csv
- ✅ 5 rows of data (5 companies)
- ✅ reportsent column = False for all

**After clean_data.py:**
- ✅ Backup created
- ✅ Data cleaned (no errors in output)
- ✅ Still 5 rows (no valid data removed)

**After generate_all_reports.py:**
- ✅ 5 PDF files in ./reports/ folder
- ✅ Each PDF named correctly with date + company + person
- ✅ All PDFs render correctly (no LaTeX errors)
- ✅ Charts show correct values
- ✅ Logos positioned correctly
- ✅ Contributor text displayed

**After send_email.py:**
- ✅ 5 emails sent to TEST_EMAIL
- ✅ Each email has correct attachment
- ✅ Sent from contact@resiliencescan.org
- ✅ Log shows successful sends

### Performance Benchmarks
- Conversion: < 30 seconds
- Cleaning: < 10 seconds
- Report generation: < 5 minutes for 5 reports
- Email sending: < 2 minutes for 5 emails

---

## Test Scenario 11: Edge Cases & Error Handling

### Objective
Test system behavior with problematic data.

### Test Cases

#### 11.1 Missing Values
**Test Data:** Company with some dimension scores as NA
**Expected:**
- ✅ Chart plots available values
- ✅ Average calculated using `na.rm=TRUE`
- ✅ No "NaN" displayed to user
- ✅ Report generates successfully

#### 11.2 Question Mark Responses
**Test Data:** Survey responses with "?" in score columns
**Expected:**
- ✅ clean_data.py converts "?" to NA
- ✅ Score columns are numeric type
- ✅ Averages calculated correctly ignoring ?
- ✅ No errors during report generation

#### 11.3 Company with No Email
**Test Data:** Row with company_name but empty email_address
**Expected:**
- ✅ Row removed during clean_data.py
- ✅ Warning message in console
- ✅ No report generated for this company
- ✅ No email attempt made

#### 11.4 Duplicate Companies
**Test Data:** Same company_name + email_address appears twice
**Expected:**
- ✅ Duplicate removed (keep first occurrence)
- ✅ Only 1 report generated
- ✅ Only 1 email sent
- ✅ Logged in cleaning summary

#### 11.5 Special Characters in Names
**Test Data:** Company name "Smith & Co / Logistics"
**Expected:**
- ✅ Filename sanitized: "Smith_Co_Logistics"
- ✅ Display name readable: "Smith & Co - Logistics"
- ✅ Report generates successfully
- ✅ Email sends successfully

#### 11.6 Very Long Company Names
**Test Data:** Company name > 100 characters
**Expected:**
- ✅ Filename truncated if necessary
- ✅ Full name displayed in report content
- ✅ No file system errors
- ✅ Report readable

---

## Test Scenario 12: Multi-User Company Testing

### Objective
Verify correct handling when a company has multiple respondents.

### Test Data
Company "Multi-Person Inc" with 3 employees:
- John Doe (john@multi.com)
- Jane Smith (jane@multi.com)
- Bob Johnson (bob@multi.com)

### Steps
1. Add 3 rows to test data (same company, different people)
2. Run complete pipeline

### Expected Results
- ✅ 3 separate PDF reports generated
- ✅ Each PDF shows individual person's scores
- ✅ Company average charts shown if ≥2 respondents
- ✅ 3 separate emails sent to different addresses
- ✅ Each email has correct person's report attached

### Validation
- Individual reports show person-specific radar charts
- Company average section appears in all 3 reports
- Company average correctly calculated from all 3 respondents

---

## Regression Testing Checklist

After any code changes, run this checklist:

- [ ] All 7 GitHub issues (I001-I007) are resolved
- [ ] Data conversion works with sample Excel file
- [ ] Data cleaning removes invalid rows correctly
- [ ] Chart values match expected scores
- [ ] Chart dimensions in correct order (R-C-F-V-A)
- [ ] Pillar averages (μ) calculated correctly
- [ ] Overall SCRES calculated correctly
- [ ] Highest/lowest contributor text displayed
- [ ] Logos positioned correctly
- [ ] Emails sent from contact@resiliencescan.org
- [ ] Correct PDFs attached to correct emails
- [ ] No LaTeX errors during PDF generation
- [ ] No Python errors during any stage
- [ ] Test mode works correctly
- [ ] Production mode disabled by default (safety)

---

## Automated Testing (Future Enhancement)

### Unit Tests to Implement
```python
# tests/test_data_conversion.py
def test_excel_to_csv_conversion():
    # Test Excel → CSV conversion
    pass

def test_column_name_cleaning():
    # Test column name standardization
    pass

# tests/test_data_cleaning.py
def test_remove_empty_companies():
    # Test removal of rows without company_name
    pass

def test_duplicate_removal():
    # Test duplicate detection and removal
    pass

def test_question_mark_conversion():
    # Test ? → NA conversion
    pass

# tests/test_calculations.py
def test_pillar_average_calculation():
    # Test average calculation for each pillar
    assert calculate_pillar_avg([2.6, 3.3, 3.5, 2.3, 3.3]) == 2.8
    pass

def test_overall_scres_calculation():
    # Test overall SCRES calculation
    assert calculate_overall_scres(2.8, 3.18, 2.9) == pytest.approx(2.96, 0.01)
    pass

# tests/test_report_generation.py
def test_report_pdf_created():
    # Test PDF file is created
    pass

def test_radar_chart_values():
    # Test radar chart contains correct values
    pass

# tests/test_email_delivery.py
def test_email_sender_address():
    # Test email From address is correct
    pass

def test_correct_attachment():
    # Test correct PDF attached to email
    pass
```

---

## Manual Testing Sign-off

After completing all test scenarios, sign off:

**Tester Name:** _____________________

**Date:** _____________________

**Results:**
- [ ] All test scenarios passed
- [ ] All GitHub issues (I001-I007) verified as resolved
- [ ] Edge cases handled correctly
- [ ] Ready for production deployment

**Notes:**
_______________________________________________________
_______________________________________________________
_______________________________________________________

---

## Contact for Testing Issues

If you encounter any issues during testing:
- Create a new GitHub issue with "TEST:" prefix
- Include specific test scenario number
- Attach relevant screenshots or error logs
- Tag with "testing" label
