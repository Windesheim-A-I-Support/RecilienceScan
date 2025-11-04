# NA Value Handling Fix

**Date:** 2025-11-04
**Issue:** Reports showing wrong scores when CSV contains NA/missing values
**Status:** ✅ FIXED

---

## Problem Description

When generating reports, records with missing score data (NaN in CSV) were being replaced with 2.5 before calculating pillar averages. This caused incorrect overall scores.

**Example:**
- Marcus Pribi Setyo N from Technology Company has ALL upstream scores as NaN
- Old behavior: Replaced all 5 NaN values with 2.5, calculated upstream_avg = 2.5
- Expected: If ALL scores are missing, upstream_avg should be NA (excluded from overall)
- Result: Overall score was 3.71 instead of 4.32 (because it incorrectly included 2.5 for upstream)

---

## Root Cause

**[ResilienceReport.qmd](ResilienceReport.qmd:1523-1556)** was replacing ALL NA values with 2.5 BEFORE calculating averages:

```r
# OLD CODE (WRONG):
col_data[is.na(col_data)] <- 2.5  # Replace ALL NAs with 2.5

# Then calculate averages
upstream_avg <- mean(c(...), na.rm = TRUE)  # But there are no NAs anymore!
```

This meant:
1. Missing individual scores → replaced with 2.5
2. Average of [2.5, 2.5, 2.5, 2.5, 2.5] = 2.5
3. Overall includes the incorrect 2.5 average
4. Validation fails because CSV shows NA but report shows 2.5

---

## Solution

**Keep NA values as NA** during average calculations, only use 2.5 for visualization:

```r
# NEW CODE (CORRECT):
# Keep NAs as NA - do NOT replace with 2.5
col_data <- ifelse(is.na(col_data), NA, pmax(0, pmin(5, col_data)))

# Calculate pillar averages properly
upstream_scores <- c(up__r, up__c, up__f, up__v, up__a)

# If ALL scores are NA, average is NA (not NaN)
upstream_avg <- if(all(is.na(upstream_scores))) NA else mean(upstream_scores, na.rm = TRUE)

# Overall score excludes NA pillars
overall_score <- mean(c(upstream_avg, internal_avg, downstream_avg), na.rm = TRUE)
```

**For visualizations** (radar charts), we DO replace NA with 2.5:
```r
# In create_radar() function:
scores[is.na(scores)] <- 2.5  # Only for displaying on radar chart
```

**For display labels:**
```r
# Show "N/A" instead of formatting NA as a number
up_label <- if(is.na(upstream_avg)) "N/A" else sprintf("%.1f", upstream_avg)
```

---

## Changes Made

### 1. Data Cleaning ([ResilienceReport.qmd:1523-1556](ResilienceReport.qmd:1523-1556))

**Before:**
```r
col_data[is.na(col_data)] <- 2.5  # WRONG: Replaces all NAs
dashboard_data[[col]] <- pmax(0, pmin(5, col_data))
```

**After:**
```r
# Keep NA as NA, only clamp valid values
col_data <- ifelse(is.na(col_data), NA, pmax(0, pmin(5, col_data)))
dashboard_data[[col]] <- col_data
```

### 2. Pillar Average Calculation ([ResilienceReport.qmd:1545-1556](ResilienceReport.qmd:1545-1556))

**Before:**
```r
upstream_avg <- mean(c(up__r, up__c, up__f, up__v, up__a), na.rm = TRUE)
# Problem: If ALL values are NA, this returns NaN
```

**After:**
```r
upstream_scores <- c(up__r, up__c, up__f, up__v, up__a)
upstream_avg <- if(all(is.na(upstream_scores))) NA else mean(upstream_scores, na.rm = TRUE)
# If ALL missing → NA (not NaN)
# If SOME missing → average of non-missing values
# If NONE missing → normal average
```

### 3. Radar Chart Labels ([ResilienceReport.qmd:1783-1789](ResilienceReport.qmd:1783-1789))

**Before:**
```r
create_radar("up", paste0("Upstream Resilience\n(μ=", sprintf("%.1f", upstream_avg), ")"), ...)
# Problem: Shows "NA" as a malformed string
```

**After:**
```r
up_label <- if(is.na(upstream_avg)) "N/A" else sprintf("%.1f", upstream_avg)
create_radar("up", paste0("Upstream Resilience\n(μ=", up_label, ")"), ...)
# Shows "N/A" cleanly when data is missing
```

### 4. Executive Summary ([ResilienceReport.qmd:1973-1997](ResilienceReport.qmd:1973-1997))

**Before:**
```r
pillars <- c("Upstream" = upstream_avg, "Internal" = internal_avg, "Downstream" = downstream_avg)
strongest <- names(pillars)[which.max(pillars)]  # FAILS if any value is NA
```

**After:**
```r
pillars <- c(...)
valid_pillars <- pillars[!is.na(pillars)]  # Only consider non-NA pillars
if(length(valid_pillars) > 0) {
  strongest <- names(valid_pillars)[which.max(valid_pillars)]
} else {
  strongest <- "N/A"
}
```

### 5. Gap Analysis Function ([ResilienceReport.qmd:1585-1604](ResilienceReport.qmd:1585-1604))

**Before:**
```r
scores[i] <- if (col %in% colnames(dashboard_data)) dashboard_data[[col]][1] else 2.5
# Problem: Doesn't check for NA
```

**After:**
```r
val <- dashboard_data[[col]][1]
scores[i] <- if(is.na(val)) 2.5 else val  # Replace NA with 2.5 for analysis
```

---

## Testing

### Test Case 1: Marcus Pribi Setyo N (All Upstream NA)

**CSV Data:**
- `up__r`, `up__c`, `up__f`, `up__v`, `up__a`: ALL = NaN
- `in__r`=5.0, `in__c`=5.0, `in__f`=4.0, `in__v`=4.75, `in__a`=4.0
- `do__r`=5.0, `do__c`=3.67, `do__f`=2.78, `do__v`=4.0, `do__a`=5.0

**Expected Results:**
- Upstream avg: NA (should not appear in report as a number)
- Internal avg: 4.55
- Downstream avg: 4.09
- Overall: (4.55 + 4.09) / 2 = 4.32 (excludes NA upstream)

**Old Behavior (WRONG):**
- Upstream avg: 2.5 (incorrectly replaced NAs)
- Overall: (2.5 + 4.55 + 4.09) / 3 = 3.71 ❌

**New Behavior (CORRECT):**
- Upstream avg: NA (shown as "N/A" in charts)
- Overall: (4.55 + 4.09) / 2 = 4.32 ✅

**Verification:**
```bash
quarto render ResilienceReport.qmd -P company="[Technology Company]" -P person="Marcus Pribi Setyo N" --to pdf
# ✅ Report generates successfully
# ✅ Upstream shows "μ=N/A"
# ✅ Overall score is 4.32 (not 3.71)
```

### Test Case 2: Casper Hondema (All Data Complete)

**Expected:** Should work exactly as before, no changes to behavior when data is complete.

**Verification:**
```bash
quarto render ResilienceReport.qmd -P company="24 ICE" -P person="Casper Hondema" --to pdf
# ✅ Report generates successfully
# ✅ Validation: [OK] All values match CSV
```

---

## Impact

### ✅ What Changed:
1. **Accurate scoring**: Records with missing data now calculate correct overall scores
2. **Proper NA handling**: Missing pillars excluded from overall average (not counted as 2.5)
3. **Clear display**: Charts show "N/A" for missing data instead of misleading numbers
4. **Validation passes**: Reports match expected CSV values

### ✅ What Stayed the Same:
1. **Visualization**: Radar charts still work (use 2.5 internally for display only)
2. **Complete data**: Records with all scores work exactly as before
3. **Robustness**: Still handles invalid characters (?, N/A, etc.) by converting to NA
4. **Error handling**: Reports never crash, even with all-NA data

---

## Key Principle

**The 2.5 "neutral midpoint" should ONLY be used for:**
- ✅ Displaying visualization (radar charts need numeric values)
- ✅ Text analysis examples (gap analysis function)

**The 2.5 should NOT be used for:**
- ❌ Calculating pillar averages (this skews the results)
- ❌ Calculating overall scores (this gives false data)

**Correct approach:**
- Keep NA as NA during calculations
- Use `na.rm = TRUE` to exclude them from averages
- Only convert to 2.5 when absolutely necessary for display

---

## Files Modified

1. ✅ [ResilienceReport.qmd](ResilienceReport.qmd)
   - Lines 1523-1556: Data cleaning (keep NAs as NA)
   - Lines 1545-1556: Pillar average calculation (handle all-NA case)
   - Lines 1783-1789: Radar chart labels (show "N/A" text)
   - Lines 1973-1997: Executive summary (handle NA in comparisons)
   - Lines 1585-1604: Gap analysis (replace NA with 2.5 for examples only)

---

## Validation

To validate a report now handles NA correctly:

```bash
# Generate report
quarto render ResilienceReport.qmd -P company="[Technology Company]" -P person="Marcus Pribi Setyo N" --to pdf

# Check PDF shows:
# - Upstream Resilience (μ=N/A) - not a number
# - Overall SCRES: 4.32 - correct value excluding upstream
```

---

## Related Issues

This fix resolves the validation warnings like:
```
[WARNING] Validation: 2 mismatch(es) found:
  Up Average: Missing value
  Overall Scres: Expected=4.32, Actual=3.71, Diff=0.61
```

Now validation should show:
```
[OK] All values match CSV
```

---

**Fix Complete:** All changes tested and working ✅
