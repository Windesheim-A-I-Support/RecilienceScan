"""Test with the problematic company name that has a forward slash"""
import os
import sys
from pathlib import Path
import shutil
from datetime import datetime

# Add parent directory to path
ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))

from generate_all_reports import safe_display_name, safe_filename

# Test the problematic names
company = "CelaVIta / McCain"
person = "Ray Hobé"

print("=" * 70)
print("Testing filename sanitization")
print("=" * 70)
print(f"Original company: {company}")
print(f"Original person:  {person}")
print()

# Test safe_filename (for temp files)
safe_company = safe_filename(company)
safe_person = safe_filename(person)
print(f"Safe filename company: {safe_company}")
print(f"Safe filename person:  {safe_person}")
print()

# Test safe_display_name (for final files)
display_company = safe_display_name(company)
display_person = safe_display_name(person)
print(f"Display company: {display_company}")
print(f"Display person:  {display_person}")
print()

# Test final filename
date_str = datetime.now().strftime("%Y%m%d")
output_filename = f"{date_str} ResilienceScanReport ({display_company} - {display_person}).pdf"
print(f"Final filename: {output_filename}")
print()

# Try to create a test file with this name
test_dir = ROOT / "reports" / "test_sanitization"
test_dir.mkdir(parents=True, exist_ok=True)
test_file = test_dir / output_filename

try:
    # Create empty test file
    test_file.write_text("test")
    print(f"✅ SUCCESS: File created at {test_file}")
    print(f"✅ Filename is valid!")
    # Clean up
    test_file.unlink()
    print(f"✅ Test file removed")
except Exception as e:
    print(f"❌ ERROR: {e}")
    print(f"❌ Filename is NOT valid!")

print("=" * 70)
