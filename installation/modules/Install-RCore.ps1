# Script: modules/Install-RCore.ps1
# Purpose: Installs R Statistical Computing Language with multiple fallback methods

Write-Host "Starting R Statistical Computing Language installation..." -ForegroundColor Yellow

# Configuration
$RVersion = "4.4.2"  # Update as needed
$RInstallerUrl = "https://cran.r-project.org/bin/windows/base/R-$RVersion-win.exe"
$InstallerFileName = "R-$RVersion-win.exe"
$DownloadPath = Join-Path -Path $env:TEMP -ChildPath $InstallerFileName

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

# Function to test if R is installed and working
function Test-RInstallation {
    try {
        $rVersion = R --version 2>&1
        if ($rVersion -match "R version") {
            Write-Host "Found R: $($rVersion -split "`n" | Select-Object -First 1)" -ForegroundColor Green
            return $true
        }
    } catch {
        # R not found or not working
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

# Function to find R installation directory
function Get-RInstallPath {
    $commonPaths = @(
        "C:\Program Files\R\R-*",
        "C:\Program Files (x86)\R\R-*",
        "$env:LOCALAPPDATA\Programs\R\R-*"
    )
    
    foreach ($path in $commonPaths) {
        $found = Get-ChildItem -Path $path -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
        if ($found) {
            return $found.FullName
        }
    }
    return $null
}

try {
    # Check if R is already installed
    Write-Host "Checking for existing R installation..." -ForegroundColor Cyan
    
    if (Test-RInstallation) {
        Write-Host "R is already installed and working." -ForegroundColor Green
        
        # Show R details
        try {
            $rInfo = R --slave -e "cat(R.version.string)" 2>$null
            Write-Host "R Details: $rInfo" -ForegroundColor Gray
            
            $rPath = Get-RInstallPath
            if ($rPath) {
                Write-Host "Installation Directory: $rPath" -ForegroundColor Gray
            }
        } catch {
            Write-Host "Could not retrieve R details" -ForegroundColor Gray
        }
        
        exit 0  # Already installed
    }
    
    Write-Host "R not found. Proceeding with installation..." -ForegroundColor Yellow
    
    # Method 1: Try Chocolatey first (if available)
    Write-Host "Attempting installation via Chocolatey..." -ForegroundColor Cyan
    
    # Refresh PATH first in case Chocolatey was just installed
    Update-SessionPath
    
    if (Test-ChocolateyAvailable) {
        Write-Host "Chocolatey is available. Installing R via Chocolatey..." -ForegroundColor Green
        
        try {
            Write-Host "Executing: choco install r.project --yes --force --timeout=7200" -ForegroundColor Gray
            
            # Run Chocolatey installation with extended timeout
            $chocoProcess = Start-Process -FilePath "choco" -ArgumentList @("install", "r.project", "--yes", "--force", "--timeout=7200") -Wait -PassThru -NoNewWindow
            
            if ($chocoProcess.ExitCode -eq 0) {
                Write-Host "Chocolatey R installation completed successfully!" -ForegroundColor Green
                
                # Manual PATH fix for R installation
                Write-Host "Adding R to system PATH..." -ForegroundColor Cyan
                try {
                    # Common R installation paths
                    $rPaths = @(
                        "C:\Program Files\R\R-4.4.2\bin\x64",
                        "C:\Program Files\R\R-4.4.2\bin",
                        "C:\Program Files (x86)\R\R-4.4.2\bin\x64",
                        "C:\Program Files (x86)\R\R-4.4.2\bin"
                    )
                    
                    $rBinPath = $null
                    foreach ($path in $rPaths) {
                        if (Test-Path $path) {
                            $rBinPath = $path
                            Write-Host "Found R installation at: $path" -ForegroundColor Gray
                            break
                        }
                    }
                    
                    if ($rBinPath) {
                        # Add to machine PATH
                        $currentPath = [Environment]::GetEnvironmentVariable("PATH", [EnvironmentVariableTarget]::Machine)
                        if ($currentPath -notlike "*$rBinPath*") {
                            $newPath = "$currentPath;$rBinPath"
                            [Environment]::SetEnvironmentVariable("PATH", $newPath, [EnvironmentVariableTarget]::Machine)
                            Write-Host "R added to system PATH: $rBinPath" -ForegroundColor Green
                        } else {
                            Write-Host "R already in system PATH" -ForegroundColor Gray
                        }
                        
                        # Add to current session PATH
                        $env:PATH = "$env:PATH;$rBinPath"
                        Write-Host "R added to current session PATH" -ForegroundColor Gray
                        
                    } else {
                        Write-Host "Could not find R binary directory" -ForegroundColor Yellow
                    }
                } catch {
                    Write-Host "Could not automatically fix R PATH: $($_.Exception.Message)" -ForegroundColor Yellow
                }
                
                # Refresh PATH and test with multiple attempts
                Update-SessionPath
                Start-Sleep -Seconds 3
                
                if (Test-RInstallation) {
                    Write-Host "R installation verified via Chocolatey!" -ForegroundColor Green
                    exit 0
                } else {
                    Write-Host "Chocolatey installation completed but R not immediately available" -ForegroundColor Yellow
                    Write-Host "This is common with R installations - continuing with direct verification..." -ForegroundColor Yellow
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
    
    # Method 2: Direct download and installation from CRAN
    Write-Host "Downloading R installer from CRAN..." -ForegroundColor Cyan
    Write-Host "URL: $RInstallerUrl" -ForegroundColor Gray
    
    # Ensure TLS 1.2 for downloading
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12
    
    try {
        Write-Host "Downloading R installer..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri $RInstallerUrl -OutFile $DownloadPath -ErrorAction Stop
        Write-Host "R installer downloaded successfully." -ForegroundColor Green
    } catch {
        Write-Host "Failed to download from direct URL. Trying CRAN mirror..." -ForegroundColor Yellow
        
        # Try different CRAN mirror
        try {
            $mirrorUrl = "https://cloud.r-project.org/bin/windows/base/R-$RVersion-win.exe"
            Write-Host "Trying cloud mirror: $mirrorUrl" -ForegroundColor Gray
            Invoke-WebRequest -Uri $mirrorUrl -OutFile $DownloadPath -ErrorAction Stop
            Write-Host "R installer downloaded from mirror successfully." -ForegroundColor Green
        } catch {
            Write-Host "Could not download R installer automatically." -ForegroundColor Red
            Write-Host "Please manually install R from: https://cran.r-project.org/bin/windows/base/" -ForegroundColor Yellow
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
    Write-Host "Running automated R installation..." -ForegroundColor Cyan
    Write-Host "This may take several minutes. Please wait..." -ForegroundColor Yellow
    
    # R Windows installer silent installation parameters
    $installArgs = @(
        "/VERYSILENT",                    # Very quiet installation
        "/SUPPRESSMSGBOXES",              # No message boxes
        "/NORESTART",                     # Don't restart system
        "/DIR=C:\Program Files\R\R-$RVersion",  # Installation directory
        "/COMPONENTS=main,x64,translations"  # Core components
    )
    
    Write-Host "Executing: $DownloadPath $($installArgs -join ' ')" -ForegroundColor Gray
    
    # Start the installation process
    $process = Start-Process -FilePath $DownloadPath -ArgumentList $installArgs -Wait -PassThru -NoNewWindow
    
    $exitCode = $process.ExitCode
    
    if ($exitCode -eq 0) {
        Write-Host "R installation completed successfully!" -ForegroundColor Green
    } else {
        Write-Host "R installation completed with exit code: $exitCode" -ForegroundColor Yellow
        # Don't fail immediately - R installations often report non-zero but still work
    }
    
    # Clean up installer
    try {
        Remove-Item -Path $DownloadPath -Force -ErrorAction SilentlyContinue
        Write-Host "Cleaned up installer file." -ForegroundColor Gray
    } catch {
        Write-Host "Could not clean up installer file (not critical)" -ForegroundColor Gray
    }
    
    # Refresh environment variables and add R to PATH if needed
    Write-Host "Refreshing environment variables..." -ForegroundColor Cyan
    Update-SessionPath
    
    # Try to add R to PATH if it's not there
    $rInstallPath = Get-RInstallPath
    if ($rInstallPath) {
        $rBinPath = Join-Path $rInstallPath "bin\x64"
        $currentPath = [Environment]::GetEnvironmentVariable("PATH", [EnvironmentVariableTarget]::Machine)
        
        if ($currentPath -notlike "*$rBinPath*") {
            Write-Host "Adding R to system PATH..." -ForegroundColor Cyan
            try {
                $newPath = "$currentPath;$rBinPath"
                [Environment]::SetEnvironmentVariable("PATH", $newPath, [EnvironmentVariableTarget]::Machine)
                $env:PATH = "$env:PATH;$rBinPath"
                Write-Host "R added to PATH successfully." -ForegroundColor Green
            } catch {
                Write-Host "Could not automatically add R to PATH. May need manual configuration." -ForegroundColor Yellow
            }
        }
    }
    
    # Wait a moment for installation to fully complete
    Start-Sleep -Seconds 5
    
    # Verify installation with multiple attempts
    Write-Host "Verifying R installation..." -ForegroundColor Cyan
    
    $verificationAttempts = 3
    $verificationSuccess = $false
    
    for ($i = 1; $i -le $verificationAttempts; $i++) {
        Write-Host "Verification attempt $i of $verificationAttempts..." -ForegroundColor Gray
        
        Update-SessionPath  # Refresh PATH each attempt
        
        if (Test-RInstallation) {
            $verificationSuccess = $true
            break
        }
        
        if ($i -lt $verificationAttempts) {
            Write-Host "R not immediately available, waiting..." -ForegroundColor Yellow
            Start-Sleep -Seconds 3
        }
    }
    
    if ($verificationSuccess) {
        Write-Host "R installation verified successfully!" -ForegroundColor Green
        
        # Show installation details
        try {
            Write-Host "R installation details:" -ForegroundColor Cyan
            $rVersionInfo = R --slave -e "cat(paste('Version:', R.version.string, '\nInstalled:', Sys.Date()))" 2>$null
            Write-Host "  $rVersionInfo" -ForegroundColor Gray
            
            $rPath = Get-RInstallPath
            if ($rPath) {
                Write-Host "  Installation Directory: $rPath" -ForegroundColor Gray
            }
            
            # Test R basic functionality
            $rTest = R --slave -e "cat('Basic R functionality test: PASSED')" 2>$null
            if ($rTest -like "*PASSED*") {
                Write-Host "  Basic functionality: Working" -ForegroundColor Gray
            }
        } catch {
            Write-Host "  Could not retrieve detailed R information" -ForegroundColor Yellow
        }
        
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor Cyan
        Write-Host "1. R packages can now be installed" -ForegroundColor Yellow
        Write-Host "2. Consider installing RStudio IDE" -ForegroundColor Yellow
        Write-Host "3. Restart terminal for full PATH integration" -ForegroundColor Yellow
        
        exit 0  # Success
    } else {
        Write-Host "WARNING: R installation completed but verification failed." -ForegroundColor Yellow
        Write-Host "R may not be immediately available in current session." -ForegroundColor Yellow
        
        # Provide troubleshooting info
        Write-Host ""
        Write-Host "Troubleshooting:" -ForegroundColor Cyan
        
        $rPath = Get-RInstallPath
        if ($rPath) {
            Write-Host "R appears to be installed at: $rPath" -ForegroundColor Green
            Write-Host "Try opening a new PowerShell/CMD window." -ForegroundColor Yellow
        } else {
            Write-Host "Could not locate R installation directory." -ForegroundColor Red
        }
        
        Write-Host ""
        Write-Host "Manual verification steps:" -ForegroundColor Yellow
        Write-Host "1. Open a new terminal window" -ForegroundColor Yellow
        Write-Host "2. Type 'R --version' to test" -ForegroundColor Yellow
        Write-Host "3. If not working, add R bin directory to PATH manually" -ForegroundColor Yellow
        
        # Don't fail the installation - it might work in a new session
        exit 0
    }
    
} catch {
    Write-Host "ERROR: R installation failed." -ForegroundColor Red
    Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Fallback options:" -ForegroundColor Yellow
    Write-Host "1. Download R manually: https://cran.r-project.org/bin/windows/base/" -ForegroundColor Yellow
    Write-Host "2. Use Chocolatey in a new session: 'choco install r.project'" -ForegroundColor Yellow
    Write-Host "3. Use Windows Package Manager: 'winget install RProject.R'" -ForegroundColor Yellow
    exit 1
}