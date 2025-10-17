import os
import pandas as pd
import csv
from pathlib import Path
import shutil
from datetime import datetime

# ✅ CONFIGURATION
ROOT = Path(__file__).resolve().parent
TEMPLATE = ROOT / "example_3.qmd"
DATA = ROOT / "data" / "cleaned_master.csv"
OUTPUT_DIR = ROOT / "reports"
COLUMN_MATCH_COMPANY = "company_name"
COLUMN_MATCH_PERSON = "name"

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

def safe_filename(name):
    """Convert string to safe filename (alphanumeric + underscore)"""
    if pd.isna(name) or name == "":
        return "Unknown"
    return "".join(c if c.isalnum() or c in [' ', '-'] else "_" for c in str(name)).replace(" ", "_")

def generate_reports():
    """Generate individual PDF reports for each person/company entry"""

    print("=" * 70)
    print("📊 RESILIENCE SCAN REPORT GENERATOR")
    print("=" * 70)

    # Load data
    df = load_csv(DATA)
    df.columns = df.columns.str.lower().str.strip()

    # Find required columns
    company_col = next((col for col in df.columns if COLUMN_MATCH_COMPANY in col), None)
    person_col = next((col for col in df.columns if COLUMN_MATCH_PERSON in col), None)

    if not company_col:
        raise ValueError(f"❌ No column matching '{COLUMN_MATCH_COMPANY}'")

    print(f"\n📁 Found columns:")
    print(f"   Company: {company_col}")
    print(f"   Person: {person_col if person_col else 'Not found (will use Unknown)'}")

    # Create output directory
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    # Get current date for filename
    date_str = datetime.now().strftime("%Y%m%d")

    # Count total and generate reports
    total_entries = len(df[df[company_col].notna()])
    print(f"\n📝 Total entries to process: {total_entries}")
    print("=" * 70)

    generated = 0
    skipped = 0
    failed = 0

    for idx, row in df.iterrows():
        company = row[company_col]

        # Skip rows without company name
        if pd.isna(company) or str(company).strip() == "":
            continue

        # Get person name (fallback to "Unknown")
        if person_col and person_col in row and not pd.isna(row[person_col]):
            person = row[person_col]
        else:
            person = "Unknown"

        # Create safe filenames
        safe_company = safe_filename(company)
        safe_person = safe_filename(person)

        # New naming format: YYYYMMDD ResilienceScanReport (COMPANY NAME - Firstname Lastname).pdf
        output_filename = f"{date_str} ResilienceScanReport ({company} - {person}).pdf"
        output_file = OUTPUT_DIR / output_filename

        # Check if already exists
        if output_file.exists():
            print(f"🔁 Skipping {company} - {person} (already exists)")
            skipped += 1
            continue

        print(f"\n📄 Generating report {generated + 1}/{total_entries}:")
        print(f"   Company: {company}")
        print(f"   Person: {person}")
        print(f"   Output: {output_filename}")

        # Build quarto command
        temp_output = f"temp_{safe_company}_{safe_person}.pdf"
        cmd = (
            f'quarto render "{TEMPLATE}" '
            f'-P company="{company}" '
            f'--to pdf '
            f'--output "{temp_output}" '
            f'--quiet'
        )

        # Execute quarto render
        result = os.system(cmd)

        if result == 0:
            if Path(temp_output).exists():
                shutil.move(temp_output, output_file)
                print(f"   ✅ Saved: {output_file}")
                generated += 1
            else:
                print(f"   ❌ Output file not found")
                failed += 1
        else:
            print(f"   ❌ Failed (exit code: {result})")
            failed += 1

    # Summary
    print("\n" + "=" * 70)
    print("📊 GENERATION SUMMARY")
    print("=" * 70)
    print(f"   ✅ Generated: {generated}")
    print(f"   🔁 Skipped:   {skipped}")
    print(f"   ❌ Failed:    {failed}")
    print(f"   📁 Total:     {total_entries}")
    print("=" * 70)

    if generated > 0:
        print(f"\n✅ Reports saved to: {OUTPUT_DIR}")

if __name__ == "__main__":
    try:
        generate_reports()
    except Exception as e:
        print(f"\n❌ ERROR: {e}")
        raise
