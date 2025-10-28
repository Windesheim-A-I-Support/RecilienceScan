# Data Folder

This folder contains the sensitive data files used by ResilienceScan.

## Required Files

### Initial Setup
Place your master database file here:
- **Recommended name**: `Resilience - MasterDatabase.xlsx`
- **Format**: Excel file (.xlsx or .xls)
- **Contents**: Your company/contact database with relevant columns

## Files Generated

- `cleaned_master.csv` - The main data file used by the application
- `backups/` folder - Timestamped backups created before updates

## First Time Setup (2 Steps)

### Step 1: Convert Data
1. Place your Excel database file (`.xlsx` or `.xls`) in this folder
2. Run the "Convert Data" function from the GUI (Data tab) or run `python convert_data.py`
3. This converts your Excel file to `cleaned_master.csv`
   - Cleans column names (lowercase, underscores, no special chars)
   - If `cleaned_master.csv` already exists: **updates it** with new data
   - **IMPORTANT**: Preserves the `reportsent` column (email tracking status)
   - Creates automatic backup before updating

### Step 2: Clean Data
1. Run the "Clean Data" function from the GUI (Data tab) or run `python clean_data.py`
2. This **fixes data quality issues** in `cleaned_master.csv`
   - Validates required columns exist (company_name, name)
   - Removes rows with invalid company names (empty, "-", "unknown")
   - Fixes non-numeric values in score columns
   - Trims whitespace from names and emails
   - Creates backup before cleaning
   - **Modifies the file in-place**

### When to Run Each Step

- **Convert Data**: Every time you have new/updated Excel data
  - Updates CSV while preserving email tracking
- **Clean Data**: After converting, to fix data quality issues
  - Ensures reports will generate without errors

## Important Notes

- All `.csv`, `.xlsx`, `.xls`, and `.parquet` files in this folder are **ignored by git** to protect sensitive information
- The `backups/` folder is also ignored by git
- Only this README file is tracked in version control
- Never commit sensitive data files to the repository

## File Privacy

These data files contain sensitive company and contact information and should:
- Never be shared publicly
- Never be committed to version control
- Be backed up securely in your own backup system
