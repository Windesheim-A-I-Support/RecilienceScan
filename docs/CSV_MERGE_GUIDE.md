# CSV Merge Functionality Guide

## Overview

The `clean_data.py` script now includes **intelligent data merging** to prevent data loss when processing new survey data. Instead of overwriting the existing database, it merges new data with existing records.

## Problem Solved

**Before:** Running `clean_data.py` would **overwrite** `cleaned_master.csv` completely, losing all previous survey data.

**After:** Running `clean_data.py` now:
1. Loads existing `cleaned_master.csv` (if it exists)
2. Creates an automatic timestamped backup
3. Intelligently merges new data with existing data
4. Saves the combined result

## Merge Strategy

The merge logic handles several scenarios:

### 1. New Companies/Respondents
**Scenario:** Completely new survey responses from new companies or people.

**Action:** **APPEND** - Adds new records to the database.

**Example:**
```
Existing: Company A, Company B
New:      Company C
Result:   Company A, Company B, Company C
```

### 2. Updated Data
**Scenario:** New survey responses from existing companies/people (identified by company_name, name, email_address).

**Action:** **UPDATE** - Replaces old records with new ones (keeps most recent).

**Example:**
```
Existing: Company A (score: 85, date: 2025-01-01)
New:      Company A (score: 87, date: 2025-01-20)
Result:   Company A (score: 87, date: 2025-01-20)  ← Updated!
```

### 3. New Fields/Columns
**Scenario:** New survey adds additional fields not present in previous surveys.

**Action:** **ADD COLUMN** - Adds new columns to all records (fills existing with NaN).

**Example:**
```
Existing: [company_name, name, score]
New:      [company_name, name, score, new_field]
Result:   [company_name, name, score, new_field]
          (existing rows have NaN for new_field)
```

### 4. Exact Duplicates
**Scenario:** Same company, same person, same data submitted multiple times.

**Action:** **KEEP MOST RECENT** - Removes duplicates, keeping the last occurrence.

## Merge Key Fields

The merge uses these fields to identify duplicates:
- `company_name`
- `name`
- `email_address`

If these fields match between an existing record and a new record, it's considered the same respondent and will be updated (not duplicated).

## Automatic Backups

Every time `clean_data.py` runs and finds existing data, it creates a backup:

**Backup Location:** `./data/backups/`

**Backup Format:** `cleaned_master_backup_YYYYMMDD_HHMMSS.csv`

**Example:** `cleaned_master_backup_20251024_143025.csv`

### Restoring from Backup

If something goes wrong, you can restore from backup:

```bash
# List backups
ls data/backups/

# Restore specific backup
cp data/backups/cleaned_master_backup_20251024_143025.csv data/cleaned_master.csv
```

## Usage

### Normal Workflow (No Change)

The merge happens **automatically**. Just run `clean_data.py` as before:

```bash
python3 clean_data.py
```

### What You'll See

```
======================================================================
🚀 RESILIENCE DATA CLEANING SCRIPT
======================================================================
🔍 Searching for data files in: ./data
✅ Found data file: ./data/new_survey.xlsx

📂 Loading file: ./data/new_survey.xlsx
   Format detected: Excel (.xlsx)
   ✅ Loaded with openpyxl engine

📊 Raw data shape: 105 rows × 45 columns
🔍 Detecting header row...
✅ Detected header at row 2 (index 1)
📋 Using row 2 as header
📦 Data rows: 103

🧹 Cleaning column names...
   ✅ Cleaned 45 column names

🗑️  Removed 3 empty rows

📚 Existing database found at: ./data/cleaned_master.csv
   ✅ Loaded existing data: 250 rows
   💾 Backup created: ./data/backups/cleaned_master_backup_20251024_143025.csv
   ✅ Backup completed

🔄 Merging data...
   Existing data: 250 rows × 45 columns
   New data:      100 rows × 45 columns
   🔑 Using merge keys: ['company_name', 'name', 'email_address']
   🗑️  Removed 5 duplicate records (kept most recent)
   ✅ Merged result: 345 rows × 45 columns
   📊 Net new records: +95

💾 Saving final data to: ./data/cleaned_master.csv
   ✅ Saved successfully!
   📊 Final shape: 345 rows × 45 columns

======================================================================
✅ SUCCESS: Data cleaning and merging completed!
======================================================================
```

## Testing

A comprehensive test suite is included: `test_merge.py`

Run tests:
```bash
python3 test_merge.py
```

Tests verify:
- ✅ New companies are appended
- ✅ Existing companies are updated
- ✅ New columns are added correctly
- ✅ Duplicates are removed
- ✅ Combined scenarios work end-to-end

## Configuration

You can customize merge behavior in `clean_data.py`:

```python
# Configuration (lines 8-15)
DATA_DIR = "./data"
OUTPUT_PATH = "./data/cleaned_master.csv"
BACKUP_DIR = "./data/backups"

# Merge configuration
MERGE_KEY_FIELDS = ['company_name', 'name', 'email_address']
```

### Customizing Merge Keys

To change which fields identify duplicates, edit `MERGE_KEY_FIELDS`:

```python
# Example: Only use email to identify duplicates
MERGE_KEY_FIELDS = ['email_address']

# Example: Use company and email only
MERGE_KEY_FIELDS = ['company_name', 'email_address']
```

## Troubleshooting

### Issue: "No common key fields found"

**Cause:** Column names in new data don't match existing data.

**Solution:** The script will fall back to simple append (no duplicate removal). Check column names are consistent.

### Issue: Backups taking too much space

**Solution:** Periodically clean old backups:

```bash
# Keep only last 10 backups
cd data/backups
ls -t cleaned_master_backup_*.csv | tail -n +11 | xargs rm
```

### Issue: Need to force overwrite (no merge)

**Solution:** Temporarily rename or move the existing database:

```bash
mv data/cleaned_master.csv data/cleaned_master_old.csv
python3 clean_data.py  # Will create new database
```

## Technical Details

### Functions Added

**`create_backup(file_path)`**
- Creates timestamped backup of file
- Returns backup path or None if failed

**`merge_dataframes(df_existing, df_new)`**
- Merges two DataFrames intelligently
- Handles new columns, duplicates, and updates
- Returns merged DataFrame

### Algorithm

1. Check if `cleaned_master.csv` exists
2. If yes:
   a. Load existing data
   b. Create backup
   c. Merge with new data
3. If no:
   a. Save new data as-is (first run)
4. Save result to `cleaned_master.csv`

### Performance

- **Small datasets (<1000 rows):** Instant
- **Medium datasets (1000-10000 rows):** 1-2 seconds
- **Large datasets (>10000 rows):** 3-10 seconds

Backup creation adds negligible time.

## Migration from Old Version

If you have the old `clean_data.py` (without merge):

1. **Backup your current data manually first:**
   ```bash
   cp data/cleaned_master.csv data/cleaned_master_manual_backup.csv
   ```

2. **Update to new version** (this PR)

3. **Run as normal** - future runs will merge automatically

## Future Enhancements

Potential improvements for future versions:

- [ ] Configurable merge strategies (append-only, update-only, etc.)
- [ ] Merge conflict resolution UI
- [ ] Support for time-series data (keep historical versions)
- [ ] Compression of old backups
- [ ] Email notification on merge conflicts
- [ ] Merge report generation (what changed)

## Related Issues

- [#30 - Implement CSV Field Merging for Database Updates](https://github.com/Windesheim-A-I-Support/RecilienceScan/issues/30)

## Questions?

If you encounter any issues or have questions about the merge functionality, please open an issue on GitHub.
