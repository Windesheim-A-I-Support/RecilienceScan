#!/bin/bash

Rscript -e '
required <- c(
  "tidyverse",
  "fmsb",
  "glue",
  "janitor",
  "readr",
  "scales"
)
new <- setdiff(required, rownames(installed.packages()))
if (length(new)) install.packages(new, repos = "https://cloud.r-project.org")
'
