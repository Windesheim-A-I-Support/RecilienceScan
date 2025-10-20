"""Test generating one specific report"""
import os
import pandas as pd
from pathlib import Path
import shutil
from datetime import datetime
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from generate_all_reports import safe_filename, safe_display_name

# Configuration
ROOT = Path(__file__).resolve().parent
TEMPLATE = ROOT / "ResilienceReport.qmd"
OUTPUT_DIR = ROOT / "reports" / "test_single"

# Test with the problematic company
company = "CelaVIta / McCain"
person = "Ray Hobé"

print("=" * 70)
print(f"Testing single report generation")
print(f"Company: {company}")
print(f"Person: {person}")
print("=" * 70)

# Create output directory
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# Get current date for filename
date_str = datetime.now().strftime("%Y%m%d")

# Create safe filenames
safe_company = safe_filename(company)
safe_person = safe_filename(person)
display_company = safe_display_name(company)
display_person = safe_display_name(person)

# New naming format
output_filename = f"{date_str} ResilienceScanReport ({display_company} - {display_person}).pdf"
output_file = OUTPUT_DIR / output_filename

print(f"\nOutput filename: {output_filename}")
print(f"Output path: {output_file}")

# Build quarto command
temp_output = f"temp_{safe_company}_{safe_person}.pdf"
cmd = (
    f'quarto render "{TEMPLATE}" '
    f'-P company="{company}" '
    f'--to pdf '
    f'--output "{temp_output}"'
)

print(f"\nRunning: {cmd}\n")

# Execute quarto render
result = os.system(cmd)

if result == 0:
    temp_path = ROOT / temp_output
    if temp_path.exists():
        shutil.move(temp_path, output_file)
        file_size = output_file.stat().st_size / 1024  # KB
        print(f"\n✅ SUCCESS: {output_filename} ({file_size:.1f} KB)")
    else:
        print(f"\n❌ ERROR: Output file not found at {temp_path}")
else:
    print(f"\n❌ ERROR: Quarto render failed (exit code: {result})")

print("=" * 70)
