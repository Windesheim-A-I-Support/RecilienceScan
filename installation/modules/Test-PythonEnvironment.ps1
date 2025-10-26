# Script: modules/Test-PythonEnvironment.ps1
# Purpose: Tests Python environment functionality and package availability

Write-Host "Testing Python environment..." -ForegroundColor Yellow

# Function to test Python availability
function Test-PythonCommand {
    try {
        $pythonVersion = python --version 2>&1
        return $pythonVersion -match "Python \d+\.\d+\.\d+"
    } catch {
        return $false
    }
}

# Function to test pip availability
function Test-PipCommand {
    try {
        $pipVersion = pip --version 2>&1
        return $pipVersion -match "pip \d+\.\d+"
    } catch {
        return $false
    }
}

# Function to test package import
function Test-PythonPackage {
    param([string]$PackageName)
    
    try {
        $importTest = python -c "import $PackageName; print('SUCCESS')" 2>$null
        return $importTest -eq "SUCCESS"
    } catch {
        return $false
    }
}

try {
    $testResults = @{
        PythonAvailable = $false
        PipAvailable = $false
        PackagesWorking = 0
        PackagesFailed = 0
        OverallStatus = "FAILED"
    }
    
    # Test Python command
    Write-Host "Testing Python command..." -ForegroundColor Cyan
    if (Test-PythonCommand) {
        $pythonVersion = python --version 2>&1
        Write-Host "  + Python available: $pythonVersion" -ForegroundColor Green
        $testResults.PythonAvailable = $true
    } else {
        Write-Host "  - Python command not available" -ForegroundColor Red
        $testResults.OverallStatus = "CRITICAL_FAILURE"
    }
    
    # Test pip command
    Write-Host "Testing pip command..." -ForegroundColor Cyan
    if (Test-PipCommand) {
        $pipVersion = pip --version 2>&1
        Write-Host "  + pip available: $pipVersion" -ForegroundColor Green
        $testResults.PipAvailable = $true
    } else {
        Write-Host "  - pip command not available" -ForegroundColor Red
        $testResults.OverallStatus = "CRITICAL_FAILURE"
    }
    
    # Test essential packages
    if ($testResults.PythonAvailable) {
        Write-Host "Testing essential Python packages..." -ForegroundColor Cyan
        
        $essentialPackages = @(
            "sys", "os", "json", "datetime", "pathlib",
            "pandas", "numpy", "matplotlib", "requests", 
            "openpyxl", "tqdm", "jupyter"
        )
        
        foreach ($package in $essentialPackages) {
            if (Test-PythonPackage -PackageName $package) {
                Write-Host "  + $package imports successfully" -ForegroundColor Green
                $testResults.PackagesWorking++
            } else {
                Write-Host "  - $package import failed" -ForegroundColor Red
                $testResults.PackagesFailed++
            }
        }
    }
    
    # Test Python executable path
    Write-Host "Testing Python installation details..." -ForegroundColor Cyan
    try {
        $pythonPath = python -c "import sys; print(sys.executable)" 2>$null
        $pythonVersion = python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}')" 2>$null
        $pythonPlatform = python -c "import sys; print(sys.platform)" 2>$null
        
        Write-Host "  Python executable: $pythonPath" -ForegroundColor Gray
        Write-Host "  Python version: $pythonVersion" -ForegroundColor Gray  
        Write-Host "  Platform: $pythonPlatform" -ForegroundColor Gray
    } catch {
        Write-Host "  - Could not retrieve Python details" -ForegroundColor Yellow
    }
    
    # Test pip installation capabilities
    Write-Host "Testing pip functionality..." -ForegroundColor Cyan
    try {
        $pipList = pip list --format=freeze 2>$null | Measure-Object -Line
        Write-Host "  + pip can list packages ($($pipList.Lines) packages installed)" -ForegroundColor Green
    } catch {
        Write-Host "  - pip list command failed" -ForegroundColor Red
    }
    
    # Determine overall status
    if ($testResults.PythonAvailable -and $testResults.PipAvailable) {
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
    Write-Host "PYTHON ENVIRONMENT TEST SUMMARY" -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor Cyan
    
    Write-Host "Python Command: $(if ($testResults.PythonAvailable) { 'Available' } else { 'Missing' })" -ForegroundColor $(if ($testResults.PythonAvailable) { "Green" } else { "Red" })
    Write-Host "pip Command: $(if ($testResults.PipAvailable) { 'Available' } else { 'Missing' })" -ForegroundColor $(if ($testResults.PipAvailable) { "Green" } else { "Red" })
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
        Write-Host "- Python environment is not functional" -ForegroundColor Red
        Write-Host "- Reinstall Python or fix PATH issues" -ForegroundColor Red
    } elseif ($testResults.PackagesFailed -gt 0) {
        Write-Host ""
        Write-Host "RECOMMENDATIONS:" -ForegroundColor Yellow
        Write-Host "- Install missing packages: pip install <package-name>" -ForegroundColor Yellow
        Write-Host "- Check requirements.txt for project-specific packages" -ForegroundColor Yellow
    } else {
        Write-Host ""
        Write-Host "Python environment is ready for data science work!" -ForegroundColor Green
    }
    
    # Exit based on status
    if ($testResults.OverallStatus -eq "CRITICAL_FAILURE") {
        exit 1
    } else {
        exit 0
    }
    
} catch {
    Write-Host "ERROR: Python environment testing failed." -ForegroundColor Red
    Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}