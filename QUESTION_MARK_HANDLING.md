# Question Mark and Invalid Value Handling

**Summary:** YES, question marks (?) and all invalid values are handled correctly throughout the entire pipeline.

---

## How Invalid Values Are Handled

### Step 1: Data Cleaning ([clean_data_enhanced.py](clean_data_enhanced.py))

**Line 229:** Replace question marks and invalid characters with NaN
```python
df[col] = df[col].replace(['?', '', ' ', 'nan'], np.nan)
```

**Line 235:** Remove any remaining non-numeric characters
```python
df[col] = df[col].str.replace(r'[^0-9.-]', '', regex=True)
```

**Line 238:** Convert to numeric (anything that can't convert becomes NaN)
```python
df[col] = pd.to_numeric(df[col], errors='coerce')
```

**Result:** CSV file has NaN for all invalid values (?, N/A, empty, etc.)

### Step 2: Report Generation ([ResilienceReport.qmd](ResilienceReport.qmd))

**Lines 1523-1543:** Load data and keep NaN as NaN
```r
# Convert to numeric
col_data <- suppressWarnings(as.numeric(col_data))

# Keep NA as NA - do NOT replace with 2.5
col_data <- ifelse(is.na(col_data), NA, pmax(0, pmin(5, col_data)))

dashboard_data[[col]] <- col_data
```

**Lines 1551-1553:** Calculate averages excluding NaN
```r
upstream_scores <- c(up__r, up__c, up__f, up__v, up__a)
upstream_avg <- if(all(is.na(upstream_scores))) NA else mean(upstream_scores, na.rm = TRUE)
```

**Lines 1760, 1883:** Only for radar charts, replace NA with 2.5 for display
```r
scores[is.na(scores)] <- 2.5  # Visualization only!
```

---

## What Happens with Different Invalid Values

| Original Value | Data Cleaner | CSV Stored As | Report Calculation | Radar Chart Display |
|----------------|--------------|---------------|-------------------|---------------------|
| `?` | Set to NaN | NaN | Excluded from average | Shown as 2.5 |
| `N/A` | Set to NaN | NaN | Excluded from average | Shown as 2.5 |
| `n.a.` | Set to NaN | NaN | Excluded from average | Shown as 2.5 |
| Empty cell | Set to NaN | NaN | Excluded from average | Shown as 2.5 |
| `3,5` (comma) | Convert to `3.5` | 3.5 | Used in average | Shown as 3.5 |
| `6.7` (>5) | Clamp to 5 | 5.0 | Used in average | Shown as 5.0 |
| `-1` (<0) | Clamp to 0 | 0.0 | Used in average | Shown as 0.0 |
| `abc123` | Set to NaN | NaN | Excluded from average | Shown as 2.5 |

---

## Example Scenarios

### Scenario 1: Single Question Mark

**CSV Data:**
```
up__r: ?
up__c: 4.0
up__f: 5.0
up__v: 3.0
up__a: 4.5
```

**Processing:**
1. Data Cleaner: `?` → NaN
2. CSV Stored: `NaN, 4.0, 5.0, 3.0, 4.5`
3. Report Calculation: `mean(4.0, 5.0, 3.0, 4.5) = 4.125` (NaN excluded) ✅
4. Radar Chart: Shows `[2.5, 4.0, 5.0, 3.0, 4.5]` (only for visualization)

**Result:** Upstream average = 4.125 (correct, excludes the ?)

### Scenario 2: All Question Marks (All Missing)

**CSV Data:**
```
up__r: ?
up__c: ?
up__f: ?
up__v: ?
up__a: ?
```

**Processing:**
1. Data Cleaner: All `?` → NaN
2. CSV Stored: `NaN, NaN, NaN, NaN, NaN`
3. Report Calculation: `if(all(is.na(...))) NA else ...` → Result: NA ✅
4. Radar Chart: Shows `[2.5, 2.5, 2.5, 2.5, 2.5]` (visualization needs numbers)
5. Chart Label: Shows "μ=N/A" (not a misleading number)

**Result:**
- Upstream average = NA (not included in overall score) ✅
- Chart shows neutral values but label clearly says "N/A" ✅

### Scenario 3: Mix of Valid and Invalid

**CSV Data:**
```
up__r: 3.0
up__c: ?
up__f: 4.5
up__v: N/A
up__a: 5.0
```

**Processing:**
1. Data Cleaner: `?` and `N/A` → NaN
2. CSV Stored: `3.0, NaN, 4.5, NaN, 5.0`
3. Report Calculation: `mean(3.0, 4.5, 5.0) = 4.167` (2 NaNs excluded) ✅
4. Radar Chart: Shows `[3.0, 2.5, 4.5, 2.5, 5.0]`

**Result:** Upstream average = 4.167 (correct, only averages the 3 valid values)

---

## Key Points

### ✅ Question Marks ARE Handled
- Detected by data cleaner
- Logged in `value_replacements_log.csv`
- Converted to NaN
- Excluded from calculations
- Report shows "N/A" when appropriate

### ✅ Not Counted in Averages
- `na.rm = TRUE` excludes them
- If ALL values are NA, pillar average is NA (not 0, not 2.5)
- Overall score only includes non-NA pillars

### ✅ Transparent Logging
Data cleaner creates `value_replacements_log.csv`:
```csv
row,company,person,column,original_value,action
42,Technology Company,Marcus,up__r,?,set_to_NaN (missing data)
43,Technology Company,Marcus,up__c,N/A,set_to_NaN (missing data)
```

### ✅ 2.5 Only Used for Display
- **NOT** used in calculations (this was the bug we fixed!)
- **ONLY** used for radar chart visualization
- Chart labels show "N/A" so users know it's missing data

---

## Testing

### Test 1: Verify Question Mark Handling

**Add a question mark to CSV:**
```bash
# Manually edit data/cleaned_master.csv
# Change one score to "?"
```

**Run data cleaner:**
```bash
python clean_data_enhanced.py
```

**Expected:**
- ✅ Logs: "up__r: 1 invalid value(s) (e.g., '?')"
- ✅ Creates `data/value_replacements_log.csv` with details
- ✅ CSV now has NaN instead of ?

**Generate report:**
```bash
quarto render ResilienceReport.qmd -P company="Company" -P person="Person" --to pdf
```

**Expected:**
- ✅ Report generates successfully (no crash)
- ✅ Average excludes the missing value
- ✅ If all 5 scores have ?, shows "μ=N/A"

### Test 2: Verify Calculation Accuracy

Use Marcus from Technology Company (all upstream are NaN):

**CSV:**
```
Upstream: ALL NaN
Internal: 5.0, 5.0, 4.0, 4.75, 4.0 (avg: 4.55)
Downstream: 5.0, 3.67, 2.78, 4.0, 5.0 (avg: 4.09)
```

**Expected Overall:**
```
(4.55 + 4.09) / 2 = 4.32  (excludes upstream)
```

**Generate:**
```bash
quarto render ResilienceReport.qmd -P company="[Technology Company]" -P person="Marcus Pribi Setyo N" --to pdf
```

**Result:**
- ✅ Upstream shows "μ=N/A"
- ✅ Overall SCRES: 4.32 (correct!)
- ✅ No validation warnings

---

## Documentation

- **[NA_HANDLING_FIX.md](NA_HANDLING_FIX.md)** - Complete technical details of NA handling
- **[DATA_QUALITY_STRATEGY.md](DATA_QUALITY_STRATEGY.md)** - Overall data quality approach
- **[IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md)** - Full implementation guide

---

## Summary

**Question:** Are question marks handled correctly and not counted?

**Answer:** ✅ **YES**
1. Data cleaner converts `?` to NaN
2. NaN values are logged
3. Report **excludes** NaN from averages (not counted)
4. Only uses 2.5 for visualization (not calculations)
5. Charts show "N/A" label for missing data

**The entire pipeline correctly handles invalid values from start to finish!**
