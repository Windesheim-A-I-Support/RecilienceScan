# Script: modules/Install-Winget.ps1
# Purpose: Installs Windows Package Manager (winget) if not present

Write-Host "Installing Windows Package Manager (winget)..." -ForegroundColor Yellow

# Function to test if winget is installed and working
function Test-WingetInstallation {
    try {
        $wingetVersion = winget --version 2>&1
        if ($wingetVersion -and $wingetVersion -notlike "*not recognized*" -and $wingetVersion -match "v\d+\.\d+") {
            Write-Host "Found winget: $wingetVersion" -ForegroundColor Green
            return $true
        }
    } catch {
        # winget not found or not working
    }
    return $false
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

# Function to check Windows version compatibility
function Test-WingetCompatibility {
    $windowsVersion = [System.Environment]::OSVersion.Version
    $buildNumber = [int](Get-CimInstance -ClassName Win32_OperatingSystem).BuildNumber
    
    # winget requires Windows 10 version 1809 (build 17763) or later
    if ($windowsVersion.Major -ge 10 -and $buildNumber -ge 17763) {
        Write-Host "Windows version is compatible with winget (Build: $buildNumber)" -ForegroundColor Green
        return $true
    } else {
        Write-Host "Windows version is NOT compatible with winget (Build: $buildNumber, Required: 17763+)" -ForegroundColor Red
        return $false
    }
}

# Function to get latest winget release info
function Get-LatestWingetRelease {
    try {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12
        $latestRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/winget-cli/releases/latest" -ErrorAction Stop
        $msixAsset = $latestRelease.assets | Where-Object { $_.name -like "*.msixbundle" } | Select-Object -First 1
        
        if ($msixAsset) {
            return @{
                Version = $latestRelease.tag_name
                DownloadUrl = $msixAsset.browser_download_url
                FileName = $msixAsset.name
                Success = $true
            }
        }
    } catch {
        Write-Host "Could not fetch latest winget release info" -ForegroundColor Yellow
    }
    
    return @{ Success = $false }
}

try {
    # Check if winget is already installed
    Write-Host "Checking for existing winget installation..." -ForegroundColor Cyan
    
    if (Test-WingetInstallation) {
        Write-Host "winget is already installed and working." -ForegroundColor Green
        exit 0  # Already installed
    }
    
    # Check Windows version compatibility
    Write-Host "Checking Windows version compatibility..." -ForegroundColor Cyan
    if (-not (Test-WingetCompatibility)) {
        Write-Host "winget cannot be installed on this Windows version." -ForegroundColor Red
        Write-Host "winget requires Windows 10 version 1809 (build 17763) or later." -ForegroundColor Red
        exit 1
    }
    
    Write-Host "winget not found but system is compatible. Proceeding with installation..." -ForegroundColor Yellow
    
    # Method 1: Check if App Installer is present but winget is missing
    Write-Host "Checking App Installer status..." -ForegroundColor Cyan
    $appInstaller = Get-AppxPackage -Name "Microsoft.DesktopAppInstaller" -ErrorAction SilentlyContinue
    
    if ($appInstaller) {
        Write-Host "App Installer is present but winget not working. Attempting repair..." -ForegroundColor Yellow
        try {
            # Try to repair/reset App Installer
            Get-AppxPackage -Name "Microsoft.DesktopAppInstaller" | Reset-AppxPackage -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 5
            
            if (Test-WingetInstallation) {
                Write-Host "winget repaired successfully!" -ForegroundColor Green
                exit 0
            }
        } catch {
            Write-Host "App Installer repair failed" -ForegroundColor Yellow
        }
    }
    
    # Method 2: Install via Microsoft Store (if available)
    Write-Host "Attempting installation via Microsoft Store..." -ForegroundColor Cyan
    try {
        # Try to install App Installer from Microsoft Store
        Start-Process "ms-windows-store://pdp/?productid=9NBLGGH4NNS1" -ErrorAction Stop
        Write-Host "Microsoft Store opened for App Installer installation." -ForegroundColor Green
        Write-Host "Please install 'App Installer' from the Microsoft Store and run this script again." -ForegroundColor Yellow
        Write-Host "Waiting 30 seconds for potential installation..." -ForegroundColor Gray
        
        # Wait and check if installation happened
        Start-Sleep -Seconds 30
        Update-SessionPath
        
        if (Test-WingetInstallation) {
            Write-Host "winget installed successfully via Microsoft Store!" -ForegroundColor Green
            exit 0
        } else {
            Write-Host "Microsoft Store installation not completed or unsuccessful." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "Could not open Microsoft Store: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    # Method 3: Direct download and installation
    Write-Host "Attempting direct installation..." -ForegroundColor Cyan
    
    $releaseInfo = Get-LatestWingetRelease
    
    if ($releaseInfo.Success) {
        $downloadPath = Join-Path -Path $env:TEMP -ChildPath $releaseInfo.FileName
        
        Write-Host "Downloading winget $($releaseInfo.Version)..." -ForegroundColor Cyan
        Write-Host "URL: $($releaseInfo.DownloadUrl)" -ForegroundColor Gray
        
        try {
            Invoke-WebRequest -Uri $releaseInfo.DownloadUrl -OutFile $downloadPath -ErrorAction Stop
            Write-Host "Download completed successfully" -ForegroundColor Green
            
            # Install the msixbundle
            Write-Host "Installing winget package..." -ForegroundColor Cyan
            Add-AppxPackage -Path $downloadPath -ErrorAction Stop
            
            # Clean up download
            Remove-Item -Path $downloadPath -Force -ErrorAction SilentlyContinue
            
            # Refresh PATH and test
            Update-SessionPath
            Start-Sleep -Seconds 5
            
            if (Test-WingetInstallation) {
                Write-Host "winget installed successfully via direct download!" -ForegroundColor Green
                exit 0
            } else {
                Write-Host "Direct installation completed but winget not immediately available" -ForegroundColor Yellow
            }
            
        } catch {
            Write-Host "Direct installation failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    # All methods failed
    Write-Host ""
    Write-Host "All automated installation methods failed." -ForegroundColor Red
    Write-Host ""
    Write-Host "Manual installation options:" -ForegroundColor Yellow
    Write-Host "1. Install 'App Installer' from Microsoft Store:" -ForegroundColor Yellow
    Write-Host "   https://www.microsoft.com/store/productId/9NBLGGH4NNS1" -ForegroundColor Yellow
    Write-Host "2. Download winget manually from GitHub:" -ForegroundColor Yellow
    Write-Host "   https://github.com/microsoft/winget-cli/releases/latest" -ForegroundColor Yellow
    Write-Host "3. Enable Windows Update and wait for automatic installation" -ForegroundColor Yellow
    
    # Diagnostic information
    Write-Host ""
    Write-Host "System Information:" -ForegroundColor Cyan
    $buildNumber = (Get-CimInstance -ClassName Win32_OperatingSystem).BuildNumber
    $windowsVersion = [System.Environment]::OSVersion.Version
    Write-Host "- Windows Version: $($windowsVersion.Major).$($windowsVersion.Minor)" -ForegroundColor Gray
    Write-Host "- Build Number: $buildNumber" -ForegroundColor Gray
    Write-Host "- App Installer Present: $(if ($appInstaller) { 'Yes' } else { 'No' })" -ForegroundColor Gray
    Write-Host "- Administrator: $(([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))" -ForegroundColor Gray
    
    exit 1
    
} catch {
    Write-Host "ERROR: Unexpected error during winget installation." -ForegroundColor Red
    Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "winget installation failed. This may indicate:" -ForegroundColor Yellow
    Write-Host "1. Incompatible Windows version (requires Windows 10 1809+ or Windows 11)" -ForegroundColor Yellow
    Write-Host "2. Corporate environment restrictions" -ForegroundColor Yellow
    Write-Host "3. Microsoft Store access issues" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Alternative package managers:" -ForegroundColor Cyan
    Write-Host "- Chocolatey: https://chocolatey.org/install" -ForegroundColor Yellow
    Write-Host "- Scoop: https://scoop.sh" -ForegroundColor Yellow
    exit 1
}