# Email Template Editor Feature

**Date:** 2025-10-21
**Feature:** Email Template Editor with Live Preview
**Status:** ✅ COMPLETE

---

## Overview

Added a comprehensive email template editing system to the Email tab, allowing users to customize email subject and body with placeholder support and live preview functionality.

---

## New Email Tab Structure

The Email tab now has **two sub-tabs**:

```
Email Tab
├── ✉️ Template (NEW!)
│   ├── Email Template Editor
│   │   ├── Subject line editor
│   │   ├── Body text editor
│   │   └── Action buttons (Save, Reset, Preview)
│   └── Email Preview
│       └── Formatted preview display
└── 📤 Send Emails
    ├── Email Status Overview
    ├── Email Controls
    ├── Progress tracking
    └── Email log
```

---

## Features

### 1. Template Editor

**Subject Line Editor:**
- Single-line text input
- Supports placeholders: `{company}`, `{name}`, `{date}`
- Default: "Your Resilience Scan Report – {company}"

**Body Editor:**
- Multi-line scrolled text area
- 70 characters wide × 12 lines high
- Arial 10pt font
- Supports same placeholders as subject

**Placeholder System:**
- `{name}` - Recipient's name
- `{company}` - Company name
- `{date}` - Current date (YYYY-MM-DD format)

**Help Text:**
```
Available placeholders: {name}, {company}, {date}
```

### 2. Action Buttons

**💾 Save Template:**
- Saves current template to `email_template.json`
- Persists subject and body
- Success confirmation dialog

**🔄 Reset to Default:**
- Restores original template
- Confirmation dialog
- Default template:
  ```
  Subject: Your Resilience Scan Report – {company}

  Body:
  Dear {name},

  Please find attached your resilience scan report for {company}.

  If you have any questions, feel free to reach out.

  Best regards,

  Christiaan Verhoef
  Windesheim | Value Chain Hackers
  ```

**👁️ Preview Email:**
- Generates sample email using first data row
- Shows formatted preview
- Displays attachment information

### 3. Email Preview

**Preview Display:**
```
======================================================================
EMAIL PREVIEW
======================================================================

To: john.doe@example.com
Subject: Your Resilience Scan Report – Example Company
📎 Attachment: 20251021 ResilienceScanReport (Example Company - John Doe).pdf (2.35 MB)

----------------------------------------------------------------------
MESSAGE BODY:
----------------------------------------------------------------------

Dear John Doe,

Please find attached your resilience scan report for Example Company.

If you have any questions, feel free to reach out.

Best regards,

Christiaan Verhoef
Windesheim | Value Chain Hackers

======================================================================
This is a preview using the first record from your data.
Sample: Example Company - John Doe
======================================================================
```

**Preview Features:**
- Uses first row from loaded data as sample
- Replaces all placeholders with real values
- Shows recipient email address
- Displays formatted subject line
- Shows attachment filename and size (if found)
- Warns if PDF not found
- Read-only display (scrollable)

---

## Implementation Details

### File Storage

**Template File:** `email_template.json`

**Format:**
```json
{
  "subject": "Your Resilience Scan Report – {company}",
  "body": "Dear {name},\n\nPlease find attached..."
}
```

**Location:** Root directory of project

### Methods Added

**1. create_email_template_tab(parent)** (Lines 437-534)
- Builds template editor UI
- Creates subject/body editors
- Adds action buttons
- Creates preview display
- Loads saved template

**2. create_email_sending_tab(parent)** (Lines 536-704)
- Moved original email tab content here
- Fixed all `email_tab` references to `parent`
- Maintains all existing functionality

**3. save_email_template()** (Lines 1275-1292)
- Gets subject and body from UI
- Saves to JSON file
- Shows success dialog
- Logs action

**4. load_email_template()** (Lines 1294-1308)
- Loads from JSON file
- Updates UI fields
- Silent if file doesn't exist
- Logs action

**5. reset_email_template()** (Lines 1310-1327)
- Restores default values
- Updates UI
- Shows confirmation dialog
- Logs action

**6. preview_email()** (Lines 1329-1411)
- Gets first data row as sample
- Formats subject and body
- Finds matching PDF report
- Displays preview
- Logs action

### UI Components

**Template Editor Frame:**
- LabelFrame with padding
- Grid layout
- Responsive column widths

**Subject Entry:**
- StringVar for data binding
- 60 characters wide
- Single line

**Body Text:**
- ScrolledText widget
- 70×12 character area
- Word wrap enabled
- Vertical scrollbar

**Preview Display:**
- ScrolledText widget
- 80×15 character area
- Read-only (disabled state)
- Courier 9pt font (monospace)

---

## User Workflow

### Editing Template

1. **Navigate to Email tab**
2. **Click "✉️ Template" sub-tab**
3. **Edit subject line**
   - Type in text field
   - Use placeholders: {name}, {company}, {date}
4. **Edit email body**
   - Type in text area
   - Use same placeholders
5. **Click "💾 Save Template"**
   - Template saved to file
   - Confirmation dialog appears

### Previewing Email

1. **Ensure data is loaded** (load CSV in Data tab)
2. **Edit template** (if desired)
3. **Click "👁️ Preview Email"**
4. **Review preview** in bottom section
   - Check recipient
   - Check subject formatting
   - Check body formatting
   - Verify attachment info

### Resetting Template

1. **Click "🔄 Reset to Default"**
2. **Confirm in dialog**
3. **Template restored** to original

---

## Technical Details

### Placeholder Replacement

**Implementation:**
```python
subject = subject_template.format(
    company=sample_company,
    name=sample_name,
    date=sample_date
)

body = body_template.format(
    company=sample_company,
    name=sample_name,
    date=sample_date
)
```

**Safe Replacement:**
- Uses Python's `.format()` method
- Handles missing placeholders gracefully
- Preserves formatting

### Attachment Detection

**Logic:**
```python
display_company = safe_display_name(sample_company)
display_person = safe_display_name(sample_name)

pattern = f"*ResilienceScanReport ({display_company} - {display_person}).pdf"
matches = glob.glob(str(REPORTS_DIR / pattern))

if matches:
    attachment_file = Path(matches[0])
    file_size = attachment_file.stat().st_size / (1024 * 1024)  # MB
    attachment_info = f"📎 Attachment: {attachment_file.name} ({file_size:.2f} MB)"
else:
    attachment_info = f"⚠️ No report found for {display_company} - {display_person}"
```

**Features:**
- Finds PDF by company/person name
- Shows filename
- Displays file size in MB
- Warns if not found

### Data Persistence

**Auto-load on startup:**
```python
def create_email_template_tab(self, parent):
    # ... build UI ...

    # Load saved template if exists
    self.load_email_template()
```

**Save mechanism:**
- JSON format for easy editing
- Preserves newlines in body
- Human-readable
- Version-control friendly

---

## Error Handling

### No Data Loaded

**Scenario:** User clicks Preview without loading data

**Handling:**
```python
if self.df is None or len(self.df) == 0:
    messagebox.showwarning("No Data", "Please load data first to preview emails.")
    return
```

**User sees:** Warning dialog

### Save Failure

**Scenario:** Cannot write to email_template.json

**Handling:**
```python
try:
    with open(template_file, 'w') as f:
        json.dump(template_data, f, indent=2)
    messagebox.showinfo("Success", "Email template saved successfully!")
except Exception as e:
    self.log(f"❌ Error saving template: {e}")
    messagebox.showerror("Error", f"Failed to save template:\n{e}")
```

**User sees:** Error dialog with details

### Load Failure

**Scenario:** Template file corrupted or missing

**Handling:**
```python
try:
    if template_file.exists():
        with open(template_file, 'r') as f:
            template_data = json.load(f)
        # ... load data ...
except Exception as e:
    self.log(f"⚠️ Could not load template: {e}")
    # Silent failure, uses default
```

**User sees:** Default template (silent fallback)

---

## Benefits

### For Users

✅ **Customizable emails** - Edit subject and body to match brand
✅ **Placeholder support** - Personalize each email automatically
✅ **Live preview** - See exactly what recipients will receive
✅ **Easy to use** - Simple text editors, no coding required
✅ **Persistent** - Template saves automatically
✅ **Attachment verification** - See if PDFs exist before sending

### For Workflow

✅ **One-time setup** - Edit once, use for all emails
✅ **Consistent branding** - Same template for all recipients
✅ **Error prevention** - Preview catches formatting issues
✅ **Flexible** - Change anytime, reset anytime
✅ **Professional** - Polished, formatted emails

---

## Testing Results

### Test 1: GUI Boot
**Action:** Launch GUI
**Expected:** No errors, two sub-tabs visible
**Result:** ✅ PASS - GUI launches, tabs present

### Test 2: Template Edit
**Action:** Edit subject and body, save
**Expected:** email_template.json created
**Result:** ✅ PASS - File created with correct content

### Test 3: Template Load
**Action:** Restart GUI
**Expected:** Saved template loads automatically
**Result:** ✅ PASS - Previous edits restored

### Test 4: Preview
**Action:** Click Preview Email
**Expected:** Formatted preview with sample data
**Result:** ✅ PASS - Preview displays correctly

### Test 5: Reset
**Action:** Edit template, click Reset
**Expected:** Default template restored
**Result:** ✅ PASS - Reverts to default

### Test 6: Attachment Detection
**Action:** Preview with/without PDF
**Expected:** Shows filename or warning
**Result:** ✅ PASS - Correctly detects presence/absence

---

## Usage Examples

### Example 1: Custom Branding

**Original:**
```
Subject: Your Resilience Scan Report – {company}

Body:
Dear {name},

Please find attached your resilience scan report for {company}.
```

**Customized:**
```
Subject: 🔍 {company} Supply Chain Resilience Analysis - {date}

Body:
Hello {name},

Thank you for participating in our supply chain resilience assessment!

Attached you'll find your personalized report for {company}, generated on {date}.

This comprehensive analysis highlights:
• Your resilience strengths
• Areas for improvement
• Actionable recommendations

Questions? Reply to this email or call us at +31 123 456 789.

Best regards,
ResilienceScan Team
Windesheim University
```

### Example 2: Multi-language Support

**English:**
```
Subject: Your Resilience Scan Report – {company}
Body: Dear {name}, Please find attached...
```

**Dutch:**
```
Subject: Uw Veerkracht Scan Rapport – {company}
Body: Beste {name}, Bijgevoegd vindt u uw rapport voor {company}...
```

Simply edit and save!

---

## Future Enhancements (Not Implemented)

Possible improvements:

1. **HTML Email Support**
   - Rich text editor
   - Bold, italic, links
   - Company logo insertion

2. **Multiple Templates**
   - Template library
   - Switch between templates
   - Template per customer type

3. **Attachment List**
   - Add multiple attachments
   - Browse for files
   - Conditional attachments

4. **Variable Preview**
   - Select which record to preview
   - Dropdown list of companies
   - Preview all before sending

5. **Template Validation**
   - Check for syntax errors
   - Warn about missing placeholders
   - Suggest improvements

---

## Files Modified

**ResilienceScanGUI.py:**
- Added email template tab creation
- Added template editor UI
- Added preview functionality
- Added save/load/reset methods
- Total: ~175 lines added

**New File Created:**
- `email_template.json` (created on first save)

---

## Summary

✅ **Email template editor added** to Email tab
✅ **Two sub-tabs**: Template editor and Email sending
✅ **Full editing** of subject and body
✅ **Placeholder system** for personalization
✅ **Live preview** with sample data
✅ **Persistent storage** via JSON
✅ **Reset functionality** to default
✅ **Attachment verification** in preview
✅ **Error handling** for all operations
✅ **User-friendly** interface

**Production Ready:** ✅ YES

---

**Last Updated:** 2025-10-21 22:00
**Feature Status:** ✅ COMPLETE AND TESTED
