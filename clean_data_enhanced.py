import pandas as pd
import numpy as np
import os
import re
from pathlib import Path
from datetime import datetime
import shutil
import json

# Configuration
DATA_DIR = "./data"
INPUT_PATH = "./data/cleaned_master.csv"
BACKUP_DIR = "./data/backups"
VALIDATION_LOG = "./data/cleaning_validation_log.json"
CLEANING_REPORT = "./data/cleaning_report.txt"

# Required columns for report generation
REQUIRED_COLUMNS = ['company_name', 'name', 'email_address']
SCORE_COLUMNS = ['up__r', 'up__c', 'up__f', 'up__v', 'up__a',
                 'in__r', 'in__c', 'in__f', 'in__v', 'in__a',
                 'do__r', 'do__c', 'do__f', 'do__v', 'do__a']

class DataCleaningValidator:
    def __init__(self):
        self.issues = []
        self.warnings = []
        self.info = []
        self.removed_records = []
        self.statistics = {
            'initial_rows': 0,
            'final_rows': 0,
            'removed_rows': 0,
            'records_with_insufficient_data': 0,
            'records_with_no_scores': 0,
            'duplicates_removed': 0
        }

    def log_issue(self, level, message, row_info=None):
        """Log an issue with details"""
        entry = {
            'level': level,
            'message': message,
            'timestamp': datetime.now().isoformat()
        }
        if row_info:
            entry['row'] = row_info

        if level == 'ERROR':
            self.issues.append(entry)
        elif level == 'WARNING':
            self.warnings.append(entry)
        else:
            self.info.append(entry)

        # Print to console (using ASCII symbols for Windows compatibility)
        symbol = '[X]' if level == 'ERROR' else '[!]' if level == 'WARNING' else '[i]'
        print(f"{symbol} [{level}] {message}")

    def create_backup(self, file_path):
        """Create a timestamped backup of a file."""
        if not Path(file_path).exists():
            self.log_issue('WARNING', f"Input file not found: {file_path}")
            return None

        os.makedirs(BACKUP_DIR, exist_ok=True)
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = Path(file_path).stem
        ext = Path(file_path).suffix
        backup_path = os.path.join(BACKUP_DIR, f"{filename}_{timestamp}{ext}")

        shutil.copy2(file_path, backup_path)
        self.log_issue('INFO', f"Backup created: {backup_path}")
        return backup_path

    def validate_columns(self, df):
        """Validate that required columns exist"""
        print("\n" + "="*70)
        print("COLUMN VALIDATION")
        print("="*70)

        df_cols_lower = [col.lower() for col in df.columns]
        missing_required = []

        for req_col in REQUIRED_COLUMNS:
            if req_col.lower() not in df_cols_lower:
                missing_required.append(req_col)
                self.log_issue('ERROR', f"Required column '{req_col}' not found")

        if missing_required:
            raise ValueError(f"Missing required columns: {missing_required}")

        # Check score columns
        missing_scores = []
        for score_col in SCORE_COLUMNS:
            if score_col.lower() not in df_cols_lower:
                missing_scores.append(score_col)

        if missing_scores:
            self.log_issue('WARNING', f"Missing score columns: {missing_scores}")

        self.log_issue('INFO', f"All required columns present: {REQUIRED_COLUMNS}")

    def validate_record_completeness(self, df):
        """Check each record for sufficient data to generate a report"""
        print("\n" + "="*70)
        print("RECORD COMPLETENESS VALIDATION")
        print("="*70)

        records_to_keep = []

        for idx, row in df.iterrows():
            issues_found = []

            # Check company name
            if pd.isna(row.get('company_name')) or str(row.get('company_name', '')).strip() == '':
                issues_found.append('No company name')

            # Check person name
            if pd.isna(row.get('name')) or str(row.get('name', '')).strip() == '':
                issues_found.append('No person name')

            # Check email
            if pd.isna(row.get('email_address')) or '@' not in str(row.get('email_address', '')):
                issues_found.append('Invalid/missing email')

            # Count available scores
            available_scores = 0
            for score_col in SCORE_COLUMNS:
                if score_col in df.columns:
                    val = row[score_col]
                    if pd.notna(val) and val not in ['?', '', ' ']:
                        try:
                            float_val = float(str(val).replace(',', '.'))
                            if 0 <= float_val <= 5:
                                available_scores += 1
                        except:
                            pass

            # Determine if record is usable
            min_scores_required = 5  # At least 5 valid scores needed

            if issues_found:
                self.log_issue('WARNING',
                             f"Row {idx + 2}: {', '.join(issues_found)}",
                             {
                                 'company': row.get('company_name', 'N/A'),
                                 'person': row.get('name', 'N/A'),
                                 'email': row.get('email_address', 'N/A')
                             })
                self.removed_records.append({
                    'row': idx + 2,
                    'company': row.get('company_name', 'N/A'),
                    'person': row.get('name', 'N/A'),
                    'reason': ', '.join(issues_found)
                })
                continue

            if available_scores < min_scores_required:
                self.log_issue('WARNING',
                             f"Row {idx + 2}: Insufficient data ({available_scores}/15 scores)",
                             {
                                 'company': row.get('company_name', 'N/A'),
                                 'person': row.get('name', 'N/A'),
                                 'available_scores': available_scores
                             })
                self.removed_records.append({
                    'row': idx + 2,
                    'company': row.get('company_name', 'N/A'),
                    'person': row.get('name', 'N/A'),
                    'reason': f'Only {available_scores} valid scores (need {min_scores_required})'
                })
                self.statistics['records_with_insufficient_data'] += 1
                continue

            records_to_keep.append(idx)

        if records_to_keep:
            df_clean = df.iloc[records_to_keep].copy()
            self.log_issue('INFO', f"Kept {len(records_to_keep)}/{len(df)} records after validation")
            return df_clean
        else:
            self.log_issue('ERROR', "No valid records remaining after validation!")
            return pd.DataFrame()

    def clean_score_columns(self, df):
        """Clean and convert score columns to numeric"""
        print("\n" + "="*70)
        print("SCORE COLUMN CLEANING")
        print("="*70)

        for col in SCORE_COLUMNS:
            if col in df.columns:
                # Convert to string first, handle NaN
                df[col] = df[col].astype(str)

                # Replace question marks and empty strings with NaN
                df[col] = df[col].replace(['?', '', ' ', 'nan'], np.nan)

                # Replace comma with period for European decimals
                df[col] = df[col].str.replace(',', '.')

                # Convert to numeric
                df[col] = pd.to_numeric(df[col], errors='coerce')

                # Clip to valid range [0, 5]
                df[col] = df[col].clip(lower=0, upper=5)

        self.log_issue('INFO', f"Cleaned {len(SCORE_COLUMNS)} score columns")
        return df

    def remove_duplicates(self, df):
        """Remove duplicate records"""
        print("\n" + "="*70)
        print("DUPLICATE DETECTION")
        print("="*70)

        before_count = len(df)

        # Check for duplicates based on company + email
        duplicates = df.duplicated(subset=['company_name', 'email_address'], keep='first')
        duplicate_count = duplicates.sum()

        if duplicate_count > 0:
            self.log_issue('WARNING', f"Found {duplicate_count} duplicate records (keeping first occurrence)")
            self.statistics['duplicates_removed'] = duplicate_count
            df = df[~duplicates]
        else:
            self.log_issue('INFO', "No duplicates found")

        return df

    def save_validation_log(self):
        """Save detailed validation log"""
        # Convert numpy int64 to Python int for JSON serialization
        stats = {k: int(v) if isinstance(v, (np.int64, np.int32)) else v
                 for k, v in self.statistics.items()}

        log_data = {
            'timestamp': datetime.now().isoformat(),
            'statistics': stats,
            'errors': self.issues,
            'warnings': self.warnings,
            'info': self.info,
            'removed_records': self.removed_records
        }

        with open(VALIDATION_LOG, 'w') as f:
            json.dump(log_data, f, indent=2)

        self.log_issue('INFO', f"Validation log saved: {VALIDATION_LOG}")

    def generate_report(self):
        """Generate human-readable cleaning report"""
        lines = []
        lines.append("="*70)
        lines.append("DATA CLEANING REPORT")
        lines.append(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        lines.append("="*70)

        lines.append("\nSTATISTICS:")
        lines.append(f"  Initial rows: {self.statistics['initial_rows']}")
        lines.append(f"  Final rows: {self.statistics['final_rows']}")
        lines.append(f"  Removed rows: {self.statistics['removed_rows']}")
        lines.append(f"  Duplicates removed: {self.statistics['duplicates_removed']}")
        lines.append(f"  Records with insufficient data: {self.statistics['records_with_insufficient_data']}")

        lines.append("\nREMOVED RECORDS:")
        if self.removed_records:
            for record in self.removed_records:
                lines.append(f"  Row {record['row']}: {record['company']} - {record['person']}")
                lines.append(f"    Reason: {record['reason']}")
        else:
            lines.append("  None")

        lines.append("\nERRORS:")
        if self.issues:
            for issue in self.issues:
                lines.append(f"  {issue['message']}")
        else:
            lines.append("  None")

        lines.append("\nWARNINGS:")
        if self.warnings:
            for warning in self.warnings[:20]:  # Limit to first 20
                lines.append(f"  {warning['message']}")
            if len(self.warnings) > 20:
                lines.append(f"  ... and {len(self.warnings) - 20} more warnings")
        else:
            lines.append("  None")

        lines.append("\n" + "="*70)
        lines.append("RECOMMENDATIONS:")
        if self.statistics['removed_rows'] > 0:
            lines.append(f"  [OK] {self.statistics['removed_rows']} records were excluded from the master CSV")
            lines.append("  [OK] These records will NOT be available for report generation")
            lines.append("  [OK] Review removed records above to ensure data quality")

        if self.statistics['final_rows'] == 0:
            lines.append("  [!] WARNING: No valid records remaining!")
            lines.append("  [!] Check source data quality")
        else:
            lines.append(f"  [OK] {self.statistics['final_rows']} valid records ready for report generation")

        lines.append("="*70)

        report_text = '\n'.join(lines)

        with open(CLEANING_REPORT, 'w') as f:
            f.write(report_text)

        print("\n" + report_text)
        self.log_issue('INFO', f"Cleaning report saved: {CLEANING_REPORT}")

def clean_and_fix():
    """
    Main function compatible with GUI workflow.
    Returns (success: bool, summary: str) tuple.
    """
    validator = DataCleaningValidator()

    # Check if input file exists
    if not Path(INPUT_PATH).exists():
        validator.log_issue('ERROR', f"Input file not found: {INPUT_PATH}")
        return False, "File not found - please run 'Convert Data' first"

    # Create backup
    backup_path = validator.create_backup(INPUT_PATH)

    # Load data
    validator.log_issue('INFO', f"Loading data from: {INPUT_PATH}")
    try:
        df = pd.read_csv(INPUT_PATH, low_memory=False)
        validator.statistics['initial_rows'] = len(df)
        validator.log_issue('INFO', f"Loaded {len(df)} rows, {len(df.columns)} columns")
    except Exception as e:
        validator.log_issue('ERROR', f"Failed to load CSV: {e}")
        return False, f"Failed to load CSV: {e}"

    # Standardize column names
    df.columns = df.columns.str.lower().str.strip()

    # Validate columns
    try:
        validator.validate_columns(df)
    except ValueError as e:
        validator.log_issue('ERROR', str(e))
        validator.save_validation_log()
        validator.generate_report()
        return False, str(e)

    # Clean score columns
    df = validator.clean_score_columns(df)

    # Validate record completeness
    df = validator.validate_record_completeness(df)

    if df.empty:
        validator.log_issue('ERROR', "No valid records after cleaning!")
        validator.statistics['final_rows'] = 0
        validator.statistics['removed_rows'] = validator.statistics['initial_rows']
        validator.save_validation_log()
        validator.generate_report()
        return False, "All records were removed during validation - no valid data remaining"

    # Remove duplicates
    df = validator.remove_duplicates(df)

    # Update statistics
    validator.statistics['final_rows'] = len(df)
    validator.statistics['removed_rows'] = validator.statistics['initial_rows'] - validator.statistics['final_rows']

    # Ensure reportsent column exists
    if 'reportsent' not in df.columns:
        df['reportsent'] = False
        validator.log_issue('INFO', "Added 'reportsent' column (default: False)")

    # Save cleaned data
    try:
        df.to_csv(INPUT_PATH, index=False)
        validator.log_issue('INFO', f"Saved cleaned data: {INPUT_PATH}")
    except Exception as e:
        validator.log_issue('ERROR', f"Failed to save CSV: {e}")
        return False, f"Failed to save cleaned data: {e}"

    # Save validation artifacts
    validator.save_validation_log()
    validator.generate_report()

    print("\n" + "="*70)
    print("[OK] CLEANING COMPLETED SUCCESSFULLY")
    print("="*70)
    print(f"[DATA] Final dataset: {validator.statistics['final_rows']} records")
    print(f"[REMOVED] Removed: {validator.statistics['removed_rows']} records")
    print(f"[REPORT] Cleaning report: {CLEANING_REPORT}")
    print(f"[LOG] Validation log: {VALIDATION_LOG}")
    print("="*70)

    # Build summary for GUI
    summary_parts = []
    if validator.statistics['removed_rows'] > 0:
        summary_parts.append(f"Removed {validator.statistics['removed_rows']} invalid/incomplete record(s)")
    if validator.statistics['duplicates_removed'] > 0:
        summary_parts.append(f"Removed {validator.statistics['duplicates_removed']} duplicate(s)")
    if validator.statistics['records_with_insufficient_data'] > 0:
        summary_parts.append(f"Excluded {validator.statistics['records_with_insufficient_data']} record(s) with insufficient data")

    if not summary_parts:
        summary = "All records passed validation - no changes needed!"
    else:
        summary = "\n".join(summary_parts)

    summary += f"\n\nFinal dataset: {validator.statistics['final_rows']} valid records ready for reports"
    summary += f"\n\nDetailed reports saved to:\n- {CLEANING_REPORT}\n- {VALIDATION_LOG}"

    return True, summary

def main():
    """Standalone execution wrapper"""
    print("="*70)
    print("ENHANCED DATA CLEANING WITH VALIDATION")
    print("="*70)

    success, summary = clean_and_fix()

    if success:
        print("\n[SUCCESS] Data cleaning completed successfully!")
    else:
        print("\n[FAILED] Data cleaning failed!")
        print(f"Reason: {summary}")

    return success

if __name__ == "__main__":
    success = main()
    exit(0 if success else 1)
