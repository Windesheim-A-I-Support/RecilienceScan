# Script: modules/Install-PythonBasicPackages.ps1
# Purpose: Installs essential Python packages for basic data science and development

Write-Host "Installing essential Python packages..." -ForegroundColor Yellow
Write-Host "=== PYTHON BASIC PACKAGES INSTALLATION ===" -ForegroundColor Cyan

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

# Function to test if pip is available
function Test-PipAvailable {
    try {
        $pipVersion = pip --version 2>&1
        if ($pipVersion -match "pip \d+\.\d+") {
            return $true
        }
    } catch {
        return $false
    }
    return $false
}

# Function to test if Python is available
function Test-PythonAvailable {
    try {
        $pythonVersion = python --version 2>&1
        if ($pythonVersion -match "Python \d+\.\d+") {
            return $true
        }
    } catch {
        return $false
    }
    return $false
}

# Function to install Python package with error handling
function Install-PythonPackage {
    param(
        [string]$PackageName,
        [string]$DisplayName = $PackageName,
        [string]$Version = $null
    )
    
    try {
        $packageSpec = if ($Version) { "$PackageName==$Version" } else { $PackageName }
        Write-Host "  Installing $DisplayName..." -ForegroundColor Cyan
        
        # Use pip to install package
        $result = pip install $packageSpec --upgrade --no-warn-script-location 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    + $DisplayName installed successfully" -ForegroundColor Green
            return $true
        } else {
            Write-Host "    - $DisplayName installation failed" -ForegroundColor Red
            Write-Host "      Error: $result" -ForegroundColor Gray
            return $false
        }
    } catch {
        Write-Host "    - $DisplayName installation error: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to verify package installation
function Test-PythonPackage {
    param([string]$PackageName)
    
    try {
        $result = python -c "import $PackageName; print('$PackageName OK')" 2>&1
        return $result -like "*OK*"
    } catch {
        return $false
    }
}

try {
    # Check if Python is available
    Write-Host "Checking for Python installation..." -ForegroundColor Cyan
    
    if (-not (Test-PythonAvailable)) {
        Write-Host "Python not found in current PATH. Refreshing environment..." -ForegroundColor Yellow
        Update-SessionPath
        Start-Sleep -Seconds 2
        
        if (-not (Test-PythonAvailable)) {
            Write-Host "Python is still not available after PATH refresh." -ForegroundColor Red
            Write-Host "This may happen if Python was just installed in the same session." -ForegroundColor Yellow
            Write-Host "Python packages installation will be skipped for now." -ForegroundColor Yellow
            Write-Host "You can install packages manually later or restart your terminal." -ForegroundColor Yellow
            exit 0  # Don't fail the installation
        }
    }
    
    Write-Host "Python is available. Checking pip..." -ForegroundColor Green
    
    # Check if pip is available
    if (-not (Test-PipAvailable)) {
        Write-Host "pip not found. Refreshing environment..." -ForegroundColor Yellow
        Update-SessionPath
        Start-Sleep -Seconds 2
        
        if (-not (Test-PipAvailable)) {
            Write-Host "pip is still not available. This may indicate an incomplete Python installation." -ForegroundColor Red
            Write-Host "Please ensure Python was installed with pip included." -ForegroundColor Yellow
            exit 1
        }
    }
    
    # Get Python and pip version info
    try {
        $pythonVersion = python --version 2>&1
        $pipVersion = pip --version 2>&1
        Write-Host "Python: $pythonVersion" -ForegroundColor Gray
        Write-Host "pip: $pipVersion" -ForegroundColor Gray
    } catch {
        Write-Host "Could not retrieve Python/pip version information" -ForegroundColor Gray
    }
    
    # Upgrade pip first
    Write-Host "Upgrading pip to latest version..." -ForegroundColor Cyan
    try {
        pip install --upgrade pip --no-warn-script-location 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  + pip upgraded successfully" -ForegroundColor Green
        } else {
            Write-Host "  ! pip upgrade failed, continuing anyway" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  ! pip upgrade error, continuing anyway" -ForegroundColor Yellow
    }
    
    # Define essential Python packages for basic usage
    $essentialPackages = @(
        @{ Package = "pip"; Display = "pip (Package Installer)" },
        @{ Package = "setuptools"; Display = "setuptools (Package Development)" },
        @{ Package = "wheel"; Display = "wheel (Binary Package Format)" },
        @{ Package = "requests"; Display = "requests (HTTP Library)" },
        @{ Package = "urllib3"; Display = "urllib3 (HTTP Client)" },
        @{ Package = "certifi"; Display = "certifi (SSL Certificates)" },
        @{ Package = "six"; Display = "six (Python 2/3 Compatibility)" },
        @{ Package = "python-dateutil"; Display = "dateutil (Date/Time Utilities)" },
        @{ Package = "pytz"; Display = "pytz (Timezone Support)" },
        @{ Package = "packaging"; Display = "packaging (Core Packaging Utilities)" },
        @{ Package = "lxml"; Display = "lxml (XML/HTML Parsing)" },
        @{ Package = "PyYAML"; Display = "PyYAML (YAML Files)" },
        @{ Package = "pillow"; Display = "pillow (Image Processing)" },
        @{ Package = "pywin32"; Display = "pywin32 (Windows COM Interface - may need post-install)" }
    )
    
    # Additional useful packages
    $usefulPackages = @(
        @{ Package = "pandas"; Display = "pandas (Data Analysis)" },
        @{ Package = "numpy"; Display = "numpy (Numerical Computing)" },
        @{ Package = "matplotlib"; Display = "matplotlib (Plotting)" },
        @{ Package = "openpyxl"; Display = "openpyxl (Excel Files)" },
        @{ Package = "jupyter"; Display = "jupyter (Interactive Notebooks)" },
        @{ Package = "ipython"; Display = "ipython (Enhanced Python Shell)" },
        @{ Package = "scipy"; Display = "scipy (Scientific Computing)" },
        @{ Package = "seaborn"; Display = "seaborn (Statistical Plotting)" },
        @{ Package = "scikit-learn"; Display = "scikit-learn (Machine Learning)" },
        @{ Package = "matplotlib"; Display = "matplotlib (Plotting)" },
        @{ Package = "plotly"; Display = "plotly (Interactive Plots)" },
        @{ Package = "tqdm"; Display = "tqdm (Progress Bars)" },
        @{ Package = "pytest"; Display = "pytest (Testing Framework)" },
        @{ Package = "virtualenv"; Display = "virtualenv (Virtual Environments)" }
    )
    
    # Track installation results
    $successCount = 0
    $failureCount = 0
    $allPackages = $essentialPackages + $usefulPackages
    $totalPackages = $allPackages.Count
    
    Write-Host "Installing $totalPackages essential Python packages..." -ForegroundColor Yellow
    Write-Host "This may take several minutes depending on internet speed..." -ForegroundColor Gray
    Write-Host ""
    
    # Install essential packages first
    Write-Host "Installing core packages..." -ForegroundColor Cyan
    foreach ($pkg in $essentialPackages) {
        if (Install-PythonPackage -PackageName $pkg.Package -DisplayName $pkg.Display) {
            $successCount++
        } else {
            $failureCount++
        }
    }
    
    Write-Host ""
    Write-Host "Installing data science packages..." -ForegroundColor Cyan
    foreach ($pkg in $usefulPackages) {
        if (Install-PythonPackage -PackageName $pkg.Package -DisplayName $pkg.Display) {
            $successCount++
        } else {
            $failureCount++
        }
    }
    
    # Summary
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host "PYTHON BASIC PACKAGES INSTALLATION SUMMARY" -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor Cyan
    
    Write-Host "Total packages: $totalPackages" -ForegroundColor Gray
    Write-Host "Successfully installed: $successCount" -ForegroundColor Green
    Write-Host "Failed: $failureCount" -ForegroundColor $(if ($failureCount -gt 0) { "Red" } else { "Gray" })
    
    # Test key packages
    Write-Host ""
    Write-Host "Testing key package imports..." -ForegroundColor Cyan
    
    $testPackages = @("requests", "pandas", "numpy", "matplotlib")
    $importSuccesses = 0
    
    foreach ($testPkg in $testPackages) {
        if (Test-PythonPackage -PackageName $testPkg) {
            Write-Host "  + $testPkg imports successfully" -ForegroundColor Green
            $importSuccesses++
        } else {
            Write-Host "  - $testPkg import failed" -ForegroundColor Red
        }
    }
    
    # Check Jupyter installation
    Write-Host ""
    Write-Host "Checking Jupyter installation..." -ForegroundColor Cyan
    try {
        $jupyterVersion = jupyter --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  + Jupyter is available" -ForegroundColor Green
        } else {
            Write-Host "  - Jupyter may not be properly installed" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  - Jupyter installation test failed" -ForegroundColor Red
    }
    
    # List installed packages
    Write-Host ""
    Write-Host "Checking pip package list..." -ForegroundColor Cyan
    try {
        $packageCount = (pip list 2>$null | Measure-Object -Line).Lines
        if ($packageCount -gt 0) {
            Write-Host "  + Total pip packages installed: $packageCount" -ForegroundColor Green
        }
    } catch {
        Write-Host "  ! Could not retrieve package list" -ForegroundColor Yellow
    }
    
    # Final status
    if ($successCount -eq $totalPackages -and $importSuccesses -eq $testPackages.Count) {
        Write-Host ""
        Write-Host "All essential Python packages installed and working!" -ForegroundColor Green
        Write-Host "Python environment is ready for data science work." -ForegroundColor Green
        exit 0
    } elseif ($successCount -gt ($totalPackages * 0.7)) {
        Write-Host ""
        Write-Host "Most essential Python packages installed successfully." -ForegroundColor Yellow
        Write-Host "Some packages failed but core Python functionality should work." -ForegroundColor Yellow
        exit 0
    } else {
        Write-Host ""
        Write-Host "Multiple Python package installations failed." -ForegroundColor Red
        Write-Host "Python environment may not be fully functional." -ForegroundColor Red
        
        Write-Host ""
        Write-Host "Common solutions:" -ForegroundColor Yellow
        Write-Host "1. Ensure internet connectivity for package downloads" -ForegroundColor Yellow
        Write-Host "2. Update pip: python -m pip install --upgrade pip" -ForegroundColor Yellow
        Write-Host "3. Try installing packages manually: pip install pandas numpy matplotlib" -ForegroundColor Yellow
        Write-Host "4. Check for Python installation issues" -ForegroundColor Yellow
        
        # Don't fail completely - some packages might still work
        exit 0
    }
    
} catch {
    Write-Host "ERROR: Unexpected error during Python package installation." -ForegroundColor Red
    Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "You can try installing packages manually:" -ForegroundColor Yellow
    Write-Host "pip install pandas numpy matplotlib requests openpyxl jupyter" -ForegroundColor Cyan
    exit 1
}