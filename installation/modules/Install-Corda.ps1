# modules/Install-Conda.ps1
# Install Miniconda/Anaconda for Python package management
# (module-safe: no 'exit', sets $LASTEXITCODE, uses Write-Log if available)

$ErrorActionPreference = 'Stop'
$LASTEXITCODE = 1
$moduleLog = $null

# --- Logger shim ------------------------------------------------------------
function _log {
    param([string]$Message, [ValidateSet('INFO','SUCCESS','WARNING','ERROR')]$Level = 'INFO')
    if (Get-Command -Name Write-Log -ErrorAction SilentlyContinue) {
        Write-Log -Message $Message -Level $Level
    } else {
        $fc = switch ($Level) { "SUCCESS" { "Green" } "WARNING" { "Yellow" } "ERROR" { "Red" } default { "Gray" } }
        Write-Host "[$Level] $Message" -ForegroundColor $fc
    }
}

# --- Helper Functions -------------------------------------------------------
function Update-SessionPath {
    $systemPath = [Environment]::GetEnvironmentVariable("PATH", 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable("PATH", 'User')
    $env:PATH = @($systemPath, $userPath) -join ';'
    
    # Add common conda paths
    $condaPaths = @(
        "$env:USERPROFILE\miniconda3\Scripts",
        "$env:USERPROFILE\miniconda3\condabin",
        "$env:USERPROFILE\anaconda3\Scripts", 
        "$env:USERPROFILE\anaconda3\condabin",
        "$env:LOCALAPPDATA\Continuum\miniconda3\Scripts",
        "$env:LOCALAPPDATA\Continuum\anaconda3\Scripts"
    ) | Where-Object { Test-Path $_ -ErrorAction SilentlyContinue }
    
    if ($condaPaths) {
        $env:PATH = @($env:PATH; $condaPaths) -join ';'
    }
}

function Test-CondaWorking {
    try {
        Update-SessionPath
        $version = (& conda --version) 2>$null
        if ($LASTEXITCODE -eq 0 -and $version -match 'conda \d+\.\d+') {
            return ,@($true, $version.Trim())
        }
    } catch {}
    return ,@($false, $null)
}

function Get-Architecture {
    if ([Environment]::Is64BitOperatingSystem) {
        return 'x86_64'
    } else { 
        return 'x86'
    }
}

function Start-ModuleTranscript {
    try {
        $dir = Join-Path $env:TEMP "conda-install"
        if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
        $script:moduleLog = Join-Path $dir ("conda-install-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))
        Start-Transcript -Path $script:moduleLog -Force | Out-Null
    } catch {}
}

function Stop-ModuleTranscript { 
    try { Stop-Transcript | Out-Null } catch {} 
}

# --- Installation Methods ---------------------------------------------------

function Install-MinicondaViaWinget {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { 
        return ,@($false, $null, $null) 
    }
    
    _log "Method 1: Installing Miniconda via Winget..." "INFO"
    try {
        winget source update 2>$null | Out-Null
        $process = Start-Process winget -ArgumentList @('install', 'Anaconda.Miniconda3', '--silent', '--accept-package-agreements', '--accept-source-agreements') -WindowStyle Hidden -Wait -PassThru
        
        if ($process.ExitCode -eq 0) {
            Start-Sleep 3
            $ok, $ver = Test-CondaWorking
            if ($ok) { return ,@($true, "Winget", $ver) }
        }
    } catch { 
        _log "Winget installation failed: $($_.Exception.Message)" "WARNING" 
    }
    return ,@($false, $null, $null)
}

function Install-MinicondaViaChocolatey {
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) { 
        return ,@($false, $null, $null) 
    }
    
    _log "Method 2: Installing Miniconda via Chocolatey..." "INFO"
    try {
        choco install miniconda3 --yes --no-progress 2>$null | Out-Null
        Start-Sleep 3
        $ok, $ver = Test-CondaWorking
        if ($ok) { return ,@($true, "Chocolatey", $ver) }
    } catch { 
        _log "Chocolatey installation failed: $($_.Exception.Message)" "WARNING" 
    }
    return ,@($false, $null, $null)
}

function Install-MinicondaViaDirectDownload {
    _log "Method 3: Installing Miniconda via direct download..." "INFO"
    
    $arch = Get-Architecture
    $baseUrl = "https://repo.anaconda.com/miniconda"
    $installer = "Miniconda3-latest-Windows-$arch.exe"
    $downloadUrl = "$baseUrl/$installer"
    
    $downloadDir = Join-Path $env:TEMP "miniconda-install"
    if (!(Test-Path $downloadDir)) { New-Item -ItemType Directory -Path $downloadDir | Out-Null }
    $installerPath = Join-Path $downloadDir $installer
    
    try {
        _log "Downloading Miniconda installer ($arch)..." "INFO"
        if (Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue) {
            Start-BitsTransfer -Source $downloadUrl -Destination $installerPath -ErrorAction Stop
        } else {
            Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -UseBasicParsing -ErrorAction Stop
        }
        
        _log "Running Miniconda installer silently..." "INFO"
        $process = Start-Process $installerPath -ArgumentList @('/InstallationType=JustMe', '/RegisterPython=1', '/S') -Wait -PassThru
        
        if ($process.ExitCode -eq 0) {
            Start-Sleep 5
            $ok, $ver = Test-CondaWorking
            if ($ok) { 
                Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
                return ,@($true, "Direct Download", $ver) 
            }
        } else {
            _log "Miniconda installer returned exit code $($process.ExitCode)" "WARNING"
        }
    } catch { 
        _log "Direct download installation failed: $($_.Exception.Message)" "WARNING" 
    }
    return ,@($false, $null, $null)
}

# --- Main Installation Logic ------------------------------------------------
Start-ModuleTranscript

try {
    _log "=== Conda/Miniconda Installation ===" "INFO"
    _log "Architecture: $(Get-Architecture)" "INFO"
    
    # Check for existing installation
    _log "Checking for existing Conda installation..." "INFO"
    $ok, $ver = Test-CondaWorking
    if ($ok -and -not $Global:ForceReinstallFlag) {
        _log "Conda already installed: $ver" "SUCCESS"
        $Global:CondaInstall = [pscustomobject]@{ Success=$true; Method="Existing"; Version=$ver; Log=$moduleLog }
        $LASTEXITCODE = 0
        return
    }
    
    if ($Global:ForceReinstallFlag) {
        _log "ForceReinstall flag detected - proceeding with installation" "WARNING"
    }
    
    # Try installation methods
    $installMethods = @(
        'Install-MinicondaViaWinget',
        'Install-MinicondaViaChocolatey', 
        'Install-MinicondaViaDirectDownload'
    )
    
    foreach ($method in $installMethods) {
        try {
            _log "Attempting: $method" "INFO"
            $result = & $method
            $success, $methodName, $version = $result
            
            if ($success) {
                _log "SUCCESS: Conda installed via $methodName" "SUCCESS"
                _log "Version: $version" "SUCCESS"
                
                # Initialize conda
                _log "Initializing conda for PowerShell..." "INFO"
                try {
                    & conda init powershell 2>$null | Out-Null
                    _log "Conda initialized for PowerShell" "SUCCESS"
                } catch {
                    _log "Conda initialization failed (manual setup may be needed)" "WARNING"
                }
                
                $Global:CondaInstall = [pscustomobject]@{ 
                    Success = $true
                    Method = $methodName
                    Version = $version
                    Log = $moduleLog 
                }
                $LASTEXITCODE = 0
                return
            }
        } catch {
            _log "ERROR in $method : $($_.Exception.Message)" "WARNING"
        }
    }
    
    _log "All Conda installation methods failed" "ERROR"
    _log "Manual installation: https://docs.conda.io/en/latest/miniconda.html" "ERROR"
    
    $Global:CondaInstall = [pscustomobject]@{ 
        Success = $false
        Method = $null
        Version = $null
        Log = $moduleLog 
    }
    $LASTEXITCODE = 1
    
} catch {
    _log "Unexpected error: $($_.Exception.Message)" "ERROR"
    $Global:CondaInstall = [pscustomobject]@{ 
        Success = $false
        Method = "Exception"
        Version = $null
        Log = $moduleLog 
    }
    $LASTEXITCODE = 1
    
} finally {
    Stop-ModuleTranscript
    
    if ($Global:CondaInstall.Success) {
        _log "=== CONDA INSTALLATION SUCCESSFUL ===" "SUCCESS"
        _log "Restart PowerShell to use conda commands" "INFO"
    } else {
        _log "=== CONDA INSTALLATION FAILED ===" "ERROR"
    }
}