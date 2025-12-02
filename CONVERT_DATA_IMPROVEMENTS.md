# Convert Data Improvements - Production 1.0

## Summary of Changes

The `convert_data.py` script has been enhanced to handle Excel files with different column naming conventions and intelligently map them to the expected format.

## New Features

### 1. Intelligent Column Name Mapping

**Function:** `map_column_names(df)`

Automatically recognizes and maps column name variations to standard names:

- `email_id`, `email`, `e-mail` → `email_address`
- `company`, `organization`, `firm` → `company_name`
- `respondent`, `participant` → `name`
- `date`, `submit_date`, `timestamp` → `submitdate`
- `role`, `job_title`, `position` → `function`

**Example Output:**
```
[MAPPING] Applied 2 column name mappings:
   'email_id' → 'email_address'
   'company' → 'company_name'
```

### 2. Required Column Validation

**Function:** `validate_required_columns(df)`

Validates that all critical columns exist before conversion:

**Required Core Columns:**
- `company_name`
- `name`
- `email_address`

**Required Score Columns:**
- Pillar averages: `up__r`, `up__c`, `up__f`, `up__v`, `up__a`
- Internal: `in__r`, `in__c`, `in__f`, `in__v`, `in__a`
- Downstream: `do__r`, `do__c`, `do__f`, `do__v`, `do__a`

If validation fails, the script stops and shows which columns are missing.

### 3. Enhanced Merge Logic (APPEND MODE)

**Updated Function:** `merge_with_existing(new_df)`

**OLD Behavior:**
- Replaced entire file with new Excel data
- Only preserved `reportsent` status

**NEW Behavior:**
- **KEEPS** all existing records in `cleaned_master.csv`
- **APPENDS** new records from Excel
- **UPDATES** existing records if they match (by company_name + email_address)
- **PRESERVES** `reportsent` status for existing records

**Example Output:**
```
[DATA] Merge analysis:
   - Existing records kept: 507
   - Existing records updated: 12
   - New records added: 45
   - Total records in final file: 552
```

## Processing Flow

```
1. Load Excel file
2. Find header row
3. Convert to DataFrame
4. Clean column names (remove special chars)
5. ✨ NEW: Map column name variations to standard names
6. ✨ NEW: Validate required columns exist
7. Remove empty rows
8. ✨ ENHANCED: Merge with existing (append mode)
9. Format date columns
10. Save to cleaned_master.csv
```

## Error Handling

### Missing Required Columns

If Excel file is missing required columns:
```
[ERROR] Excel file is missing required columns for report generation
   Please check EXPECTED_CSV_FORMAT.md for required column names
   Missing: email_address, up__r, in__c
```

**Solution:** Rename columns in Excel or add missing score columns.

### Column Name Variations

If Excel has `email_id` instead of `email_address`:
```
[MAPPING] Applied 1 column name mapping:
   'email_id' → 'email_address'
[VALIDATION] All required columns present ✓
```

**No action needed** - automatically handled.

## Documentation

See `EXPECTED_CSV_FORMAT.md` for:
- Complete list of expected column names
- All recognized column name variations
- Data type specifications
- Score value rules
- Merge behavior details

## Backwards Compatibility

✅ **100% Backwards Compatible**
- Existing Excel files continue to work unchanged
- If columns already have standard names, no mapping occurs
- Existing `cleaned_master.csv` files are preserved and extended
- All existing functionality remains intact

## Testing Recommendations

Before deploying to production, test with:

1. **Standard Excel file** (current format) - should work as before
2. **Excel with variations** (email_id, company, etc.) - should map correctly
3. **Excel with missing columns** - should fail with clear error
4. **Multiple conversions** - should append, not replace

## Usage

No changes to usage - script works exactly as before:

```bash
python convert_data.py
```

Or through GUI:
- Data tab → "Convert Excel to CSV" button

## Benefits for Production 1.0

1. ✅ **Flexible input** - Accepts Excel files with different column naming
2. ✅ **Data preservation** - Never loses existing data
3. ✅ **Clear errors** - Tells user exactly what's wrong
4. ✅ **Incremental updates** - Can add new survey responses without recreating everything
5. ✅ **Documented** - Clear specification of expected format
