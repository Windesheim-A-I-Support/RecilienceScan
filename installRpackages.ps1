# Set path to Rscript if not already in PATH
$RscriptPath = "C:\Program Files\R\R-4.4.2\bin\Rscript.exe"

# Check if Rscript exists
if (!(Test-Path $RscriptPath)) {
    Write-Error "❌ Rscript not found at $RscriptPath. Please check the path."
    exit 1
}

# List of required packages
$packages = @(
    "tidyverse",
    "fmsb",
    "glue",
    "janitor",
    "readr",
    "scales"
)

# Build R expression to install missing packages
$packagesList = $packages -join '", "'
$expr = @"
pkgs <- c("$packagesList")
new <- setdiff(pkgs, rownames(installed.packages()))
if (length(new)) install.packages(new, repos = "https://cloud.r-project.org")
"@

# Run the Rscript command
& "$RscriptPath" -e $expr
