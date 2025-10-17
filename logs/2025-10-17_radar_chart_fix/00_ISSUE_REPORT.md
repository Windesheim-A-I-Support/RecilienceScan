# Issue Report: Radar Chart Values Don't Match CSV Data

**Date:** 2025-10-17
**Issue ID:** Radar Chart Mismatch
**Severity:** High - Data Integrity Issue

---

## Problem Description

The radar charts in generated PDF reports are showing **incorrect values** that don't match the actual data in the CSV file.

### Example Case: Pietje Bell BV

**What the radar chart shows:**
- R = 3.0
- A = 4.1
- V = 3.8
- F = 3.3
- C = 3.8

**What the CSV actually contains:**
- R = 2.8
- A = 4.0
- V = 3.0
- F = 3.0
- C = 2.3

**Discrepancy:** All values are wrong! The radar charts are not reading from the CSV.

---

## Impact

- **All generated reports** contain incorrect resilience scores
- **All companies** are affected (not just Pietje Bell BV)
- Reports sent to clients contain wrong data
- Could damage credibility of the resilience assessment

---

## Affected Files

- `/data/Resilience - MasterDatabase(MasterData).csv` - Source data (correct)
- `example_3.qmd` - Report template with radar chart generation
- `clean_data.py` - Data cleaning script
- `generate_all_reports.py` - Batch report generation script

---

## User Request

User requested investigation into why radar chart values don't match the CSV data and fix the issue.
