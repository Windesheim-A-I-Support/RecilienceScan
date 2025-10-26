# Script: modules/Install-RBasicPackages.ps1
# Purpose: Installs essential R packages for data science and statistical analysis

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

# Function to test if R is available (Windows-specific)
# Robust R Package Installer with Multiple Methods
function Install-RPackage {
    param(
        [string]$PackageName,
        [string]$DisplayName = $PackageName
    )
    
    Write-Host "  Installing $DisplayName..." -ForegroundColor Cyan
    
    # Method 1: cmd /c bypass (most reliable for parameter issues)
    try {
        Write-Host "    Trying method 1 (cmd bypass)..." -ForegroundColor Gray
        $installCommand = "if (!require('$PackageName', quietly=TRUE)) { install.packages('$PackageName', repos='https://cran.rstudio.com/', dependencies=TRUE); cat('INSTALLED') } else { cat('ALREADY_PRESENT') }"
        
        $result = cmd /c "R.exe --slave -e `"$installCommand`"" 2>&1
        
        if ($result -like "*INSTALLED*" -or $result -like "*ALREADY_PRESENT*") {
            $verifyResult = cmd /c "R.exe --slave -e `"cat(ifelse(require('$PackageName', quietly=TRUE), 'OK', 'FAILED'))`"" 2>$null
            if ($verifyResult -eq "OK") {
                Write-Host "    + $DisplayName installed and verified (method 1)" -ForegroundColor Green
                return $true
            }
        }
    } catch {
        Write-Host "    - Method 1 failed: $($_.Exception.Message)" -ForegroundColor Gray
    }
    
    # Method 2: Start-Process with explicit arguments
    try {
        Write-Host "    Trying method 2 (Start-Process)..." -ForegroundColor Gray
        $installCommand = "if (!require('$PackageName', quietly=TRUE)) { install.packages('$PackageName', repos='https://cran.rstudio.com/', dependencies=TRUE); cat('INSTALLED') } else { cat('ALREADY_PRESENT') }"
        
        $tempOut = [System.IO.Path]::GetTempFileName()
        $process = Start-Process "R.exe" -ArgumentList @("--slave", "-e", $installCommand) -Wait -PassThru -RedirectStandardOutput $tempOut -NoNewWindow -WindowStyle Hidden
        
        if ($process.ExitCode -eq 0) {
            $result = Get-Content $tempOut -Raw
            Remove-Item $tempOut -Force -ErrorAction SilentlyContinue
            
            if ($result -like "*INSTALLED*" -or $result -like "*ALREADY_PRESENT*") {
                # Verify installation
                $verifyTemp = [System.IO.Path]::GetTempFileName()
                $verifyProcess = Start-Process "R.exe" -ArgumentList @("--slave", "-e", "cat(ifelse(require('$PackageName', quietly=TRUE), 'OK', 'FAILED'))") -Wait -PassThru -RedirectStandardOutput $verifyTemp -NoNewWindow -WindowStyle Hidden
                $verifyResult = Get-Content $verifyTemp -Raw
                Remove-Item $verifyTemp -Force -ErrorAction SilentlyContinue
                
                if ($verifyResult -eq "OK") {
                    Write-Host "    + $DisplayName installed and verified (method 2)" -ForegroundColor Green
                    return $true
                }
            }
        }
        Remove-Item $tempOut -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Host "    - Method 2 failed: $($_.Exception.Message)" -ForegroundColor Gray
    }
    
    # Method 3: & operator with explicit parameter separation
    try {
        Write-Host "    Trying method 3 (& operator)..." -ForegroundColor Gray
        $installCommand = "if (!require('$PackageName', quietly=TRUE)) { install.packages('$PackageName', repos='https://cran.rstudio.com/', dependencies=TRUE); cat('INSTALLED') } else { cat('ALREADY_PRESENT') }"
        
        $result = & R.exe --slave --no-restore --no-save -e $installCommand 2>&1
        
        if ($result -like "*INSTALLED*" -or $result -like "*ALREADY_PRESENT*") {
            $verifyResult = & R.exe --slave --no-restore --no-save -e "cat(ifelse(require('$PackageName', quietly=TRUE), 'OK', 'FAILED'))" 2>$null
            if ($verifyResult -eq "OK") {
                Write-Host "    + $DisplayName installed and verified (method 3)" -ForegroundColor Green
                return $true
            }
        }
    } catch {
        Write-Host "    - Method 3 failed: $($_.Exception.Message)" -ForegroundColor Gray
    }
    
    # Method 4: Rscript alternative (different executable)
    try {
        Write-Host "    Trying method 4 (Rscript)..." -ForegroundColor Gray
        $installCommand = "if (!require('$PackageName', quietly=TRUE)) { install.packages('$PackageName', repos='https://cran.rstudio.com/', dependencies=TRUE); cat('INSTALLED') } else { cat('ALREADY_PRESENT') }"
        
        $result = Rscript.exe -e $installCommand 2>&1
        
        if ($result -like "*INSTALLED*" -or $result -like "*ALREADY_PRESENT*") {
            $verifyResult = Rscript.exe -e "cat(ifelse(require('$PackageName', quietly=TRUE), 'OK', 'FAILED'))" 2>$null
            if ($verifyResult -eq "OK") {
                Write-Host "    + $DisplayName installed and verified (method 4)" -ForegroundColor Green
                return $true
            }
        }
    } catch {
        Write-Host "    - Method 4 failed: $($_.Exception.Message)" -ForegroundColor Gray
    }
    
    # Method 5: Temp file approach (most isolated)
    try {
        Write-Host "    Trying method 5 (temp file)..." -ForegroundColor Gray
        
        $tempScript = [System.IO.Path]::GetTempFileName() + ".R"
        $installScript = @"
if (!require('$PackageName', quietly=TRUE)) {
  install.packages('$PackageName', repos='https://cran.rstudio.com/', dependencies=TRUE)
  cat('INSTALLED')
} else {
  cat('ALREADY_PRESENT')
}
"@
        
        Set-Content -Path $tempScript -Value $installScript
        
        $result = R.exe --slave --no-restore --no-save -f $tempScript 2>&1
        Remove-Item $tempScript -Force -ErrorAction SilentlyContinue
        
        if ($result -like "*INSTALLED*" -or $result -like "*ALREADY_PRESENT*") {
            # Verify with temp script
            $verifyScript = [System.IO.Path]::GetTempFileName() + ".R"
            Set-Content -Path $verifyScript -Value "cat(ifelse(require('$PackageName', quietly=TRUE), 'OK', 'FAILED'))"
            
            $verifyResult = R.exe --slave --no-restore --no-save -f $verifyScript 2>$null
            Remove-Item $verifyScript -Force -ErrorAction SilentlyContinue
            
            if ($verifyResult -eq "OK") {
                Write-Host "    + $DisplayName installed and verified (method 5)" -ForegroundColor Green
                return $true
            }
        }
    } catch {
        Write-Host "    - Method 5 failed: $($_.Exception.Message)" -ForegroundColor Gray
    }
    
    # Method 6: PowerShell Invoke-Expression (last resort)
    try {
        Write-Host "    Trying method 6 (Invoke-Expression)..." -ForegroundColor Gray
        
        $installCommand = "R.exe --slave -e `"if (!require('$PackageName', quietly=TRUE)) { install.packages('$PackageName', repos='https://cran.rstudio.com/', dependencies=TRUE); cat('INSTALLED') } else { cat('ALREADY_PRESENT') }`""
        
        $result = Invoke-Expression $installCommand 2>&1
        
        if ($result -like "*INSTALLED*" -or $result -like "*ALREADY_PRESENT*") {
            $verifyCommand = "R.exe --slave -e `"cat(ifelse(require('$PackageName', quietly=TRUE), 'OK', 'FAILED'))`""
            $verifyResult = Invoke-Expression $verifyCommand 2>$null
            
            if ($verifyResult -eq "OK") {
                Write-Host "    + $DisplayName installed and verified (method 6)" -ForegroundColor Green
                return $true
            }
        }
    } catch {
        Write-Host "    - Method 6 failed: $($_.Exception.Message)" -ForegroundColor Gray
    }
    
    # All methods failed
    Write-Host "    - $DisplayName installation failed (all methods exhausted)" -ForegroundColor Red
    Write-Host "      Try manual installation: install.packages('$PackageName')" -ForegroundColor Yellow
    return $false
}

# Enhanced R availability test with multiple methods
function Test-RAvailable {
    # Method 1: Direct R.exe test
    try {
        $rVersion = R.exe --version 2>&1
        if ($rVersion -match "R version") {
            return $true
        }
    } catch {}
    
    # Method 2: Rscript test
    try {
        $rscriptVersion = Rscript.exe --version 2>&1
        if ($rscriptVersion -match "R scripting front-end version") {
            return $true
        }
    } catch {}
    
    # Method 3: cmd bypass test
    try {
        $result = cmd /c "R.exe --version" 2>&1
        if ($result -match "R version") {
            return $true
        }
    } catch {}
    
    return $false
}

# Test function to verify R package installation works
function Test-RPackageInstallation {
    Write-Host "Testing R package installation methods..." -ForegroundColor Cyan
    
    # Test with a simple, fast-installing package
    $testPackage = "jsonlite"  # Small, common package
    
    Write-Host "Running installation test with package: $testPackage" -ForegroundColor Yellow
    $success = Install-RPackage -PackageName $testPackage -DisplayName "$testPackage (test package)"
    
    if ($success) {
        Write-Host "✓ R package installation is working!" -ForegroundColor Green
        return $true
    } else {
        Write-Host "✗ R package installation failed completely" -ForegroundColor Red
        Write-Host "Manual troubleshooting required" -ForegroundColor Yellow
        return $false
    }

    # Get R version info using proper Windows syntax
    try {
        $rVersionInfo = R.exe --slave -e "cat(R.version.string)" 2>$null
        Write-Host "R Version: $rVersionInfo" -ForegroundColor Gray
    } catch {
        Write-Host "R Version: Could not determine" -ForegroundColor Gray
    }
    
    # Define essential R packages (prioritize critical ones first)
    $essentialPackages = @(
        @{ Package = "rmarkdown"; Display = "rmarkdown (R Markdown - CRITICAL)" },
        @{ Package = "knitr"; Display = "knitr (Dynamic reports - CRITICAL)" },
        @{ Package = "ggplot2"; Display = "ggplot2 (Graphics)" },
        @{ Package = "dplyr"; Display = "dplyr (Data manipulation)" },
        @{ Package = "readr"; Display = "readr (Data import)" },
        @{ Package = "readxl"; Display = "readxl (Excel files)" },
        @{ Package = "openxlsx"; Display = "openxlsx (Excel writing)" },
        @{ Package = "DBI"; Display = "DBI (Database interface)" },
        @{ Package = "here"; Display = "here (File paths)" },
        @{ Package = "lubridate"; Display = "lubridate (Date/time)" },
        @{ Package = "tidyverse"; Display = "tidyverse (Meta-package - install last)" },
        # Add these packages to your existing $essentialPackages array:

        @{ Package = "stringr"; Display = "stringr (String manipulation)" },
        @{ Package = "tidyr"; Display = "tidyr (Data reshaping)" },
        @{ Package = "fmsb"; Display = "fmsb (Radar charts)" },
        @{ Package = "scales"; Display = "scales (Plot scaling)" },
        @{ Package = "viridis"; Display = "viridis (Color palettes)" },
        @{ Package = "patchwork"; Display = "patchwork (Plot composition)" },
        @{ Package = "RColorBrewer"; Display = "RColorBrewer (Color schemes)" },
        @{ Package = "gridExtra"; Display = "gridExtra (Grid graphics)" },
        @{ Package = "png"; Display = "png (PNG support)" },
        @{ Package = "kableExtra"; Display = "kableExtra (Enhanced tables)" }
    )
    
    # Track installation results
    $successCount = 0
    $failureCount = 0
    $totalPackages = $essentialPackages.Count
    
    Write-Host "Installing $totalPackages essential R packages..." -ForegroundColor Yellow
    Write-Host "This may take several minutes as R compiles packages..." -ForegroundColor Gray
    Write-Host ""
    
    # Set CRAN mirror using proper Windows syntax
    Write-Host "Setting CRAN mirror..." -ForegroundColor Cyan
    try {
        R.exe --slave -e "options(repos = c(CRAN = 'https://cran.rstudio.com/'))" 2>$null
    } catch {
        Write-Host "  Could not set CRAN mirror (continuing anyway)" -ForegroundColor Yellow
    }
    
    # Install each package
    foreach ($pkg in $essentialPackages) {
        if (Install-RPackage -PackageName $pkg.Package -DisplayName $pkg.Display) {
            $successCount++
        } else {
            $failureCount++
        }
    }
    
    # Summary
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host "R BASIC PACKAGES INSTALLATION SUMMARY" -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor Cyan
    
    Write-Host "Total packages: $totalPackages" -ForegroundColor Gray
    Write-Host "Successfully installed: $successCount" -ForegroundColor Green
    Write-Host "Failed: $failureCount" -ForegroundColor $(if ($failureCount -gt 0) { "Red" } else { "Gray" })
    
    # Test critical packages specifically
    Write-Host ""
    Write-Host "Testing critical package loading..." -ForegroundColor Cyan
    
    $criticalPackages = @("rmarkdown", "knitr", "ggplot2", "dplyr")
    $criticalSuccesses = 0
    
    foreach ($testPkg in $criticalPackages) {
        try {
            $loadTest = R.exe --slave -e "cat(ifelse(require('$testPkg', quietly=TRUE), 'OK', 'FAILED'))" 2>$null
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
    
    # Check tidyverse specifically (often fails)
    Write-Host ""
    Write-Host "Checking tidyverse meta-package..." -ForegroundColor Cyan
    try {
        $tidyverseTest = R.exe --slave -e "cat(ifelse(require('tidyverse', quietly=TRUE), 'OK', 'FAILED'))" 2>$null
        if ($tidyverseTest -eq "OK") {
            Write-Host "  + tidyverse meta-package working" -ForegroundColor Green
        } else {
            Write-Host "  - tidyverse meta-package not working (individual packages may still work)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  - tidyverse test error" -ForegroundColor Red
    }
    
    # Final status based on critical packages
    if ($criticalSuccesses -eq $criticalPackages.Count) {
        Write-Host ""
        Write-Host "All critical R packages installed and working!" -ForegroundColor Green
        Write-Host "R environment is ready for Quarto and data analysis." -ForegroundColor Green
        exit 0
    } elseif ($criticalSuccesses -ge 2) {
        Write-Host ""
        Write-Host "Most critical R packages are working." -ForegroundColor Yellow
        Write-Host "R environment should function for basic tasks." -ForegroundColor Yellow
        exit 0
    } else {
        Write-Host ""
        Write-Host "Critical R package installations failed." -ForegroundColor Red
        Write-Host "R environment may not be functional for Quarto rendering." -ForegroundColor Red
        
        Write-Host ""
        Write-Host "Troubleshooting steps:" -ForegroundColor Yellow
        Write-Host "1. Install Rtools: https://cran.r-project.org/bin/windows/Rtools/" -ForegroundColor Yellow
        Write-Host "2. Update R to latest version" -ForegroundColor Yellow
        Write-Host "3. Try installing packages manually in R console:" -ForegroundColor Yellow
        Write-Host "   R.exe" -ForegroundColor Cyan
        Write-Host "   install.packages(c('rmarkdown', 'knitr'))" -ForegroundColor Cyan
        
        # Don't fail completely - some packages might still work
        exit 0
    }
    
} catch {
    Write-Host "ERROR: Unexpected error during R package installation." -ForegroundColor Red
    Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Manual installation in R console:" -ForegroundColor Yellow
    Write-Host "R.exe" -ForegroundColor Cyan
    Write-Host "install.packages(c('rmarkdown', 'knitr', 'ggplot2', 'dplyr'))" -ForegroundColor Cyan
    exit 1
}