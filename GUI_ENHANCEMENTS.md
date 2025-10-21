# ResilienceScan GUI Enhancements

**Date:** 2025-10-20
**Status:** Core Components Created, Integration Pending

---

## What Has Been Built

### 1. Email Tracking System ✅
**File:** `email_tracker.py` (400+ lines)

**Features Implemented:**
- ✅ SQLite database for tracking email status
- ✅ Import from cleaned_master.csv
- ✅ Track sent/pending/failed status
- ✅ Mark emails as sent with timestamp
- ✅ Manual status updates
- ✅ Bulk status updates
- ✅ Check if email already sent
- ✅ Export tracking data to CSV
- ✅ Statistics (total, pending, sent, failed)
- ✅ Test mode tracking
- ✅ Error message storage
- ✅ Notes field for manual updates

**Database Schema:**
```sql
email_tracking (
    id INTEGER PRIMARY KEY,
    company_name TEXT,
    person_name TEXT,
    email_address TEXT,
    report_filename TEXT,
    sent_date TIMESTAMP,
    sent_status TEXT,      -- 'pending', 'sent', 'failed'
    test_mode INTEGER,
    error_message TEXT,
    manually_updated INTEGER,
    notes TEXT
)
```

**Usage:**
```python
from email_tracker import EmailTracker

tracker = EmailTracker()

# Import from CSV
tracker.import_from_csv("data/cleaned_master.csv")

# Check if sent
status = tracker.check_if_sent("Company", "Person", "email@example.com")

# Mark as sent
tracker.mark_as_sent("Company", "Person", "email@example.com",
                     "report.pdf", test_mode=True)

# Manual update
tracker.manually_update_status(record_id=123, new_status='sent',
                               notes='Manually verified')

# Get statistics
stats = tracker.get_statistics()
# Returns: {'total': 479, 'pending': 450, 'sent': 29}
```

**Test Results:**
```
Imported: 479 emails
Skipped: 28 (invalid email addresses)
Pending: 479
```

---

### 2. Cross-Platform Dependency Manager ✅
**File:** `dependency_manager.py` (500+ lines)

**Features Implemented:**
- ✅ Check Python version (3.8+ required)
- ✅ Check Python packages (pandas, openpyxl, xlrd)
- ✅ Check R installation
- ✅ Check Quarto installation
- ✅ Check Git (optional)
- ✅ Platform detection (Windows/Linux/Mac)
- ✅ Generate install commands per platform
- ✅ Auto-install Python packages
- ✅ Provide manual install instructions
- ✅ Download URLs for manual installation
- ✅ Check if auto-install is possible
- ✅ Summary of dependency status

**Cross-Platform Support:**

| Software | Windows | Linux | Mac |
|----------|---------|-------|-----|
| Python | Manual download | apt-get | brew |
| R | Manual download | apt-get | brew |
| Quarto | Manual download | dpkg | brew |
| Git | Manual download | apt-get | brew |
| Packages | pip (auto) | pip (auto) | pip (auto) |

**Platform-Specific Commands:**

**Linux:**
```bash
# Python packages (auto-install)
pip install pandas openpyxl xlrd

# R
sudo apt-get install r-base r-base-dev

# Quarto
wget https://quarto.org/download/latest/quarto-linux-amd64.deb
sudo dpkg -i quarto-linux-amd64.deb

# Git
sudo apt-get install git
```

**Windows:**
```powershell
# Python packages (auto-install)
pip install pandas openpyxl xlrd

# R - Download from: https://cran.r-project.org/bin/windows/base/
# Quarto - Download from: https://quarto.org/docs/get-started/
# Git - Download from: https://git-scm.com/download/win
```

**Test Results (Linux):**
```
Platform: Linux
✅ Python 3.12.3 [REQUIRED]
✅ pandas 2.2.3 [REQUIRED]
❌ openpyxl [REQUIRED]
❌ xlrd [REQUIRED]
✅ R 4.5.1 [REQUIRED]
✅ Quarto 1.8.25 [REQUIRED]
✅ Git 2.43.0 [OPTIONAL]

Summary: 4/6 required dependencies met
```

---

## What Needs Integration

### 1. Email Tracking in GUI 🔄

**Email Tab Enhancements Needed:**

**a) Email Status Tracking View:**
```
┌─────────────────────────────────────────────────────────┐
│ Email Status Overview                                    │
├─────────────────────────────────────────────────────────┤
│ Total: 479 | Pending: 450 | Sent: 29 | Failed: 0       │
│                                                           │
│ Filter: [All ▼] [Pending ▼] [Sent ▼] [Failed ▼]        │
│ Search: [________________________] [🔍 Search]           │
│                                                           │
│ ┌────────────────────────────────────────────────────┐  │
│ │ Company       │ Person    │ Email     │ Status │   │  │
│ ├────────────────────────────────────────────────────┤  │
│ │ Coca-Cola     │ John Doe  │ john@...  │ ✅ Sent│   │  │
│ │ Scania        │ Jane      │ jane@...  │ ⏳ Pend│   │  │
│ │ Royal Koopmans│ Bob       │ bob@...   │ ❌ Fail│   │  │
│ └────────────────────────────────────────────────────┘  │
│                                                           │
│ [Mark as Sent] [Mark as Failed] [Reset to Pending]      │
│ [Export Status] [Import Status] [Refresh]               │
└─────────────────────────────────────────────────────────┘
```

**b) Manual Status Update Dialog:**
```
┌─────────────────────────────────────┐
│ Update Email Status                 │
├─────────────────────────────────────┤
│ Company: Coca-Cola Company          │
│ Person: John Doe                    │
│ Email: john.doe@cocacola.com        │
│                                     │
│ New Status: [Sent ▼]               │
│                                     │
│ Notes:                              │
│ ┌─────────────────────────────────┐ │
│ │ Manually verified - sent via    │ │
│ │ alternative method              │ │
│ └─────────────────────────────────┘ │
│                                     │
│ [Update] [Cancel]                  │
└─────────────────────────────────────┘
```

**c) Before Sending - Check Status:**
```python
# Before sending email, check if already sent:
status = tracker.check_if_sent(company, person, email)

if status and status['sent']:
    # Show dialog: "Email already sent on [date]. Send again?"
    if not confirm_resend():
        skip_this_email()
```

**Integration Points:**
1. Initialize EmailTracker in GUI __init__
2. Import emails on data load
3. Check status before sending
4. Update status after sending
5. Add manual update buttons
6. Show status in email list

---

### 2. Dependency Checker Tab 🔄

**New Tab Layout:**
```
┌─────────────────────────────────────────────────────────┐
│ System Dependencies                                      │
├─────────────────────────────────────────────────────────┤
│ Platform: Linux (Ubuntu 22.04)                          │
│ Architecture: x86_64                                     │
│                                                           │
│ ┌────────────────────────────────────────────────────┐  │
│ │ Software      │ Status │ Version  │ Action       │   │  │
│ ├────────────────────────────────────────────────────┤  │
│ │ ✅ Python     │ OK     │ 3.12.3   │ [Info]      │   │  │
│ │ ✅ pandas     │ OK     │ 2.2.3    │ [Update]    │   │  │
│ │ ❌ openpyxl   │ Missing│ -        │ [Install]   │   │  │
│ │ ❌ xlrd       │ Missing│ -        │ [Install]   │   │  │
│ │ ✅ R          │ OK     │ 4.5.1    │ [Info]      │   │  │
│ │ ✅ Quarto     │ OK     │ 1.8.25   │ [Check]     │   │  │
│ │ ✅ Git        │ OK     │ 2.43.0   │ [Info]      │   │  │
│ └────────────────────────────────────────────────────┘  │
│                                                           │
│ Summary: 5/6 required dependencies met                   │
│ ⚠️ Missing: openpyxl, xlrd                              │
│                                                           │
│ [Check All] [Install All Missing] [Refresh] [Export]    │
│                                                           │
│ Installation Log:                                        │
│ ┌────────────────────────────────────────────────────┐  │
│ │ [15:30:22] Checking Python... ✅ OK               │  │
│ │ [15:30:23] Checking pandas... ✅ OK               │  │
│ │ [15:30:24] Checking openpyxl... ❌ Not found      │  │
│ │ [15:30:25] Ready to install openpyxl              │  │
│ └────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

**Features:**
- ✅ Check all dependencies on tab open
- ✅ Show status with color-coded icons
- ✅ Individual install buttons
- ✅ Bulk "Install All Missing" button
- ✅ Progress feedback during installation
- ✅ Platform-appropriate commands
- ✅ Manual download links for Windows
- ✅ Refresh button to re-check
- ✅ Export check results

**Install Button Behavior:**

For **Python Packages** (auto-install):
```python
def install_package(package_name):
    # Show progress dialog
    progress = show_progress(f"Installing {package_name}...")

    # Run pip install
    result = dependency_manager.install_package(package_name)

    if result['success']:
        show_success(f"{package_name} installed successfully!")
        refresh_check(package_name)
    else:
        show_error(f"Failed to install {package_name}: {result['error']}")
```

For **R/Quarto** (platform dependent):
```python
def install_software(software_name):
    cmd_info = dependency_manager.get_install_command(software_name)

    if cmd_info['command']:
        # Linux/Mac with package manager
        if platform_is_linux_or_mac():
            show_admin_warning("Requires administrator privileges")
            # Run with sudo/admin
            result = run_with_admin(cmd_info['command'])
    else:
        # Windows - manual download
        download_url = cmd_info['download_url']
        show_download_dialog(download_url)
        open_browser(download_url)
```

---

### 3. Enhanced Data Viewer 🔄

**Data Tab Enhancements:**

**a) Pagination:**
```
┌─────────────────────────────────────────────────────────┐
│ Data Viewer                                              │
├─────────────────────────────────────────────────────────┤
│ Rows per page: [50 ▼] | Showing: 1-50 of 507           │
│                                                           │
│ ┌────────────────────────────────────────────────────┐  │
│ │ ID │ Company      │ Person   │ Email     │ Date  │   │  │
│ ├────────────────────────────────────────────────────┤  │
│ │ 1  │ Vattenfall   │ Deurw... │ d@...     │ 2023  │   │  │
│ │ 2  │ Coca-Cola    │ TCCC...  │ t@...     │ 2023  │   │  │
│ │ 3  │ Suplacon     │ Pim Ja...│ p@...     │ 2024  │   │  │
│ │... │ ...          │ ...      │ ...       │ ...   │   │  │
│ │ 50 │ Company      │ Person   │ email@... │ 2024  │   │  │
│ └────────────────────────────────────────────────────┘  │
│                                                           │
│ [◄◄ First] [◄ Prev] Page 1 of 11 [Next ►] [Last ►►]   │
└─────────────────────────────────────────────────────────┘
```

**b) Filtering:**
```
┌─────────────────────────────────────────────────────────┐
│ Filters                                                  │
├─────────────────────────────────────────────────────────┤
│ Company: [___________________] [🔍]                      │
│ Person: [___________________] [🔍]                       │
│ Email: [___________________] [🔍]                        │
│ Date Range: [From: _______] [To: _______]               │
│                                                           │
│ [Apply Filters] [Clear All] [Export Filtered]           │
└─────────────────────────────────────────────────────────┘
```

**c) Row Details Dialog:**
```
┌─────────────────────────────────────────────┐
│ Record Details - Row 127                    │
├─────────────────────────────────────────────┤
│ Company: Scania Logistics NL                │
│ Person: Elbrich de Jong                     │
│ Email: elbrich.dejong@scania.com           │
│ Submit Date: 2024-03-15                     │
│                                             │
│ Scores:                                     │
│ ├─ Upstream:    3.45                        │
│ ├─ Internal:    3.78                        │
│ ├─ Downstream:  3.22                        │
│ └─ Overall:     3.48                        │
│                                             │
│ Status:                                     │
│ ├─ Report Generated: ✅ Yes                │
│ ├─ Email Sent: ✅ Yes (2024-10-15)         │
│ └─ Test Mode: No                            │
│                                             │
│ [Generate Report] [Send Email] [Close]     │
└─────────────────────────────────────────────┘
```

**Implementation:**
```python
class EnhancedDataViewer:
    def __init__(self, parent, df):
        self.df = df
        self.filtered_df = df
        self.current_page = 0
        self.rows_per_page = 50
        self.total_pages = len(df) // self.rows_per_page + 1

    def apply_filters(self, company=None, person=None, email=None):
        self.filtered_df = self.df.copy()

        if company:
            self.filtered_df = self.filtered_df[
                self.filtered_df['company_name'].str.contains(company, case=False, na=False)
            ]

        if person:
            self.filtered_df = self.filtered_df[
                self.filtered_df['name'].str.contains(person, case=False, na=False)
            ]

        if email:
            self.filtered_df = self.filtered_df[
                self.filtered_df['email_address'].str.contains(email, case=False, na=False)
            ]

        self.update_display()

    def next_page(self):
        if self.current_page < self.total_pages - 1:
            self.current_page += 1
            self.update_display()

    def prev_page(self):
        if self.current_page > 0:
            self.current_page -= 1
            self.update_display()

    def get_page_data(self):
        start = self.current_page * self.rows_per_page
        end = start + self.rows_per_page
        return self.filtered_df.iloc[start:end]
```

---

## Integration Plan

### Phase 1: Email Tracking Integration
**Files to modify:** `ResilienceScanGUI.py`

1. Import EmailTracker at top
2. Initialize in __init__:
   ```python
   self.email_tracker = EmailTracker()
   ```

3. In load_initial_data():
   ```python
   # After loading CSV
   self.email_tracker.import_from_csv(DATA_FILE)
   ```

4. In create_email_tab():
   - Add "Email Status" section above controls
   - Add status treeview with columns: Company, Person, Email, Status, Date
   - Add filter buttons: All, Pending, Sent, Failed
   - Add manual update button

5. Before sending email:
   ```python
   status = self.email_tracker.check_if_sent(company, person, email)
   if status and status['sent']:
       if not self.confirm_resend(status):
           continue  # Skip
   ```

6. After sending email:
   ```python
   if success:
       self.email_tracker.mark_as_sent(company, person, email, pdf_file, test_mode)
   else:
       self.email_tracker.mark_as_sent(company, person, email, pdf_file, test_mode, error)
   ```

### Phase 2: Dependency Checker Tab
**Files to modify:** `ResilienceScanGUI.py`

1. Import DependencyManager:
   ```python
   from dependency_manager import DependencyManager
   ```

2. Add new tab in notebook:
   ```python
   self.create_dependencies_tab()
   ```

3. Create tab with:
   - Platform info label
   - Dependency check table (Tree view)
   - Install buttons per row
   - "Install All Missing" button
   - Refresh button
   - Installation log text area

4. On tab open:
   ```python
   self.dependency_manager = DependencyManager()
   self.dependency_manager.check_all()
   self.display_dependency_checks()
   ```

5. Install button click:
   ```python
   def install_dependency(self, dep_name):
       if dep_name.startswith('Python Package'):
           # Auto install
           result = self.dependency_manager.install_package(package_name)
           self.show_result(result)
       else:
           # Show manual instructions or download link
           self.show_install_instructions(dep_name)
   ```

### Phase 3: Enhanced Data Viewer
**Files to modify:** `ResilienceScanGUI.py`

1. Replace simple treeview with paginated viewer

2. Add pagination controls:
   ```python
   self.data_pagination_frame = ttk.Frame(data_tab)
   # Add First, Prev, Page X of Y, Next, Last buttons
   ```

3. Add filter frame:
   ```python
   self.data_filter_frame = ttk.Frame(data_tab)
   # Add filter inputs and buttons
   ```

4. Add row click event:
   ```python
   self.data_tree.bind('<Double-Button-1>', self.show_row_details)
   ```

5. Implement show_row_details():
   ```python
   def show_row_details(self, event):
       # Get selected row
       # Show dialog with all data
       # Include email status from tracker
       # Add action buttons
   ```

---

## Quick Start Guide

### Current Files:
- ✅ `ResilienceScanGUI.py` - Base GUI (needs integration)
- ✅ `email_tracker.py` - Email tracking system (ready)
- ✅ `dependency_manager.py` - Dependency checking (ready)
- ✅ `gui_system_check.py` - Basic system checks (ready)

### To Use Email Tracking Now:

```python
from email_tracker import EmailTracker

# Initialize
tracker = EmailTracker()

# Import from CSV
imported, skipped = tracker.import_from_csv("data/cleaned_master.csv")
print(f"Imported: {imported}, Skipped: {skipped}")

# Check status before sending
status = tracker.check_if_sent("Scania", "Elbrich", "elbrich@scania.com")
if status:
    print(f"Status: {status['status']}")
    print(f"Sent: {status['sent']}")
    print(f"Date: {status['date']}")

# Mark as sent
tracker.mark_as_sent(
    company="Scania",
    person="Elbrich",
    email="elbrich@scania.com",
    report_filename="report.pdf",
    test_mode=True
)

# Get statistics
stats = tracker.get_statistics()
print(stats)  # {'total': 479, 'pending': 478, 'sent': 1}

# Export for backup
tracker.export_to_csv("email_status_backup.csv")
```

### To Use Dependency Manager Now:

```python
from dependency_manager import DependencyManager

# Initialize
manager = DependencyManager()

# Check all
checks = manager.check_all()

# Show results
for check in checks:
    print(f"{check['name']}: {check['installed']} - {check['version']}")

# Check if ready
summary = manager.get_summary()
print(f"Ready: {summary['ready_for_use']}")

# Install a package
result = manager.install_package('openpyxl')
if result['success']:
    print("Installed successfully!")
```

---

## Next Steps

### Immediate (High Priority):
1. ✅ Email tracking system created
2. ✅ Dependency manager created
3. 🔄 Integrate email tracking into GUI
4. 🔄 Add dependency checker tab
5. 🔄 Enhance data viewer with pagination

### Short Term (Medium Priority):
6. Add bulk email status updates
7. Add email status export/import
8. Add dependency check on startup
9. Add warning if dependencies missing
10. Add one-click "Fix All" button

### Future Enhancements:
11. Email template editor
12. Report preview
13. Batch selection for generation
14. Scheduling/automation
15. Remote monitoring

---

## Summary

✅ **Created:** Email tracking system with SQLite database
✅ **Created:** Cross-platform dependency manager
✅ **Tested:** Both systems work independently
🔄 **Pending:** Integration into main GUI
🔄 **Pending:** Enhanced data viewer with pagination

**Status:** Core components ready, awaiting integration

---

**Last Updated:** 2025-10-20 22:00
