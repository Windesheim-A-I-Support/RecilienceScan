# Script: modules/Install-RBasicPackages.ps1
# Purpose: Installs essential R packages for data science and statistical analysis
# FIXED VERSION - Uses working Rscript approach

Write-Host "Installing essential R packages..." -ForegroundColor Yellow

# Function to refresh PATH environment variable
function Update-SessionPath {
    $systemPath = [Environment]::GetEnvironmentVariable("PATH", [EnvironmentVariableTarget]::Machine)
    $userPath = [Environment]::GetEnvironmentVariable("PATH", [EnvironmentVariableTarget]::User)
    
    if ($userPath) {
        $env:PATH = "$systemPath;$userPath"
    } else {
        $env:PATH = $systemPath
    }
}

# Function to test if R is available
function Test-RAvailable {
    try {
        # Try Rscript first (most reliable)
        $rscriptVersion = Rscript.exe --version 2>&1
        if ($rscriptVersion -match "R scripting front-end version") {
            return $true
        }
    } catch {}
    
    try {
        # Try R.exe as fallback
        $rVersion = R.exe --version 2>&1
        if ($rVersion -match "R version") {
            return $true
        }
    } catch {}
    
    return $false
}

try {
    # Check if R is available
    Write-Host "Checking for R installation..." -ForegroundColor Cyan
    
    if (-not (Test-RAvailable)) {
        Write-Host "R not found in current PATH. Refreshing environment..." -ForegroundColor Yellow
        Update-SessionPath
        Start-Sleep -Seconds 2
        
        if (-not (Test-RAvailable)) {
            Write-Host "R is still not available after PATH refresh." -ForegroundColor Red
            Write-Host "This may happen if R was just installed in the same session." -ForegroundColor Yellow
            Write-Host "R packages installation will be skipped for now." -ForegroundColor Yellow
            Write-Host "You can install R packages manually later or restart your terminal." -ForegroundColor Yellow
            exit 0  # Don't fail the installation
        }
    }
    
    Write-Host "R is available. Proceeding with package installation..." -ForegroundColor Green
    
    # Get R version info
    try {
        $rVersionInfo = Rscript.exe -e "cat(R.version.string)" 2>$null
        Write-Host "R Version: $rVersionInfo" -ForegroundColor Gray
    } catch {
        Write-Host "R Version: Could not determine" -ForegroundColor Gray
    }
    
    # Define essential R packages for RecilienceScan
    $essentialPackagesList = @(
        'rmarkdown',
        'knitr', 
        'readr',
        'dplyr',
        'stringr',
        'tidyr',
        'ggplot2',
        'readxl',
        'openxlsx',
        'DBI',
        'here',
        'lubridate',
        'fmsb',
        'scales',
        'viridis',
        'patchwork',
        'RColorBrewer',
        'gridExtra',
        'png',
        'kableExtra'
    )
    
    $totalPackages = $essentialPackagesList.Count
    Write-Host "Installing $totalPackages essential R packages..." -ForegroundColor Yellow
    Write-Host "This may take several minutes as R compiles packages..." -ForegroundColor Gray
    Write-Host ""
    
    # Create the install command (using your working approach)
    $packageString = "'" + ($essentialPackagesList -join "', '") + "'"
    $installCommand = "install.packages(c($packageString), repos = 'https://cloud.r-project.org', dependencies = TRUE)"
    
    Write-Host "Installing packages using cloud.r-project.org repository..." -ForegroundColor Cyan
    Write-Host "Command: Rscript -e `"$installCommand`"" -ForegroundColor Gray
    
    # Execute the installation
    $process = Start-Process "Rscript.exe" -ArgumentList @("-e", $installCommand) -Wait -PassThru -NoNewWindow
    
    if ($process.ExitCode -eq 0) {
        Write-Host ""
        Write-Host "Package installation completed!" -ForegroundColor Green
        
        # Test critical packages
        Write-Host ""
        Write-Host "Testing critical package loading..." -ForegroundColor Cyan
        
        $criticalPackages = @("rmarkdown", "knitr", "ggplot2", "dplyr")
        $criticalSuccesses = 0
        
        foreach ($testPkg in $criticalPackages) {
            try {
                $loadTest = Rscript.exe -e "cat(ifelse(require('$testPkg', quietly=TRUE), 'OK', 'FAILED'))" 2>$null
                if ($loadTest -eq "OK") {
                    Write-Host "  + $testPkg loads successfully" -ForegroundColor Green
                    $criticalSuccesses++
                } else {
                    Write-Host "  - $testPkg failed to load" -ForegroundColor Red
                }
            } catch {
                Write-Host "  - $testPkg load test error" -ForegroundColor Red
            }
        }
        
        # Test tidyverse (if included)
        Write-Host ""
        Write-Host "Testing additional packages..." -ForegroundColor Cyan
        $additionalPackages = @("fmsb", "scales", "viridis")
        $additionalSuccesses = 0
        
        foreach ($testPkg in $additionalPackages) {
            try {
                $loadTest = Rscript.exe -e "cat(ifelse(require('$testPkg', quietly=TRUE), 'OK', 'FAILED'))" 2>$null
                if ($loadTest -eq "OK") {
                    Write-Host "  + $testPkg loads successfully" -ForegroundColor Green
                    $additionalSuccesses++
                } else {
                    Write-Host "  - $testPkg failed to load" -ForegroundColor Yellow
                }
            } catch {
                Write-Host "  - $testPkg load test error" -ForegroundColor Yellow
            }
        }
        
        # Final status
        Write-Host ""
        Write-Host ("=" * 60) -ForegroundColor Cyan
        Write-Host "R PACKAGES INSTALLATION SUMMARY" -ForegroundColor Cyan
        Write-Host ("=" * 60) -ForegroundColor Cyan
        
        Write-Host "Total packages: $totalPackages" -ForegroundColor Gray
        Write-Host "Critical packages working: $criticalSuccesses/$($criticalPackages.Count)" -ForegroundColor $(if ($criticalSuccesses -eq $criticalPackages.Count) { "Green" } else { "Yellow" })
        Write-Host "Additional packages working: $additionalSuccesses/$($additionalPackages.Count)" -ForegroundColor $(if ($additionalSuccesses -ge 2) { "Green" } else { "Yellow" })
        
        if ($criticalSuccesses -eq $criticalPackages.Count) {
            Write-Host ""
            Write-Host "SUCCESS: All critical R packages installed and working!" -ForegroundColor Green
            Write-Host "R environment is ready for Quarto and RecilienceScan." -ForegroundColor Green
            exit 0
        } elseif ($criticalSuccesses -ge 3) {
            Write-Host ""
            Write-Host "MOSTLY SUCCESS: Most critical R packages are working." -ForegroundColor Yellow
            Write-Host "R environment should function for basic tasks." -ForegroundColor Yellow
            exit 0
        } else {
            Write-Host ""
            Write-Host "PARTIAL FAILURE: Some critical R packages failed to load." -ForegroundColor Red
            Write-Host "R environment may have limited functionality." -ForegroundColor Red
            exit 0
        }
        
    } else {
        Write-Host ""
        Write-Host "Package installation failed with exit code: $($process.ExitCode)" -ForegroundColor Red
        Write-Host ""
        Write-Host "Troubleshooting steps:" -ForegroundColor Yellow
        Write-Host "1. Try manually: Rscript -e `"install.packages(c('rmarkdown', 'knitr'), repos='https://cloud.r-project.org')`"" -ForegroundColor Cyan
        Write-Host "2. Check internet connection and proxy settings" -ForegroundColor Yellow
        Write-Host "3. Install Rtools if needed: https://cran.r-project.org/bin/windows/Rtools/" -ForegroundColor Yellow
        exit 1
    }
    
} catch {
    Write-Host "ERROR: Unexpected error during R package installation." -ForegroundColor Red
    Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Manual installation command that should work:" -ForegroundColor Yellow
    Write-Host "Rscript -e `"install.packages(c('rmarkdown', 'knitr', 'ggplot2', 'dplyr'), repos='https://cloud.r-project.org')`"" -ForegroundColor Cyan
    exit 1
}