# Data Quality Strategy for ResilienceScan

## Problem: Non-Numeric Values in Score Fields

### Issue
Survey responses sometimes contain invalid values in score fields:
- `?` (question marks)
- `N/A`, `n.a.` (not applicable)
- Empty strings
- Special characters
- Text responses in numeric fields

These cause errors in calculations, report generation, and validation.

---

## Current Solution (Implemented)

### In ResilienceReport.qmd (Lines 1523-1544)

**Robust data cleaning before calculations:**

```r
for (col in score_cols) {
  if (col %in% colnames(dashboard_data)) {
    # 1. Convert to character
    col_data <- as.character(dashboard_data[[col]])

    # 2. Replace European commas with dots
    col_data <- gsub(",", ".", col_data)

    # 3. Remove all non-numeric characters (?, N/A, text, etc.)
    col_data <- gsub("[^0-9.-]", "", col_data)

    # 4. Convert to numeric (NA for unconvertible)
    col_data <- suppressWarnings(as.numeric(col_data))

    # 5. Replace NA with neutral score (2.5 midpoint)
    col_data[is.na(col_data)] <- 2.5

    # 6. Clamp to valid range [0, 5]
    dashboard_data[[col]] <- pmax(0, pmin(5, col_data))
  }
}
```

**What this does:**
- ✅ Handles `?`, `N/A`, `n.a.`, empty strings
- ✅ Converts European number format (3,5 → 3.5)
- ✅ Replaces invalid values with 2.5 (neutral)
- ✅ Ensures all values are in valid range [0, 5]
- ✅ Report generation never crashes
- ⚠️ Silently replaces bad data (may mask data quality issues)

---

## Recommended Multi-Layer Strategy

### Layer 1: Survey Prevention (Best)
**Prevent bad data at source**

#### Survey Platform Configuration
1. **Use dropdown/radio buttons** instead of text fields
   - Force selection from: 0, 1, 2, 3, 4, 5
   - No free text entry possible

2. **Add "Don't Know" option**
   - Separate from numeric scores
   - Tracked as distinct value
   - Can be handled specially in reports

3. **Make fields required**
   - No incomplete submissions
   - Or explicitly track which fields were skipped

**Implementation:**
- Update survey tool (e.g., Qualtrics, Google Forms, LimeSurvey)
- Change all score questions to multiple choice
- Add validation rules

**Pros:** ✅ Eliminates problem at source
**Cons:** ⚠️ Requires survey redesign, can't fix historical data

---

### Layer 2: Data Cleaning Script (Recommended)
**Clean data before it enters the system**

#### Enhanced data/data_cleaner.py

```python
import pandas as pd
import numpy as np
import logging

# Set up logging
logging.basicConfig(filename='data/cleaning_report.txt',
                    level=logging.INFO)

def clean_score_column(series, column_name):
    """Clean a score column and log issues"""
    original = series.copy()
    issues = []

    # Convert to string
    series = series.astype(str)

    # Replace European commas
    series = series.str.replace(',', '.')

    # Detect problematic values BEFORE cleaning
    invalid_mask = ~series.str.match(r'^[0-5](\.[0-9]+)?$')
    invalid_values = original[invalid_mask]

    if len(invalid_values) > 0:
        for idx, val in invalid_values.items():
            issues.append({
                'row': idx,
                'column': column_name,
                'original_value': val,
                'action': 'replaced_with_2.5'
            })
            logging.warning(f"Row {idx}, {column_name}: '{val}' → 2.5")

    # Clean: remove non-numeric
    series = series.str.replace(r'[^0-9.-]', '', regex=True)

    # Convert to numeric
    series = pd.to_numeric(series, errors='coerce')

    # Replace NA with 2.5
    series = series.fillna(2.5)

    # Clamp to [0, 5]
    series = series.clip(0, 5)

    return series, issues

def clean_resilience_data(input_path, output_path):
    """Clean entire dataset"""
    df = pd.read_csv(input_path)

    score_cols = [col for col in df.columns if '__' in col]
    all_issues = []

    print(f"Cleaning {len(score_cols)} score columns...")

    for col in score_cols:
        df[col], issues = clean_score_column(df[col], col)
        all_issues.extend(issues)

    # Save cleaned data
    df.to_csv(output_path, index=False)

    # Generate report
    print(f"\n{'='*60}")
    print(f"DATA CLEANING REPORT")
    print(f"{'='*60}")
    print(f"Total issues found: {len(all_issues)}")
    print(f"Cleaned data saved to: {output_path}")

    if all_issues:
        print(f"\nSample issues:")
        for issue in all_issues[:10]:
            print(f"  Row {issue['row']}, {issue['column']}: "
                  f"'{issue['original_value']}' → 2.5")

        # Save detailed report
        issues_df = pd.DataFrame(all_issues)
        issues_df.to_csv('data/cleaning_issues_log.csv', index=False)
        print(f"\nFull log: data/cleaning_issues_log.csv")

    return df, all_issues

# Usage
if __name__ == "__main__":
    clean_resilience_data(
        'data/raw_master.csv',
        'data/cleaned_master.csv'
    )
```

**Benefits:**
- ✅ Creates audit trail of all changes
- ✅ Produces cleaning report for review
- ✅ Can review and correct specific issues
- ✅ One-time cleaning, all reports use clean data
- ✅ Can add to data pipeline automation

---

### Layer 3: Real-Time Validation (Quality Gates)
**Validate during report generation**

#### Add validation warnings to ResilienceReport.qmd

```r
# After data cleaning, check for substituted values
validation_issues <- data.frame(
  column = character(),
  original = character(),
  cleaned = numeric()
)

# Track which values were 2.5 after cleaning (likely substituted)
for (col in score_cols) {
  if (col %in% colnames(dashboard_data)) {
    if (dashboard_data[[col]][1] == 2.5) {
      # Check if this was originally a problem value
      # (requires storing original before cleaning)
      validation_issues <- rbind(validation_issues,
        data.frame(column = col,
                   original = "?",
                   cleaned = 2.5))
    }
  }
}

# Add warning box to report if issues found
if (nrow(validation_issues) > 0) {
  cat("\n::: {.callout-warning}\n")
  cat("### Data Quality Notice\n\n")
  cat(sprintf("%d score(s) contained invalid values and were set to 2.5 (neutral):\n\n",
              nrow(validation_issues)))
  for (i in 1:min(5, nrow(validation_issues))) {
    cat(sprintf("- %s\n", validation_issues$column[i]))
  }
  cat(":::\n\n")
}
```

**Benefits:**
- ✅ Users see data quality warnings in reports
- ✅ Can flag reports for review
- ✅ Transparency about data substitutions

---

### Layer 4: Monitoring Dashboard
**Track data quality over time**

#### Create data_quality_dashboard.py

```python
import pandas as pd
import matplotlib.pyplot as plt

def generate_quality_report(csv_path):
    df = pd.read_csv(csv_path)

    score_cols = [col for col in df.columns if '__' in col]

    # Check for potential issues
    issues = {
        'missing': {},
        'out_of_range': {},
        'suspicious': {}
    }

    for col in score_cols:
        # Missing values
        issues['missing'][col] = df[col].isna().sum()

        # Out of range
        numeric_col = pd.to_numeric(df[col], errors='coerce')
        issues['out_of_range'][col] = (
            (numeric_col < 0) | (numeric_col > 5)
        ).sum()

        # All same value (suspicious)
        if numeric_col.nunique() == 1:
            issues['suspicious'][col] = 'all_same_value'

    # Generate report
    print("DATA QUALITY DASHBOARD")
    print("=" * 60)
    print(f"Total responses: {len(df)}")
    print(f"\nColumns with missing values:")
    for col, count in issues['missing'].items():
        if count > 0:
            print(f"  {col}: {count} ({count/len(df)*100:.1f}%)")

    print(f"\nColumns with out-of-range values:")
    for col, count in issues['out_of_range'].items():
        if count > 0:
            print(f"  {col}: {count}")

    # Visualization
    fig, axes = plt.subplots(1, 3, figsize=(15, 5))

    # Plot 1: Missing values
    missing_counts = pd.Series(issues['missing'])
    missing_counts[missing_counts > 0].plot(kind='bar', ax=axes[0])
    axes[0].set_title('Missing Values by Column')

    # Plot 2: Distribution of scores
    all_scores = pd.concat([pd.to_numeric(df[col], errors='coerce')
                            for col in score_cols])
    all_scores.hist(bins=50, ax=axes[1])
    axes[1].set_title('Score Distribution')

    # Plot 3: Completion rate by respondent
    completion = df[score_cols].notna().mean(axis=1)
    completion.hist(bins=20, ax=axes[2])
    axes[2].set_title('Response Completion Rate')

    plt.tight_layout()
    plt.savefig('data/quality_dashboard.png')
    print(f"\nDashboard saved to: data/quality_dashboard.png")

if __name__ == "__main__":
    generate_quality_report('data/cleaned_master.csv')
```

---

## Recommended Implementation Priority

### Phase 1: Immediate (✅ DONE)
- [x] Robust error handling in ResilienceReport.qmd
- [x] Prevent crashes from bad data

### Phase 2: Short-term (Next sprint)
1. **Enhanced data cleaning script**
   - Add logging to data_cleaner.py
   - Generate cleaning_issues_log.csv
   - Review and manually correct critical issues

2. **Add validation warnings to reports**
   - Show which fields had substituted values
   - Add "Data Quality Notice" callout box

### Phase 3: Medium-term (Next month)
1. **Survey redesign**
   - Change to dropdown menus for scores
   - Add "Don't Know" option
   - Make fields required

2. **Automated data pipeline**
   - Clean data on upload
   - Run quality checks automatically
   - Email alerts for issues

### Phase 4: Long-term (Next quarter)
1. **Quality monitoring dashboard**
   - Track data quality metrics over time
   - Identify problematic questions
   - Monitor completion rates

2. **Data validation rules in GUI**
   - Validate CSV before loading
   - Show quality report before generation
   - Block generation if critical issues found

---

## Best Practices

### For Data Entry
- ✅ Use constrained input (dropdowns)
- ✅ Add explicit "Don't Know" / "N/A" options
- ✅ Make fields required or track skipped explicitly
- ❌ Avoid free text for numeric fields

### For Data Cleaning
- ✅ Log all changes (before/after)
- ✅ Generate cleaning reports
- ✅ Keep original raw data
- ✅ Version cleaned data
- ❌ Don't silently change data

### For Report Generation
- ✅ Handle missing data gracefully
- ✅ Show data quality warnings
- ✅ Add debug/verification sections
- ✅ Validate calculations
- ❌ Don't crash on bad data

### For Monitoring
- ✅ Track completion rates
- ✅ Monitor data quality trends
- ✅ Review outliers
- ✅ Flag suspicious patterns

---

## Testing Recommendations

### Test Data Scenarios
Create test cases with:
1. Perfect data (all valid scores)
2. Missing values (empty cells)
3. Invalid symbols (?, N/A, --)
4. Out of range (6, -1, 10)
5. Text responses ("good", "high")
6. Mixed formats (3,5 vs 3.5)
7. Edge cases (0.0, 5.0, exactly 2.5)

### Validation Tests
- Generate reports for each test case
- Verify no crashes
- Check calculations are correct
- Verify debug table shows issues
- Confirm validation passes/fails appropriately

---

## Summary

**Current State:** ✅ Reports won't crash on bad data

**Recommended Next Steps:**
1. Add cleaning logs to see what's being fixed
2. Show data quality warnings in reports
3. Redesign survey to prevent bad data entry

**Long-term Goal:** Prevent bad data at source + monitor quality over time
