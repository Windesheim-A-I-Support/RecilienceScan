# Script: modules/Test-WingetAvailability.ps1
# Purpose: Tests availability of Windows Package Manager (winget)

Write-Host "Testing Windows Package Manager (winget) availability..." -ForegroundColor Yellow

# Function to test if winget is available and working
function Test-WingetInstallation {
    try {
        $wingetVersion = winget --version 2>&1
        if ($wingetVersion -and $wingetVersion -notlike "*not recognized*" -and $wingetVersion -notlike "*error*") {
            Write-Host "Found winget: $wingetVersion" -ForegroundColor Green
            return $true
        }
    } catch {
        # winget not found or not working
    }
    return $false
}

# Function to check Windows version for winget compatibility
function Test-WingetCompatibility {
    $windowsVersion = [System.Environment]::OSVersion.Version
    $buildNumber = (Get-CimInstance -ClassName Win32_OperatingSystem).BuildNumber
    
    # winget requires Windows 10 version 1809 (build 17763) or later
    if ($windowsVersion.Major -ge 10 -and [int]$buildNumber -ge 17763) {
        return $true
    }
    return $false
}

try {
    # Check if winget is already available
    Write-Host "Checking for winget command..." -ForegroundColor Cyan
    
    if (Test-WingetInstallation) {
        Write-Host "Windows Package Manager (winget) is available and working." -ForegroundColor Green
        
        # Get winget info
        try {
            Write-Host "Winget details:" -ForegroundColor Cyan
            $wingetVersion = winget --version
            Write-Host "  Version: $wingetVersion" -ForegroundColor Gray
            
            # Test basic functionality
            $wingetInfo = winget --info 2>$null
            if ($wingetInfo) {
                Write-Host "  Status: Fully functional" -ForegroundColor Gray
            }
            
            # Check for common sources
            $sources = winget source list 2>$null
            if ($sources) {
                Write-Host "  Sources: Available" -ForegroundColor Gray
            }
            
        } catch {
            Write-Host "  Could not retrieve detailed winget information" -ForegroundColor Yellow
        }
        
        exit 0  # Available and working
    }
    
    Write-Host "winget command not found. Checking system compatibility..." -ForegroundColor Yellow
    
    # Check Windows version compatibility
    Write-Host "Checking Windows version compatibility..." -ForegroundColor Cyan
    
    if (-not (Test-WingetCompatibility)) {
        Write-Host "Windows version is not compatible with winget." -ForegroundColor Red
        Write-Host "winget requires Windows 10 version 1809 (build 17763) or later." -ForegroundColor Red
        
        $buildNumber = (Get-CimInstance -ClassName Win32_OperatingSystem).BuildNumber
        Write-Host "Current build: $buildNumber" -ForegroundColor Gray
        
        Write-Host "winget will not be available on this system." -ForegroundColor Yellow
        exit 0  # Not available but not an error
    }
    
    Write-Host "Windows version is compatible with winget." -ForegroundColor Green
    
    # Check if winget can be installed
    Write-Host "Checking winget installation options..." -ForegroundColor Cyan
    
    # Check for App Installer (winget comes with this)
    $appInstaller = Get-AppxPackage -Name "Microsoft.DesktopAppInstaller" -ErrorAction SilentlyContinue
    
    if ($appInstaller) {
        Write-Host "App Installer is installed but winget may need updating." -ForegroundColor Yellow
        Write-Host "App Installer version: $($appInstaller.Version)" -ForegroundColor Gray
        
        Write-Host ""
        Write-Host "To update winget:" -ForegroundColor Cyan
        Write-Host "1. Open Microsoft Store" -ForegroundColor Yellow
        Write-Host "2. Search for 'App Installer'" -ForegroundColor Yellow
        Write-Host "3. Click 'Update' if available" -ForegroundColor Yellow
        Write-Host "4. Or download from: https://aka.ms/getwinget" -ForegroundColor Yellow
        
    } else {
        Write-Host "App Installer not found." -ForegroundColor Yellow
        
        Write-Host ""
        Write-Host "To install winget:" -ForegroundColor Cyan
        Write-Host "1. Install from Microsoft Store: 'App Installer'" -ForegroundColor Yellow
        Write-Host "2. Or download from: https://aka.ms/getwinget" -ForegroundColor Yellow
        Write-Host "3. Or it may be available via Windows Update" -ForegroundColor Yellow
    }
    
    # Check for alternative package managers
    Write-Host ""
    Write-Host "Alternative package managers available:" -ForegroundColor Cyan
    
    $alternatives = @()
    
    # Check Chocolatey
    try {
        $chocoVersion = choco --version 2>$null
        if ($chocoVersion) {
            $alternatives += "Chocolatey (v$chocoVersion)"
            Write-Host "  + Chocolatey: Available" -ForegroundColor Green
        }
    } catch {
        Write-Host "  - Chocolatey: Not available" -ForegroundColor Gray
    }
    
    # Check Scoop
    try {
        $scoopVersion = scoop --version 2>$null
        if ($scoopVersion) {
            $alternatives += "Scoop (v$scoopVersion)"
            Write-Host "  + Scoop: Available" -ForegroundColor Green
        }
    } catch {
        Write-Host "  - Scoop: Not available" -ForegroundColor Gray
    }
    
    # Summary
    Write-Host ""
    Write-Host ("=" * 50) -ForegroundColor Cyan
    Write-Host "WINGET AVAILABILITY SUMMARY" -ForegroundColor Cyan
    Write-Host ("=" * 50) -ForegroundColor Cyan
    
    Write-Host "winget status: Not currently available" -ForegroundColor Yellow
    Write-Host "System compatibility: Compatible" -ForegroundColor Green
    
    if ($alternatives.Count -gt 0) {
        Write-Host "Alternative package managers: $($alternatives -join ', ')" -ForegroundColor Green
        Write-Host ""
        Write-Host "Installation can proceed using alternative package managers." -ForegroundColor Green
    } else {
        Write-Host "Alternative package managers: None detected" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Consider installing Chocolatey or Scoop for package management." -ForegroundColor Yellow
    }
    
    # Don't fail - winget is optional and alternatives exist
    exit 0
    
} catch {
    Write-Host "ERROR: Failed to check winget availability." -ForegroundColor Red
    Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "winget availability check is not critical for installation." -ForegroundColor Yellow
    Write-Host "Other package managers (Chocolatey, Scoop) can be used instead." -ForegroundColor Yellow
    
    # Don't fail the installation
    exit 0
}