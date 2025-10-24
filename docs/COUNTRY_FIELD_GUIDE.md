# Country Field Support Guide

## Overview

The ResilienceScan system now supports a `country` field in the master database, allowing for geographic analysis and filtering of resilience data.

## Problem Solved

**Before:** The `country` field was added to the data model later and was missing from:
- Master data file (cleaned_master.csv)
- Report templates (demo data)
- Documentation

**After:**
- ✅ Country field supported in data schema
- ✅ Templates updated with country field
- ✅ Clean_data.py handles country gracefully
- ✅ Backward compatible (country optional)

## Field Specification

### Field Name
```
country
```

### Data Type
**String** (text)

### Expected Values
Full country names (English), for example:
- Netherlands
- Belgium
- Germany
- France
- United Kingdom

### Position in Schema
The `country` field should appear early in the CSV structure, typically after `company_name`:

```
company_name, country, name, email_address, ...
```

## Adding Country Field to Existing Data

### Method 1: Manual Addition (Excel)

1. Open `data/cleaned_master.csv` in Excel
2. Insert new column after `company_name`
3. Name it `country`
4. Fill in country values for each company
5. Save as CSV (UTF-8)

### Method 2: Python Script

```python
import pandas as df

# Load existing data
df = pd.read_csv('data/cleaned_master.csv')

# Add country column (default to empty or specific value)
if 'country' not in df.columns:
    df.insert(1, 'country', '')  # Insert after company_name

    # Optional: Set default value
    # df['country'] = 'Netherlands'

    # Or map from company names
    country_mapping = {
        'Company A': 'Netherlands',
        'Company B': 'Belgium',
        # ... add more mappings
    }
    df['country'] = df['company_name'].map(country_mapping).fillna('')

# Save
df.to_csv('data/cleaned_master.csv', index=False)
print(f"✅ Added country column. Total columns: {len(df.columns)}")
```

## Backward Compatibility

The system is **fully backward compatible**:

### If Country Field is Present
- ✅ Recognized as "Geographic" field type
- ✅ Included in data analysis
- ✅ Available for filtering and grouping

### If Country Field is Missing
- ✅ System works normally
- ✅ No errors thrown
- ✅ Reports generate successfully
- ℹ️  Geographic analysis simply not available

The template automatically detects and handles the country field using pattern matching:

```r
} else if (grepl("region|country|location|address", col_name)) {
  "Geographic"
```

## Usage in Reports

### Automatic Detection

The country field is automatically recognized in:
- Data validation summaries
- Column analysis reports
- Field categorization

### Demo Data

Sample data now includes country field:

```r
companies <- data.frame(
  company_name = c("GlobalLogistics Corp", "Regional Express Ltd", ...),
  country = c("Netherlands", "Belgium", ...),
  ...
)
```

## Clean Data Script Handling

The `clean_data.py` script handles country field automatically:

### When Processing New Data

1. **Country Present in New Data:**
   - Included in cleaned output
   - Merged with existing data (if country was missing before, it's added)

2. **Country Missing in New Data:**
   - No error thrown
   - Existing country data preserved (if present)
   - New records have empty/NaN for country

### Merge Behavior

When merging data with country field:

```
Existing data: [company_name, name, score]
New data:      [company_name, country, name, score]
Result:        [company_name, country, name, score]
               (existing rows have NaN for country)
```

The merge logic automatically adds new columns like `country` to all records.

## Future Enhancements

Potential features for future versions:

- [ ] Country-based filtering in reports
- [ ] Regional benchmarking (compare countries)
- [ ] Geographic visualization (maps)
- [ ] Multi-language country names
- [ ] Country validation (check valid country names)
- [ ] ISO country codes support (NL, BE, DE, etc.)

## Data Sources

### Survey Forms

If using Formbricks or other survey tools, add country as a field:

**Field Type:** Dropdown or Text Input

**Options (Dropdown):**
- Netherlands
- Belgium
- Germany
- France
- United Kingdom
- Other

### Excel Import

When importing from Power BI/Excel, ensure country column is included in export.

### Manual Entry

For testing or small datasets, country can be added manually to CSV.

## Validation

Currently, **no validation** is performed on country values. Future versions may include:

- Valid country name checking
- ISO code validation
- Standardization (e.g., "The Netherlands" → "Netherlands")

## Examples

### Example CSV Structure (With Country)

```csv
company_name,country,name,email_address,score,submitdate
"Company A","Netherlands","John Doe","john@companya.com",85,2025-01-01
"Company B","Belgium","Jane Smith","jane@companyb.com",90,2025-01-02
"Company C","Germany","Bob Johnson","bob@companyc.com",75,2025-01-03
```

### Example CSV Structure (Without Country - Still Valid)

```csv
company_name,name,email_address,score,submitdate
"Company A","John Doe","john@companya.com",85,2025-01-01
"Company B","Jane Smith","jane@companyb.com",90,2025-01-02
```

Both structures are valid and will work correctly!

## Migration Path

For existing installations:

### Step 1: Update Templates (Done in this PR)
- ✅ ResilienceReport.qmd updated with country field
- ✅ ExecutiveDashboard.qmd updated with country field
- ✅ Sample data includes country

### Step 2: Add Country to Existing Data (Manual)
```bash
# Backup first
cp data/cleaned_master.csv data/cleaned_master_backup.csv

# Add country column (use Python script above or manual Excel edit)
```

### Step 3: Include Country in Future Surveys
- Update survey forms to collect country
- Update Excel export templates
- Train users to include country

## Troubleshooting

### Issue: Country column appears but is empty

**Solution:** Existing data doesn't have country values. This is normal. Fill in values manually or via script.

### Issue: Reports show "Unknown" for geographic analysis

**Solution:** Country field is missing or empty. Add country data to CSV.

### Issue: New data has country but existing doesn't

**Solution:** No problem! The merge will add the country column to existing records (filled with NaN/empty). You can backfill later.

## Related Issues

- [#31 - Add 'country' Field to Master Data and Dashboard](https://github.com/Windesheim-A-I-Support/RecilienceScan/issues/31)
- [#30 - CSV Merging](https://github.com/Windesheim-A-I-Support/RecilienceScan/issues/30) - Handles new column addition

## Questions?

If you have questions about adding or using the country field, please open an issue on GitHub.
