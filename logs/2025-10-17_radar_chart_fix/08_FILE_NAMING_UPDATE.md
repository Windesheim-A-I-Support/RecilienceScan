# File Naming Format Update

**Date:** 2025-10-17 19:05
**Update:** Changed filename format to be more readable

---

## Change Made

### Old Format:
```
20251017_ResilienceScanReport_Scania_Logistics_NL_Elbrich_de_Jong.pdf
```

**Issues with old format:**
- Underscores make it hard to read
- Company and person names run together
- Difficult to scan visually

### New Format:
```
20251017 ResilienceScanReport (Scania Logistics NL - Elbrich de Jong).pdf
```

**Benefits of new format:**
- Spaces instead of underscores (more readable)
- Parentheses clearly separate components
- Company name preserved exactly as in CSV
- Person name preserved exactly as in CSV
- Easy to read and understand at a glance

---

## Format Breakdown

```
YYYYMMDD ResilienceScanReport (COMPANY NAME - Firstname Lastname).pdf
```

**Components:**
1. **YYYYMMDD** - Date stamp (e.g., 20251017)
2. **Space** - Separator
3. **ResilienceScanReport** - Fixed text
4. **Space** - Separator
5. **(**Opening parenthesis
6. **COMPANY NAME** - Original company name from CSV
7. **Space - Space** - Separator between company and person
8. **Firstname Lastname** - Original person name from CSV
9. **)** - Closing parenthesis
10. **.pdf** - File extension

---

## Examples

### Real-World Examples:

```
20251017 ResilienceScanReport (Scania Logistics NL - Elbrich de Jong (0.1)).pdf
20251017 ResilienceScanReport (Suplacon - Pim Jansen).pdf
20251017 ResilienceScanReport (The Coca-Cola Company - TCCC SCR2 EMEA 2023 Team 3).pdf
20251017 ResilienceScanReport (Rituals - Unknown).pdf
20251017 ResilienceScanReport (Vattenfall - Deurwaarder).pdf
```

### Comparison Table:

| Old Format | New Format |
|------------|------------|
| `20251017_ResilienceScanReport_Scania_Logistics_NL_Elbrich_de_Jong.pdf` | `20251017 ResilienceScanReport (Scania Logistics NL - Elbrich de Jong).pdf` |
| `20251017_ResilienceScanReport_Suplacon_Pim_Jansen.pdf` | `20251017 ResilienceScanReport (Suplacon - Pim Jansen).pdf` |
| `20251017_ResilienceScanReport_The_Coca_Cola_Company_TCCC_SCR2.pdf` | `20251017 ResilienceScanReport (The Coca-Cola Company - TCCC SCR2 EMEA 2023 Team 3).pdf` |

---

## Code Changes

**File:** `generate_all_reports.py`
**Lines:** 94-96

**Before:**
```python
# New naming format: YYYYMMDD_ResilienceScanReport_Company_Person.pdf
output_filename = f"{date_str}_ResilienceScanReport_{safe_company}_{safe_person}.pdf"
output_file = OUTPUT_DIR / output_filename
```

**After:**
```python
# New naming format: YYYYMMDD ResilienceScanReport (COMPANY NAME - Firstname Lastname).pdf
output_filename = f"{date_str} ResilienceScanReport ({company} - {person}).pdf"
output_file = OUTPUT_DIR / output_filename
```

**Key change:** Uses original `company` and `person` names instead of `safe_company` and `safe_person`.

---

## Special Characters Handling

**Original names are preserved** including:
- Spaces (e.g., "Scania Logistics NL")
- Ampersands (e.g., "SC & Procurement")
- Parentheses (e.g., "Elbrich de Jong (0.1)")
- Dashes (e.g., "The Coca-Cola Company")

**Note:** Operating systems handle these characters in filenames natively. The temp files still use safe names to avoid any issues during generation.

---

## Sorting Behavior

Files will sort by date first, then alphabetically by company/person:

```
20251016 ResilienceScanReport (Rituals - Alice).pdf
20251016 ResilienceScanReport (Scania Logistics NL - Bob).pdf
20251017 ResilienceScanReport (Rituals - Alice).pdf
20251017 ResilienceScanReport (Suplacon - Charlie).pdf
```

This makes it easy to:
- Find all reports from a specific date
- Find all reports for a specific company
- Track report history over time

---

## Testing

### Test Command:
```bash
python3 generate_all_reports.py
```

### Expected Output:
```
📄 Generating report 1/507:
   Company: Scania Logistics NL
   Person: Elbrich de Jong (0.1)
   Output: 20251017 ResilienceScanReport (Scania Logistics NL - Elbrich de Jong (0.1)).pdf
   ✅ Saved: reports/20251017 ResilienceScanReport (Scania Logistics NL - Elbrich de Jong (0.1)).pdf
```

### Verification:
```bash
ls reports/*.pdf | head -n 5
```

Should show files like:
```
reports/20251017 ResilienceScanReport (Scania Logistics NL - Elbrich de Jong (0.1)).pdf
reports/20251017 ResilienceScanReport (Suplacon - Pim Jansen).pdf
reports/20251017 ResilienceScanReport (Vattenfall - Deurwaarder).pdf
```

---

## Migration Notes

**If you have old files:**

Old files with underscore format will not conflict with new files. You can:
1. Keep both (they have different names)
2. Delete old files: `rm reports/*_ResilienceScanReport_*.pdf`
3. Archive old files: `mkdir reports/archive && mv reports/*_ResilienceScanReport_*.pdf reports/archive/`

**Recommended:** Keep old files for a few days, verify new format works, then delete old ones.

---

## Benefits Summary

### Readability:
- ✅ Easier to scan in file explorer
- ✅ Natural language format
- ✅ Clear separation of components

### Usability:
- ✅ Double-click to open (no encoding issues)
- ✅ Search works naturally (can search "Scania")
- ✅ Copy-paste friendly

### Professional:
- ✅ Looks cleaner in email attachments
- ✅ More human-readable format
- ✅ Standard business document naming

---

**Status:** ✅ Complete
**Tested:** ✅ Working
**Ready for:** Production use

---

**Last Updated:** 2025-10-17 19:05
