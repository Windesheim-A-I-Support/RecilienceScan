---
title: "Strategic Resilience and Financial Performance Profile for `r params$company`"
subtitle: "An In-depth Analysis by the Supply Chain Finance Lectoraat, Hogeschool Windesheim"
author:
  - name: Ronald de Boer 
    affiliations:
      - name: Supply Chain Finance Lectoraat
      - name: Hogeschool Windesheim
        address: Campus 2, Zwolle
bibliography: references.bib
format: 
  pdf:
    documentclass: article
    classoption: ["oneside", "open=any", "fontsize=11pt"]
    link-citations: false
    number-sections: falsec:\Users\Christiaan\Downloads\complete_qmd_file.md
    lof: false
    lot: false
    titlepage: "bg-image"
    titlepage-bg-image: "img/corner-bg.png"
    titlepage-logo: "img/logo.png" 
    titlepage-header: "Resilience Scan | NEXT GEN Logistics Initiative"
    titlepage-footer: |
      Supply Chain Finance Lectoraat, Hogeschool Windesheim\
      https://resiliencescan.org/ | https://www.windesheim.com/research/professorships/supply-chain-finance
    coverpage-include-file:
      - tex/copyright.tex
    titlepage-include-file:
      - tex/dedication.tex
    titlepage-theme:
      vrule-color: "004D40" 
      vrule-width: "10pt"
    coverpage: otter 
    coverpage-bg-image: "img/otter-bar.jpeg"
    coverpage-title: "resiliencescan" 
    coverpage-author: ["Supply Chain Finance Lectoraat, Hogeschool Windesheim", "NEXT GEN Logistics"] 
    coverpage-theme:
      title-color: "white"
      title-fontfamily: "QTDublinIrish.otf" 
      title-fontsize: 70
      author-style: "plain"
      author-sep: "newline"
      author-fontstyle: ["textbf", "textsc"]
      author-fontsize: 24
      author-color: "4CAF50" 
      author-align: "right"
      author-bottom: "1.5in"
      footer-style: "none"
      header-style: "none"
      date-style: "none"
    keep-tex: true
    # Temporarily remove complex header-includes for stability
    # header-includes: |
    #   \usepackage{fancyhdr}
    #   ... (rest of fancyhdr setup) ...
execute:
  echo: false
  warning: false
  message: false
params:
  company: "Placeholder Company"
---

```{r package-installer, include=FALSE}
# Define required R packages
required_packages <- c(
  "readr", "dplyr", "stringr", "tidyr", "ggplot2", 
  "fmsb", "scales", "janitor",
  "rmarkdown", "knitr", "bookdown", "tinytex", "quarto"
)

# Detect and install missing R packages
missing_packages <- required_packages[!sapply(required_packages, requireNamespace, quietly = TRUE)]

if (length(missing_packages) > 0) {
  message("📦 Installing missing R packages: ", paste(missing_packages, collapse = ", "))
  install.packages(missing_packages, repos = "https://cran.rstudio.com/", dependencies = TRUE)
} else {
  message("✅ All required R packages are already installed.")
}

# Check TinyTeX
if (!tinytex::is_tinytex()) {
  message("📦 TinyTeX not detected — installing TinyTeX...")
  tinytex::install_tinytex()
} else {
  message("✅ TinyTeX already installed.")
}

# Check Quarto CLI
quarto_path <- Sys.which("quarto")

if (quarto_path == "") {
  warning("❌ Quarto CLI is not installed! Please install it from https://quarto.org/download/ before continuing.")
} else {
  message("✅ Quarto CLI detected at: ", quarto_path)
}
```

```{r helpers, include=FALSE}
safe_print_score <- function(score) {
  if (is.na(score) || is.null(score) || !is.numeric(score)) {
    return("N/A")
  }
  return(sprintf("%.2f", score))
}

convert_to_numeric_simple <- function(x) {
  x_char <- as.character(x)
  x_char <- ifelse(tolower(trimws(x_char)) %in% c("?", "", " ", "n/a", "na", "n.a.", "nan"), NA_character_, x_char)
  suppressWarnings(as.numeric(str_replace(x_char, ",", ".")))
}
```

```{r setup, include=FALSE}
library(readr)
library(dplyr)
library(stringr)
library(tidyr)
library(ggplot2)
library(fmsb)
library(scales) 

df_full <- read_csv("data/cleaned_master.csv", col_types = cols(.default = "c"))
colnames(df_full) <- tolower(trimws(colnames(df_full)))

df_company_raw <- df_full %>% 
  filter(tolower(company_name) == tolower(params$company))

score_columns_to_convert <- c(
  "up__r", "up__c", "up__f", "up__v", "up__a",
  "in__r", "in__c", "in__f", "in__v", "in__a",
  "do__r", "do__c", "do__f", "do__v", "do__a",
  "overall_scres"
)

info_cols_to_keep <- c("company_name", "sector", "size_number_of_employees")

actual_score_columns_to_convert <- intersect(score_columns_to_convert, names(df_company_raw))
actual_info_cols_to_keep <- intersect(info_cols_to_keep, names(df_company_raw))

df_company_numeric <- df_company_raw

# Convert numeric columns using the function from helpers chunk
if (length(actual_score_columns_to_convert) > 0) {
    df_company_numeric <- df_company_numeric %>%
      mutate(across(all_of(actual_score_columns_to_convert), convert_to_numeric_simple))
}

up_cols <- c("up__r", "up__c", "up__f", "up__v", "up__a")
in_cols <- c("in__r", "in__c", "in__f", "in__v", "in__a")
do_cols <- c("do__r", "do__c", "do__f", "do__v", "do__a")
max_score <- 5 
min_score <- 0 
dimension_labels <- c("Redundancy", "Collaboration", "Flexibility", "Transparency", "Agility")

data_up_radar <- NULL
data_in_radar <- NULL
data_do_radar <- NULL
company_sector <- "Not Specified" 
company_size <- "Not Specified"   

if(nrow(df_company_numeric) >= 1) {
  if(nrow(df_company_numeric) > 1) {
    warning(paste("Multiple rows found for company:", params$company, ". Using the first row only."))
    df_company_numeric <- df_company_numeric[1, , drop = FALSE] 
  }
  
  # Set company sector
  if("sector" %in% names(df_company_numeric)) {
    if(!is.na(df_company_numeric$sector) && df_company_numeric$sector != "") {
      company_sector <- df_company_numeric$sector
    }
  }
  
  # Set company size  
  if("size_number_of_employees" %in% names(df_company_numeric)) {
    if(!is.na(df_company_numeric$size_number_of_employees) && df_company_numeric$size_number_of_employees != "") {
      company_size <- df_company_numeric$size_number_of_employees
    }
  }

  if(all(up_cols %in% names(df_company_numeric))) {
    df_company_numeric$up_pillar_score <- rowMeans(select(df_company_numeric, all_of(up_cols)), na.rm = TRUE)
    radar_data <- df_company_numeric %>% slice(1) %>% select(all_of(up_cols))
    if(ncol(radar_data) == 5 && !all(is.na(as.numeric(radar_data[1,])))) {
        data_up_radar <- data.frame(rbind(rep(max_score, 5), rep(min_score, 5), as.numeric(radar_data[1,])))
        colnames(data_up_radar) <- dimension_labels
    } else { warning(paste("Upstream radar data for", params$company, "could not be prepared."))}
  } else { df_company_numeric$up_pillar_score <- NA }

  if(all(in_cols %in% names(df_company_numeric))) {
    df_company_numeric$in_pillar_score <- rowMeans(select(df_company_numeric, all_of(in_cols)), na.rm = TRUE)
    radar_data <- df_company_numeric %>% slice(1) %>% select(all_of(in_cols))
    if(ncol(radar_data) == 5 && !all(is.na(as.numeric(radar_data[1,])))) {
        data_in_radar <- data.frame(rbind(rep(max_score, 5), rep(min_score, 5), as.numeric(radar_data[1,])))
        colnames(data_in_radar) <- dimension_labels
    } else { warning(paste("Internal radar data for", params$company, "could not be prepared."))}
  } else { df_company_numeric$in_pillar_score <- NA }

  if(all(do_cols %in% names(df_company_numeric))) {
    df_company_numeric$do_pillar_score <- rowMeans(select(df_company_numeric, all_of(do_cols)), na.rm = TRUE)
    radar_data <- df_company_numeric %>% slice(1) %>% select(all_of(do_cols))
    if(ncol(radar_data) == 5 && !all(is.na(as.numeric(radar_data[1,])))) {
        data_do_radar <- data.frame(rbind(rep(max_score, 5), rep(min_score, 5), as.numeric(radar_data[1,])))
        colnames(data_do_radar) <- dimension_labels
    } else { warning(paste("Downstream radar data for", params$company, "could not be prepared."))}
  } else { df_company_numeric$do_pillar_score <- NA }

} else if (nrow(df_company_numeric) == 0) {
  stop(paste("No data found for company:", params$company, ". Halting report generation."))
}

# Prepare overlay and overall data
has_up <- exists("data_up_radar") && is.data.frame(data_up_radar) && nrow(data_up_radar) == 3 && ncol(data_up_radar) == 5 && all(sapply(data_up_radar, is.numeric)) && !all(is.na(data_up_radar[3, , drop=FALSE]))
has_in <- exists("data_in_radar") && is.data.frame(data_in_radar) && nrow(data_in_radar) == 3 && ncol(data_in_radar) == 5 && all(sapply(data_in_radar, is.numeric)) && !all(is.na(data_in_radar[3, , drop=FALSE]))
has_do <- exists("data_do_radar") && is.data.frame(data_do_radar) && nrow(data_do_radar) == 3 && ncol(data_do_radar) == 5 && all(sapply(data_do_radar, is.numeric)) && !all(is.na(data_do_radar[3, , drop=FALSE]))

if (has_up || has_in || has_do) {
  available_rows <- list()
  if (has_up) available_rows <- append(available_rows, list(as.numeric(data_up_radar[3,])))
  if (has_in) available_rows <- append(available_rows, list(as.numeric(data_in_radar[3,])))
  if (has_do) available_rows <- append(available_rows, list(as.numeric(data_do_radar[3,])))

  overall_vec <- Reduce("+", available_rows) / length(available_rows)
  data_overall_radar <- data.frame(rbind(
    rep(max_score, 5),
    rep(min_score, 5),
    overall_vec
  ))
  colnames(data_overall_radar) <- dimension_labels
} else {
  data_overall_radar <- NULL
}

overlay_data <- NULL
if (has_up || has_in || has_do) {
  overlay_data <- rbind(rep(max_score, 5), rep(min_score, 5))
  if (has_up) overlay_data <- rbind(overlay_data, as.numeric(data_up_radar[3,]))
  if (has_in) overlay_data <- rbind(overlay_data, as.numeric(data_in_radar[3,]))
  if (has_do) overlay_data <- rbind(overlay_data, as.numeric(data_do_radar[3,]))
  overlay_data <- as.data.frame(overlay_data)
  colnames(overlay_data) <- dimension_labels
}
```

```{r dashboard-radars, fig.width=16, fig.height=26}
# Dashboard layout with company introduction and radar charts - optimized for A4
op <- par(no.readonly = TRUE)
on.exit(par(op), add = TRUE)

# Set up layout: 1 row for intro, then 3x2 grid for charts, plus detailed analysis
layout_matrix <- matrix(c(
  1, 1,  # Company introduction spans 2 columns
  2, 3,  # Overall and Comparative 
  4, 5,  # Upstream and Internal
  6, 7,  # Downstream and Summary
  8, 9   # Detailed analysis spans 2 columns
), nrow = 5, byrow = TRUE)

layout(layout_matrix, heights = c(0.15, 0.22, 0.22, 0.22, 0.19))
par(oma = c(2, 2, 4, 2))

# Panel 1: Company Introduction
par(mar = c(2, 3, 3, 3))
plot.new()

# Background box for introduction
rect(0.02, 0.1, 0.98, 0.9, col = "#f8f9fa", border = "#dee2e6", lwd = 2)

# Try to load and display logo
logo_path <- "img/logo.png"
if (file.exists(logo_path)) {
  tryCatch({
    if (requireNamespace("png", quietly = TRUE)) {
      logo_img <- png::readPNG(logo_path)
      rasterImage(logo_img, 0.05, 0.65, 0.25, 0.85)
    }
  }, error = function(e) {
    rect(0.05, 0.65, 0.25, 0.85, col = "lightgrey", border = "grey")
    text(0.15, 0.75, "LOGO", cex = 0.8, col = "grey40")
  })
} else {
  rect(0.05, 0.65, 0.25, 0.85, col = "lightgrey", border = "grey")
  text(0.15, 0.75, "LOGO", cex = 0.8, col = "grey40")
}

# Company name and details
text(0.6, 0.8, params$company, cex = 1.8, font = 2, col = "#2c3e50")
text(0.6, 0.7, paste("Sector:", company_sector, "| Size:", company_size), cex = 1.0, col = "#6c757d")

# Assessment description
text(0.5, 0.5, "Supply Chain Resilience Assessment", cex = 1.2, font = 2, col = "#495057")
text(0.5, 0.4, "Analysis across 5 key dimensions:", cex = 1.0, col = "#495057")
text(0.5, 0.3, "Redundancy • Collaboration • Flexibility • Transparency • Agility", 
     cex = 1.0, font = 2, col = "#6a1b9a")

# Panel 2: Overall (top row, left)
par(mar = c(2, 2, 3, 2))
if (!is.null(data_overall_radar)) {
  fmsb::radarchart(
    data_overall_radar, axistype = 1,
    pcol = "#6A1B9A", pfcol = scales::alpha("#6A1B9A", 0.4), plwd = 3, plty = 1,
    cglcol = "grey80", cglty = 1, axislabcol = "grey40",
    caxislabels = sprintf("%.1f", seq(min_score, max_score, length.out = 6)),
    cglwd = 1.2, vlcex = 1.0, centerzero = TRUE, title = "Overall Resilience"
  )
} else {
  plot.new()
  title("Overall Resilience\n(no data available)", cex.main = 1.1)
}

# Panel 3: Comparative Overlay (top row, right)
par(mar = c(2, 2, 3, 2))
if (!is.null(overlay_data)) {
  n_series <- nrow(overlay_data) - 2
  cols <- c("#0277BD", "#FF8F00", "#2E7D32")[seq_len(n_series)]
  fcols <- sapply(cols, function(z) scales::alpha(z, 0.25))
  fmsb::radarchart(
    overlay_data, axistype = 1,
    pcol = cols, pfcol = fcols, plwd = 3, plty = 1,
    cglcol = "grey80", cglty = 1, axislabcol = "grey40",
    caxislabels = sprintf("%.1f", seq(min_score, max_score, length.out = 6)),
    cglwd = 1.2, vlcex = 1.0, centerzero = TRUE, title = "Comparative Analysis"
  )
  legend("bottomright",
    legend = c(if (has_up) "Upstream" else NULL,
               if (has_in) "Internal" else NULL,
               if (has_do) "Downstream" else NULL),
    col = cols[1:n_series],
    lty = 1, lwd = 2, bty = "n", cex = 0.8, text.col = "grey20")
} else {
  plot.new()
  title("Comparative Analysis\n(no data available)", cex.main = 1.1)
}

# Panels 4-6: Individual segment radars
segments_data <- list(
  list(data = if(has_up) data_up_radar else NULL, title = "Upstream Supply Chain", color = "#0277BD"),
  list(data = if(has_in) data_in_radar else NULL, title = "Internal Operations", color = "#FF8F00"),
  list(data = if(has_do) data_do_radar else NULL, title = "Downstream Distribution", color = "#2E7D32")
)

for(i in 1:3) {
  par(mar = c(2, 2, 3, 2))
  if (!is.null(segments_data[[i]]$data)) {
    fmsb::radarchart(
      segments_data[[i]]$data, axistype = 1,
      pcol = segments_data[[i]]$color, pfcol = scales::alpha(segments_data[[i]]$color, 0.45), 
      plwd = 3, plty = 1,
      cglcol = "grey80", cglty = 1, axislabcol = "grey40",
      caxislabels = sprintf("%.1f", seq(min_score, max_score, length.out = 6)),
      cglwd = 1.2, vlcex = 1.0, centerzero = TRUE, title = segments_data[[i]]$title
    )
  } else {
    plot.new()
    title(paste(segments_data[[i]]$title, "\n(no data available)"), cex.main = 1.1)
  }
}

# Panel 7: Performance Summary
par(mar = c(2, 2, 3, 2))
plot.new()

rect(0.05, 0.05, 0.95, 0.95, col = "#f8f9fa", border = "grey70", lwd = 2)

text(0.5, 0.85, "PERFORMANCE SUMMARY", cex = 1.1, font = 2, col = "#2c3e50")
segments(0.1, 0.8, 0.9, 0.8, col = "grey60", lwd = 1)

y_positions <- c(0.68, 0.58, 0.48, 0.38)
labels <- c("OVERALL", "Upstream", "Internal", "Downstream")
scores <- c(
  safe_print_score(df_company_numeric$overall_scres),
  safe_print_score(df_company_numeric$up_pillar_score),
  safe_print_score(df_company_numeric$in_pillar_score),
  safe_print_score(df_company_numeric$do_pillar_score)
)

for (i in 1:4) {
  text(0.15, y_positions[i], labels[i], cex = 0.9, font = ifelse(i==1, 2, 1), 
       adj = c(0, 0.5), col = "grey30")
  
  score_val <- scores[i]
  if (score_val != "N/A" && !is.na(as.numeric(score_val))) {
    score_num <- as.numeric(score_val)
    bg_color <- if (score_num >= 4) "#27ae60" else if (score_num >= 3) "#f39c12" else "#e74c3c"
    
    rect(0.65, y_positions[i] - 0.025, 0.85, y_positions[i] + 0.025, 
         col = bg_color, border = NA)
    text(0.75, y_positions[i], score_val, cex = 1.0, font = 2, col = "white")
  } else {
    text(0.75, y_positions[i], score_val, cex = 0.9, font = 1, col = "grey50")
  }
}

text(0.5, 0.25, "SCALE", cex = 0.9, font = 2, col = "grey30")
text(0.5, 0.18, "0-2.9: Needs Improvement", cex = 0.7, col = "#e74c3c")
text(0.5, 0.14, "3-3.9: Good Performance", cex = 0.7, col = "#f39c12")
text(0.5, 0.10, "4-5.0: Excellence", cex = 0.7, col = "#27ae60")

# Panel 8: Detailed Dimension Analysis (left side of bottom row)
par(mar = c(2, 2, 3, 2))
plot.new()

rect(0.02, 0.02, 0.98, 0.98, col = "#f8f9fa", border = "grey70", lwd = 2)

text(0.5, 0.93, "DIMENSIE ANALYSE", cex = 1.2, font = 2, col = "#2c3e50")
text(0.5, 0.88, "Sterkste en Zwakste Punten per Dimensie", cex = 0.9, col = "grey40")
segments(0.08, 0.85, 0.92, 0.85, col = "grey60", lwd = 1)

# Collect all dimensional scores
dimension_scores <- data.frame(
  Dimension = dimension_labels,
  Upstream = if(has_up) as.numeric(data_up_radar[3,]) else rep(NA, 5),
  Internal = if(has_in) as.numeric(data_in_radar[3,]) else rep(NA, 5),
  Downstream = if(has_do) as.numeric(data_do_radar[3,]) else rep(NA, 5),
  stringsAsFactors = FALSE
)

# Calculate overall scores per dimension
dimension_scores$Overall <- rowMeans(dimension_scores[,c("Upstream", "Internal", "Downstream")], na.rm = TRUE)

# Find highest and lowest performing dimensions
valid_scores <- dimension_scores$Overall[!is.na(dimension_scores$Overall)]
if(length(valid_scores) > 0) {
  highest_idx <- which.max(dimension_scores$Overall)
  lowest_idx <- which.min(dimension_scores$Overall)
  
  # Display top performing dimension
  text(0.5, 0.75, "STERKSTE DIMENSIE:", cex = 1.0, font = 2, col = "#27ae60")
  text(0.5, 0.70, dimension_scores$Dimension[highest_idx], cex = 1.1, font = 2, col = "#2c3e50")
  text(0.5, 0.65, paste("Gemiddelde Score:", sprintf("%.2f", dimension_scores$Overall[highest_idx])), 
       cex = 0.9, col = "grey40")
  
  # Display segments for highest dimension
  y_pos <- 0.58
  for(segment in c("Upstream", "Internal", "Downstream")) {
    if(!is.na(dimension_scores[highest_idx, segment])) {
      score <- dimension_scores[highest_idx, segment]
      color <- if(score >= 4) "#27ae60" else if(score >= 3) "#f39c12" else "#e74c3c"
      text(0.25, y_pos, segment, cex = 0.8, adj = c(0, 0.5), col = "grey30")
      text(0.75, y_pos, sprintf("%.2f", score), cex = 0.8, adj = c(1, 0.5), col = color, font = 2)
      y_pos <- y_pos - 0.04
    }
  }
  
  # Display lowest performing dimension
  text(0.5, 0.42, "AANDACHTSGEBIED:", cex = 1.0, font = 2, col = "#e74c3c")
  text(0.5, 0.37, dimension_scores$Dimension[lowest_idx], cex = 1.1, font = 2, col = "#2c3e50")
  text(0.5, 0.32, paste("Gemiddelde Score:", sprintf("%.2f", dimension_scores$Overall[lowest_idx])), 
       cex = 0.9, col = "grey40")
  
  # Display segments for lowest dimension
  y_pos <- 0.25
  for(segment in c("Upstream", "Internal", "Downstream")) {
    if(!is.na(dimension_scores[lowest_idx, segment])) {
      score <- dimension_scores[lowest_idx, segment]
      color <- if(score >= 4) "#27ae60" else if(score >= 3) "#f39c12" else "#e74c3c"
      text(0.25, y_pos, segment, cex = 0.8, adj = c(0, 0.5), col = "grey30")
      text(0.75, y_pos, sprintf("%.2f", score), cex = 0.8, adj = c(1, 0.5), col = color, font = 2)
      y_pos <- y_pos - 0.04
    }
  }
}

# Panel 9: Detailed Scores Table (right side of bottom row)
par(mar = c(2, 2, 3, 2))
plot.new()

rect(0.02, 0.02, 0.98, 0.98, col = "#f8f9fa", border = "grey70", lwd = 2)

text(0.5, 0.93, "COMPLETE SCORE MATRIX", cex = 1.2, font = 2, col = "#2c3e50")
segments(0.08, 0.89, 0.92, 0.89, col = "grey60", lwd = 1)

# Create table headers
text(0.25, 0.84, "DIMENSIE", cex = 0.9, font = 2, col = "grey30")
text(0.47, 0.84, "UP", cex = 0.8, font = 2, col = "#0277BD")
text(0.62, 0.84, "INT", cex = 0.8, font = 2, col = "#FF8F00")
text(0.77, 0.84, "DOWN", cex = 0.8, font = 2, col = "#2E7D32")
text(0.90, 0.84, "GEM", cex = 0.8, font = 2, col = "#6A1B9A")

# Draw table rows
y_start <- 0.78
row_height <- 0.12

for(i in 1:5) {
  y_pos <- y_start - (i-1) * row_height
  
  # Dimension name
  text(0.08, y_pos, dimension_scores$Dimension[i], cex = 0.8, adj = c(0, 0.5), col = "grey20")
  
  # Scores for each segment
  segments <- c("Upstream", "Internal", "Downstream", "Overall")
  x_positions <- c(0.47, 0.62, 0.77, 0.90)
  colors <- c("#0277BD", "#FF8F00", "#2E7D32", "#6A1B9A")
  
  for(j in 1:4) {
    score <- dimension_scores[i, segments[j]]
    if(!is.na(score)) {
      # Color code the background
      bg_color <- if(score >= 4) "#27ae60" else if(score >= 3) "#f39c12" else "#e74c3c"
      
      # Draw background rectangle
      rect(x_positions[j] - 0.04, y_pos - 0.015, x_positions[j] + 0.04, y_pos + 0.015, 
           col = scales::alpha(bg_color, 0.3), border = bg_color, lwd = 1)
      
      text(x_positions[j], y_pos, sprintf("%.2f", score), 
           cex = 0.8, adj = c(0.5, 0.5), col = "black", font = 2)
    } else {
      text(x_positions[j], y_pos, "N/A", cex = 0.8, adj = c(0.5, 0.5),