# Testing Guide

**Date:** 2025-10-17

---

## Prerequisites

Before testing, ensure:
- ✅ `clean_data.py` has been updated
- ✅ `example_3.qmd` has been updated
- ✅ Quarto is working (user confirmed: 2025-10-17)

---

## Step 1: Clean the Data

Run the data cleaning script:

```bash
cd /home/chris/Documents/github/RecilienceScan
python3 clean_data.py
```

**Expected Output:**
```
======================================================================
🚀 RESILIENCE DATA CLEANING SCRIPT
======================================================================
✅ Found data file: ./data/Resilience - MasterDatabase(MasterData).csv
✅ Loaded with encoding=latin1, delimiter=','
✅ Detected header at row 2 (index 1)
✅ Cleaned 178 column names
✅ Saved successfully!
📊 Final shape: 507 rows × 178 columns
======================================================================
✅ SUCCESS: Data cleaning completed!
======================================================================
```

**Verify:**
```bash
ls -lh data/cleaned_master.csv
# Should show the file exists with reasonable size
```

---

## Step 2: Test Single Report Generation

Generate a test report for one company:

```bash
quarto render example_3.qmd -P company="Suplacon" --to pdf --output test_Suplacon.pdf
```

**Expected Behavior:**
- Quarto renders without errors
- PDF is created: `test_Suplacon.pdf`
- File size is reasonable (> 10KB)

**Verify the PDF:**
```bash
ls -lh test_Suplacon.pdf
mv test_Suplacon.pdf reports/
```

---

## Step 3: Verify Radar Chart Values

Open the generated PDF and check the radar chart values against the CSV.

### Get Expected Values from CSV:

```bash
python3 << 'EOF'
import pandas as pd
df = pd.read_csv('./data/cleaned_master.csv')
suplacon = df[df['company_name'] == 'Suplacon'].iloc[0]

print('=== SUPLACON - EXPECTED VALUES FROM CSV ===')
print('\nUpstream Resilience:')
print(f'  R (Redundancy):     {suplacon["up__r"]}')
print(f'  C (Collaboration):  {suplacon["up__c"]}')
print(f'  F (Flexibility):    {suplacon["up__f"]}')
print(f'  V (Visibility):     {suplacon["up__v"]}')
print(f'  A (Agility):        {suplacon["up__a"]}')

print('\nInternal Resilience:')
print(f'  R (Redundancy):     {suplacon["in__r"]}')
print(f'  C (Collaboration):  {suplacon["in__c"]}')
print(f'  F (Flexibility):    {suplacon["in__f"]}')
print(f'  V (Visibility):     {suplacon["in__v"]}')
print(f'  A (Agility):        {suplacon["in__a"]}')

print('\nDownstream Resilience:')
print(f'  R (Redundancy):     {suplacon["do__r"]}')
print(f'  C (Collaboration):  {suplacon["do__c"]}')
print(f'  F (Flexibility):    {suplacon["do__f"]}')
print(f'  V (Visibility):     {suplacon["do__v"]}')
print(f'  A (Agility):        {suplacon["do__a"]}')
EOF
```

### Manual Verification:

1. Open `reports/test_Suplacon.pdf`
2. Look at the radar charts on the first page
3. Compare the values shown in the radar charts with the values printed above
4. **They should match!** ✅

**Expected for Suplacon:**
- Upstream R: 2.6
- Upstream C: 3.25
- Upstream F: 3.5
- Upstream V: 2.25
- Upstream A: 3.33 (approximately)

---

## Step 4: Test Batch Generation

Run the full batch report generation:

```bash
python3 generate_all_reports.py
```

**Expected Output:**
```
✅ Delimiter ',' with encoding 'utf-8'
📄 Generating: Vattenfall
✅ Saved: reports/Vattenfall.pdf
📄 Generating: The_Coca_Cola_Company
✅ Saved: reports/The_Coca_Cola_Company.pdf
📄 Generating: Suplacon
🔁 Skipping Suplacon (already exists)
...
```

**Verify:**
```bash
ls -lh reports/*.pdf
# Should show multiple PDF files
```

---

## Step 5: Spot Check Multiple Companies

Pick 2-3 random companies and verify their radar chart values match the CSV.

### Example: Check Vattenfall

```bash
python3 << 'EOF'
import pandas as pd
df = pd.read_csv('./data/cleaned_master.csv')
company = df[df['company_name'] == 'Vattenfall'].iloc[0]

print('=== VATTENFALL - EXPECTED VALUES ===')
print(f'Upstream R: {company["up__r"]}')
print(f'Upstream C: {company["up__c"]}')
print(f'Upstream F: {company["up__f"]}')
print(f'Upstream V: {company["up__v"]}')
print(f'Upstream A: {company["up__a"]}')
EOF
```

Then open `reports/Vattenfall.pdf` and verify the values match.

---

## Step 6: Test with New Data File

To test the robustness of the new `clean_data.py`:

### Test 6a: Excel File

If you have an Excel version of the master database:
```bash
# Copy Excel file to data directory
cp /path/to/MasterDatabase.xlsx data/

# Run cleaning
python3 clean_data.py

# It should auto-detect and load the Excel file
```

### Test 6b: Different Delimiter

If you have a semicolon-delimited CSV:
```bash
# Copy file to data directory
cp /path/to/data.csv data/

# Run cleaning
python3 clean_data.py

# It should auto-detect the semicolon delimiter
```

---

## Success Criteria

The fix is successful if:

- ✅ `clean_data.py` runs without errors
- ✅ `cleaned_master.csv` is created with correct data
- ✅ Single report generates successfully
- ✅ Radar chart values in PDF match CSV values
- ✅ Batch generation works for all companies
- ✅ No synthetic data is used when CSV exists

---

## Troubleshooting

### Issue: "File not found: data/cleaned_master.csv"
**Solution:** Run `python3 clean_data.py` first

### Issue: Quarto render fails
**Solution:** Check Quarto installation with `quarto check`

### Issue: Radar charts still show wrong values
**Solution:**
1. Delete existing reports: `rm reports/*.pdf`
2. Re-run `python3 clean_data.py`
3. Verify `cleaned_master.csv` exists and has data
4. Try rendering with debug mode: `quarto render example_3.qmd -P company="Test" -P debug_mode=true`

### Issue: Python packages missing
**Solution:**
```bash
pip install pandas openpyxl xlrd
```

---

## Logging Test Results

After testing, document results in `04_TEST_RESULTS.md`:

```bash
cd logs/2025-10-17_radar_chart_fix
# Create test results file with your findings
```

---

## Next Steps After Successful Testing

1. Delete test files: `rm test_*.pdf`
2. Commit changes to git
3. Update documentation
4. Notify users that fix is deployed
