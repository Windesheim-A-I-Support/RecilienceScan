# Script: modules/Install-Rtools.ps1
# Purpose: Installs Rtools for R package development on Windows (simplified approach)

Write-Host "Installing Rtools for R package development..." -ForegroundColor Yellow

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

# Function to test if Rtools is installed and working
function Test-RtoolsInstallation {
    try {
        # Method 1: Check if make command is available (primary indicator)
        if (Get-Command make -ErrorAction SilentlyContinue) {
            Write-Host "Found make command in PATH" -ForegroundColor Green
            return $true
        }
        
        # Method 2: Check common Rtools installation paths
        $rtoolsPaths = @(
            "C:\rtools45\usr\bin\make.exe",
            "C:\rtools44\usr\bin\make.exe", 
            "C:\rtools43\usr\bin\make.exe",
            "C:\rtools42\usr\bin\make.exe"
        )
        
        foreach ($path in $rtoolsPaths) {
            if (Test-Path $path) {
                Write-Host "Found Rtools installation: $(Split-Path (Split-Path $path))" -ForegroundColor Green
                return $true
            }
        }
        
        # Method 3: Test via R if available
        if (Get-Command R -ErrorAction SilentlyContinue) {
            try {
                $rtoolsTest = R --slave -e "cat(ifelse(require('pkgbuild', quietly=TRUE) && pkgbuild::has_rtools(debug=FALSE), 'TRUE', 'FALSE'))" 2>$null
                if ($rtoolsTest -eq "TRUE") {
                    Write-Host "R confirms Rtools is available" -ForegroundColor Green
                    return $true
                }
            } catch {
                # R test failed, not critical
            }
        }
        
    } catch {
        # All tests failed
    }
    return $false
}

try {
    # Check if Rtools is already installed
    Write-Host "Checking for existing Rtools installation..." -ForegroundColor Cyan
    
    if (Test-RtoolsInstallation) {
        Write-Host "Rtools is already installed and working." -ForegroundColor Green
        exit 0
    }
    
    Write-Host "Rtools not found. Proceeding with installation..." -ForegroundColor Yellow
    
    # Method 1: Chocolatey (most reliable)
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Host "Installing Rtools via Chocolatey..." -ForegroundColor Cyan
        try {
            choco install rtools --yes --force
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Chocolatey Rtools installation completed" -ForegroundColor Green
                Update-SessionPath
                Start-Sleep -Seconds 3
                
                if (Test-RtoolsInstallation) {
                    Write-Host "Rtools installation verified via Chocolatey!" -ForegroundColor Green
                    exit 0
                }
            }
        } catch {
            Write-Host "Chocolatey installation failed: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    
    # Method 2: Winget
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "Installing Rtools via Winget..." -ForegroundColor Cyan
        try {
            winget install RProject.Rtools --accept-package-agreements --accept-source-agreements
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Winget Rtools installation completed" -ForegroundColor Green
                Update-SessionPath
                Start-Sleep -Seconds 3
                
                if (Test-RtoolsInstallation) {
                    Write-Host "Rtools installation verified via Winget!" -ForegroundColor Green
                    exit 0
                }
            }
        } catch {
            Write-Host "Winget installation failed: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    
    # No package managers worked
    Write-Host "Package manager installation failed." -ForegroundColor Red
    Write-Host ""
    Write-Host "Manual installation required:" -ForegroundColor Yellow
    Write-Host "1. Visit: https://cran.r-project.org/bin/windows/Rtools/" -ForegroundColor Yellow
    Write-Host "2. Download the Rtools installer for your R version" -ForegroundColor Yellow
    Write-Host "3. Run the installer with default settings" -ForegroundColor Yellow
    Write-Host "4. Rtools will be automatically detected by R" -ForegroundColor Yellow
    
    exit 1
    
} catch {
    Write-Host "ERROR: Rtools installation failed." -ForegroundColor Red
    Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Manual installation options:" -ForegroundColor Yellow
    Write-Host "1. Download from: https://cran.r-project.org/bin/windows/Rtools/" -ForegroundColor Yellow
    Write-Host "2. Install via Chocolatey: choco install rtools" -ForegroundColor Yellow
    Write-Host "3. Install via Winget: winget install RProject.Rtools" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Rtools is only needed for building R packages from source." -ForegroundColor Gray
    Write-Host "Most users can install pre-built packages without Rtools." -ForegroundColor Gray
    exit 1
}