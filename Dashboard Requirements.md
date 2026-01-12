# ResilienceScan Control Dashboard

Repository: https://github.com/Windesheim-A-I-Support/RecilienceScan  

This dashboard is the **control tower** of the ResilienceScan system.  
It verifies that the **data, the pipeline, and the software stack are functioning correctly**.

It is both:
- an **operations monitor**
- a **research quality assurance layer**



---

## 1. What this dashboard must guarantee

At any moment, the dashboard must be able to answer:

- Is the data valid?
- Are the scripts running?
- Does Quarto render?
- Are PDFs produced?
- Are emails sent?
- Is the system broken anywhere?

If the answer is unclear, the system is **not trustworthy**.

---

## 2. The ResilienceScan pipeline

The system consists of:

CSV → Validation → Quarto → PDF → Email → Archive

Implemented by:

- `validate_data_integrity.py`
- `generate_all_reports.py`
- `send_email.py`
- filesystem folders
- Quarto + LaTeX
- Outlook / SMTP

The dashboard must observe every step.

---

## 3. Health checks (system diagnostics)

The dashboard must actively verify:

| Component | What must be checked |
|--------|------------------|
| Python runtime | Scripts can execute |
| Quarto | `quarto render` works |
| LaTeX | PDF engine available |
| Templates | Templates load without error |
| CSV parser | Can open uploaded data |
| Email system | Can connect and send test mail |
| File system | Output folders writable |

This is not logging.  
These are **live tests**.

---

## 4. Dataset & data integrity

The dashboard must show:

- All uploaded CSV files
- Validation status
- Which companies failed validation
- Which rules failed
- Missing or invalid values

Directly mapped to `validate_data_integrity.py`.

---

## 5. Report generation monitor

The dashboard must show:

- Which PDFs exist
- Which companies are missing PDFs
- When each report was rendered
- If Quarto or LaTeX failed

Mapped to `generate_all_reports.py` output and logs.

---

## 6. Email delivery monitor

The dashboard must show:

- Which company received which report
- When it was sent
- Which emails failed
- Error messages

Mapped to `send_email.py` logs.

---

## 7. Company status view

Each company must have a clear state:

| Stage | Status |
|------|------|
| Data | Loaded / Invalid / Missing |
| Validation | Passed / Failed |
| Report | Generated / Failed / Missing |
| Email | Sent / Failed / Not sent |
| Archive | Stored / Missing |

This makes every report auditable.

---

## 8. Benchmark & insight layer

Once the system is healthy, the dashboard also shows:

- Company resilience profile
- Benchmarks vs peers
- Trends across scans

These values must always match the Quarto PDFs.

---

## 9. Failure is visible

The dashboard must highlight:

- Broken templates
- Broken Quarto
- Broken email
- Broken CSVs
- Missing outputs

Silence is not acceptable.

---

## 10. Non-negotiable rule

If the dashboard is green,  
the system is producing correct, auditable research.

If the dashboard is red,  
no report may be trusted.

---
