# Project Title
<!-- Optional: logo/banner here -->
<!-- Badges: build status | license | last release | docs | code style -->

---

## 📑 Table of Contents
- [Objective](#objective)
- [Motivation & Methodology](#motivation--methodology)
- [Project Need](#project-need)
- [Use Cases](#use-cases)
- [Scope & Non-Goals](#scope--non-goals)
- [Roadmap (Milestones)](#roadmap-milestones)
- [Architecture Overview](#architecture-overview)
- [Directory Structure](#directory-structure)
- [Technical Proposal](#technical-proposal)
- [Getting Started](#getting-started)
- [Configuration](#configuration)
- [Validation Spec](#validation-spec)
- [Logging & Audit](#logging--audit)
- [Testing Strategy](#testing-strategy)
- [Known Limitations & Future Work](#known-limitations--future-work)
- [Design Decisions](#design-decisions)
- [Dependencies](#dependencies)
- [Code/Data Provenance](#codedata-provenance)
- [Standardization Notice](#standardization-notice)
- [Researcher/End-User Acceptance Test](#researcherend-user-acceptance-test)
- [Troubleshooting & FAQ](#troubleshooting--faq)
- [Project Board & Automation](#project-board--automation)
- [Contributing](#contributing)
- [Security & Privacy](#security--privacy)
- [Compliance & Branding](#compliance--branding)
- [Community & Governance](#community--governance)
- [Citation](#citation)
- [References](#references)
- [License](#license)
- [Acknowledgements & Contact](#acknowledgements--contact)
- [Changelog](#changelog)
- [Release Checklist](#release-checklist)

---

## Frequent Problems

It says it cannot find the packages: But R is installed: Then you might need to install the packages manually; Please open an eleveted Administrator prompt
Make sure you have execution rights and 

```
Rscript -e "install.packages(c('readr', 'dplyr', 'stringr', 'tidyr', 'ggplot2', 'knitr', 'fmsb', 'scales', 'viridis', 'patchwork', 'RColorBrewer', 'gridExtra', 'png', 'lubridate', 'kableExtra'), repos = 'https://cloud.r-project.org')"
```

## 📌 Objective

The **Resilience Report Automation & Open-Source Survey Pipeline** project exists to reduce the manual burden of producing, validating, and distributing survey-based reports.  

- **Current Deliverable (M1):**  
  A reproducible, researcher-friendly pipeline that accepts cleaned CSV files, validates them, generates **branded PDF reports** using Quarto + LaTeX, and sends them via Outlook email with logging for traceability.

- **Long-Term Vision:**  
  Transition from today’s manual Power BI/Excel exports into a **fully open-source survey infrastructure** where surveys can be:  
  1. **Designed** in open-source survey tools.  
  2. **Published** on the web.  
  3. **Collected** into a secure, open database.  
  4. **Validated & Transformed** automatically.  
  5. **Reported** via Quarto into branded outputs.  
  6. **Delivered** automatically to respondents and stakeholders.  
  7. **Archived** for reproducibility and deeper research analysis.  

This objective ensures **trust, efficiency, and reproducibility** in reporting workflows while aligning with Windesheim and VCH’s broader push toward **open science** and **EU-aligned compliance**.


---

## 🧬 Motivation & Methodology
<!-- Academic/research gap addressed, objectives, hypotheses, methodology summary. Reference any related papers or datasets. -->

### Motivation
The current workflow for generating Resilience Reports is **manual, error-prone, and difficult to reproduce**:  
- Data is exported from Power BI/Excel and manually cleaned.  
- Reports are created by hand, leading to inconsistent formatting and branding.  
- Distribution relies on manual email attachments, which introduces risk and wastes researcher time.  

Researchers, stakeholders, and institutions need a **reliable, auditable, and automated system** that ensures:  
- **Efficiency** — less time spent on repetitive formatting and distribution.  
- **Consistency** — reports always follow institutional branding and design standards.  
- **Trust** — outputs are validated and traceable back to their source data.  
- **Reproducibility** — the entire process can be replicated by any researcher, not just the original developer.  

### Methodology
This project applies a **stepwise, milestone-driven approach** to build up from manual reproducibility to full automation:  

1. **Baseline (M1):** Automate report generation and delivery from cleaned CSVs using Quarto + Outlook.  
2. **Incremental Automation (M2–M4):** Introduce scripted validation, CI/CD reproducibility checks, and event-driven delivery pipelines.  
3. **Survey Pipeline Integration (M5–M6):** Transition from Excel/Power BI exports into open-source survey tools (e.g., Formbricks, LimeSurvey) with direct data ingestion.  
4. **Full Open-Source Pipeline:** Surveys designed, published, validated, reported, and delivered end-to-end with storage for long-term analysis.  

The methodology emphasizes:  
- **Open-source tools** (Quarto, LaTeX, R/Python, survey platforms).  
- **Researcher usability** (installer scripts, documentation, acceptance tests).  
- **Validation & auditability** (schema checks, logs, traceability).  
- **Scalability & governance** (institutional branding, EU compliance alignment).  

---

## 🔎 Project Need

### Pain Points in the Current Workflow
- **Manual effort:** Reports require exporting from Power BI, cleaning in Excel, formatting, and emailing — all by hand.  
- **Inconsistency:** Branding and layout differ between researchers, reducing professional appearance and trust.  
- **Fragility:** Knowledge of how to build the reports is tacit and not documented — if a researcher leaves, the workflow breaks.  
- **Risk of errors:** Copy-paste steps and manual attachments create opportunities for mistakes.  
- **Limited reproducibility:** Results cannot easily be replicated on a different machine or by a new team member.  

### Institutional Context
- **Windesheim University & VCH (Value Chain Hackers):**  
  Require reproducible, trustworthy reporting pipelines that scale beyond one researcher’s laptop.  
- **EU Compliance & Open Science:**  
  Projects increasingly need to demonstrate **traceability, reproducibility, and transparency** (e.g., CSRD, CSDDD, EUDR).  
- **Research Infrastructure Gap:**  
  Many research groups rely on fragile, manual tools (Excel, Power BI) — this project fills the gap with open-source infrastructure.  

### Why This Project is Needed
- **Empower researchers:** Any researcher should be able to generate and send validated, branded reports independently.  
- **Ensure continuity:** The process must survive beyond individuals and be documented for handover.  
- **Save time:** Automating repetitive steps frees researchers to focus on analysis, not formatting.  
- **Increase trust:** Consistent branding, validated data, and logged deliveries strengthen credibility with external stakeholders.  
- **Enable scalability:** Creates the foundation for a fully open-source survey pipeline, ready for more advanced automation and integration.  

---

## 💡 Use Cases

### Current Use Case
Today, generating a Resilience Report requires:  
1. Exporting survey results from Power BI into Excel.  
2. Manually cleaning and saving the data as a CSV file.  
3. Formatting results into a report by hand.  
4. Attaching and sending the report via Outlook.  

**Problems this creates:**  
- Time-consuming and repetitive.  
- Reports differ in look and feel depending on who creates them.  
- High risk of errors in copy-pasting or attaching the wrong file.  
- Not reproducible by a new researcher without personal guidance.  

---

### Ultimate Vision Use Case
The long-term goal is a **fully open-source survey pipeline**:  
1. **Survey Design:** Researchers design a new survey using open-source survey tools.  
2. **Publication:** The survey is published online for participants to access.  
3. **Data Collection:** Responses are collected automatically into an open database.  
4. **Validation & Transformation:** Responses are validated and cleaned automatically, ensuring quality and reliability.  
5. **Report Generation:** Quarto + LaTeX produce branded PDF/HTML reports, including validation summaries.  
6. **Automated Delivery:** Reports are automatically emailed to respondents and stakeholders, integrated into existing workflows (e.g., Outlook).  
7. **Archival & Analysis:** Reports and raw data are archived for reproducibility and available for deeper, longitudinal analysis.  

**Benefits of this vision:**  
- No manual intervention needed.  
- Reports always branded and validated.  
- Full transparency and traceability from survey → report → delivery.  
- Scales easily for new surveys, larger datasets, and multiple researchers.  


---

## 🛠️ Scope & Non-Goals

### In Scope (for current milestone M1)
- **Validated CSV workflow:** Start from a manually cleaned CSV exported from Power BI/Excel.  
- **Validation checks:** Basic schema and business rules to ensure data integrity.  
- **Report generation:** Quarto + LaTeX produce branded PDF reports (with title pages, fonts, and layouts standardized).  
- **Email delivery:** Outlook integration to send the correct report(s) to the correct recipient(s).  
- **Logging & traceability:** Timestamped logs of validation, reporting, and email delivery.  
- **Reproducibility:** Installer script tested on a clean VM so another researcher can set up and run the system.  
- **Documentation:** README, screenshots, and Researcher Acceptance Test to enable handover.  

### Out of Scope (for now, future milestones)
- **Automated ingestion from WordPress:** Monitoring and downloading new files automatically.  
- **Full replacement of PowerAutomate:** Integration with existing Microsoft automation flows remains manual for now.  
- **Scheduling/CI pipelines:** GitHub Actions and automated scheduling are considered optional stretch goals in M1.  
- **Multi-language reports:** Only a single language/branding variant supported in the first release.  
- **Survey tool integration:** No direct integration yet with open-source survey platforms (Formbricks, LimeSurvey, etc.).  
- **Advanced analytics:** Focus is on report reproducibility, not extended dashboards or statistical modeling.  


## 📈 Roadmap (Milestones)

The project follows a **milestone-driven roadmap**, moving from manual reproducibility → automation → full open-source survey pipelines.


### **M1 — Feature Release One (Current)**
- Researcher-runnable workflow.  
- Input: cleaned CSV (from Power BI/Excel).  
- Validation checks (schema + business rules).  
- Quarto + LaTeX generate branded PDF(s).  
- Outlook integration sends reports to correct recipients.  
- Logs capture validation and delivery events.  
- Tested on a clean VM + Researcher Acceptance Test.  


### **M2 — Semi-Automated Local Flow**
- Replace manual Excel cleaning with scripted data transformation.  
- One command validates → renders → delivers reports.  
- Installer and documentation updated.  


### **M3 — CI/CD Integration**
- GitHub Actions pipeline builds reports from a sample CSV.  
- Ensures reproducibility and provides acceptance artifacts.  
- Optionally caches TinyTeX for faster builds.  


### **M4 — Automated Delivery**
- Event-driven or scheduled pipelines.  
- Monitor WordPress (or other sources) for new files.  
- Auto-download and trigger report workflow.  
- Delivery status updated automatically.  


### **M5 — Open-Source Survey Integration**
- Transition from Power BI/Excel to open-source survey platforms (e.g., Formbricks, LimeSurvey).  
- Direct ingestion of responses into storage.  
- End-to-end validation pipeline introduced.  

---

### **M6 — Full Open-Source Survey Pipeline**
- Complete automation: survey design → publish → collect → validate → report → deliver → archive.  
- Long-term storage in an open database.  
- Reports and data archived for reproducibility and longitudinal analysis.  
- Scales to multiple surveys, teams, and institutional use.  

---

## 🏗️ Architecture Overview

> High-level view of how data flows from source → validation → reporting → delivery → archival.  
> (Adjust nodes as the project evolves.)

```mermaid
flowchart LR
  subgraph Source
    WP[Website / Export (WordPress, Power BI/Excel)]
    CSV[Cleaned CSV]
  end

  subgraph Pipeline
    VAL[Validate (schema + rules)]
    QMD[Render (Quarto + LaTeX)]
    PKG[Package (per-recipient PDFs)]
    MAIL[Deliver (Outlook / n8n)]
  end

  subgraph Storage
    LOGS[Logs & Status]
    AR[Archive (reports, inputs)]
    DB[(Future: DB/Object Store)]
  end

  WP --> CSV --> VAL --> QMD --> PKG --> MAIL
  VAL --> LOGS
  QMD --> AR
  MAIL --> LOGS
  AR --> DB
```

## 🗂️ Directory Structure


### Components (Summary)
- **Ingestion (Current → Future):**  
  Manual placement of a **cleaned CSV** (M1) → WordPress watcher / scripted download (M4) → direct open-source survey ingest (M5–M6).

- **Validation:**  
  Schema and business-rule checks with clear error messages; fail-fast behavior and actionable guidance.

- **Reporting:**  
  **Quarto + LaTeX** render branded PDF/HTML; title pages, fonts, and layout standardized.

- **Packaging:**  
  (Optional) Split outputs per company/recipient; file naming conventions for traceability.

- **Delivery:**  
  **Outlook** (M1) for seamless researcher workflow → **n8n/SMTP** as automation matures.

- **Storage & Audit:**  
  Store inputs/outputs, **logs**, and send-status files; future move to **database/object storage** for durability and analysis.

- **Orchestration (Future):**  
  **n8n** or similar to connect watchers → validation → rendering → delivery → archival; optional **GitHub Actions** for CI acceptance builds.

---

## ⚙️ Technical Proposal

### Ingestion
- **Current (M1):**  
  Researchers manually export from Power BI/Excel and save a cleaned CSV into the `data/` folder.  
- **Near-Term (M4):**  
  Script or n8n flow checks the WordPress site for new files, downloads them if updated, and places them in the correct folder.  
- **Long-Term (M5–M6):**  
  Direct integration with open-source survey platforms (e.g., Formbricks, LimeSurvey) feeding responses into structured storage.


### Validation & Transformation
- **Schema Validation:**  
  A lightweight script (Python or R) ensures required columns, formats, and ranges are correct.  
- **Business Rules:**  
  Additional checks (e.g., minimum sample size, plausible value ranges, trend sanity checks).  
- **Error Handling:**  
  Fail-fast with clear messages and “how to fix” guidance. Validation log stored in `logs/`.

### Reporting
- **Renderer:** Quarto CLI with TinyTeX installed locally.  
- **Templates:** Branded `.qmd` templates using Windesheim/VCH title pages, fonts, and styling.  
- **Outputs:**  
  - Branded PDFs (primary).  
  - Optional HTML for previews or interactive reports.  
- **Packaging:**  
  Naming conventions ensure per-recipient reports are identifiable (e.g., `reports/2025Q3_companyname.pdf`).


### Delivery
- **Current (M1):**  
  Python script sends PDFs via Outlook using the researcher’s existing email profile.  
- **Future:**  
  - n8n SMTP node for automation.  
  - Delivery confirmation and retry logic.  
  - Optional multiple channels (e.g., Teams, Slack, or secure links).


### Storage & Archival
- **Current:**  
  - `reports/` holds all generated PDFs.  
  - `logs/` tracks validation results and email delivery.  
- **Future:**  
  - Database (Postgres + Supabase) or object storage (S3/MinIO) for durability and long-term analysis.  
  - Metadata (input hash → report hash → delivery log) enables traceability.

### Orchestration
- **Current (M1):**  
  Step-by-step execution documented in README (`validate → render → send`).  
- **Future:**  
  - n8n flows to watch sources, trigger validation, reporting, delivery, and archival.  
  - GitHub Actions to run acceptance tests on a sample CSV and store a test PDF as artifact.  
  - Scheduling (cron/n8n) for periodic runs or event-driven triggers.  


### Guiding Principles
- **Reproducibility:** Entire pipeline must work on a clean VM with no hidden dependencies.  
- **Open Source First:** Prefer open-source tools over proprietary automation.  
- **Researcher-Friendly:** Simple commands, installer scripts, and documentation.  
- **Traceability:** Every report linked back to its source data, with logs for audit.  


## 🚀 Getting Started

Follow these steps to set up the project on a clean environment.  
*(Adjust commands for Windows/Linux as needed — the goal is reproducibility across systems.)*

---

### Prerequisites
- **Operating System:** Windows VM recommended (for Outlook integration).  
- **Installed Tools:**  
  - [Quarto CLI](https://quarto.org/docs/get-started/)  
  - [TinyTeX](https://yihui.org/tinytex/) (installer script provided)  
  - [Python 3.11+](https://www.python.org/downloads/)  
  - R (optional, for data validation scripts if using R-based tooling)  
- **Email:** Outlook desktop client with an active account.  
- **Git:** for cloning and version control.  

---

### Installation
1. Clone the repository:  
   \\```bash
   git clone https://github.com/<your-org>/<your-repo>.git
   cd <your-repo>
   \\```

2. Run the installer script to set up Quarto, TinyTeX, required fonts, and Python dependencies:  
   \\```bash
   scripts/install.bat   # Windows
   # or
   bash scripts/install.sh  # Linux/macOS
   \\```

3. Verify installation:  
   \\```bash
   quarto check
   python --version
   \\```

---

### First Run
1. Place your **cleaned CSV** file into the `data/` folder:  
   \\```
   data/input.csv
   \\```

2. Validate the CSV:  
   \\```bash
   python scripts/validate_csv.py data/input.csv
   \\```  
   - ✅ Success → proceed to rendering.  
   - ❌ Failure → see error messages in `logs/validation.log` and fix input.

3. Render the report:  
   \\```bash
   quarto render reports/template.qmd --to pdf
   \\```  
   - Output saved in `reports/`.

4. Send the report via Outlook:  
   \\```bash
   python scripts/send_email.py --map config/recipients.csv --src reports/
   \\```  
   - Delivery log appended to `logs/email_log.csv`.  

---

### Example Outputs
- **PDF Report:** `reports/2025Q3_example_company.pdf`  
- **Validation Log:** `logs/validation.log`  
- **Email Log:** `logs/email_log.csv`  

---

📌 **Next Step:** See [Configuration](#configuration) for details on customizing recipients, validation rules, and branding.

---

## 🔧 Configuration

The project relies on a small number of configuration files and environment settings to remain flexible and reproducible.

---

### Directory Structure
\\```
.
├── config/                 # Configuration files
│   ├── recipients.csv      # Mapping of company → email
│   ├── schema.json         # Schema for validation
│   ├── rules.yml           # Business rules for validation
│
├── data/                   # Input data
│   └── input.csv           # Cleaned CSV placed here
│
├── reports/                # Generated reports
│   └── <period>_<company>.pdf
│
├── logs/                   # Logs and audit trails
│   ├── validation.log
│   ├── email_log.csv
│   └── run_log.csv
│
├── scripts/                # Helper scripts
│   ├── install.*           # Installer (Windows/Linux)
│   ├── validate_csv.*      # Validation script
│   └── send_email.py       # Outlook delivery script
│
├── docs/                   # Documentation
│   └── data_dictionary.md
│
└── tests/                  # Unit and acceptance tests
\\```

---

### Recipients Mapping (`config/recipients.csv`)
\\```
company,email
Acme Ltd,reports@acme.com
Beta BV,ops@beta.example
Gamma GmbH,info@gamma.de
\\```

- Used by `send_email.py` to route the correct report to the correct recipient.  
- Each row must correspond to a company present in the CSV data.

---

### Validation Schema (`config/schema.json`)
Defines required columns and expected types. Example:  
\\```json
{
  "columns": {
    "company": "string",
    "period": "string",
    "score_total": "number",
    "n_responses": "integer"
  },
  "constraints": {
    "score_total": {"min": 0, "max": 100},
    "n_responses": {"min": 5}
  }
}
\\```

---

### Business Rules (`config/rules.yml`)
Captures additional checks not enforced by schema. Example:  
\\```yaml
rules:
  - name: "Minimum responses per company"
    field: "n_responses"
    condition: ">= 5"
    message: "At least 5 responses required per company."
  - name: "Score within range"
    field: "score_total"
    condition: "0 <= value <= 100"
    message: "Score must be between 0 and 100."
\\```

---

### Environment Variables
- `OUTLOOK_PROFILE`: Outlook profile to use for sending emails.  
- `REPORT_PERIOD`: Optional override for the reporting period label.  
- `DATA_PATH`: Location of input data file (defaults to `data/input.csv`).  

---

### Branding & Templates
- **Quarto templates** are stored in `reports/` and include:  
  - `template.qmd` for report structure.  
  - `titlepage.tex` for LaTeX title page customization.  
  - Fonts embedded via TinyTeX installation.  


## 👩‍🔬 Researcher/End-User Acceptance Test
<!-- Checklist or template for testing by non-developers. -->
## 👩‍🔬 Researcher/End-User Acceptance Test

The **Researcher Acceptance Test (RAT)** ensures that the pipeline can be executed successfully by a non-developer, using only the provided documentation.

---

### Test Environment
- **VM / Machine Name:** _____________________  
- **Operating System:** _____________________  
- **Date:** _____________________  
- **Researcher Name:** _____________________  

---

### Checklist

1. **Setup & Installation**
   - [ ] Clone repository successfully.  
   - [ ] Run installer script without errors.  
   - [ ] Quarto, TinyTeX, and Python confirmed working.  

2. **Input Preparation**
   - [ ] Place cleaned CSV into `data/`.  
   - [ ] Confirm file is correctly named (`input.csv` or configured name).  

3. **Validation**
   - [ ] Run `validate_csv` script.  
   - [ ] Invalid CSV → clear error message shown.  
   - [ ] Valid CSV → success message shown.  

4. **Report Generation**
   - [ ] Run Quarto render command.  
   - [ ] PDF produced in `reports/` folder.  
   - [ ] Branding and layout match expectations (title page, fonts, logos).  

5. **Email Delivery**
   - [ ] Run email script with `recipients.csv` mapping.  
   - [ ] Correct PDF sent to correct recipient.  
   - [ ] Confirmation in `logs/email_log.csv`.  

6. **Logging & Traceability**
   - [ ] `validation.log` created/updated.  
   - [ ] `email_log.csv` updated with timestamp and result.  

---

### Outcome
- **Pass / Fail:** _____________________  
- **Notes / Gotchas:**  
  - ________________________________________________________  
  - ________________________________________________________  

- **Signature:** _____________________  

---

## 🩺 Troubleshooting & FAQ
<!-- Common errors and solutions. -->

---

## 📋 Project Board & Automation
<!-- Project board structure, automation rules. -->

---

## 🤝 Contributing
<!-- Guidelines, code style, branching model, code of conduct. -->

---

## 🔒 Security & Privacy
<!-- Secrets management, data protection policies. -->

---

## 🏛️ Compliance & Branding
<!-- Regulatory/institutional requirements, branding. -->

---

## 🌐 Community & Governance
<!-- Contributor interaction guidelines, governance model. -->

---

## 📚 Citation
<!-- Citation formats (BibTeX, DOI) if for research. If academic, add preferred reference format. -->

---

## 📖 References
<!-- List key sources, datasets, related papers, documentation. -->

---

## 📜 License
<!-- License type, SPDX ID. -->

---

## 🙏 Acknowledgements & Contact
<!-- Team, institutions, contributors, funders, contact info. Include at least two contacts (institutional & personal email recommended). -->

---

## 🗓️ Changelog
<!-- Semantic changelog; major updates per version. -->

---

## 📦 Release Checklist
<!-- Pre-release verification items. -->


```





