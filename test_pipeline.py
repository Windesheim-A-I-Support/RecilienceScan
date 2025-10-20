"""Test pipeline with limited number of reports"""
import os
import pandas as pd
import csv
from pathlib import Path
import shutil
from datetime import datetime

# Configuration
ROOT = Path(__file__).resolve().parent
TEMPLATE = ROOT / "ResilienceReport.qmd"
DATA = ROOT / "data" / "cleaned_master.csv"
OUTPUT_DIR = ROOT / "reports" / "test_pipeline"
COLUMN_MATCH_COMPANY = "company_name"
COLUMN_MATCH_PERSON = "name"
TEST_LIMIT = 3  # Only generate 3 reports for testing

def load_csv(path):
    """Load CSV with encoding and delimiter detection"""
    encodings = ["utf-8", "cp1252", "latin1"]
    for enc in encodings:
        try:
            with open(path, encoding=enc) as f:
                sample = f.read(2048)
                try:
                    sep = csv.Sniffer().sniff(sample).delimiter
                    print(f"✅ Delimiter '{sep}' with encoding '{enc}'")
                except Exception:
                    sep = ","
                    print(f"⚠️ Using fallback delimiter ',' with encoding '{enc}'")
                return pd.read_csv(path, encoding=enc, sep=sep)
        except Exception as e:
            print(f"⚠️ Failed with encoding {enc}: {e}")
    raise RuntimeError("❌ Could not read CSV.")

def generate_test_reports():
    """Generate test reports for first few entries"""

    print("=" * 70)
    print("📊 TESTING RESILIENCE SCAN REPORT PIPELINE")
    print("=" * 70)

    # Load data
    df = load_csv(DATA)
    df.columns = df.columns.str.lower().str.strip()

    # Create output directory
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    # Get columns
    company_col = COLUMN_MATCH_COMPANY
    person_col = COLUMN_MATCH_PERSON

    print(f"\n📁 Data loaded: {len(df)} total entries")
    print(f"🧪 Testing with first {TEST_LIMIT} entries")
    print(f"📂 Output directory: {OUTPUT_DIR}")

    # Process only first TEST_LIMIT entries
    success_count = 0
    error_count = 0

    for idx, row in df.head(TEST_LIMIT).iterrows():
        company = row[company_col] if company_col in row.index else "Unknown"
        person = row[person_col] if person_col in row.index else "Unknown"

        print(f"\n{'='*70}")
        print(f"🔄 [{idx+1}/{TEST_LIMIT}] Processing: {company} - {person}")

        # Generate filename with new format: YYYYMMDD ResilienceScanReport (Company - Person).pdf
        date_str = datetime.now().strftime("%Y%m%d")
        output_filename = f"{date_str} ResilienceScanReport ({company} - {person}).pdf"
        output_file = OUTPUT_DIR / output_filename

        # Render with quarto
        cmd = f'quarto render "{TEMPLATE}" -P company="{company}" --to pdf --output temp_report.pdf 2>&1'
        print(f"🔧 Running: quarto render ResilienceReport.qmd -P company=\"{company}\"")
        result = os.system(cmd)

        if result == 0:
            # Move to correct location with proper name
            temp_output = ROOT / "temp_report.pdf"
            if temp_output.exists():
                shutil.move(temp_output, output_file)
                file_size = output_file.stat().st_size / 1024  # KB
                print(f"✅ SUCCESS: {output_filename} ({file_size:.1f} KB)")
                success_count += 1
            else:
                print(f"❌ ERROR: PDF not generated for {company} - {person}")
                error_count += 1
        else:
            print(f"❌ ERROR: Quarto render failed (exit code {result})")
            error_count += 1

    # Summary
    print(f"\n{'='*70}")
    print("📊 TEST PIPELINE SUMMARY")
    print("=" * 70)
    print(f"✅ Successful: {success_count}/{TEST_LIMIT}")
    print(f"❌ Failed: {error_count}/{TEST_LIMIT}")
    print(f"📂 Reports saved to: {OUTPUT_DIR}")
    print("=" * 70)

    return success_count == TEST_LIMIT

if __name__ == "__main__":
    success = generate_test_reports()
    exit(0 if success else 1)
