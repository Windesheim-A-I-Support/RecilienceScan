import os
import pandas as pd
import win32com.client as win32
from datetime import datetime
from pathlib import Path
import glob

# ✅ CONFIGURATION
CSV_PATH = "data/cleaned_master.csv"
REPORTS_FOLDER = "reports"
TEST_MODE = True
TEST_EMAIL = "cg.verhoef@windesheim.nl"  # <- Change this to your address

def safe_display_name(name):
    """Sanitize name for display in filename (keep spaces and hyphens, replace slashes)"""
    if pd.isna(name) or name == "":
        return "Unknown"
    # Replace forward slash with dash, keep other safe characters
    name_str = str(name).strip()
    # Replace problematic characters but keep it readable
    name_str = name_str.replace("/", "-")
    name_str = name_str.replace("\\", "-")
    name_str = name_str.replace(":", "-")
    name_str = name_str.replace("*", "")
    name_str = name_str.replace("?", "")
    name_str = name_str.replace('"', "'")
    name_str = name_str.replace("<", "(")
    name_str = name_str.replace(">", ")")
    name_str = name_str.replace("|", "-")
    return name_str

def find_report_file(company, person, reports_folder):
    """Find report file matching the new naming format: YYYYMMDD ResilienceScanReport (Company - Person).pdf"""
    # Sanitize names to match filename
    display_company = safe_display_name(company)
    display_person = safe_display_name(person)

    # Try to find file with today's date
    date_str = datetime.now().strftime("%Y%m%d")
    expected_filename = f"{date_str} ResilienceScanReport ({display_company} - {display_person}).pdf"
    expected_path = Path(reports_folder) / expected_filename

    if expected_path.exists():
        return str(expected_path)

    # Try to find file with any date (most recent)
    pattern = f"*ResilienceScanReport ({display_company} - {display_person}).pdf"
    matches = glob.glob(str(Path(reports_folder) / pattern))

    if matches:
        # Return most recent file
        return max(matches, key=os.path.getmtime)

    return None

def send_emails():
    df = pd.read_csv(CSV_PATH)
    df.columns = df.columns.str.lower().str.strip()

    required_cols = {"company_name", "email_address", "name"}
    if not required_cols.issubset(df.columns):
        print(f"❌ Missing one or more required columns: {required_cols}")
        return

    outlook = win32.Dispatch("Outlook.Application")
    sent_count = 0

    for _, row in df.iterrows():
        company = str(row["company_name"])
        email = row["email_address"]
        name = row.get("name", "there")

        if pd.isna(email) or "@" not in email:
            print(f"⚠️ Skipping {company} — invalid email")
            continue

        # Find report file using new naming format
        attachment_path = find_report_file(company, name, REPORTS_FOLDER)

        if not attachment_path:
            print(f"❌ Report not found for {company} - {name}")
            print(f"   Expected format: YYYYMMDD ResilienceScanReport ({safe_display_name(company)} - {safe_display_name(name)}).pdf")
            continue

        if TEST_MODE:
            print(f"🧪 TEST MODE: Would send to {email} for {company}")
            real_email = email
            email = TEST_EMAIL
        else:
            print(f"📨 Sending to {email} for {company}")

        mail = outlook.CreateItem(0)
        mail.To = email
        mail.Subject = f"Your Resilience Scan Report – {company}"

        body = (
            f"Dear {name},\n\n"
            f"Please find attached your resilience scan report for {company}.\n\n"
            "If you have any questions, feel free to reach out.\n\n"
            "Best regards,\n\n"
            "Christiaan Verhoef\n"
            "Windesheim | Value Chain Hackers"
        )

        if TEST_MODE:
            body = (
                f"[TEST MODE]\nThis email was originally intended for: {real_email}\n\n"
                + body
            )

        mail.Body = body
        mail.Attachments.Add(os.path.abspath(attachment_path))
        mail.Send()
        sent_count += 1

    print(f"\n📬 Finished sending {sent_count} {'test' if TEST_MODE else 'live'} emails.")

if __name__ == "__main__":
    send_emails()
