import os
import json
import pandas as pd
from pathlib import Path
from datetime import datetime
import subprocess
import re
import PyPDF2

# Configuration
ROOT = Path(__file__).resolve().parent
DATA = ROOT / "outputs" / "cleaned_master.csv"  # Docker path: /app/outputs/cleaned_master.csv
REPORTS_DIR = ROOT / "reports"  # Docker path: /app/reports/
VALIDATION_FILE = ROOT / "validation_results.json"  # Docker path: /app/validation_results.json
SUMMARY_FILE = ROOT / "validation_summary.txt"  # Docker path: /app/validation_summary.txt
LOG_FILE = ROOT / "validation_pipeline.log"  # Docker path: /app/validation_pipeline.log

# Constants
EXPECTED_REPORT_COUNT = 30
TOLERANCE = 0.15  # 15% tolerance for score comparisons


def log(msg):
    """Log message to both console and log file"""
    print(msg)
    with open(LOG_FILE, 'a', encoding='utf-8') as f:
        f.write(f"{msg}\n")


def load_csv_with_encoding(path):
    """Load CSV with encoding and delimiter detection"""
    encodings = ["utf-8", "cp1252", "latin1"]
    for enc in encodings:
        try:
            with open(path, encoding=enc) as f:
                sample = f.read(2048)
                try:
                    sep = csv.Sniffer().sniff(sample).delimiter
                    log(f"[OK] Delimiter '{sep}' with encoding '{enc}'")
                except Exception:
                    sep = ","
                    log(f"[WARNING] Using fallback delimiter ',' with encoding '{enc}'")
                return pd.read_csv(path, encoding=enc, sep=sep)
        except Exception as e:
            log(f"[WARNING] Failed with encoding {enc}: {e}")
    raise RuntimeError("[ERROR] Could not read CSV.")


def extract_text_from_pdf(pdf_path):
    """Extract text from PDF file with error handling"""
    try:
        with open(pdf_path, 'rb') as file:
            pdf_reader = PyPDF2.PdfReader(file)
            text = ""
            for page in pdf_reader.pages:
                text += page.extract_text()
            return text
    except Exception as e:
        log(f"[ERROR] PDF extraction failed for {pdf_path.name}: {e}")
        return None


def extract_scores_from_text(text):
    """Extract all resilience scores from PDF text"""
    scores = {}

    # Extract pillar averages
    upstream_avg_pattern = r'Upstream\s*\(avg:\s*(\d+\.?\d*)\)'
    internal_avg_pattern = r'Internal\s*\(avg:\s*(\d+\.?\d*)\)'
    downstream_avg_pattern = r'Downstream\s*\(avg:\s*(\d+\.?\d*)\)'
    overall_pattern = r'Overall\s+SCRES:\s*(\d+\.?\d*)'

    upstream_avg_match = re.search(upstream_avg_pattern, text, re.IGNORECASE)
    internal_avg_match = re.search(internal_avg_pattern, text, re.IGNORECASE)
    downstream_avg_match = re.search(downstream_avg_pattern, text, re.IGNORECASE)
    overall_match = re.search(overall_pattern, text, re.IGNORECASE)

    if upstream_avg_match:
        scores['upstream_avg'] = float(upstream_avg_match.group(1))
    if internal_avg_match:
        scores['internal_avg'] = float(internal_avg_match.group(1))
    if downstream_avg_match:
        scores['downstream_avg'] = float(downstream_avg_match.group(1))
    if overall_match:
        scores['overall_scres'] = float(overall_match.group(1))

    # Extract individual dimension scores
    dimension_patterns = {
        'Redundancy': r'Redundancy\s*\((\d+\.?\d*)\)',
        'Collaboration': r'Collaboration\s*\((\d+\.?\d*)\)',
        'Flexibility': r'Flexibility\s*\((\d+\.?\d*)\)',
        'Visibility': r'Visibility\s*\((\d+\.?\d*)\)',
        'Agility': r'Agility\s*\((\d+\.?\d*)\)'
    }

    # Split text into pillar sections
    sections = re.split(r'(Upstream|Internal|Downstream)\s*\(avg:', text, flags=re.IGNORECASE)

    if len(sections) >= 3:
        for i in range(1, len(sections), 2):
            pillar_name = sections[i].lower()
            pillar_text = sections[i+1][:500] if i+1 < len(sections) else ""

            if 'upstream' in pillar_name:
                section_prefix = 'up'
            elif 'internal' in pillar_name:
                section_prefix = 'in'
            elif 'downstream' in pillar_name:
                section_prefix = 'do'
            else:
                continue

            for dim_name, pattern in dimension_patterns.items():
                match = re.search(pattern, pillar_text, re.IGNORECASE)
                if match:
                    code = dim_name[0]
                    scores[f'{section_prefix}_{code}'] = float(match.group(1))

    return scores


def get_expected_values(df, company_name):
    """Calculate expected values for a company from CSV"""
    company_data = df[df['company_name'] == company_name]
    if len(company_data) == 0:
        return None

    row = company_data.iloc[0]

    # Calculate upstream
    up_scores = {
        'R': float(row['up__r']) if pd.notna(row['up__r']) else None,
        'C': float(row['up__c']) if pd.notna(row['up__c']) else None,
        'F': float(row['up__f']) if pd.notna(row['up__f']) else None,
        'V': float(row['up__v']) if pd.notna(row['up__v']) else None,
        'A': float(row['up__a']) if pd.notna(row['up__a']) else None,
    }
    up_scores_valid = [s for s in up_scores.values() if s is not None]
    up_avg = sum(up_scores_valid) / len(up_scores_valid) if up_scores_valid else None

    # Calculate internal
    in_scores = {
        'R': float(row['in__r']) if pd.notna(row['in__r']) else None,
        'C': float(row['in__c']) if pd.notna(row['in__c']) else None,
        'F': float(row['in__f']) if pd.notna(row['in__f']) else None,
        'V': float(row['in__v']) if pd.notna(row['in__v']) else None,
        'A': float(row['in__a']) if pd.notna(row['in__a']) else None,
    }
    in_scores_valid = [s for s in in_scores.values() if s is not None]
    in_avg = sum(in_scores_valid) / len(in_scores_valid) if in_scores_valid else None

    # Calculate downstream
    do_scores = {
        'R': float(row['do__r']) if pd.notna(row['do__r']) else None,
        'C': float(row['do__c']) if pd.notna(row['do__c']) else None,
        'F': float(row['do__f']) if pd.notna(row['do__f']) else None,
        'V': float(row['do__v']) if pd.notna(row['do__v']) else None,
        'A': float(row['do__a']) if pd.notna(row['do__a']) else None,
    }
    do_scores_valid = [s for s in do_scores.values() if s is not None]
    do_avg = sum(do_scores_valid) / len(do_scores_valid) if do_scores_valid else None

    # Overall
    overall_avgs = [avg for avg in [up_avg, in_avg, do_avg] if avg is not None]
    overall = sum(overall_avgs) / len(overall_avgs) if overall_avgs else None

    return {
        'company': company_name,
        'person': row.get('name', 'Unknown'),
        'upstream': up_scores,
        'upstream_avg': round(up_avg, 2) if up_avg else None,
        'internal': in_scores,
        'internal_avg': round(in_avg, 2) if in_avg else None,
        'downstream': do_scores,
        'downstream_avg': round(do_avg, 2) if do_avg else None,
        'overall_scres': round(overall, 2) if overall else None
    }


def compare_values(expected, actual, tolerance=TOLERANCE):
    """Compare expected vs actual values with tolerance"""
    results = {
        'pillar_avgs': {},
        'dimensions': {},
        'overall': {}
    }

    # Check pillar averages
    for pillar in ['upstream', 'internal', 'downstream']:
        exp_key = f'{pillar}_avg'
        exp_val = expected.get(exp_key)
        act_val = actual.get(exp_key)

        if exp_val is not None and act_val is not None:
            diff = abs(exp_val - act_val)
            matches = diff <= tolerance
            results['pillar_avgs'][pillar] = {
                'expected': exp_val,
                'actual': act_val,
                'diff': round(diff, 2),
                'matches': matches
            }
        elif exp_val is None and act_val is None:
            results['pillar_avgs'][pillar] = {
                'expected': None,
                'actual': None,
                'matches': True,
                'note': 'Both NA'
            }
        else:
            results['pillar_avgs'][pillar] = {
                'expected': exp_val,
                'actual': act_val,
                'matches': False,
                'error': 'Mismatch in NA handling'
            }

    # Check individual dimensions
    for pillar in ['up', 'in', 'do']:
        pillar_name = {'up': 'upstream', 'in': 'internal', 'do': 'downstream'}[pillar]
        for dim in ['R', 'C', 'F', 'V', 'A']:
            exp_val = expected.get(pillar_name, {}).get(dim)
            act_key = f'{pillar}_{dim}'
            act_val = actual.get(act_key)

            key = f'{pillar_name}_{dim}'

            if exp_val is not None and act_val is not None:
                diff = abs(exp_val - act_val)
                matches = diff <= tolerance
                results['dimensions'][key] = {
                    'expected': exp_val,
                    'actual': act_val,
                    'diff': round(diff, 2),
                    'matches': matches
                }
            elif exp_val is None and act_val is None:
                results['dimensions'][key] = {
                    'expected': None,
                    'actual': None,
                    'matches': True,
                    'note': 'Both NA'
                }
            elif exp_val is None:
                results['dimensions'][key] = {
                    'expected': None,
                    'actual': act_val,
                    'matches': True,
                    'note': 'CSV has NA'
                }
            elif act_val is None:
                results['dimensions'][key] = {
                    'expected': exp_val,
                    'actual': None,
                    'matches': False,
                    'error': 'Not found in PDF'
                }

    # Check overall SCRES
    exp_val = expected.get('overall_scres')
    act_val = actual.get('overall_scres')

    if exp_val is not None and act_val is not None:
        diff = abs(exp_val - act_val)
        matches = diff <= tolerance
        results['overall'] = {
            'expected': exp_val,
            'actual': act_val,
            'diff': round(diff, 2),
            'matches': matches
        }
    else:
        results['overall'] = {
            'expected': exp_val,
            'actual': act_val,
            'matches': False,
            'error': 'Missing value'
        }

    return results


def validate_pipeline():
    """Main pipeline validation function"""
    # Clear log file
    open(LOG_FILE, 'w').close()

    log("=" * 70)
    log("DOCKER VALIDATION PIPELINE")
    log("Deterministic validation of ResilienceScan pipeline")
    log("=" * 70)

    # Get current timestamp
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    log(f"Timestamp: {timestamp}")

    # Check runtime versions (Docker pattern)
    log("\n[RUNTIME] Checking container runtimes...")
    try:
        # Check Python version
        python_version = subprocess.check_output(['python3', '--version'], text=True).strip()
        log(f"   Python: {python_version}")

        # Check R version
        r_version = subprocess.check_output(['R', '--version'], text=True).strip()
        log(f"   R: {r_version}")

        # Check Quarto version
        quarto_version = subprocess.check_output(['quarto', '--version'], text=True).strip()
        log(f"   Quarto: {quarto_version}")
    except Exception as e:
        log(f"   [WARNING] Runtime check failed: {e}")

    # Verify directory structure
    log("\n[DIR] Verifying directory structure...")
    directories = {
        'data': DATA.parent,
        'outputs': ROOT / "outputs",
        'reports': REPORTS_DIR,
        'logs': ROOT / "logs"
    }

    for name, path in directories.items():
        if path.exists():
            log(f"   [OK] {name.capitalize()} directory: {path}")
        else:
            log(f"   [WARN] {name.capitalize()} directory missing: {path}")

    # Check input file
    log("\n[INPUT] Checking input file...")
    if not DATA.exists():
        log(f"   [FAIL] Input file not found: {DATA}")
        log("   Pipeline cannot proceed without cleaned data")
        save_summary()
        return

    log(f"   [OK] Input file found: {DATA}")

    # Load CSV data
    log("\n[LOAD] Loading CSV data...")
    try:
        df = load_csv_with_encoding(DATA)
        log(f"   Total companies: {df['company_name'].nunique()}")
        log(f"   Total rows: {len(df)}")
    except Exception as e:
        log(f"   [FAIL] Could not load CSV: {e}")
        save_summary()
        return

    # Check reports directory
    log(f"\n[REPORTS] Checking reports directory...")
    if not REPORTS_DIR.exists():
        log(f"   [FAIL] Reports directory not found: {REPORTS_DIR}")
        log("   No reports to validate")
        save_summary()
        return

    # Count PDF reports
    pdf_files = list(REPORTS_DIR.glob("*.pdf"))
    log(f"   [OK] Reports directory found: {REPORTS_DIR}")
    log(f"   Found {len(pdf_files)} PDF reports")

    # Check if we have the expected number of reports
    if len(pdf_files) < EXPECTED_REPORT_COUNT:
        log(f"   [WARN] Expected {EXPECTED_REPORT_COUNT} reports, found {len(pdf_files)}")
    else:
        log(f"   [OK] Found expected {EXPECTED_REPORT_COUNT} or more reports")

    # Check validation results
    log(f"\n[VALIDATION] Checking validation results...")
    if not VALIDATION_FILE.exists():
        log(f"   [FAIL] Validation results not found: {VALIDATION_FILE}")
        log("   Run validation first to generate results")
        save_summary()
        return

    log(f"   [OK] Validation results found: {VALIDATION_FILE}")

    # Load validation results
    try:
        with open(VALIDATION_FILE, 'r', encoding='utf-8') as f:
            validation_results = json.load(f)

        total_reports = len(validation_results)
        passed_reports = sum(1 for r in validation_results if r.get('all_match', False))
        failed_reports = total_reports - passed_reports

        log(f"   Total reports validated: {total_reports}")
        log(f"   Passed validation: {passed_reports}/{total_reports}")
        log(f"   Failed validation: {failed_reports}/{total_reports}")

        if total_reports > 0:
            pass_rate = (passed_reports / total_reports) * 100
            log(f"   Pass rate: {pass_rate:.1f}%")

            if passed_reports == total_reports:
                log("   [SUCCESS] All reports passed validation!")
            else:
                log("   [ATTENTION] Some reports failed validation")

    except Exception as e:
        log(f"   [FAIL] Error loading validation results: {e}")
        save_summary()
        return

    # Summary statistics
    log("\n[SUMMARY] Pipeline validation summary")
    log(f"   Input file: {DATA}")
    log(f"   Reports directory: {REPORTS_DIR}")
    log(f"   PDF reports found: {len(pdf_files)}")
    log(f"   Validation results: {VALIDATION_FILE}")
    log(f"   Total validated: {total_reports}")
    log(f"   Passed: {passed_reports}")
    log(f"   Failed: {failed_reports}")
    log(f"   Pass rate: {pass_rate:.1f}%")

    # Final status
    log("\n[STATUS] Pipeline validation status")
    if passed_reports == total_reports and total_reports == len(pdf_files):
        log("   [SUCCESS] Pipeline validation complete - all reports valid")
        log("   All input data, reports, and validation results are consistent")
    elif passed_reports == total_reports and total_reports < len(pdf_files):
        log("   [WARNING] All validated reports passed, but not all reports validated")
        log(f"   {len(pdf_files) - total_reports} reports were not validated")
    else:
        log("   [FAIL] Pipeline validation incomplete - some reports failed")
        log("   Review validation results for specific issues")

    log("=" * 70)

    # Save summary
    save_summary()
    log(f"\n[SAVE] Validation summary saved to: {SUMMARY_FILE}")
    log(f"[SAVE] Detailed log saved to: {LOG_FILE}")


def save_summary():
    """Save the validation summary to file"""
    try:
        with open(SUMMARY_FILE, 'w', encoding='utf-8') as f:
            f.write("Docker Validation Pipeline Summary\n")
            f.write("=" * 50 + "\n\n")

            # Read log file and extract summary
            with open(LOG_FILE, 'r', encoding='utf-8') as log_file:
                lines = log_file.readlines()

                # Extract key summary lines
                summary_lines = []
                for line in lines:
                    if any(keyword in line for keyword in
                        ['Timestamp:', 'Python:', 'R:', 'Quarto:',
                         'Total companies:', 'Found PDF reports:',
                         'Total reports validated:', 'Pass rate:',
                         'Pipeline validation status']):
                        summary_lines.append(line.strip())

                f.write('\n'.join(summary_lines))

    except Exception as e:
        log(f"[ERROR] Could not save summary file: {e}")


if __name__ == "__main__":
    validate_pipeline()