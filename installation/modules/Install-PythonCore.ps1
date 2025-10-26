# Script: modules/Install-PythonCore.ps1
# Purpose: Automatically installs Python with silent installation parameters

Write-Host "Starting automated Python installation..." -ForegroundColor Yellow

# Configuration
$PythonVersion = "3.11.9"
$PythonInstallerUrl = "https://www.python.org/ftp/python/$PythonVersion/python-$PythonVersion-amd64.exe"
$InstallerFileName = "python-$PythonVersion-amd64.exe"
$DownloadPath = Join-Path -Path $env:TEMP -ChildPath $InstallerFileName

# Function to test if Python is installed and working
function Test-PythonInstallation {
    try {
        $pythonVersion = python --version 2>&1
        if ($pythonVersion -match "Python \d+\.\d+\.\d+") {
            Write-Host "Found Python: $pythonVersion" -ForegroundColor Green
            return $true
        }
    } catch {
        # Python not found or not working
    }
    return $false
}

try {
    # Check if Python is already installed
    Write-Host "Checking for existing Python installation..." -ForegroundColor Cyan
    
    if (Test-PythonInstallation) {
        Write-Host "Python is already installed and working." -ForegroundColor Green
        
        # Check pip as well
        try {
            $pipVersion = pip --version 2>&1
            Write-Host "Found pip: $pipVersion" -ForegroundColor Green
        } catch {
            Write-Host "Python found but pip may need attention" -ForegroundColor Yellow
        }
        
        exit 0  # Already installed
    }
    
    Write-Host "Python not found. Proceeding with automated installation..." -ForegroundColor Yellow
    
    # Download Python installer
    Write-Host "Downloading Python $PythonVersion installer..." -ForegroundColor Cyan
    Write-Host "URL: $PythonInstallerUrl" -ForegroundColor Gray
    # Script: modules/Install-PythonCore.ps1
# Purpose: Automatically installs Python with silent installation parameters

Write-Host "Starting automated Python installation..." -ForegroundColor Yellow

# Configuration
$PythonVersion = "3.11.9"
$PythonInstallerUrl = "https://www.python.org/ftp/python/$PythonVersion/python-$PythonVersion-amd64.exe"
$InstallerFileName = "python-$PythonVersion-amd64.exe"
$DownloadPath = Join-Path -Path $env:TEMP -ChildPath $InstallerFileName

# Function to test if Python is installed and working
function Test-PythonInstallation {
    try {
        $pythonVersion = python --version 2>&1
        if ($pythonVersion -match "Python \d+\.\d+\.\d+") {
            Write-Host "Found Python: $pythonVersion" -ForegroundColor Green
            return $true
        }
    } catch {
        # Python not found or not working
    }
    return $false
}

try {
    # Check if Python is already installed
    Write-Host "Checking for existing Python installation..." -ForegroundColor Cyan
    
    if (Test-PythonInstallation) {
        Write-Host "Python is already installed and working." -ForegroundColor Green
        
        # Check pip as well
        try {
            $pipVersion = pip --version 2>&1
            Write-Host "Found pip: $pipVersion" -ForegroundColor Green
        } catch {
            Write-Host "Python found but pip may need attention" -ForegroundColor Yellow
        }
        
        exit 0  # Already installed
    }
    
    Write-Host "Python not found. Proceeding with automated installation..." -ForegroundColor Yellow
    
    # Download Python installer
    Write-Host "Downloading Python $PythonVersion installer..." -ForegroundColor Cyan
    Write-Host "URL: $PythonInstallerUrl" -ForegroundColor Gray
    
    # Ensure TLS 1.2 for downloading
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12
    
    Invoke-WebRequest -Uri $PythonInstallerUrl -OutFile $DownloadPath -ErrorAction Stop
    Write-Host "Python installer downloaded successfully." -ForegroundColor Green
    
    # Verify download
    if (-not (Test-Path $DownloadPath)) {
        throw "Downloaded installer not found at $DownloadPath"
    }
    
    $fileSize = (Get-Item $DownloadPath).Length / 1MB
    Write-Host "Downloaded installer size: $([math]::Round($fileSize, 1)) MB" -ForegroundColor Gray
    
    # Run silent installation
    Write-Host "Running automated Python installation..." -ForegroundColor Cyan
    Write-Host "This may take several minutes. Please wait..." -ForegroundColor Yellow
    
    # Python installer silent installation parameters:
    # /quiet = Silent installation (no UI)
    # PrependPath=1 = Add Python to PATH (CRITICAL!)
    # Include_test=0 = Don't install test suite (saves space)
    # SimpleInstall=1 = Simple installation mode
    # InstallAllUsers=0 = Install for current user only
    # TargetDir = Custom installation directory (optional)
    
    $installArgs = @(
        "/quiet"                    # Silent installation
        "PrependPath=1"            # Add to PATH - CRITICAL!
        "Include_test=0"           # Skip test suite
        "SimpleInstall=1"          # Simple install
        "InstallAllUsers=0"        # Current user only
    )
    
    Write-Host "Executing: $DownloadPath $($installArgs -join ' ')" -ForegroundColor Gray
    
    # Start the installation process
    $process = Start-Process -FilePath $DownloadPath -ArgumentList $installArgs -Wait -PassThru -NoNewWindow
    
    $exitCode = $process.ExitCode
    
    if ($exitCode -eq 0) {
        Write-Host "Python installation completed successfully!" -ForegroundColor Green
    } else {
        Write-Host "Python installation completed with exit code: $exitCode" -ForegroundColor Yellow
        if ($exitCode -eq 1) {
            Write-Host "Exit code 1 typically means installation completed but with warnings" -ForegroundColor Yellow
        }
    }
    
    # Clean up installer
    try {
        Remove-Item -Path $DownloadPath -Force -ErrorAction SilentlyContinue
        Write-Host "Cleaned up installer file." -ForegroundColor Gray
    } catch {
        Write-Host "Could not clean up installer file (not critical)" -ForegroundColor Gray
    }
    
    # Refresh environment variables to pick up new PATH
    Write-Host "Refreshing environment variables..." -ForegroundColor Cyan
    
    # Update PATH for current session
    $systemPath = [Environment]::GetEnvironmentVariable("PATH", [EnvironmentVariableTarget]::Machine)
    $userPath = [Environment]::GetEnvironmentVariable("PATH", [EnvironmentVariableTarget]::User)
    
    if ($userPath) {
        $env:PATH = "$systemPath;$userPath"
    } else {
        $env:PATH = $systemPath
    }
    
    # Wait a moment for installation to fully complete
    Start-Sleep -Seconds 3
    
    # Verify installation
    Write-Host "Verifying Python installation..." -ForegroundColor Cyan
    
    if (Test-PythonInstallation) {
        Write-Host "Python installation verified successfully!" -ForegroundColor Green
        
        # Upgrade pip to latest version
        Write-Host "Upgrading pip to latest version..." -ForegroundColor Cyan
        try {
            Write-Host "Executing: python.exe -m pip install --upgrade pip" -ForegroundColor Gray
            python.exe -m pip install --upgrade pip
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "pip upgraded successfully" -ForegroundColor Green
                
                # Verify new pip version
                try {
                    $newPipVersion = pip --version 2>&1
                    Write-Host "New pip version: $newPipVersion" -ForegroundColor Green
                } catch {
                    Write-Host "Could not verify new pip version" -ForegroundColor Yellow
                }
            } else {
                Write-Host "pip upgrade failed with exit code: $LASTEXITCODE" -ForegroundColor Red
                Write-Host "Continuing with existing pip version..." -ForegroundColor Yellow
            }
        } catch {
            Write-Host "pip upgrade error: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "Continuing with existing pip version..." -ForegroundColor Yellow
        }
        
        # Test pip
        try {
            $pipVersion = pip --version 2>&1
            Write-Host "pip is working: $pipVersion" -ForegroundColor Green
        } catch {
            Write-Host "Python installed but pip may need attention" -ForegroundColor Yellow
        }
        
        # Show installation details
        try {
            Write-Host "Python installation details:" -ForegroundColor Cyan
            python -c "import sys; print(f'  Python version: {sys.version}'); print(f'  Executable: {sys.executable}'); print(f'  Platform: {sys.platform}')"
        } catch {
            Write-Host "  Could not retrieve detailed Python information" -ForegroundColor Yellow
        }
        
        exit 0  # Success
    } else {
        Write-Host "WARNING: Python installation completed but verification failed." -ForegroundColor Yellow
        Write-Host "Python may not be immediately available in current session." -ForegroundColor Yellow
        Write-Host "Try opening a new PowerShell/CMD window, or restart your terminal." -ForegroundColor Yellow
        
        # Don't fail the installation - it might work in a new session
        exit 0
    }
    
} catch {
    Write-Host "ERROR: Python installation failed." -ForegroundColor Red
    Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Fallback options:" -ForegroundColor Yellow
    Write-Host "1. Try installing Python manually from https://www.python.org/downloads/" -ForegroundColor Yellow
    Write-Host "2. Use Windows Store Python: 'ms-windows-store://pdp/?productid=9NRWMJP3717K'" -ForegroundColor Yellow
    Write-Host "3. Use Chocolatey: 'choco install python'" -ForegroundColor Yellow
    exit 1
}
    # Ensure TLS 1.2 for downloading
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12
    
    Invoke-WebRequest -Uri $PythonInstallerUrl -OutFile $DownloadPath -ErrorAction Stop
    Write-Host "Python installer downloaded successfully." -ForegroundColor Green
    
    # Verify download
    if (-not (Test-Path $DownloadPath)) {
        throw "Downloaded installer not found at $DownloadPath"
    }
    
    $fileSize = (Get-Item $DownloadPath).Length / 1MB
    Write-Host "Downloaded installer size: $([math]::Round($fileSize, 1)) MB" -ForegroundColor Gray
    
    # Run silent installation
    Write-Host "Running automated Python installation..." -ForegroundColor Cyan
    Write-Host "This may take several minutes. Please wait..." -ForegroundColor Yellow
    
    # Python installer silent installation parameters:
    # /quiet = Silent installation (no UI)
    # PrependPath=1 = Add Python to PATH (CRITICAL!)
    # Include_test=0 = Don't install test suite (saves space)
    # SimpleInstall=1 = Simple installation mode
    # InstallAllUsers=0 = Install for current user only
    # TargetDir = Custom installation directory (optional)
    
    $installArgs = @(
        "/quiet"                    # Silent installation
        "PrependPath=1"            # Add to PATH - CRITICAL!
        "Include_test=0"           # Skip test suite
        "SimpleInstall=1"          # Simple install
        "InstallAllUsers=0"        # Current user only
    )
    
    Write-Host "Executing: $DownloadPath $($installArgs -join ' ')" -ForegroundColor Gray
    
    # Start the installation process
    $process = Start-Process -FilePath $DownloadPath -ArgumentList $installArgs -Wait -PassThru -NoNewWindow
    
    $exitCode = $process.ExitCode
    
    if ($exitCode -eq 0) {
        Write-Host "Python installation completed successfully!" -ForegroundColor Green
    } else {
        Write-Host "Python installation completed with exit code: $exitCode" -ForegroundColor Yellow
        if ($exitCode -eq 1) {
            Write-Host "Exit code 1 typically means installation completed but with warnings" -ForegroundColor Yellow
        }
    }
    
    # Clean up installer
    try {
        Remove-Item -Path $DownloadPath -Force -ErrorAction SilentlyContinue
        Write-Host "Cleaned up installer file." -ForegroundColor Gray
    } catch {
        Write-Host "Could not clean up installer file (not critical)" -ForegroundColor Gray
    }
    
    # Refresh environment variables to pick up new PATH
    Write-Host "Refreshing environment variables..." -ForegroundColor Cyan
    
    # Update PATH for current session
    $systemPath = [Environment]::GetEnvironmentVariable("PATH", [EnvironmentVariableTarget]::Machine)
    $userPath = [Environment]::GetEnvironmentVariable("PATH", [EnvironmentVariableTarget]::User)
    
    if ($userPath) {
        $env:PATH = "$systemPath;$userPath"
    } else {
        $env:PATH = $systemPath
    }
    
    # Wait a moment for installation to fully complete
    Start-Sleep -Seconds 3
    
    # Verify installation
    Write-Host "Verifying Python installation..." -ForegroundColor Cyan
    
    if (Test-PythonInstallation) {
        Write-Host "Python installation verified successfully!" -ForegroundColor Green
        
        # Test pip
        try {
            $pipVersion = pip --version 2>&1
            Write-Host "pip is also working: $pipVersion" -ForegroundColor Green
        } catch {
            Write-Host "Python installed but pip may need attention" -ForegroundColor Yellow
        }
        
        # Show installation details
        try {
            Write-Host "Python installation details:" -ForegroundColor Cyan
            python -c "import sys; print(f'  Python version: {sys.version}'); print(f'  Executable: {sys.executable}'); print(f'  Platform: {sys.platform}')"
        } catch {
            Write-Host "  Could not retrieve detailed Python information" -ForegroundColor Yellow
        }
        
        exit 0  # Success
    } else {
        Write-Host "WARNING: Python installation completed but verification failed." -ForegroundColor Yellow
        Write-Host "Python may not be immediately available in current session." -ForegroundColor Yellow
        Write-Host "Try opening a new PowerShell/CMD window, or restart your terminal." -ForegroundColor Yellow
        
        # Don't fail the installation - it might work in a new session
        exit 0
    }
    
} catch {
    Write-Host "ERROR: Python installation failed." -ForegroundColor Red
    Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Fallback options:" -ForegroundColor Yellow
    Write-Host "1. Try installing Python manually from https://www.python.org/downloads/" -ForegroundColor Yellow
    Write-Host "2. Use Windows Store Python: 'ms-windows-store://pdp/?productid=9NRWMJP3717K'" -ForegroundColor Yellow
    Write-Host "3. Use Chocolatey: 'choco install python'" -ForegroundColor Yellow
    exit 1
}