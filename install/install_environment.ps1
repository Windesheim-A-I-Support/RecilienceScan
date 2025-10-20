# Resilience Report Generator - BULLETPROOF Windows Installer
# This script handles all real-world installation issues and dependencies
# WORKS FROM ANY FOLDER LOCATION (including /install subfolder)

param(
    [switch]$SkipChecks,
    [switch]$ForceReinstall,
    [switch]$Verbose,
    [switch]$SkipVenv,
    [switch]$NoRtools
)

# Set execution policy and error handling
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
$ErrorActionPreference = "Continue"  # Don't stop on errors

# CRITICAL: Determine project root directory
$scriptPath = $MyInvocation.MyCommand.Path
$scriptDir = Split-Path -Parent $scriptPath
$projectRoot = $null

# Smart project root detection
$possibleRoots = @(
    $scriptDir,                    # Script is in root
    (Split-Path -Parent $scriptDir), # Script is in subfolder
    (Split-Path -Parent (Split-Path -Parent $scriptDir)) # Script is in nested subfolder
)

foreach ($root in $possibleRoots) {
    # Look for key project files to identify root
    $keyFiles = @("ResilienceReport.qmd", "clean_data.py", "generate_reports.py")
    $foundFiles = 0
    
    foreach ($file in $keyFiles) {
        if (Test-Path (Join-Path $root $file)) {
            $foundFiles++
        }
    }
    
    # If we found most key files, this is probably the root
    if ($foundFiles -ge 2) {
        $projectRoot = $root
        break
    }
}

# If auto-detection failed, ask user or use parent directory
if (-not $projectRoot) {
    Write-Warning "Could not auto-detect project root directory."
    Write-Info "Script location: $scriptDir"
    Write-Info "Looking for project files (ResilienceReport.qmd, clean_data.py, generate_reports.py)"
    
    # Default to parent directory of script
    $projectRoot = Split-Path -Parent $scriptDir
    Write-Info "Using parent directory as project root: $projectRoot"
    
    # Give user a chance to correct this
    Write-Host "Press ENTER to continue with '$projectRoot' as project root, or CTRL+C to cancel and move the script..."
    Read-Host
}

# Change to project root directory
Set-Location $projectRoot
Write-Success "Working from project root: $projectRoot"

# Color functions
function Write-Success { param($Message) Write-Host "✓ $Message" -ForegroundColor Green }
function Write-Info { param($Message) Write-Host "ℹ $Message" -ForegroundColor Blue }
function Write-Warning { param($Message) Write-Host "⚠ $Message" -ForegroundColor Yellow }
function Write-Error-Custom { param($Message) Write-Host "✗ $Message" -ForegroundColor Red }
function Write-Step { param($Message) Write-Host "`n" + "="*50 -ForegroundColor Magenta; Write-Host "  $Message" -ForegroundColor Magenta; Write-Host "="*50 -ForegroundColor Magenta }

# Global tracking variables
$global:InstallationStatus = @{
    Python = $false
    R = $false
    Rtools = $false
    Quarto = $false
    TinyTeX = $false
    PythonPackages = $false
    RPackages = $false
    QuartoExtensions = $false
    CustomFont = $false
}

# Header
Write-Host ""
Write-Host "██████╗ ███████╗███████╗██╗██╗     ██╗███████╗███╗   ██╗ ██████╗███████╗" -ForegroundColor Cyan
Write-Host "██╔══██╗██╔════╝██╔════╝██║██║     ██║██╔════╝████╗  ██║██╔════╝██╔════╝" -ForegroundColor Cyan
Write-Host "██████╔╝█████╗  ███████╗██║██║     ██║█████╗  ██╔██╗ ██║██║     █████╗  " -ForegroundColor Cyan
Write-Host "██╔══██╗██╔══╝  ╚════██║██║██║     ██║██╔══╝  ██║╚██╗██║██║     ██╔══╝  " -ForegroundColor Cyan
Write-Host "██║  ██║███████╗███████║██║███████╗██║███████╗██║ ╚████║╚██████╗███████╗" -ForegroundColor Cyan
Write-Host "╚═╝  ╚═╝╚══════╝╚══════╝╚═╝╚══════╝╚═╝╚══════╝╚═╝  ╚═══╝ ╚═════╝╚══════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "           COMPREHENSIVE WINDOWS INSTALLER v2.0" -ForegroundColor Yellow
Write-Host "         Handles ALL dependencies and common failures" -ForegroundColor Yellow
Write-Host ""

# Function to safely execute commands with retry logic
function Invoke-RobustCommand {
    param(
        [string]$Description,
        [scriptblock]$Command,
        [int]$MaxRetries = 3,
        [int]$DelaySeconds = 5,
        [bool]$Critical = $false
    )
    
    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        try {
            Write-Info "$Description (attempt $attempt/$MaxRetries)"
            $result = & $Command
            
            if ($LASTEXITCODE -eq 0 -or $null -eq $LASTEXITCODE) {
                Write-Success "$Description completed successfully"
                return $true
            } else {
                throw "Command failed with exit code $LASTEXITCODE"
            }
        }
        catch {
            Write-Warning "$Description failed: $($_.Exception.Message)"
            if ($attempt -eq $MaxRetries) {
                if ($Critical) {
                    Write-Error-Custom "$Description CRITICAL FAILURE after $MaxRetries attempts"
                    return $false
                } else {
                    Write-Warning "$Description failed after $MaxRetries attempts, continuing..."
                    return $false
                }
            }
            Start-Sleep -Seconds $DelaySeconds
        }
    }
}

# Function to download with robust error handling
function Get-RobustDownload {
    param($Url, $OutputPath, $Description)
    
    $downloadCommand = {
        # Try multiple download methods
        try {
            Invoke-WebRequest -Uri $Url -OutFile $OutputPath -UseBasicParsing -TimeoutSec 300
        }
        catch {
            # Fallback to .NET WebClient
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($Url, $OutputPath)
            $webClient.Dispose()
        }
    }
    
    return Invoke-RobustCommand -Description "Downloading $Description" -Command $downloadCommand -MaxRetries 3
}

# Check administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    if (-not $SkipChecks) {
        Write-Warning "Administrator privileges required. Restarting as administrator..."
        $arguments = "-File `"$($MyInvocation.MyCommand.Path)`""
        @($SkipChecks, $ForceReinstall, $Verbose, $SkipVenv, $NoRtools) | ForEach-Object {
            if ($_) { $arguments += " -$($_.Name)" }
        }
        Start-Process PowerShell -ArgumentList $arguments -Verb RunAs
        exit
    }
}

# Create temp and logs directory
$tempDir = Join-Path $env:TEMP "ResilienceInstaller_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
$logFile = Join-Path $tempDir "installation.log"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

Write-Success "Running with administrator privileges"
Write-Info "Temp directory: $tempDir"
Write-Info "Installation log: $logFile"

# Start transcript for logging
Start-Transcript -Path $logFile

# STEP 1: PYTHON INSTALLATION WITH ROBUST HANDLING
Write-Step "PYTHON 3.11 INSTALLATION"

$pythonInstalled = $false
if (-not $ForceReinstall) {
    try {
        $pythonVersion = & python --version 2>$null
        if ($pythonVersion -match "Python (\d+)\.(\d+)\.(\d+)") {
            $major = [int]$matches[1]; $minor = [int]$matches[2]
            if ($major -ge 3 -and $minor -ge 8) {
                Write-Success "Python $pythonVersion is compatible"
                $global:InstallationStatus.Python = $true
                $pythonInstalled = $true
            }
        }
    } catch { }
}

if (-not $pythonInstalled) {
    $pythonUrl = "https://www.python.org/ftp/python/3.11.8/python-3.11.8-amd64.exe"
    $pythonInstaller = Join-Path $tempDir "python-installer.exe"
    
    if (Get-RobustDownload -Url $pythonUrl -OutputPath $pythonInstaller -Description "Python 3.11.8") {
        $installCommand = {
            Start-Process -FilePath $pythonInstaller -ArgumentList @(
                "/quiet", "InstallAllUsers=1", "PrependPath=1", 
                "Include_test=0", "Include_doc=0", "Include_tcltk=0"
            ) -Wait -PassThru | Out-Null
        }
        
        if (Invoke-RobustCommand -Description "Python installation" -Command $installCommand -Critical $true) {
            # Force refresh environment variables
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            
            # Verify installation
            Start-Sleep -Seconds 5
            try {
                $newVersion = & python --version 2>$null
                Write-Success "Python installed: $newVersion"
                $global:InstallationStatus.Python = $true
            } catch {
                Write-Warning "Python installation may have issues, but continuing..."
            }
        }
    }
}

# STEP 2: PYTHON PACKAGE MANAGEMENT
Write-Step "PYTHON ENVIRONMENT SETUP"

# Upgrade pip with robust handling
$pipUpgradeCommand = {
    & python -m pip install --upgrade pip setuptools wheel --quiet --disable-pip-version-check
}
Invoke-RobustCommand -Description "pip upgrade" -Command $pipUpgradeCommand

# Virtual environment handling
if (-not $SkipVenv -and $global:InstallationStatus.Python) {
    if (Test-Path "venv" -PathType Container) {
        if ($ForceReinstall) {
            Write-Info "Removing existing virtual environment..."
            Remove-Item "venv" -Recurse -Force -ErrorAction SilentlyContinue
        } else {
            Write-Info "Virtual environment exists, skipping creation"
        }
    }
    
    if (-not (Test-Path "venv" -PathType Container)) {
        $venvCommand = { & python -m venv venv }
        if (Invoke-RobustCommand -Description "Virtual environment creation" -Command $venvCommand) {
            Write-Success "Virtual environment created"
        }
    }
    
    # Try to activate venv
    if (Test-Path "venv\Scripts\Activate.ps1") {
        try {
            & .\venv\Scripts\Activate.ps1 2>$null
            Write-Success "Virtual environment activated"
        } catch {
            Write-Warning "Could not activate venv, using global Python"
        }
    }
}

# Install Python packages
Write-Info "Installing Python packages..."

# Handle requirements.txt if it exists
if (Test-Path "requirements.txt") {
    $reqInstallCommand = { 
        & python -m pip install -r requirements.txt --upgrade --quiet --disable-pip-version-check --timeout 300
    }
    if (Invoke-RobustCommand -Description "requirements.txt installation" -Command $reqInstallCommand) {
        $global:InstallationStatus.PythonPackages = $true
    }
}

# Essential packages with individual handling
$essentialPackages = @("pandas", "pywin32", "openpyxl", "numpy", "matplotlib", "seaborn", "requests")
$packagesInstalled = 0

foreach ($package in $essentialPackages) {
    $packageCommand = { 
        & python -m pip install $package --upgrade --quiet --disable-pip-version-check --timeout 300
    }
    if (Invoke-RobustCommand -Description "Installing $package" -Command $packageCommand) {
        $packagesInstalled++
    }
}

if ($packagesInstalled -gt ($essentialPackages.Count * 0.7)) {
    $global:InstallationStatus.PythonPackages = $true
    Write-Success "Most Python packages installed successfully"
} else {
    Write-Warning "Some Python packages failed to install"
}

# STEP 3: R INSTALLATION
Write-Step "R 4.4.2 INSTALLATION"

$rInstalled = $false
if (-not $ForceReinstall) {
    try {
        $rCheck = & R --version 2>$null
        if ($rCheck -and $rCheck[0] -match "R version") {
            Write-Success "R already installed: $($rCheck[0])"
            $global:InstallationStatus.R = $true
            $rInstalled = $true
        }
    } catch { }
}

if (-not $rInstalled) {
    $rUrl = "https://cran.r-project.org/bin/windows/base/R-4.4.2-win.exe"
    $rInstaller = Join-Path $tempDir "R-installer.exe"
    
    if (Get-RobustDownload -Url $rUrl -OutputPath $rInstaller -Description "R 4.4.2") {
        $rInstallCommand = {
            Start-Process -FilePath $rInstaller -ArgumentList @("/SILENT", "/NORESTART") -Wait -PassThru | Out-Null
        }
        
        if (Invoke-RobustCommand -Description "R installation" -Command $rInstallCommand -Critical $true) {
            # Add R to PATH with multiple possible locations
            $rPaths = @(
                "C:\Program Files\R\R-4.4.2\bin\x64",
                "C:\Program Files\R\R-4.4.2\bin",
                "C:\R\R-4.4.2\bin\x64",
                "C:\R\R-4.4.2\bin"
            )
            
            foreach ($rPath in $rPaths) {
                if (Test-Path $rPath) {
                    $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
                    if ($currentPath -notlike "*$rPath*") {
                        [Environment]::SetEnvironmentVariable("Path", "$currentPath;$rPath", "Machine")
                        $env:Path += ";$rPath"
                        Write-Success "Added R to PATH: $rPath"
                    }
                    $global:InstallationStatus.R = $true
                    break
                }
            }
        }
    }
}

# STEP 4: RTOOLS INSTALLATION (CRITICAL FOR PACKAGE COMPILATION)
if (-not $NoRtools -and $global:InstallationStatus.R) {
    Write-Step "RTOOLS 4.4 INSTALLATION (Required for R package compilation)"
    
    $rtoolsInstalled = $false
    
    # Check if Rtools is already installed and working
    try {
        $rtoolsCheck = & R --vanilla --slave -e "cat(ifelse(pkgbuild::has_build_tools(debug = FALSE), 'RTOOLS_OK', 'RTOOLS_MISSING'))" 2>$null
        if ($rtoolsCheck -eq "RTOOLS_OK") {
            Write-Success "Rtools already installed and working"
            $global:InstallationStatus.Rtools = $true
            $rtoolsInstalled = $true
        }
    } catch { }
    
    if (-not $rtoolsInstalled) {
        # Determine correct Rtools version for R 4.4.x
        $rtoolsUrl = "https://cran.r-project.org/bin/windows/Rtools/rtools44/files/rtools44-6104-6039.exe"
        $rtoolsInstaller = Join-Path $tempDir "rtools-installer.exe"
        
        if (Get-RobustDownload -Url $rtoolsUrl -OutputPath $rtoolsInstaller -Description "Rtools 4.4") {
            $rtoolsInstallCommand = {
                Start-Process -FilePath $rtoolsInstaller -ArgumentList @("/SILENT") -Wait -PassThru | Out-Null
            }
            
            if (Invoke-RobustCommand -Description "Rtools installation" -Command $rtoolsInstallCommand) {
                # Configure Rtools PATH in .Renviron
                $renvironPath = Join-Path $env:USERPROFILE ".Renviron"
                $renvironContent = 'PATH="${RTOOLS44_HOME}\usr\bin;${PATH}"'
                
                try {
                    Add-Content -Path $renvironPath -Value $renvironContent -Force
                    Write-Success "Rtools PATH configured in .Renviron"
                    $global:InstallationStatus.Rtools = $true
                } catch {
                    Write-Warning "Could not configure .Renviron, Rtools may need manual configuration"
                }
            }
        }
    }
} else {
    Write-Info "Skipping Rtools installation (use -NoRtools to disable this warning)"
}

# STEP 5: R PACKAGES WITH ROBUST HANDLING
Write-Step "R PACKAGES INSTALLATION (Comprehensive List)"

if ($global:InstallationStatus.R) {
    # Complete package list with critical packages for your project
    $rPackageGroups = @{
        "Core" = @("readr", "dplyr", "tidyr", "stringr", "lubridate")
        "Visualization" = @("ggplot2", "fmsb", "scales", "plotly", "RColorBrewer") 
        "Document" = @("rmarkdown", "knitr", "quarto", "tinytex")
        "Data" = @("readxl", "writexl", "openxlsx", "janitor")
        "Extended" = @("tidyverse", "patchwork", "ggthemes")
    }
    
    # Create comprehensive R installation script with error handling
    $rScript = @"
# Comprehensive R package installer with error recovery
options(repos = c(CRAN = "https://cloud.r-project.org"))
options(timeout = 600)  # 10 minute timeout for large packages

# Function to safely install packages
safe_install <- function(pkg) {
  tryCatch({
    if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
      cat("Installing", pkg, "...\n")
      
      # Try binary first, then source if needed
      install.packages(pkg, dependencies = TRUE, type = "both", quiet = TRUE)
      
      if (require(pkg, character.only = TRUE, quietly = TRUE)) {
        cat("SUCCESS:", pkg, "\n")
        return(TRUE)
      } else {
        # Try source installation if binary failed
        install.packages(pkg, dependencies = TRUE, type = "source", quiet = TRUE)
        if (require(pkg, character.only = TRUE, quietly = TRUE)) {
          cat("SUCCESS_SOURCE:", pkg, "\n")
          return(TRUE)
        } else {
          cat("FAILED:", pkg, "\n")
          return(FALSE)
        }
      }
    } else {
      cat("ALREADY_INSTALLED:", pkg, "\n")
      return(TRUE)
    }
  }, error = function(e) {
    cat("ERROR:", pkg, "-", e$message, "\n")
    return(FALSE)
  })
}

# Install pkgbuild first (needed for build tools check)
safe_install("pkgbuild")

# Install packages by group with priorities
core_pkgs <- c("readr", "dplyr", "tidyr", "stringr", "lubridate", "ggplot2", "fmsb", "scales")
doc_pkgs <- c("rmarkdown", "knitr", "quarto")
data_pkgs <- c("readxl", "writexl", "openxlsx", "janitor")
viz_pkgs <- c("plotly", "RColorBrewer", "patchwork", "ggthemes")
extended_pkgs <- c("tidyverse")

# Install in order of importance
all_packages <- c(core_pkgs, doc_pkgs, data_pkgs, viz_pkgs, extended_pkgs)
results <- sapply(all_packages, safe_install)

# Summary
success_count <- sum(results)
total_count <- length(all_packages)
cat("\n=== R PACKAGE INSTALLATION SUMMARY ===\n")
cat("Successful:", success_count, "/", total_count, "\n")

# Check critical packages
critical_pkgs <- c("ggplot2", "fmsb", "dplyr", "rmarkdown")
critical_results <- sapply(critical_pkgs, function(pkg) require(pkg, character.only = TRUE, quietly = TRUE))
critical_success <- sum(critical_results)

cat("Critical packages:", critical_success, "/", length(critical_pkgs), "\n")

if (critical_success == length(critical_pkgs)) {
  cat("CRITICAL_PACKAGES_OK\n")
} else {
  cat("CRITICAL_PACKAGES_MISSING\n")
}

if (success_count >= total_count * 0.8) {
  cat("R_PACKAGES_MOSTLY_OK\n")
} else {
  cat("R_PACKAGES_ISSUES\n")
}
"@

    $rScriptPath = Join-Path $tempDir "install_r_packages.R"
    $rScript | Out-File -FilePath $rScriptPath -Encoding UTF8

    Write-Info "Installing R packages (this may take 15-30 minutes)..."
    Write-Warning "Large packages like tidyverse may take significant time to compile"
    
    $rPackageCommand = { & R --vanilla --slave -f $rScriptPath }
    
    if (Invoke-RobustCommand -Description "R packages installation" -Command $rPackageCommand -MaxRetries 2) {
        # Parse results
        $rOutput = & R --vanilla --slave -f $rScriptPath 2>$null
        
        if ($rOutput -match "CRITICAL_PACKAGES_OK") {
            Write-Success "Critical R packages installed successfully!"
            $global:InstallationStatus.RPackages = $true
        } elseif ($rOutput -match "R_PACKAGES_MOSTLY_OK") {
            Write-Success "Most R packages installed successfully"
            $global:InstallationStatus.RPackages = $true
        } else {
            Write-Warning "R package installation had significant issues"
            Write-Info "You may need to install missing packages manually or install Rtools"
        }
    }
} else {
    Write-Warning "Skipping R packages (R not installed)"
}

# STEP 6: QUARTO INSTALLATION
Write-Step "QUARTO CLI INSTALLATION"

$quartoInstalled = $false
if (-not $ForceReinstall) {
    try {
        $quartoVersion = & quarto --version 2>$null
        if ($quartoVersion) {
            Write-Success "Quarto already installed: $quartoVersion"
            $global:InstallationStatus.Quarto = $true
            $quartoInstalled = $true
        }
    } catch { }
}

if (-not $quartoInstalled) {
    # Get latest Quarto version
    $quartoUrl = "https://github.com/quarto-dev/quarto-cli/releases/download/v1.5.56/quarto-1.5.56-win.msi"
    $quartoInstaller = Join-Path $tempDir "quarto-installer.msi"
    
    if (Get-RobustDownload -Url $quartoUrl -OutputPath $quartoInstaller -Description "Quarto CLI") {
        $quartoInstallCommand = {
            Start-Process msiexec.exe -ArgumentList "/i", $quartoInstaller, "/quiet", "/norestart" -Wait -PassThru | Out-Null
        }
        
        if (Invoke-RobustCommand -Description "Quarto installation" -Command $quartoInstallCommand) {
            # Refresh PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            
            # Verify installation
            Start-Sleep -Seconds 5
            try {
                $newQuartoVersion = & quarto --version 2>$null
                Write-Success "Quarto installed: $newQuartoVersion"
                $global:InstallationStatus.Quarto = $true
            } catch {
                Write-Warning "Quarto installation verification failed"
            }
        }
    }
}

# STEP 7: TINYTEX WITH ROBUST HANDLING
Write-Step "TinyTeX INSTALLATION (LaTeX for PDF generation)"

if ($global:InstallationStatus.Quarto) {
    # Multiple methods to install TinyTeX with error recovery
    $tinyTexMethods = @{
        "Quarto" = { & quarto install tinytex --update-path --log-level warning }
        "R_tinytex" = { & R --vanilla --slave -e "tinytex::install_tinytex()" }
    }
    
    $tinyTexInstalled = $false
    
    # Check if TinyTeX is already working
    try {
        $texCheck = & quarto check 2>$null
        if ($texCheck -match "LaTeX.*OK" -or $texCheck -match "TinyTeX") {
            Write-Success "TinyTeX already installed and working"
            $global:InstallationStatus.TinyTeX = $true
            $tinyTexInstalled = $true
        }
    } catch { }
    
    if (-not $tinyTexInstalled) {
        foreach ($method in $tinyTexMethods.Keys) {
            Write-Info "Attempting TinyTeX installation via $method..."
            
            if (Invoke-RobustCommand -Description "TinyTeX installation ($method)" -Command $tinyTexMethods[$method] -MaxRetries 2) {
                # Verify installation
                Start-Sleep -Seconds 10
                try {
                    $postInstallCheck = & quarto check 2>$null
                    if ($postInstallCheck -match "LaTeX.*OK") {
                        Write-Success "TinyTeX installation successful via $method"
                        $global:InstallationStatus.TinyTeX = $true
                        $tinyTexInstalled = $true
                        break
                    }
                } catch { }
            }
            
            if ($tinyTexInstalled) { break }
        }
        
        if (-not $tinyTexInstalled) {
            Write-Warning "TinyTeX installation failed with all methods"
            Write-Info "You may need to install LaTeX manually (MiKTeX or TeX Live)"
        }
    }
} else {
    Write-Warning "Skipping TinyTeX (Quarto not installed)"
}

# STEP 8: QUARTO EXTENSIONS
Write-Step "QUARTO EXTENSIONS"

if ($global:InstallationStatus.Quarto) {
    $extensionCommand = { & quarto install extension nmfs-opensci/quarto_titlepages --no-prompt --quiet }
    
    if (Invoke-RobustCommand -Description "NMFS title pages extension" -Command $extensionCommand) {
        $global:InstallationStatus.QuartoExtensions = $true
    } else {
        Write-Info "Extension can be installed manually later with:"
        Write-Info "  quarto install extension nmfs-opensci/quarto_titlepages"
    }
} else {
    Write-Warning "Skipping extensions (Quarto not installed)"
}

# STEP 9: CUSTOM FONT WITH MULTIPLE METHODS
Write-Step "CUSTOM FONT INSTALLATION"

$fontPath = "fonts\QTDublinIrish.otf"
if (Test-Path $fontPath) {
    $fontMethods = @{
        "PowerShell" = {
            # Modern PowerShell method
            $fontFile = Get-Item $fontPath
            $fontsFolder = [Environment]::GetFolderPath("Fonts")
            $fontDestination = Join-Path $fontsFolder $fontFile.Name
            
            Copy-Item $fontPath $fontDestination -Force
            
            # Register in registry
            $regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
            $fontName = "QT Dublin Irish (TrueType)"
            New-ItemProperty -Path $regPath -Name $fontName -Value $fontFile.Name -Force | Out-Null
        }
        "FontResource" = {
            # Alternative method using Add-Font if available
            if (Get-Command Add-Font -ErrorAction SilentlyContinue) {
                Add-Font -Path $fontPath -Confirm:$false
            } else {
                throw "Add-Font not available"
            }
        }
        "Shell" = {
            # Shell application method
            $shell = New-Object -ComObject Shell.Application
            $fonts = $shell.Namespace(20) # Fonts folder
            $fonts.CopyHere((Get-Item $fontPath).FullName, 16)
        }
    }
    
    $fontInstalled = $false
    foreach ($method in $fontMethods.Keys) {
        if (Invoke-RobustCommand -Description "Font installation ($method)" -Command $fontMethods[$method]) {
            Write-Success "Custom font installed successfully via $method"
            $global:InstallationStatus.CustomFont = $true
            $fontInstalled = $true
            break
        }
    }
    
    if (-not $fontInstalled) {
        Write-Warning "Automatic font installation failed"
        Write-Info "Please install fonts\QTDublinIrish.otf manually by right-clicking it"
    }
} else {
    Write-Warning "Custom font file not found at $fontPath"
    Write-Info "Make sure the fonts directory exists with QTDublinIrish.otf"
}

# STEP 10: PROJECT STRUCTURE AND VERIFICATION
Write-Step "PROJECT STRUCTURE VERIFICATION"

# Create required directories
$requiredDirs = @("data", "reports", "img", "tex", "fonts")
foreach ($dir in $requiredDirs) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Success "Created directory: $dir"
    } else {
        Write-Success "Directory exists: $dir"
    }
}

# Check for critical files
$criticalFiles = @("ResilienceReport.qmd", "clean_data.py", "generate_reports.py", "send_emails.py")
$missingFiles = @()
foreach ($file in $criticalFiles) {
    if (Test-Path $file) {
        Write-Success "File exists: $file"
    } else {
        Write-Warning "File missing: $file"
        $missingFiles += $file
    }
}

# FINAL SYSTEM VERIFICATION
Write-Step "COMPREHENSIVE SYSTEM VERIFICATION"

$verificationTests = @{
    "Python" = { & python -c "import sys; print(f'Python {sys.version}')" }
    "R" = { & R --version | Select-Object -First 1 }
    "Quarto" = { & quarto --version }
    "Python-pandas" = { & python -c "import pandas; print('pandas OK')" }
    "Python-pywin32" = { & python -c "import win32com.client; print('pywin32 OK')" }
    "R-ggplot2" = { & R --vanilla --slave -e "library(ggplot2); cat('ggplot2 OK')" }
    "R-fmsb" = { & R --vanilla --slave -e "library(fmsb); cat('fmsb OK')" }
    "R-rmarkdown" = { & R --vanilla --slave -e "library(rmarkdown); cat('rmarkdown OK')" }
    "TinyTeX" = { & quarto check --quiet | Select-String "LaTeX" }
}

Write-Info "Running comprehensive verification tests..."
$verificationResults = @{}

foreach ($test in $verificationTests.Keys) {
    try {
        $result = & $verificationTests[$test] 2>$null
        if ($result -and $LASTEXITCODE -eq 0) {
            Write-Success "$test ✓"
            $verificationResults[$test] = $true
        } else {
            Write-Error-Custom "$test ✗"
            $verificationResults[$test] = $false
        }
    }
    catch {
        Write-Error-Custom "$test ✗ (Error: $($_.Exception.Message))"
        $verificationResults[$test] = $false
    }
}

# Calculate success rates
$totalTests = $verificationResults.Count
$passedTests = ($verificationResults.Values | Where-Object { $_ -eq $true }).Count
$successRate = [math]::Round(($passedTests / $totalTests) * 100, 1)

# Stop transcript
Stop-Transcript

# FINAL INSTALLATION REPORT
Write-Host ""
Write-Host "██████╗ ███████╗██████╗  ██████╗ ██████╗ ████████╗" -ForegroundColor Green
Write-Host "██╔══██╗██╔════╝██╔══██╗██╔═══██╗██╔══██╗╚══██╔══╝" -ForegroundColor Green
Write-Host "██████╔╝█████╗  ██████╔╝██║   ██║██████╔╝   ██║   " -ForegroundColor Green
Write-Host "██╔══██╗██╔══╝  ██╔═══╝ ██║   ██║██╔══██╗   ██║   " -ForegroundColor Green
Write-Host "██║  ██║███████╗██║     ╚██████╔╝██║  ██║   ██║   " -ForegroundColor Green
Write-Host "╚═╝  ╚═╝╚══════╝╚═╝      ╚═════╝ ╚═╝  ╚═╝   ╚═╝   " -ForegroundColor Green
Write-Host ""

Write-Host "INSTALLATION SUMMARY" -ForegroundColor Yellow
Write-Host "=" * 50 -ForegroundColor Yellow

# Component status
foreach ($component in $global:InstallationStatus.Keys) {
    if ($global:InstallationStatus[$component]) {
        Write-Success "$component:INSTALLED"
    } else {
        Write-Error-Custom "$component FAILED/MISSING"
    }
}

Write-Host ""
Write-Host "VERIFICATION RESULTS" -ForegroundColor Yellow
Write-Host "=" * 50 -ForegroundColor Yellow
Write-Host "Overall Success Rate: $successRate% ($passedTests/$totalTests tests passed)" -ForegroundColor $(if ($successRate -ge 80) { "Green" } elseif ($successRate -ge 60) { "Yellow" } else { "Red" })

# Determine overall status
$criticalComponents = @("Python", "R", "Quarto")
$criticalSuccess = $true
foreach ($component in $criticalComponents) {
    if (-not $global:InstallationStatus[$component]) {
        $criticalSuccess = $false
        break
    }
}

Write-Host ""
if ($criticalSuccess -and $successRate -ge 70) {
    Write-Host "🎉 INSTALLATION SUCCESSFUL! 🎉" -ForegroundColor Green
    Write-Host ""
    Write-Success "Your Resilience Report Generator is ready to use!"
    Write-Host ""
    Write-Info "NEXT STEPS:"
    Write-Host "  1. Place your master data CSV in the data/ directory"
    Write-Host "  2. Run: python clean_data.py"
    Write-Host "  3. Run: python generate_reports.py"
    Write-Host "  4. (Optional) Run: python send_emails.py"
    
    if (-not $global:InstallationStatus.CustomFont) {
        Write-Host ""
        Write-Warning "FONT REMINDER: Install fonts\QTDublinIrish.otf manually for proper formatting"
    }
    
    if (-not $global:InstallationStatus.TinyTeX) {
        Write-Host ""
        Write-Warning "PDF GENERATION: TinyTeX installation had issues. You may need to:"
        Write-Host "  • Run: quarto install tinytex"
        Write-Host "  • Or install MiKTeX/TeX Live manually"
    }
    
} elseif ($criticalSuccess) {
    Write-Host "⚠️ INSTALLATION COMPLETED WITH WARNINGS ⚠️" -ForegroundColor Yellow
    Write-Host ""
    Write-Warning "Core components installed, but some features may not work properly"
    Write-Host ""
    Write-Info "ISSUES TO ADDRESS:"
    
    if (-not $global:InstallationStatus.RPackages) {
        Write-Host "  • R packages: Some failed to install (may need Rtools)"
    }
    if (-not $global:InstallationStatus.TinyTeX) {
        Write-Host "  • TinyTeX: PDF generation may not work"
    }
    if (-not $global:InstallationStatus.QuartoExtensions) {
        Write-Host "  • Quarto extensions: Title pages may not format correctly"
    }
    if (-not $global:InstallationStatus.CustomFont) {
        Write-Host "  • Custom font: Reports won't use the intended typography"
    }
    
    Write-Host ""
    Write-Info "TRY THESE FIXES:"
    Write-Host "  • Re-run this installer with -ForceReinstall"
    Write-Host "  • Install missing components manually"
    Write-Host "  • Check the installation log: $logFile"
    
} else {
    Write-Host "❌ INSTALLATION FAILED ❌" -ForegroundColor Red
    Write-Host ""
    Write-Error-Custom "Critical components failed to install"
    Write-Host ""
    Write-Info "FAILED COMPONENTS:"
    foreach ($component in $criticalComponents) {
        if (-not $global:InstallationStatus[$component]) {
            Write-Host "  ✗ $component"
        }
    }
    
    Write-Host ""
    Write-Info "TROUBLESHOOTING STEPS:"
    Write-Host "  1. Run as Administrator (if not already)"
    Write-Host "  2. Check internet connection"
    Write-Host "  3. Disable antivirus temporarily"
    Write-Host "  4. Install components manually:"
    Write-Host "     • Python: https://www.python.org/downloads/"
    Write-Host "     • R: https://cran.r-project.org/bin/windows/base/"
    Write-Host "     • Quarto: https://quarto.org/docs/get-started/"
    Write-Host "  5. Check installation log: $logFile"
    Write-Host "  6. Re-run installer with -ForceReinstall"
}

# Cleanup temp files (keep log)
Write-Host ""
Write-Info "Cleaning up temporary files..."
Get-ChildItem $tempDir -Exclude "*.log" | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
Write-Info "Installation log saved at: $logFile"

# Final recommendations
Write-Host ""
Write-Host "ADDITIONAL RECOMMENDATIONS:" -ForegroundColor Cyan
Write-Host "• Restart your computer for all changes to take effect"
Write-Host "• Run 'python verify_setup.py' to double-check everything"
Write-Host "• Join the NMFS Open Science community for support"
Write-Host "• Check GitHub issues if you encounter problems"

if ($global:InstallationStatus.TinyTeX -and $global:InstallationStatus.RPackages) {
    Write-Host "• Try generating a test report to verify PDF creation works"
}

Write-Host ""
Write-Host "Thank you for using the Resilience Report Generator!" -ForegroundColor Cyan
Write-Host "This tool helps democratize data science - just like NMFS Open Science!" -ForegroundColor Cyan

Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")