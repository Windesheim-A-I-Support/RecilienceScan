# RecilienceScan - Installation Guide

## Quick Install (PowerShell - Recommended)

**Run as Administrator:**

```powershell
cd C:\Users\ChrisTest\Documents\Github\RecilienceScan\installation
powershell -ExecutionPolicy Bypass -File Install-ResilienceScan.ps1 -Profile RecilienceScan
```

This will automatically install:
- ✅ Python packages (pandas, openpyxl, pywin32)
- ✅ R
- ✅ R packages (tidyverse, knitr, rmarkdown)
- ✅ Quarto CLI
- ✅ Git
- ✅ VS Code

## After Installation

1. **Close and reopen your terminal** (for PATH updates)
2. **Verify installation:**
   ```bash
   cd ..
   python installation/install_all_dependencies.py
   ```
3. **Launch GUI:**
   ```bash
   python ResilienceScanGUI.py
   ```

## Manual Install (If PowerShell Fails)

### 1. Python Packages
```bash
python installation/install_dependencies_auto.py
```

### 2. Quarto
Download: https://quarto.org/docs/get-started/
```
https://github.com/quarto-dev/quarto-cli/releases/download/v1.4.549/quarto-1.4.549-win.msi
```

### 3. R
Download: https://cran.r-project.org/bin/windows/base/
```
https://cran.r-project.org/bin/windows/base/R-4.3.2-win.exe
```

### 4. R Packages
Open R console:
```r
install.packages(c("tidyverse", "knitr", "rmarkdown"))
```

## Testing Dependencies

### Test Report Generation
```bash
python installation/run_generate_safe.py
```

If you see `'quarto' is not recognized`:
- Quarto not installed OR
- Terminal not restarted after install

### Test Email Sending
```bash
python send_email.py
```

Configure SMTP settings in the file first!

## Troubleshooting

**Quarto not found:**
- Restart terminal
- Check: `quarto --version`

**R not found:**
- Restart terminal
- Check: `R --version`

**Unicode errors:**
- Use `installation/run_generate_safe.py` instead of `generate_all_reports.py`
- Use `installation/run_clean_safe.py` instead of `clean_data.py`

**Outlook COM errors:**
- Open Outlook desktop once
- Configure an email account
- See Issue #52 for details

## What Gets Installed

| Component | Purpose |
|-----------|---------|
| pandas | Data processing |
| openpyxl | Excel file handling |
| pywin32 | Outlook COM automation |
| Quarto | PDF report generation |
| R | Statistical computing |
| tidyverse | R data tools |
| knitr | R document engine |
| rmarkdown | R markdown support |

---

**Ready to use ResilienceScan!**

1. Load CSV data (Data tab)
2. Generate reports (Generation tab)
3. Send emails (Email tab)
