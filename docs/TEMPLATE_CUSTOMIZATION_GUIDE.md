# ResilienceScan Template Customization Guide

## Overview

This guide explains how to customize the ResilienceScan report templates to match your branding, modify content, and adjust formatting.

## Available Templates

### 1. ResilienceReport.qmd
**Purpose:** Comprehensive resilience analysis report

**Features:**
- Full data validation and quality checks
- Detailed resilience scoring across 3 pillars (Upstream, Internal, Downstream)
- 5 dimension analysis (RCFVA: Redundancy, Collaboration, Flexibility, Visibility, Agility)
- Radar charts for visual representation
- Strategic recommendations
- Branded PDF output with title page

**Use When:** You need a complete, detailed analysis report

### 2. ExecutiveDashboard.qmd
**Purpose:** High-level executive summary dashboard

**Features:**
- One-page business report
- Overview radar charts
- Key performance indicators (KPIs)
- Strategic recommendations
- Performance bands and benchmarking

**Use When:** You need a quick executive overview

## Template Structure

### Quarto YAML Header

Every template starts with a YAML header defining metadata and formatting:

```yaml
---
title: "Your Report Title"
subtitle: "Subtitle or Tagline"
author:
  - name: Your Name
    affiliations:
      - name: Your Organization
        address: Your Address
format:
  pdf:
    documentclass: article
    titlepage: "bg-image"
    titlepage-logo: "img/logo.png"
    ... (more formatting options)
params:
  company: "Placeholder Company"
  diagnostic_mode: false
  debug_mode: false
---
```

### Key Sections

1. **Package Setup** - Loads required R packages
2. **Data Loading** - Reads CSV data
3. **Validation** - Checks data quality
4. **Analysis** - Computes resilience scores
5. **Visualization** - Creates charts and graphs
6. **Recommendations** - Generates insights
7. **Output** - Formats final report

## Customization Options

### 1. Branding & Logos

#### Update Title Page Logo

**Location:** `img/logo.png`

**In Template:**
```yaml
titlepage-logo: "img/logo.png"
```

**To Customize:**
1. Replace `img/logo.png` with your logo (PNG format, 500x200px recommended)
2. Or change path in YAML:
   ```yaml
   titlepage-logo: "path/to/your/logo.png"
   ```

#### Update Cover Page Image

**Location:** `img/otter-bar.jpeg`

**In Template:**
```yaml
coverpage-bg-image: "img/otter-bar.jpeg"
```

**To Customize:**
1. Replace `img/otter-bar.jpeg` with your image
2. Or update path in YAML

#### Update Title Page Background

**Location:** `img/corner-bg.png`

**In Template:**
```yaml
titlepage-bg-image: "img/corner-bg.png"
```

### 2. Colors & Fonts

#### Brand Colors

**Primary Color (Vertical Rule):**
```yaml
titlepage-theme:
  vrule-color: "004D40"  # Hex color code
  vrule-width: "10pt"
```

**Author Color:**
```yaml
coverpage-theme:
  author-color: "4CAF50"
```

**To Customize:**
- Replace hex codes with your brand colors
- Example: `"FF0000"` for red, `"0000FF"` for blue

#### Title Font

**Current:**
```yaml
title-fontfamily: "QTDublinIrish.otf"
title-fontsize: 70
```

**To Customize:**
1. Add your font file to `_extensions/titlepage/fonts/` directory
2. Update YAML:
   ```yaml
   title-fontfamily: "YourFont.otf"
   title-fontsize: 70
   ```

### 3. Text Content

#### Update Title & Subtitle

```yaml
title: "Your Custom Title Here"
subtitle: "Your Custom Subtitle or Tagline"
```

#### Update Author Info

```yaml
author:
  - name: Your Name
    affiliations:
      - name: Your Organization
        address: Street Address, City
```

#### Update Footer Text

```yaml
titlepage-footer: |
  Your Organization Name\
  https://yourwebsite.com/ | https://your-research-page.com
```

### 4. Report Parameters

Parameters allow dynamic content generation:

```yaml
params:
  company: "Placeholder Company"
  diagnostic_mode: false
  debug_mode: false
  data_guide_mode: false
```

**Usage:**
```bash
# Generate report for specific company
quarto render ResilienceReport.qmd -P company="Acme Corp"

# Enable diagnostic mode
quarto render ResilienceReport.qmd -P diagnostic_mode=true

# Enable debug mode (verbose output)
quarto render ResilienceReport.qmd -P debug_mode=true
```

### 5. Data Source Configuration

#### Change Data File Path

**Default:**
```r
data_file_path <- "data/cleaned_master.csv"
```

**To Customize:**
Edit line 676 in ResilienceReport.qmd:
```r
data_file_path <- "path/to/your/data.csv"
```

Or pass as parameter:
```yaml
params:
  data_path: "custom/path/data.csv"
```

Then in code:
```r
data_file_path <- if(exists("params") && !is.null(params$data_path))
  params$data_path else "data/cleaned_master.csv"
```

### 6. Score Ranges & Thresholds

#### Performance Bands

**Location:** Lines 1050-1100 (varies by template)

**Default Bands:**
```r
score_min <- 0
score_max <- 5

# Performance levels
excellent <- score >= 4.0
good <- score >= 3.5 && score < 4.0
average <- score >= 3.0 && score < 3.5
below <- score >= 2.5 && score < 3.0
poor <- score < 2.5
```

**To Customize:**
```r
# Example: Stricter thresholds
excellent <- score >= 4.5
good <- score >= 4.0 && score < 4.5
average <- score >= 3.5 && score < 4.0
below <- score >= 3.0 && score < 3.5
poor <- score < 3.0
```

### 7. Radar Chart Styling

#### Colors

**Location:** Radar chart code blocks

**Default:**
```r
radar_color <- rgb(0.3, 0.6, 0.9, 0.5)  # Blue with transparency
border_color <- rgb(0.2, 0.4, 0.7, 0.9)  # Darker blue
```

**To Customize:**
```r
# Your brand color
radar_color <- rgb(1.0, 0.5, 0.0, 0.5)  # Orange
border_color <- rgb(0.8, 0.3, 0.0, 0.9)  # Dark orange

# Or use your hex color
radar_color <- col2rgb("#FF6600") / 255  # Convert hex to RGB
```

#### Size & Layout

```r
# Radar chart size
par(mfrow = c(2, 2), mar = c(2, 2, 4, 2))  # 2x2 grid

# Or single large chart
par(mfrow = c(1, 1), mar = c(4, 4, 4, 4))  # 1x1 full size
```

### 8. Strategic Recommendations

#### Customize Recommendation Logic

**Location:** Lines 1200-1300 (varies by template)

**Example:**
```r
recommendations <- c()

# Add custom recommendations based on scores
if (redundancy_score < 3.0) {
  recommendations <- c(recommendations,
    "🔴 CRITICAL: Implement backup suppliers immediately")
}

if (visibility_score < 3.5) {
  recommendations <- c(recommendations,
    "⚠️  Install real-time tracking systems")
}

# Your custom rules here
if (agility_score > 4.0 && flexibility_score > 4.0) {
  recommendations <- c(recommendations,
    "✅ Excellent adaptive capacity - maintain current practices")
}
```

## Advanced Customizations

### 1. Add New Sections

Add a new section after line 1300:

```r
cat("## Your Custom Section\n\n")

cat("Add your custom analysis here.\n\n")

# Example: Industry comparison
if ("sector" %in% colnames(df)) {
  cat("### Industry Benchmarking\n\n")

  sector_avg <- df %>%
    group_by(sector) %>%
    summarise(avg_score = mean(overall_scres, na.rm = TRUE))

  print(kable(sector_avg, caption = "Average Scores by Industry"))
}
```

### 2. Custom Visualizations

Add custom charts:

```r
# Example: Bar chart of dimension scores
dimensions <- c("Redundancy", "Collaboration", "Flexibility",
                "Visibility", "Agility")
scores <- c(redundancy, collaboration, flexibility,
            visibility, agility)

barplot(scores, names.arg = dimensions,
        col = "#4CAF50",
        main = "Resilience Dimensions",
        ylim = c(0, 5))
abline(h = 3.0, col = "red", lty = 2)  # Threshold line
```

### 3. Conditional Content

Show content based on conditions:

```r
if (overall_score < 3.0) {
  cat("## ⚠️ Urgent Action Required\n\n")
  cat("Your resilience score indicates significant vulnerabilities...\n\n")
} else if (overall_score >= 4.0) {
  cat("## ✅ Excellent Performance\n\n")
  cat("Your organization demonstrates strong resilience capabilities...\n\n")
}
```

### 4. Multi-Language Support

Add language parameter:

```yaml
params:
  language: "en"  # en, nl, de, fr
```

Then in code:
```r
# Load translations
translations <- list(
  en = list(title = "Resilience Report",
            summary = "Executive Summary"),
  nl = list(title = "Veerkracht Rapport",
            summary = "Samenvatting"),
  de = list(title = "Resilienz Bericht",
            summary = "Zusammenfassung")
)

lang <- params$language
cat("##", translations[[lang]]$summary, "\n\n")
```

## Template Variables Reference

### Available Variables in Template

After data loading, these variables are available:

```r
# Company info
company_name        # Company being analyzed
sector             # Industry sector
country            # Geographic location (if present)

# Scores
overall_scres      # Overall resilience score (0-5)

# Upstream pillar
up__r, up__c, up__f, up__v, up__a  # 5 dimensions

# Internal pillar
in__r, in__c, in__f, in__v, in__a  # 5 dimensions

# Downstream pillar
do__r, do__c, do__f, do__v, do__a  # 5 dimensions

# Dimension averages
redundancy         # Average across pillars
collaboration      # Average across pillars
flexibility        # Average across pillars
visibility         # Average across pillars
agility            # Average across pillars
```

### Params Reference

```r
params$company         # Company name to analyze
params$diagnostic_mode # Enable diagnostic output
params$debug_mode      # Enable debug logging
params$data_guide_mode # Show data loading guide
```

## Common Customization Recipes

### Recipe 1: Change Brand Colors Throughout

```yaml
# In YAML header
titlepage-theme:
  vrule-color: "YOUR_PRIMARY_COLOR"

coverpage-theme:
  author-color: "YOUR_SECONDARY_COLOR"
```

```r
# In R code blocks
primary_color <- "#YOUR_PRIMARY_COLOR"
secondary_color <- "#YOUR_SECONDARY_COLOR"

# Use in charts
radar_color <- col2rgb(primary_color) / 255
```

### Recipe 2: Add Company Logo to Every Page

```yaml
header-includes: |
  \usepackage{fancyhdr}
  \pagestyle{fancy}
  \fancyhead[L]{\includegraphics[height=1cm]{img/logo.png}}
  \fancyhead[R]{\textbf{Your Company Name}}
```

### Recipe 3: Custom Email Template Integration

See `send_email.py` for email body customization:

```python
body = (
    f"Dear {name},\n\n"
    f"Please find attached your resilience scan report for {company}.\n\n"
    # Add your custom message here
    "Your custom message goes here.\n\n"
    "Best regards,\n\n"
    "Your Name\n"
    "Your Organization"
)
```

### Recipe 4: Automated Report Distribution

Integrate with ResilienceScanGUI.py:

1. Select template in GUI
2. Generate reports for all companies
3. Automatically send via email
4. Track delivery status

## Troubleshooting

### Issue: Fonts not rendering correctly

**Solution:**
1. Ensure font files are in `_extensions/titlepage/fonts/`
2. Use `.otf` or `.ttf` formats
3. Specify full font filename with extension

### Issue: Logo not appearing

**Solution:**
1. Check image path is correct
2. Use PNG format (better compatibility)
3. Verify image dimensions (500x200px recommended)
4. Ensure image file exists at specified path

### Issue: Colors not applying

**Solution:**
1. Use 6-digit hex codes without `#`: `"FF0000"` not `"#FF0000"`
2. For RGB, use values 0-1: `rgb(1.0, 0.5, 0.0)`
3. Check YAML indentation (use spaces, not tabs)

### Issue: Custom sections not appearing

**Solution:**
1. Ensure R code block has correct syntax: ` ```{r} `
2. Check for errors in R code (enable `debug_mode: true`)
3. Verify code block is outside YAML header

## Best Practices

1. **Test Changes Incrementally** - Make one change at a time
2. **Keep Backups** - Save original templates before modifying
3. **Use Version Control** - Track changes with git
4. **Document Customizations** - Add comments explaining changes
5. **Test on Sample Data** - Use diagnostic_mode for testing
6. **Validate Output** - Check PDF renders correctly

## Example: Creating a Custom Template

```yaml
---
title: "Custom Resilience Analysis"
subtitle: "Powered by Your Organization"
author:
  - name: Your Team
    affiliations:
      - name: Your Organization
format:
  pdf:
    titlepage-logo: "img/your-logo.png"
    titlepage-theme:
      vrule-color: "YOUR_COLOR"
params:
  company: "Test Company"
  custom_threshold: 3.5
---

```{r setup}
# Your custom setup code
threshold <- params$custom_threshold

# Load custom functions
source("custom_functions.R")
```

# Your Custom Report

Your custom content here...
```

## Related Documentation

- [Country Field Guide](COUNTRY_FIELD_GUIDE.md) - Adding geographic data
- [CSV Merge Guide](CSV_MERGE_GUIDE.md) - Data merging functionality
- [Quarto Documentation](https://quarto.org/docs/reference/) - Official Quarto reference

## Questions?

For template customization help, open an issue on GitHub with:
- Description of desired customization
- Current template version
- Any error messages
- Screenshots (if applicable)
