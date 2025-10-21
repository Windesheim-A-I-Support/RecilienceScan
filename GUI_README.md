# ResilienceScan Control Center - GUI Documentation

## Overview

The **ResilienceScan Control Center** is a graphical user interface (GUI) application that provides complete control over the ResilienceScan workflow, including:

- Data processing and validation
- PDF report generation with real-time monitoring
- Email distribution management
- System logs and status tracking

## Features

### 1. **Dashboard Tab** 📊
- Quick action buttons for common tasks
- Statistics overview showing:
  - Total respondents
  - Total companies
  - Top engaged organizations
  - Report counts
- Quick access to:
  - Data reload
  - Generate all reports
  - Send all emails
  - Generate executive dashboard

### 2. **Data Tab** 📁
- Browse and load CSV data files
- Preview data in table format (first 100 rows)
- View data statistics:
  - Total records
  - Unique companies
  - Column information
- Real-time data validation

### 3. **Generation Tab** 📄
- **Controls:**
  - Select template (ResilienceReport.qmd or ExecutiveDashboard.qmd)
  - Choose output folder
  - Start/Pause/Cancel generation

- **Real-time Monitoring:**
  - Progress bar showing completion percentage
  - Current company/person being processed
  - Success/failure counts
  - Detailed generation log with timestamps

- **Features:**
  - See exactly which PDF is being created
  - Monitor data being processed
  - Track errors in real-time
  - Pause or cancel at any time

### 4. **Email Tab** 📧
- **Test Mode:**
  - Safe testing with test email address
  - Visual warning when test mode is disabled
  - Prevents accidental live sending

- **Email Controls:**
  - Start/Stop email distribution
  - Set test email address
  - Monitor sending progress

- **Tracking:**
  - Which emails were sent
  - Which emails failed
  - Real-time status updates
  - Detailed email log

### 5. **Logs Tab** 📋
- **System Log:** All application events
- **Features:**
  - Refresh logs
  - Clear logs
  - Export logs to file
  - Timestamps for all events

## Installation

### Prerequisites

1. **Python 3.8+**
   ```bash
   python3 --version
   ```

2. **Required Python Packages:**
   ```bash
   pip install pandas
   # tkinter usually comes with Python
   ```

3. **R (for report generation)**
   - Download from: https://www.r-project.org/

4. **Quarto (for PDF generation)**
   - Download from: https://quarto.org/

### Setup

1. **Navigate to project directory:**
   ```bash
   cd /home/chris/Documents/github/RecilienceScan
   ```

2. **Run system check:**
   ```bash
   python3 gui_system_check.py
   ```

3. **Launch GUI:**
   ```bash
   ./launch_gui.sh
   ```

   Or directly:
   ```bash
   python3 ResilienceScanGUI.py
   ```

## Usage Guide

### Starting the GUI

**Option 1: Using the launcher (recommended)**
```bash
./launch_gui.sh
```
- Performs system checks first
- Shows any warnings or errors
- Launches GUI if all critical components are present

**Option 2: Direct launch**
```bash
python3 ResilienceScanGUI.py
```

### Loading Data

1. **On startup,** data automatically loads from `data/cleaned_master.csv`

2. **To load different data:**
   - Go to **Data** tab
   - Click **Browse...**
   - Select CSV file
   - Data preview updates automatically

### Generating Reports

#### Generate All Reports:

1. Go to **Generation** tab
2. Select template: `ResilienceReport.qmd`
3. Click **▶ Start Generation**
4. Monitor progress:
   - Progress bar shows completion %
   - Current label shows which company/person
   - Log shows detailed status
5. **Pause** if needed (planned feature)
6. **Cancel** to stop generation

#### Generate Executive Dashboard:

1. Go to **Dashboard** tab
2. Click **📈 Generate Executive Dashboard**
3. Wait for completion (30-60 seconds)
4. PDF saved as `ExecutiveDashboard.pdf`

### Sending Emails

⚠️ **Important:** Always test first!

#### Test Mode (Safe):

1. Go to **Email** tab
2. Ensure **Test Mode** is **CHECKED** ✅
3. Enter your test email address
4. Click **▶ Start Sending**
5. All emails go only to test address
6. Monitor in email log

#### Live Mode (Production):

1. ⚠️ **Disable test mode** (uncheck box)
2. **CONFIRM** warning dialog
3. Emails will go to **real recipients**
4. Monitor progress carefully
5. **Stop** button available if needed

### Viewing Logs

1. Go to **Logs** tab
2. **System Log** shows all events
3. Use buttons to:
   - **Refresh** - Reload from log file
   - **Clear** - Remove all logs
   - **Export** - Save to external file

## Real-Time Monitoring

### What You Can See:

#### During Generation:
✅ **Exactly which company** is being processed
✅ **Which person's** report is being created
✅ **Progress percentage** (e.g., 127/507)
✅ **Success vs. failure count**
✅ **Detailed logs** with timestamps
✅ **Current file being generated**

#### During Email Sending:
✅ **Which email** is being sent
✅ **To which recipient**
✅ **Success/failure status**
✅ **Test mode indicator**
✅ **Real-time log** of all actions

### Status Indicators:

| Indicator | Meaning |
|-----------|---------|
| 📊 Blue numbers | Live statistics |
| ✅ Green checkmarks | Successful operations |
| ❌ Red X | Errors or failures |
| ⚠️ Yellow warning | Warnings or notes |
| 🔄 Arrows | Progress/activity |

## System Checks

The GUI performs automatic system checks:

### Critical Checks:
- ✅ Python version (3.8+)
- ✅ Required Python packages
- ✅ R installation
- ✅ Quarto installation
- ✅ Required files exist
- ✅ Data files are readable
- ✅ Directories are accessible

### Running Manual Check:
```bash
python3 gui_system_check.py
```

### Check Report Includes:
- Python version
- Package availability
- R and Quarto versions
- File existence and sizes
- Data file status (rows, columns)
- Directory contents
- Errors and warnings

## Troubleshooting

### GUI Won't Start

**Problem:** `tkinter` not found
**Solution:**
```bash
# Ubuntu/Debian
sudo apt-get install python3-tk

# Fedora
sudo dnf install python3-tkinter

# macOS (with Homebrew)
brew install python-tk
```

**Problem:** Import errors
**Solution:**
```bash
pip install pandas
```

### Data Won't Load

**Problem:** File not found
**Solution:**
- Check `data/cleaned_master.csv` exists
- Run `python3 clean_data.py` to create it
- Or use **Browse** to select different file

### Generation Fails

**Problem:** Quarto not found
**Solution:**
- Install Quarto from https://quarto.org/
- Restart terminal/GUI
- Run system check to verify

**Problem:** R errors
**Solution:**
- Install R from https://www.r-project.org/
- Run `Preinstallv2.sh` to install R packages
- Check R is in PATH

### Email Errors

**Problem:** Outlook not found
**Solution:**
- Currently requires Windows with Outlook
- Linux/Mac support planned

## File Structure

```
ResilienceScan/
├── ResilienceScanGUI.py          ← Main GUI application
├── gui_system_check.py           ← System validation
├── launch_gui.sh                 ← Launcher script
├── GUI_README.md                 ← This file
│
├── ResilienceReport.qmd          ← Individual report template
├── ExecutiveDashboard.qmd        ← Executive dashboard template
├── generate_all_reports.py       ← Batch generation script
├── send_email.py                 ← Email distribution script
├── clean_data.py                 ← Data preprocessing
│
├── data/
│   └── cleaned_master.csv        ← Main data file
│
├── reports/                      ← Generated PDFs
│
└── logs/                         ← Log files
    └── gui_log.txt               ← GUI activity log
```

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| Ctrl+R | Reload data |
| Ctrl+G | Go to Generation tab |
| Ctrl+E | Go to Email tab |
| Ctrl+L | Go to Logs tab |
| Ctrl+Q | Quit application |
| F5 | Refresh current view |

*(Planned features)*

## Tips & Best Practices

### 1. **Always Test First**
- Use test mode for emails
- Generate a few reports manually first
- Check logs for errors

### 2. **Monitor Progress**
- Watch the generation log
- Check for errors in real-time
- Pause if something looks wrong

### 3. **Backup Data**
- Keep original CSV files
- Export logs regularly
- Save system check reports

### 4. **Check System Health**
- Run system check before major operations
- Update Quarto/R regularly
- Verify data integrity

### 5. **Email Safety**
- Double-check test mode setting
- Verify test email address
- Start with small batches

## Advanced Features (Planned)

🔜 **Scheduled Generation** - Set times for automatic generation
🔜 **Batch Selection** - Choose specific companies/people
🔜 **Email Templates** - Customize email content
🔜 **Report Preview** - View PDFs in GUI
🔜 **Statistics Charts** - Visual analytics
🔜 **Export Reports** - Bulk export functionality
🔜 **Filter Data** - Advanced data filtering
🔜 **Multi-threading** - Faster generation

## Support

### Getting Help:

1. **Check Logs:**
   - Go to Logs tab
   - Look for error messages
   - Export and share if needed

2. **Run System Check:**
   ```bash
   python3 gui_system_check.py
   ```

3. **Check Documentation:**
   - This file (GUI_README.md)
   - Main README.md
   - logs/ folder documentation

### Common Questions:

**Q: Can I close the GUI during generation?**
A: Yes, but generation will stop. Use Pause/Cancel instead.

**Q: Where are PDFs saved?**
A: In `reports/` folder, named `YYYYMMDD ResilienceScanReport (Company - Person).pdf`

**Q: Can I change the email template?**
A: Edit `send_email.py` for custom email content.

**Q: How do I know if an email was sent?**
A: Check the Email Log tab for detailed status.

## Version History

### v1.0 (2025-10-20)
- ✅ Initial release
- ✅ Dashboard with statistics
- ✅ Data viewing and loading
- ✅ PDF generation monitoring
- ✅ Email distribution interface
- ✅ System logging
- ✅ System health checks

### Planned for v1.1:
- 🔜 Report preview
- 🔜 Batch selection
- 🔜 Enhanced error handling
- 🔜 Linux/Mac email support

## License

© 2025 Supply Chain Finance Lectoraat, Hogeschool Windesheim

## Credits

**Developer:** Claude (Anthropic)
**Project Lead:** Ronald de Boer
**Institution:** Hogeschool Windesheim
**Research Group:** Supply Chain Finance Lectoraat

---

**Last Updated:** 2025-10-20
**Version:** 1.0
