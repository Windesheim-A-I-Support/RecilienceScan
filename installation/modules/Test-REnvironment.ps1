# Script: modules/Test-REnvironment.ps1
# Purpose: Tests R environment functionality and package availability

Write-Host "Testing R environment..." -ForegroundColor Yellow

# Function to test R availability
function Test-RCommand {
    try {
        $rVersion = R --version 2>&1
        return $rVersion -match "R version \d+\.\d+\.\d+"
    } catch {
        return $false
    }
}

# Function to test Rscript availability
function Test-RscriptCommand {
    try {
        $rscriptVersion = Rscript --version 2>&1
        return $rscriptVersion -match "R scripting front-end"
    } catch {
        return $false
    }
}

# Function to test R package availability
function Test-RPackage {
    param([string]$PackageName)
    
    try {
        $testCommand = "cat(ifelse(require('$PackageName', quietly=TRUE), 'SUCCESS', 'FAILED'))"
        $result = R --slave -e $testCommand 2>$null
        return $result -eq "SUCCESS"
    } catch {
        return $false
    }
}

# Function to refresh PATH for current session
function Update-SessionPath {
    $systemPath = [Environment]::GetEnvironmentVariable("PATH", [EnvironmentVariableTarget]::Machine)
    $userPath = [Environment]::GetEnvironmentVariable("PATH", [EnvironmentVariableTarget]::User)
    
    if ($userPath) {
        $env:PATH = "$systemPath;$userPath"
    } else {
        $env:PATH = $systemPath
    }
}

try {
    $testResults = @{
        RAvailable = $false
        RscriptAvailable = $false
        PackagesWorking = 0
        PackagesFailed = 0
        OverallStatus = "FAILED"
    }
    
    # Test R command
    Write-Host "Testing R command..." -ForegroundColor Cyan
    if (-not (Test-RCommand)) {
        Write-Host "  R not found in PATH. Refreshing environment..." -ForegroundColor Yellow
        Update-SessionPath
        Start-Sleep -Seconds 1
    }
    
    if (Test-RCommand) {
        $rVersionInfo = R --slave -e "cat(R.version.string)" 2>$null
        Write-Host "  + R available: $rVersionInfo" -ForegroundColor Green
        $testResults.RAvailable = $true
    } else {
        Write-Host "  - R command not available" -ForegroundColor Red
        $testResults.OverallStatus = "CRITICAL_FAILURE"
    }
    
    # Test Rscript command
    Write-Host "Testing Rscript command..." -ForegroundColor Cyan
    if (Test-RscriptCommand) {
        Write-Host "  + Rscript available" -ForegroundColor Green
        $testResults.RscriptAvailable = $true
    } else {
        Write-Host "  - Rscript command not available" -ForegroundColor Red
    }
    
    # Test essential packages
    if ($testResults.RAvailable) {
        Write-Host "Testing essential R packages..." -ForegroundColor Cyan
        
        $essentialPackages = @(
            "base", "utils", "stats", "graphics", "grDevices",
            "ggplot2", "dplyr", "readr", "knitr", "rmarkdown", 
            "tidyverse", "readxl", "DBI", "here"
        )
        
        foreach ($package in $essentialPackages) {
            if (Test-RPackage -PackageName $package) {
                Write-Host "  + $package loads successfully" -ForegroundColor Green
                $testResults.PackagesWorking++
            } else {
                Write-Host "  - $package load failed" -ForegroundColor Red
                $testResults.PackagesFailed++
            }
        }
    }
    
    # Test R installation details
    Write-Host "Testing R installation details..." -ForegroundColor Cyan
    try {
        $rVersion = R --slave -e "cat(paste(R.version$major, R.version$minor, sep='.'))" 2>$null
        $rHome = R --slave -e "cat(R.home())" 2>$null
        $rPlatform = R --slave -e "cat(R.version$platform)" 2>$null
        
        Write-Host "  R version: $rVersion" -ForegroundColor Gray
        Write-Host "  R home: $rHome" -ForegroundColor Gray
        Write-Host "  Platform: $rPlatform" -ForegroundColor Gray
    } catch {
        Write-Host "  - Could not retrieve R details" -ForegroundColor Yellow
    }
    
    # Test package installation capabilities
    Write-Host "Testing R package management..." -ForegroundColor Cyan
    try {
        $installedPackages = R --slave -e "cat(length(installed.packages()[,1]))" 2>$null
        Write-Host "  + R has access to package installation ($installedPackages packages installed)" -ForegroundColor Green
        
        # Test CRAN mirror access
        $cranTest = R --slave -e "cat(ifelse(length(getCRANmirrors()) > 0, 'SUCCESS', 'FAILED'))" 2>$null
        if ($cranTest -eq "SUCCESS") {
            Write-Host "  + CRAN mirror access working" -ForegroundColor Green
        } else {
            Write-Host "  - CRAN mirror access issues" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  - Package management test failed" -ForegroundColor Red
    }
    
    # Test Rtools availability (Windows)
    Write-Host "Testing Rtools availability..." -ForegroundColor Cyan
    try {
        $rtoolsTest = R --slave -e "cat(ifelse(pkgbuild::has_rtools(), 'SUCCESS', 'FAILED'))" 2>$null
        if ($rtoolsTest -eq "SUCCESS") {
            Write-Host "  + Rtools available for package compilation" -ForegroundColor Green
        } else {
            Write-Host "  - Rtools not available (may affect some package installations)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  - Could not test Rtools availability" -ForegroundColor Gray
    }
    
    # Determine overall status
    if ($testResults.RAvailable -and $testResults.RscriptAvailable) {
        $packageSuccessRate = if ($essentialPackages.Count -gt 0) { 
            $testResults.PackagesWorking / ($testResults.PackagesWorking + $testResults.PackagesFailed)
        } else { 
            1 
        }
        
        if ($packageSuccessRate -ge 0.8) {
            $testResults.OverallStatus = "EXCELLENT"
        } elseif ($packageSuccessRate -ge 0.6) {
            $testResults.OverallStatus = "GOOD"
        } elseif ($packageSuccessRate -ge 0.4) {
            $testResults.OverallStatus = "FAIR"
        } else {
            $testResults.OverallStatus = "POOR"
        }
    }
    
    # Summary
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host "R ENVIRONMENT TEST SUMMARY" -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor Cyan
    
    Write-Host "R Command: $(if ($testResults.RAvailable) { 'Available' } else { 'Missing' })" -ForegroundColor $(if ($testResults.RAvailable) { "Green" } else { "Red" })
    Write-Host "Rscript Command: $(if ($testResults.RscriptAvailable) { 'Available' } else { 'Missing' })" -ForegroundColor $(if ($testResults.RscriptAvailable) { "Green" } else { "Red" })
    Write-Host "Packages Working: $($testResults.PackagesWorking)" -ForegroundColor Green
    Write-Host "Packages Failed: $($testResults.PackagesFailed)" -ForegroundColor $(if ($testResults.PackagesFailed -gt 0) { "Red" } else { "Gray" })
    Write-Host "Overall Status: $($testResults.OverallStatus)" -ForegroundColor $(
        switch ($testResults.OverallStatus) {
            "EXCELLENT" { "Green" }
            "GOOD" { "Green" }
            "FAIR" { "Yellow" }
            "POOR" { "Red" }
            "CRITICAL_FAILURE" { "Red" }
            default { "Gray" }
        }
    )
    
    # Recommendations
    if ($testResults.OverallStatus -eq "CRITICAL_FAILURE") {
        Write-Host ""
        Write-Host "CRITICAL ISSUES DETECTED:" -ForegroundColor Red
        Write-Host "- R environment is not functional" -ForegroundColor Red
        Write-Host "- Install R or fix PATH issues" -ForegroundColor Red
    } elseif ($testResults.PackagesFailed -gt 0) {
        Write-Host ""
        Write-Host "RECOMMENDATIONS:" -ForegroundColor Yellow
        Write-Host "- Install missing packages in R console" -ForegroundColor Yellow
        Write-Host "- Consider installing Rtools for package compilation" -ForegroundColor Yellow
    } else {
        Write-Host ""
        Write-Host "R environment is ready for statistical analysis!" -ForegroundColor Green
    }
    
    # Exit based on status
    if ($testResults.OverallStatus -eq "CRITICAL_FAILURE") {
        exit 1
    } else {
        exit 0
    }
    
} catch {
    Write-Host "ERROR: R environment testing failed." -ForegroundColor Red
    Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}