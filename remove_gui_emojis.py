#!/usr/bin/env python3
"""
Script to remove all emojis from ResilienceScanGUI.py
Replaces them with appropriate text prefixes/labels.
"""

# Emoji to text replacements
# IMPORTANT: Keep emojis in GUI elements (tabs, buttons, titles) as they are FRONT-END
# Only remove emojis from BACKEND logging (self.log, self.log_gen, self.log_email, print statements)

REPLACEMENTS = [
    # Log messages - Success
    ("✅ Email tracker:", "[OK] Email tracker:"),
    ("✅ Data loaded:", "[OK] Data loaded:"),
    ("✅ Data loaded from:", "[OK] Data loaded from:"),
    ("✅ Data conversion completed!", "[OK] Data conversion completed!"),
    ("✅ Data automatically loaded:", "[OK] Data automatically loaded:"),
    ("✅ Data cleaning completed!", "[OK] Data cleaning completed!"),
    ("✅ Cleaned data automatically reloaded:", "[OK] Cleaned data automatically reloaded:"),
    ("✅ Data integrity verified!", "[OK] Data integrity verified!"),
    ("✅ Data integrity validation completed!", "[OK] Data integrity validation completed!"),
    ("✅ Exported", "[OK] Exported"),
    ("✅ Success:", "[OK] Success:"),
    ("✅ Executive Dashboard generated", "[OK] Executive Dashboard generated"),
    ("✅ All checks passed!", "[OK] All checks passed!"),
    ("✅ Email template saved", "[OK] Email template saved"),
    ("✅ Email template loaded", "[OK] Email template loaded"),
    ("✅ Marked", "[OK] Marked"),
    ("✅ Cleaning process preserves", "[OK] Cleaning process preserves"),
    ("✅ Successfully sent:", "[OK] Successfully sent:"),
    ("✅ Email sent successfully!", "[OK] Email sent successfully!"),
    ("✅ Sent via SMTP", "[OK] Sent via SMTP"),
    ("✅ SUCCESS:", "[OK] SUCCESS:"),
    ("✅ Email distribution complete!", "[OK] Email distribution complete!"),
    ("✅ Installed", "[OK] Installed"),
    ("✅ Linux installation guide", "[OK] Linux installation guide"),
    ("✅ System check complete:", "[OK] System check complete:"),
    ("✅ Email configured:", "[OK] Email configured:"),

    # Log messages - Error
    ("❌ Error loading data:", "[ERROR] Error loading data:"),
    ("❌ Error loading file:", "[ERROR] Error loading file:"),
    ("❌ Data conversion failed", "[ERROR] Data conversion failed"),
    ("❌ Error during data conversion:", "[ERROR] Error during data conversion:"),
    ("❌ Data cleaning failed", "[ERROR] Data cleaning failed"),
    ("❌ Error during data cleaning:", "[ERROR] Error during data cleaning:"),
    ("❌ Data integrity validation failed", "[ERROR] Data integrity validation failed"),
    ("❌ Error during integrity validation:", "[ERROR] Error during integrity validation:"),
    ("❌ Export failed:", "[ERROR] Export failed:"),
    ("❌ Error: Output file not found", "[ERROR] Error: Output file not found"),
    ("❌ Error: Exit code", "[ERROR] Error: Exit code"),
    ("❌ Error: Quarto not found", "[ERROR] Error: Quarto not found"),
    ("❌ Error: Generation timeout", "[ERROR] Error: Generation timeout"),
    ("❌ Error:", "[ERROR] Error:"),
    ("❌ Error generating dashboard:", "[ERROR] Error generating dashboard:"),
    ("❌ Error running system check:", "[ERROR] Error running system check:"),
    ("❌ Failed to install", "[ERROR] Failed to install"),
    ("❌ Error installing dependencies:", "[ERROR] Error installing dependencies:"),
    ("❌ Error saving template:", "[ERROR] Error saving template:"),
    ("❌ No PDF reports found", "[ERROR] No PDF reports found"),
    ("❌ FAILED:", "[ERROR] FAILED:"),
    ("❌ Failed:", "[ERROR] Failed:"),
    ("❌ Significant discrepancies", "[ERROR] Significant discrepancies"),

    # Log messages - Warning
    ("ℹ️  No data loaded", "[INFO] No data loaded"),
    ("ℹ️  First time setup:", "[INFO] First time setup:"),
    ("ℹ️ TEST MODE IS OFF!", "[WARNING] TEST MODE IS OFF!"),
    ("ℹ️  All reports have already been sent!", "[INFO] All reports have already been sent!"),
    ("ℹ️ Test mode enabled", "[INFO] Test mode enabled"),
    ("ℹ️? Preview Email", "Preview Email"),

    ("⚠️ Could not auto-load data:", "[WARNING] Could not auto-load data:"),
    ("⚠️ Could not auto-reload data:", "[WARNING] Could not auto-reload data:"),
    ("⚠️ Minor discrepancies detected", "[WARNING] Minor discrepancies detected"),
    ("⚠️  SYSTEM STATUS:", "[WARNING] SYSTEM STATUS:"),
    ("⚠️ Found", "[WARNING] Found"),
    ("⚠️ Could not load template:", "[WARNING] Could not load template:"),
    ("⚠️  No report found", "[WARNING] No report found"),
    ("⚠️  Could not load CSV:", "[WARNING] Could not load CSV:"),
    ("⚠️  Could not parse filename:", "[WARNING] Could not parse filename:"),
    ("⚠️  Could not update CSV:", "[WARNING] Could not update CSV:"),
    ("⚠️ Test mode disabled", "[WARNING] Test mode disabled"),
    ("⚠️ TEST MODE ENABLED", "[WARNING] TEST MODE ENABLED"),
    ("⚠️ Outlook failed:", "[WARNING] Outlook failed:"),
    ("⚠️  Could not reload CSV:", "[WARNING] Could not reload CSV:"),
    ("⚠️  Test mode was enabled", "[WARNING] Test mode was enabled"),

    # Special action emojis
    ("🚀 Starting batch", "[START] Starting batch"),
    ("🚀 LIVE MODE", "[LIVE] LIVE MODE"),
    ("⏭ Skipping", "[SKIP] Skipping"),
    ("🔁 Already exists", "[SKIP] Already exists"),
    ("📥 Starting data conversion", "[START] Starting data conversion"),
    ("🧹 Starting enhanced data cleaning", "[START] Starting enhanced data cleaning"),
    ("🔍 Starting data integrity validation", "[START] Starting data integrity validation"),
    ("🔄 Email template reset", "[RESET] Email template reset"),
    ("🎉 SYSTEM STATUS: ALL CHECKS PASSED", "[OK] SYSTEM STATUS: ALL CHECKS PASSED"),
    ("📧 Starting email distribution", "[START] Starting email distribution"),
    ("🧪 TEST MODE ENABLED", "[TEST] TEST MODE ENABLED"),
    ("📊 Total reports ready", "[INFO] Total reports ready"),
    ("📧 Connecting to SMTP server:", "[SMTP] Connecting to SMTP server:"),
    ("⏹ Email sending stopped", "[STOP] Email sending stopped"),
    ("📧 Sending to:", "[SEND] Sending to:"),
    ("📮 Using Outlook to send", "[OUTLOOK] Using Outlook to send"),
    ("📤 Sending via Outlook", "[OUTLOOK] Sending via Outlook"),
    ("📂 Loaded CSV data", "[LOAD] Loaded CSV data"),
    ("📎 Attachment:", "[ATTACH] Attachment:"),
    ("👁 Email preview", "[PREVIEW] Email preview"),
    ("📝  Updated CSV:", "[UPDATE] Updated CSV:"),
    ("🔄 Reset", "[RESET] Reset"),
    ("📊 ", "[INFO] "),

    # Remaining emojis that might be in conditional strings
    ("📄", ""),
    ("🔍", ""),
    ("📊", ""),
]

def remove_emojis_from_gui():
    """Remove all emojis from ResilienceScanGUI.py"""
    input_file = "ResilienceScanGUI.py"

    with open(input_file, 'r', encoding='utf-8') as f:
        content = f.read()

    # Apply replacements
    for emoji_text, replacement in REPLACEMENTS:
        content = content.replace(emoji_text, replacement)

    # Write back
    with open(input_file, 'w', encoding='utf-8') as f:
        f.write(content)

    print(f"Processed {input_file}")
    print(f"Applied {len(REPLACEMENTS)} replacement rules")

if __name__ == "__main__":
    remove_emojis_from_gui()
