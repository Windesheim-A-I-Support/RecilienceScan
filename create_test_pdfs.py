"""
Create fake test PDFs for email testing
Matches the expected filename format from generate_all_reports.py
"""
import pandas as pd
from datetime import datetime
from pathlib import Path

# Create reports directory
Path('reports').mkdir(exist_ok=True)

# Load CSV to get company names
df = pd.read_csv('data/cleaned_master.csv')
df.columns = df.columns.str.lower().str.strip()

# Function to create safe display name (from send_email.py)
def safe_display_name(name):
    if pd.isna(name) or name == '':
        return 'Unknown'
    name_str = str(name).strip()
    name_str = name_str.replace('/', '-')
    name_str = name_str.replace('\\', '-')
    name_str = name_str.replace(':', '-')
    name_str = name_str.replace('*', '')
    name_str = name_str.replace('?', '')
    name_str = name_str.replace('"', "'")
    name_str = name_str.replace('<', '(')
    name_str = name_str.replace('>', ')')
    name_str = name_str.replace('|', '-')
    return name_str

# Get date string
date_str = datetime.now().strftime('%Y%m%d')

# PDF template
PDF_TEMPLATE = """%%PDF-1.4
1 0 obj
<<
/Type /Catalog
/Pages 2 0 R
>>
endobj

2 0 obj
<<
/Type /Pages
/Kids [3 0 R]
/Count 1
>>
endobj

3 0 obj
<<
/Type /Page
/Parent 2 0 R
/Resources <<
/Font <<
/F1 4 0 R
>>
>>
/MediaBox [0 0 612 792]
/Contents 5 0 R
>>
endobj

4 0 obj
<<
/Type /Font
/Subtype /Type1
/BaseFont /Helvetica
>>
endobj

5 0 obj
<<
/Length 150
>>
stream
BT
/F1 12 Tf
50 700 Td
(TEST RESILIENCE SCAN REPORT) Tj
0 -30 Td
(Company: {company}) Tj
0 -20 Td
(Contact: {person}) Tj
0 -30 Td
(This is a test PDF for email distribution testing) Tj
ET
endstream
endobj

xref
0 6
0000000000 65535 f
0000000009 00000 n
0000000058 00000 n
0000000115 00000 n
0000000270 00000 n
0000000353 00000 n
trailer
<<
/Size 6
/Root 1 0 R
>>
startxref
600
%%EOF
"""

print("=" * 70)
print("Creating Test PDFs for Email Testing")
print("=" * 70)

# Create test PDFs (first 5 valid companies)
count = 0
created_files = []

for idx, row in df.iterrows():
    if count >= 5:
        break

    company = row['company_name']
    person = row.get('name', 'Unknown')
    email = row.get('email_address', '')

    # Skip if missing data
    if pd.isna(company) or str(company).strip() in ['', '-']:
        continue

    # Skip if no valid email
    if pd.isna(email) or '@' not in str(email):
        continue

    display_company = safe_display_name(company)
    display_person = safe_display_name(person)

    # Create filename matching expected format from generate_all_reports.py
    filename = f'{date_str} ResilienceScanReport ({display_company} - {display_person}).pdf'
    filepath = Path('reports') / filename

    # Create PDF content with company/person info
    pdf_content = PDF_TEMPLATE.format(
        company=display_company,
        person=display_person
    )

    # Write fake PDF
    with open(filepath, 'wb') as f:
        f.write(pdf_content.encode('latin-1'))

    print(f"[{count+1}] Created: {filename}")
    print(f"    Company: {company}")
    print(f"    Person: {person}")
    print(f"    Email: {email}")

    created_files.append({
        'file': filename,
        'company': company,
        'person': person,
        'email': email
    })

    count += 1

print("\n" + "=" * 70)
print(f"Total test PDFs created: {count}")
print("=" * 70)

if count > 0:
    print("\nCreated files:")
    for f in created_files:
        print(f"  - {f['file']}")

    print("\nThese PDFs can now be used for email testing!")
    print("Run: python send_email.py")
else:
    print("\nNo valid companies found to create test PDFs!")

print("\nNote: These are minimal valid PDF files for testing only.")
