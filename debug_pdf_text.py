import PyPDF2
from pathlib import Path

# Read one PDF and show relevant text
pdf_file = Path("reports/20251031 ResilienceScanReport (Suplacon - Pim Jansen).pdf")

with open(pdf_file, 'rb') as file:
    pdf_reader = PyPDF2.PdfReader(file)
    text = ""
    for page in pdf_reader.pages:
        text += page.extract_text()

# Find sections with "Resilience" or "SCRES"
lines = text.split('\n')
print("Looking for lines with 'Resilience' or 'SCRES':")
print("=" * 70)
for i, line in enumerate(lines):
    if 'resilience' in line.lower() or 'scres' in line.lower():
        print(f"Line {i}: {line}")

print("\n" + "=" * 70)
print("\nFirst 2000 characters of PDF text:")
print("=" * 70)
print(text[:2000])
