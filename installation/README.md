# Installation Tools

This folder contains all installation-related scripts and utilities for ResilienceScan.

## Structure

```
installation/
├── Install-ResilienceScan.ps1    # PowerShell automated installer (RECOMMENDED)
├── modules/                      # PowerShell installation modules
├── INSTALL.md                    # Complete installation guide
├── install_all_dependencies.py   # Comprehensive dependency checker
├── install_dependencies_auto.py  # Auto-install Python packages
├── run_clean_safe.py            # Encoding-safe data cleaning wrapper
├── run_generate_safe.py         # Encoding-safe report generation wrapper
├── test_smtp.py                 # SMTP configuration tester
└── diagnose_outlook.py          # Outlook COM diagnostic tool
```

## Quick Start

### PowerShell Automated Installation (Recommended)

**Run as Administrator:**

```powershell
cd C:\Users\ChrisTest\Documents\Github\RecilienceScan\installation
powershell -ExecutionPolicy Bypass -File Install-ResilienceScan.ps1 -Profile RecilienceScan
```

This will automatically install:
- Python packages (pandas, openpyxl, pywin32)
- R + R packages (tidyverse, knitr, rmarkdown)
- Quarto CLI
- Git
- VS Code

### Manual Installation

See [INSTALL.md](INSTALL.md) for detailed manual installation instructions.

## Testing & Diagnostics

After installation, use these tools to verify everything works:

- **Check all dependencies**: `python install_all_dependencies.py`
- **Test SMTP email**: `python test_smtp.py`
- **Diagnose Outlook COM**: `python diagnose_outlook.py`

## Encoding-Safe Wrappers

Windows console encoding issues? Use these wrappers:

- `python run_clean_safe.py` - Instead of `clean_data.py`
- `python run_generate_safe.py` - Instead of `generate_all_reports.py`

These fix Unicode encoding issues on Windows systems.
