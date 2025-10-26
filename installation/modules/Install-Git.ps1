# Script: modules/Install-Git.ps1
# Purpose: Automatically installs Git with multiple fallback methods

Write-Host "Starting automated Git installation..." -ForegroundColor Yellow

# Configuration
$GitForWindowsVersion = "2.47.0"  # Update as needed
$GitInstallerUrl = "https://github.com/git-for-windows/git/releases/download/v$GitForWindowsVersion.windows.1/Git-$GitForWindowsVersion-64-bit.exe"
$InstallerFileName = "Git-$GitForWindowsVersion-64-bit.exe"
$DownloadPath = Join-Path -Path $env:TEMP -ChildPath $InstallerFileName

# Function to test if Git is installed and working
function Test-GitInstallation {
    try {
        $gitVersion = git --version 2>&1
        if ($gitVersion -match "git version") {
            Write-Host "Found Git: $gitVersion" -ForegroundColor Green
            return $true
        }
    } catch {
        # Git not found or not working
    }
    return $false
}

# Function to test if Chocolatey is available
function Test-ChocolateyAvailable {
    try {
        $chocoVersion = choco --version 2>$null
        return $chocoVersion -ne $null
    } catch {
        return $false
    }
}

# Function to refresh PATH
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
    # Check if Git is already installed
    Write-Host "Checking for existing Git installation..." -ForegroundColor Cyan
    
    if (Test-GitInstallation) {
        Write-Host "Git is already installed and working." -ForegroundColor Green
        exit 0  # Already installed
    }
    
    Write-Host "Git not found. Proceeding with installation..." -ForegroundColor Yellow
    
    # Method 1: Try Chocolatey first (if available)
    Write-Host "Attempting installation via Chocolatey..." -ForegroundColor Cyan
    
    # Refresh PATH first in case Chocolatey was just installed
    Update-SessionPath
    
    if (Test-ChocolateyAvailable) {
        Write-Host "Chocolatey is available. Installing Git via Chocolatey..." -ForegroundColor Green
        
        try {
            Write-Host "Executing: choco install git.install -params ""/GitAndUnixToolsOnPath"" --yes --force" -ForegroundColor Gray
            
            # Run Chocolatey installation
            $chocoProcess = Start-Process -FilePath "choco" -ArgumentList @("install", "git.install", "-params", '"/GitAndUnixToolsOnPath"', "--yes", "--force", "--timeout=3600") -Wait -PassThru -NoNewWindow
            
            if ($chocoProcess.ExitCode -eq 0) {
                Write-Host "Chocolatey Git installation completed successfully!" -ForegroundColor Green
                
                # Refresh PATH and test
                Update-SessionPath
                Start-Sleep -Seconds 2
                
                if (Test-GitInstallation) {
                    Write-Host "Git installation verified via Chocolatey!" -ForegroundColor Green
                    exit 0
                } else {
                    Write-Host "Chocolatey installation completed but Git not immediately available" -ForegroundColor Yellow
                    Write-Host "Trying direct installation method..." -ForegroundColor Yellow
                }
            } else {
                Write-Host "Chocolatey installation failed with exit code: $($chocoProcess.ExitCode)" -ForegroundColor Yellow
                Write-Host "Trying direct installation method..." -ForegroundColor Yellow
            }
        } catch {
            Write-Host "Chocolatey installation encountered an error: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host "Trying direct installation method..." -ForegroundColor Yellow
        }
    } else {
        Write-Host "Chocolatey not available. Using direct installation method..." -ForegroundColor Yellow
    }
    
    # Method 2: Direct download and installation from Git for Windows
    Write-Host "Downloading Git for Windows installer..." -ForegroundColor Cyan
    Write-Host "URL: $GitInstallerUrl" -ForegroundColor Gray
    
    # Ensure TLS 1.2 for downloading
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12
    
    try {
        Invoke-WebRequest -Uri $GitInstallerUrl -OutFile $DownloadPath -ErrorAction Stop
        Write-Host "Git installer downloaded successfully." -ForegroundColor Green
    } catch {
        Write-Host "Failed to download from official URL. Trying latest release..." -ForegroundColor Yellow
        
        # Fallback: Try to get latest release URL from GitHub API
        try {
            $latestRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/git-for-windows/git/releases/latest"
            $installerAsset = $latestRelease.assets | Where-Object { $_.name -like "*64-bit.exe" } | Select-Object -First 1
            
            if ($installerAsset) {
                Write-Host "Found latest release: $($installerAsset.name)" -ForegroundColor Green
                $DownloadPath = Join-Path -Path $env:TEMP -ChildPath $installerAsset.name
                Invoke-WebRequest -Uri $installerAsset.browser_download_url -OutFile $DownloadPath -ErrorAction Stop
                Write-Host "Latest Git installer downloaded successfully." -ForegroundColor Green
            } else {
                throw "Could not find suitable Git installer in latest release"
            }
        } catch {
            Write-Host "Could not download Git installer automatically." -ForegroundColor Red
            Write-Host "Please manually install Git from: https://git-scm.com/download/win" -ForegroundColor Yellow
            exit 1
        }
    }
    
    # Verify download
    if (-not (Test-Path $DownloadPath)) {
        Write-Host "Downloaded installer not found. Installation failed." -ForegroundColor Red
        exit 1
    }
    
    $fileSize = (Get-Item $DownloadPath).Length / 1MB
    Write-Host "Downloaded installer size: $([math]::Round($fileSize, 1)) MB" -ForegroundColor Gray
    
    # Run silent installation
    Write-Host "Running automated Git installation..." -ForegroundColor Cyan
    Write-Host "This may take several minutes. Please wait..." -ForegroundColor Yellow
    
    # Git for Windows silent installation parameters
    $installArgs = @(
        "/SILENT",                          # Silent installation
        "/COMPONENTS=icons,ext\shellhere,ext\guihere,gitlfs,assoc,assoc_sh", # Components
        "/o:PathOption=Cmd",               # Add Git to PATH for Command Prompt
        "/o:BashTerminalOption=ConHost",   # Use Windows' default console window
        "/o:EditorOption=Notepad",         # Use Notepad as default editor
        "/o:CRLFOption=CRLFAlways",        # Checkout Windows-style, commit Unix-style line endings
        "/o:BranchOption=BranchAskLater",  # Let Git decide on default branch name
        "/o:SSHOption=OpenSSH",            # Use bundled OpenSSH
        "/o:TortoiseOption=false",         # Don't install Tortoise integration
        "/o:CurlOption=WinSSL"             # Use Windows Secure Channel library
    )
    
    Write-Host "Executing: $DownloadPath $($installArgs -join ' ')" -ForegroundColor Gray
    
    # Start the installation process
    $process = Start-Process -FilePath $DownloadPath -ArgumentList $installArgs -Wait -PassThru -NoNewWindow
    
    $exitCode = $process.ExitCode
    
    if ($exitCode -eq 0) {
        Write-Host "Git installation completed successfully!" -ForegroundColor Green
    } else {
        Write-Host "Git installation completed with exit code: $exitCode" -ForegroundColor Yellow
    }
    
    # Clean up installer
    try {
        Remove-Item -Path $DownloadPath -Force -ErrorAction SilentlyContinue
        Write-Host "Cleaned up installer file." -ForegroundColor Gray
    } catch {
        Write-Host "Could not clean up installer file (not critical)" -ForegroundColor Gray
    }
    
    # Refresh environment variables
    Write-Host "Refreshing environment variables..." -ForegroundColor Cyan
    Update-SessionPath
    
    # Wait a moment for installation to fully complete
    Start-Sleep -Seconds 3
    
    # Verify installation
    Write-Host "Verifying Git installation..." -ForegroundColor Cyan
    
    if (Test-GitInstallation) {
        Write-Host "Git installation verified successfully!" -ForegroundColor Green
        
        # Show installation details
        try {
            Write-Host "Git installation details:" -ForegroundColor Cyan
            git --version | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
            
            $gitPath = (Get-Command git).Source
            Write-Host "  Executable: $gitPath" -ForegroundColor Gray
        } catch {
            Write-Host "  Could not retrieve detailed Git information" -ForegroundColor Yellow
        }
        
        exit 0  # Success
    } else {
        Write-Host "WARNING: Git installation completed but verification failed." -ForegroundColor Yellow
        Write-Host "Git may not be immediately available in current session." -ForegroundColor Yellow
        Write-Host "Try opening a new PowerShell/CMD window, or restart your terminal." -ForegroundColor Yellow
        
        # Don't fail the installation - it might work in a new session
        exit 0
    }
    
} catch {
    Write-Host "ERROR: Git installation failed." -ForegroundColor Red
    Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Fallback options:" -ForegroundColor Yellow
    Write-Host "1. Download Git for Windows manually: https://git-scm.com/download/win" -ForegroundColor Yellow
    Write-Host "2. Use Windows Store: 'winget install Git.Git'" -ForegroundColor Yellow
    Write-Host "3. Use Chocolatey in a new session: 'choco install git'" -ForegroundColor Yellow
    exit 1
}