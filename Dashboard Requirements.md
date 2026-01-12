# ResilienceScan – Dashboard Requirements

Project: RecilienceScan  
Repository: https://github.com/Windesheim-A-I-Support/RecilienceScan  
Purpose: Add a dashboard on top of the existing CSV → validation → report → email pipeline

---

## 1. Why this dashboard exists

The RecilienceScan system already:
- Validates survey data (`validate_data_integrity.py`)
- Generates PDFs via Quarto (`generate_all_reports.py`)
- Sends them via Outlook (`send_email.py`)

The dashboard should **not replace this**.  
It should make the **results visible and explorable before and after report generation**.

The dashboard must support these decisions:

- Is this dataset clean and valid?
- Are the resilience results credible?
- What patterns exist across companies?
- What should we discuss with this company in the feedback session?
- Which companies or sectors need attention?

---

## 2. Who will use it

Primary users:

- Windesheim researchers running ResilienceScan
- Project coordinators preparing feedback sessions
- Lecturers and students working with resilience data
- In later stages: participating companies (read-only)

---

## 3. Data the dashboard must use

The dashboard uses the **same data the reports use**, not a separate system.

Primary inputs:
- Cleaned CSV after `validate_data_integrity.py`
- Derived scores that feed Quarto templates
- Historical CSVs from previous scans (for trends & benchmarks)

No raw survey platforms, no PowerBI exports, no duplication.

---

## 4. Core KPIs that must exist

These come directly from the ResilienceScan model.

| KPI | Meaning |
|-----|--------|
| Overall Resilience Score | Composite index used in reports |
| Flexibility | Ability to adapt when disruption happens |
| Redundancy | Backup suppliers, routes, capacity |
| Transparency | Visibility into the supply chain |
| Collaboration | How well partners work together |
| Risk Exposure | How vulnerable the chain is |
| Improvement Potential | Gap between current and best practice |
| Benchmark Position | How this company compares to others |

These must match what appears in the generated PDFs.

---

## 5. Views the dashboard must have

### 5.1 Data Quality View
This mirrors `validate_data_integrity.py`

Shows:
- Number of records
- Missing values
- Invalid values
- Failed validation rules
- Which companies are affected

Purpose:
Before running reports, users must see whether the data is usable.

---

### 5.2 Company Overview
One company at a time.

Shows:
- Overall Resilience Score
- Radar or bar chart of all dimensions
- Key weaknesses
- Key strengths

Purpose:
This is what consultants and researchers discuss with the company.

---

### 5.3 Benchmark View
Shows:
- Selected company vs all others
- Sector averages
- Best-in-class vs worst-in-class

Purpose:
Give context to the PDF reports and avoid “is this good or bad?” confusion.

---

### 5.4 Trend View
Uses historical CSVs.

Shows:
- Change in resilience over time
- Which dimensions are improving or declining

Purpose:
Supports longitudinal research and repeat scans.

---

### 5.5 Report & Export View
Connected to the existing pipeline.

Shows:
- Which companies have generated PDFs
- Which have been emailed
- Which failed
- Ability to download:
  - Company CSV
  - PDF report
  - Aggregated benchmark CSV

This should reflect the log files and output folders used by:
- `generate_all_reports.py`
- `send_email.py`

---

## 6. Filters that must exist

The dashboard must allow:

- Company
- Sector / industry
- Country / region
- Time (scan date)
- Dataset (CSV upload)

These filters must always match what the reports are based on.

---

## 7. Permissions

Three roles are needed:

| Role | Access |
|------|-------|
| Researcher | Full data, all companies, all benchmarks |
| Project Staff | Same as researcher, but no raw personal data |
| Company | Only their own company + anonymous benchmarks |

---

## 8. Success criteria

The dashboard is successful when:

- A researcher can decide whether a dataset is valid without opening Excel
- A feedback session can be prepared without manually opening PDFs
- Benchmarking no longer requires PowerBI
- The dashboard always matches what appears in the Quarto PDFs

---

## 9. Technical constraints

- Must read the same CSV files used by the Python scripts
- Must not create a separate data pipeline
- Must be reproducible (just like the rest of RecilienceScan)
- Must support local and server execution

---

## 10. Non-negotiable rule

If the dashboard and the PDF ever disagree,  
**the dashboard is wrong.**

The Quarto-generated reports are the source of truth.

---
