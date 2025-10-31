import os
import subprocess
import pandas as pd
from pathlib import Path
from datetime import datetime
import json

# Configuration
ROOT = Path(__file__).resolve().parent
TEMPLATE = ROOT / "ResilienceReport.qmd"
DATA = ROOT / "data" / "cleaned_master.csv"
OUTPUT_DIR = ROOT / "reports"
VALIDATION_FILE = ROOT / "validation_results.json"

def safe_display_name(name):
    """Sanitize name for display in filename"""
    if not name or pd.isna(name):
        return "Unknown"
    name_str = str(name).strip()
    name_str = name_str.replace("/", "-").replace("\\", "-").replace(":", "-")
    name_str = name_str.replace("*", "").replace("?", "").replace('"', "'")
    name_str = name_str.replace("<", "(").replace(">", ")").replace("|", "-")
    return name_str

def generate_single_report(company_name, expected_values=None):
    """Generate a single PDF report for specified company"""

    # Create output directory
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    # Get current date for filename
    date_str = datetime.now().strftime("%Y%m%d")

    display_company = safe_display_name(company_name)

    # Build quarto command
    temp_output = f"temp_{display_company}.pdf"
    cmd = [
        'quarto', 'render', str(TEMPLATE),
        '-P', f'company={company_name}',
        '--to', 'pdf',
        '--output', temp_output
    ]

    print(f"\n[{company_name}] Generating report...")

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=180
        )

        if result.returncode == 0:
            if Path(temp_output).exists():
                # Find the generated file (person name extracted from data)
                # Move to reports directory
                import shutil
                import glob

                # Find the actual output file
                matches = glob.glob(f"*ResilienceScanReport ({display_company}*.pdf")
                if not matches:
                    # File might be in current directory with temp name
                    if Path(temp_output).exists():
                        # Rename to final name
                        final_name = OUTPUT_DIR / f"{date_str} ResilienceScanReport ({display_company}).pdf"
                        shutil.move(temp_output, final_name)
                        matches = [str(final_name)]

                if matches:
                    # Move to reports directory if not already there
                    for match in matches:
                        src = Path(match)
                        if src.parent != OUTPUT_DIR:
                            dst = OUTPUT_DIR / src.name
                            shutil.move(src, dst)
                            match = str(dst)

                    file_size = Path(matches[0]).stat().st_size // 1024
                    print(f"   [OK] Generated ({file_size} KB)")
                    return True, matches[0]
                else:
                    print(f"   [FAIL] Output file not found")
                    return False, None
            else:
                print(f"   [FAIL] Render failed - no output")
                return False, None
        else:
            print(f"   [FAIL] Quarto error (exit code {result.returncode})")
            if "Error" in result.stderr:
                error_lines = [l for l in result.stderr.split('\n') if 'Error' in l]
                print(f"      {error_lines[0][:80] if error_lines else ''}")
            return False, None

    except subprocess.TimeoutExpired:
        print(f"   [FAIL] Timeout (>180s)")
        return False, None
    except Exception as e:
        print(f"   [FAIL] Exception: {e}")
        return False, None

def get_expected_values(df, company_name):
    """Calculate expected values for a company"""
    company_data = df[df['company_name'] == company_name]
    if len(company_data) == 0:
        return None

    row = company_data.iloc[0]  # First respondent

    # Calculate upstream
    up_scores = [row['up__r'], row['up__c'], row['up__f'], row['up__v'], row['up__a']]
    up_avg = sum([s for s in up_scores if pd.notna(s)]) / len([s for s in up_scores if pd.notna(s)])

    # Calculate internal
    in_scores = [row['in__r'], row['in__c'], row['in__f'], row['in__v'], row['in__a']]
    in_avg = sum([s for s in in_scores if pd.notna(s)]) / len([s for s in in_scores if pd.notna(s)])

    # Calculate downstream
    do_scores = [row['do__r'], row['do__c'], row['do__f'], row['do__v'], row['do__a']]
    do_avg = sum([s for s in do_scores if pd.notna(s)]) / len([s for s in do_scores if pd.notna(s)])

    # Overall
    overall = (up_avg + in_avg + do_avg) / 3

    return {
        'company': company_name,
        'person': row.get('name', 'Unknown'),
        'upstream': {
            'R': float(row['up__r']) if pd.notna(row['up__r']) else None,
            'C': float(row['up__c']) if pd.notna(row['up__c']) else None,
            'F': float(row['up__f']) if pd.notna(row['up__f']) else None,
            'V': float(row['up__v']) if pd.notna(row['up__v']) else None,
            'A': float(row['up__a']) if pd.notna(row['up__a']) else None,
            'avg': round(up_avg, 2)
        },
        'internal': {
            'avg': round(in_avg, 2)
        },
        'downstream': {
            'avg': round(do_avg, 2)
        },
        'overall_scres': round(overall, 2),
        'respondent_count': len(company_data)
    }

def main():
    print("=" * 70)
    print("BATCH REPORT GENERATOR - TEST VALIDATION")
    print("=" * 70)

    # Load data
    print("\n[LOAD] Loading cleaned_master.csv...")
    df = pd.read_csv(DATA)
    print(f"   Total companies: {df['company_name'].nunique()}")
    print(f"   Total records: {len(df)}")

    # Select test companies
    test_companies = [
        'Suplacon',           # Mentioned in issue I004
        '24 ICE',             # Single respondent
        'AbbVie',             # Multiple respondents (12)
        'Agrifac Machinery B.V.',  # Multiple respondents (7)
        'Aako B.V.',          # Single respondent
        'Abbott',             # 2 respondents
    ]

    print(f"\n[TEST] Generating reports for {len(test_companies)} companies...")
    print("=" * 70)

    results = []
    successful = 0
    failed = 0

    for company in test_companies:
        # Check if company exists
        if company not in df['company_name'].values:
            print(f"\n[{company}] [WARN] Not found in dataset - skipping")
            continue

        # Get expected values
        expected = get_expected_values(df, company)

        # Generate report
        success, filepath = generate_single_report(company, expected)

        if success:
            successful += 1
            results.append({
                'company': company,
                'status': 'success',
                'filepath': filepath,
                'expected': expected
            })
        else:
            failed += 1
            results.append({
                'company': company,
                'status': 'failed',
                'expected': expected
            })

    # Summary
    print("\n" + "=" * 70)
    print("BATCH GENERATION SUMMARY")
    print("=" * 70)
    print(f"   Successful: {successful}")
    print(f"   Failed: {failed}")
    print(f"   Total: {successful + failed}")

    # Save validation data
    print(f"\n[SAVE] Saving validation data to {VALIDATION_FILE}...")
    with open(VALIDATION_FILE, 'w') as f:
        json.dump(results, f, indent=2)
    print("   [OK] Saved")

    # Display expected values for manual verification
    print("\n" + "=" * 70)
    print("EXPECTED VALUES FOR MANUAL VERIFICATION")
    print("=" * 70)

    for result in results:
        if result['status'] == 'success':
            exp = result['expected']
            print(f"\n{exp['company']} - {exp['person']}")
            print(f"   Respondents: {exp['respondent_count']}")

            # Format upstream scores (handle None values)
            up = exp['upstream']
            r_val = f"{up['R']:.2f}" if up['R'] is not None else "N/A"
            c_val = f"{up['C']:.2f}" if up['C'] is not None else "N/A"
            f_val = f"{up['F']:.2f}" if up['F'] is not None else "N/A"
            v_val = f"{up['V']:.2f}" if up['V'] is not None else "N/A"
            a_val = f"{up['A']:.2f}" if up['A'] is not None else "N/A"

            print(f"   Upstream: R={r_val}, C={c_val}, F={f_val}, V={v_val}, A={a_val}")
            print(f"   Upstream avg (u): {exp['upstream']['avg']:.2f}")
            print(f"   Internal avg (u): {exp['internal']['avg']:.2f}")
            print(f"   Downstream avg (u): {exp['downstream']['avg']:.2f}")
            print(f"   Overall SCRES: {exp['overall_scres']:.2f}/5.00")

    print("\n" + "=" * 70)
    print("NEXT STEPS:")
    print("=" * 70)
    print("1. Open each PDF in reports/ folder")
    print("2. Compare chart values with expected values above")
    print("3. Verify:")
    print("   - Chart values are NOT all identical (3.0, 3.0, 3.0...)")
    print("   - Chart values match expected R, C, F, V, A values")
    print("   - Averages (u) match expected averages")
    print("   - Overall SCRES matches expected value")
    print("=" * 70)

if __name__ == "__main__":
    main()
