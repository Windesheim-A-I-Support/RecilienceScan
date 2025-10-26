# modules/Install-QuartoCLI.ps1
# Comprehensive Quarto CLI installer with all available methods
# (module-safe: no 'exit', sets $LASTEXITCODE, uses Write-Log if available)

$ErrorActionPreference = 'Stop'
$LASTEXITCODE = 1
$moduleLog = $null

# --- Logger shim (use Main-Installer Write-Log if available) -----------------
function _log {
    param([string]$Message, [ValidateSet('INFO','SUCCESS','WARNING','ERROR')]$Level = 'INFO')
    if (Get-Command -Name Write-Log -ErrorAction SilentlyContinue) {
        Write-Log -Message $Message -Level $Level
    } else {
        $fc = switch ($Level) { "SUCCESS" { "Green" } "WARNING" { "Yellow" } "ERROR" { "Red" } default { "Gray" } }
        Write-Host "[$Level] $Message" -ForegroundColor $fc
    }
}

# --- Helper Functions --------------------------------------------------------
function Update-SessionPath {
    $systemPath = [Environment]::GetEnvironmentVariable("PATH", 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable("PATH", 'User')
    
    # Combine existing paths
    $candidates = @($systemPath, $userPath) -join ';'
    
    # Add common Quarto installation paths
    $commonPaths = @(
        "$env:ProgramFiles\Quarto\bin",
        "$env:LOCALAPPDATA\Programs\Quarto\bin",
        "$env:USERPROFILE\scoop\apps\quarto\current\bin",
        "C:\ProgramData\chocolatey\lib\quarto\tools\quarto\bin",
        "$env:USERPROFILE\miniconda3\Scripts",
        "$env:USERPROFILE\anaconda3\Scripts"
    ) | Where-Object { Test-Path $_ -ErrorAction SilentlyContinue }
    
    $env:PATH = @($candidates; $commonPaths) -join ';'
}

function Test-QuartoWorking {
    try {
        Update-SessionPath
        $version = (& quarto --version) 2>$null
        if ($LASTEXITCODE -eq 0 -and $version -match '\d+\.\d+(\.\d+)?') {
            $cleanVersion = ($version -split '\r?\n')[0].Trim()
            return ,@($true, $cleanVersion)
        }
    } catch {}
    return ,@($false, $null)
}

function With-PolicyBypass([scriptblock]$Script) {
    $orig = Get-ExecutionPolicy -Scope Process -ErrorAction SilentlyContinue
    try {
        Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction SilentlyContinue
        & $Script
    } finally {
        if ($orig) { Set-ExecutionPolicy -Scope Process -ExecutionPolicy $orig -Force -ErrorAction SilentlyContinue }
    }
}

function Start-ModuleTranscript {
    try {
        $dir = Join-Path $env:TEMP "quarto-install"
        if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
        $script:moduleLog = Join-Path $dir ("module-quarto-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))
        Start-Transcript -Path $script:moduleLog -Force | Out-Null
    } catch {}
}

function Stop-ModuleTranscript { 
    try { Stop-Transcript | Out-Null } catch {} 
}

function Get-Architecture {
    if ([Environment]::Is64BitOperatingSystem) {
        if ((Get-CimInstance Win32_Processor).Name -match 'ARM') { return 'arm64' }
        else { return 'x64' }
    } else { 
        return 'x86' 
    }
}

# --- Installation Methods ---------------------------------------------------

function Install-QuartoViaWinget {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { 
        return ,@($false, $null, $null) 
    }
    
    _log "Method 1: Winget (recommended)..." "INFO"
    try {
        winget source update 2>$null | Out-Null
        
        $isElevated = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        $args = @('install', '--id', 'Posit.Quarto', '-e', '--accept-package-agreements', '--accept-source-agreements', '--silent')
        if ($isElevated) { $args += @('--scope', 'machine') }
        
        $process = Start-Process winget -ArgumentList $args -WindowStyle Hidden -Wait -PassThru
        if ($process.ExitCode -eq 0) {
            Start-Sleep 3
            $ok, $ver = Test-QuartoWorking
            if ($ok) { return ,@($true, "Winget", $ver) }
            _log "Winget reported success, but Quarto not on PATH yet (may need shell restart)" "WARNING"
        } else {
            _log "Winget returned exit code $($process.ExitCode)" "WARNING"
        }
    } catch { 
        _log "Winget installation failed: $($_.Exception.Message)" "WARNING" 
    }
    return ,@($false, $null, $null)
}

function Install-QuartoViaScoop {
    _log "Method 2: Scoop (developer-friendly)..." "INFO"
    $ok = $false
    
    With-PolicyBypass {
        # Install Scoop if not present
        if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
            _log "Installing Scoop first..." "INFO"
            try {
                Invoke-RestMethod -UseBasicParsing get.scoop.sh | Invoke-Expression
                Update-SessionPath
                Start-Sleep 2
            } catch {
                _log "Failed to install Scoop: $($_.Exception.Message)" "WARNING"
                return ,@($false, $null, $null)
            }
        }
        
        if (Get-Command scoop -ErrorAction SilentlyContinue) {
            try {
                scoop bucket add main 2>$null | Out-Null
                scoop update 2>$null | Out-Null
                _log "Installing Quarto via Scoop..." "INFO"
                scoop install quarto 2>$null | Out-Null
                
                $ok, $ver = Test-QuartoWorking
                if ($ok) { return ,@($true, "Scoop", $ver) }
            } catch {
                _log "Scoop installation failed: $($_.Exception.Message)" "WARNING"
            }
        }
    }
    return ,@($false, $null, $null)
}

function Install-QuartoViaConda {
    if (-not (Get-Command conda -ErrorAction SilentlyContinue)) { 
        # Try mamba as fallback
        if (-not (Get-Command mamba -ErrorAction SilentlyContinue)) {
            return ,@($false, $null, $null)
        }
        $condaCmd = "mamba"
    } else {
        $condaCmd = "conda"
    }
    
    _log "Method 3: $condaCmd (data science environments)..." "INFO"
    try {
        _log "Installing Quarto via $condaCmd..." "INFO"
        $process = Start-Process $condaCmd -ArgumentList @('install', '-c', 'conda-forge', 'quarto', '--yes', '--quiet') -WindowStyle Hidden -Wait -PassThru
        
        if ($process.ExitCode -eq 0) {
            Start-Sleep 2
            Update-SessionPath
            $ok, $ver = Test-QuartoWorking
            if ($ok) { return ,@($true, "Conda/$condaCmd", $ver) }
        } else {
            _log "$condaCmd returned exit code $($process.ExitCode)" "WARNING"
        }
    } catch { 
        _log "$condaCmd installation failed: $($_.Exception.Message)" "WARNING" 
    }
    return ,@($false, $null, $null)
}

function Install-QuartoViaChocolatey {
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) { 
        return ,@($false, $null, $null) 
    }
    
    _log "Method 4: Chocolatey (enterprise-friendly)..." "INFO"
    
    # Clean up known Chocolatey Quarto issues
    try {
        Get-Process | Where-Object {$_.ProcessName -like "*choco*"} | Stop-Process -Force -ErrorAction SilentlyContinue
        $problemPaths = @(
            "C:\ProgramData\chocolatey\lib\ee6bce875b9b8971dd4aa65ea780cfa34a6f2e1e",
            "C:\ProgramData\chocolatey\lib\quarto*",
            "C:\ProgramData\chocolatey\lib-bad"
        )
        foreach ($path in $problemPaths) { 
            Get-ChildItem $path -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue 
        }
        choco cache clear --force 2>&1 | Out-Null
    } catch {}
    
    try {
        _log "Installing Quarto via Chocolatey..." "INFO"
        choco install quarto --yes --force --no-progress 2>$null | Out-Null
        
        $ok, $ver = Test-QuartoWorking
        if ($ok) { return ,@($true, "Chocolatey", $ver) }
    } catch { 
        _log "Chocolatey installation failed: $($_.Exception.Message)" "WARNING" 
    }
    return ,@($false, $null, $null)
}

function Install-QuartoViaGitHubAPI {
    _log "Method 5: GitHub API (latest release)..." "INFO"
    try {
        $api = "https://api.github.com/repos/quarto-dev/quarto-cli/releases/latest"
        $release = Invoke-RestMethod -Uri $api -UseBasicParsing
        
        $arch = Get-Architecture
        $assetPattern = if ($arch -eq 'arm64') { "*win*arm64.msi" } else { "*win*.msi" }
        $asset = $release.assets | Where-Object { $_.name -like $assetPattern } | Select-Object -First 1
        
        if (-not $asset) {
            _log "No suitable MSI found for architecture $arch" "WARNING"
            return ,@($false, $null, $null)
        }
        
        $msiPath = Join-Path $env:TEMP $asset.name
        _log "Downloading $($asset.name)..." "INFO"
        
        if (Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue) {
            Start-BitsTransfer -Source $asset.browser_download_url -Destination $msiPath -ErrorAction Stop
        } else {
            Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $msiPath -UseBasicParsing -ErrorAction Stop
        }
        
        $process = Start-Process msiexec.exe -ArgumentList @('/i', "`"$msiPath`"", '/qn', '/norestart', 'ALLUSERS=1') -Wait -PassThru
        if ($process.ExitCode -eq 0) {
            Start-Sleep 3
            $ok, $ver = Test-QuartoWorking
            if ($ok) { return ,@($true, "GitHub API", $ver) }
            _log "MSI installation succeeded but Quarto not on PATH yet" "WARNING"
        } else {
            _log "MSI installation returned exit code $($process.ExitCode)" "WARNING"
        }
    } catch { 
        _log "GitHub API installation failed: $($_.Exception.Message)" "WARNING" 
    }
    return ,@($false, $null, $null)
}

function Install-QuartoViaPortable {
    _log "Method 6: Portable ZIP (no admin required)..." "INFO"
    
    $portableDir = "$env:LOCALAPPDATA\Programs\Quarto"
    $zipPath = Join-Path $env:TEMP "quarto-portable.zip"
    
    try {
        # Try to get the latest portable release
        $zipUrl = "https://github.com/quarto-dev/quarto-cli/releases/latest/download/quarto-win.zip"
        
        _log "Downloading portable Quarto..." "INFO"
        if (Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue) {
            Start-BitsTransfer -Source $zipUrl -Destination $zipPath -ErrorAction Stop
        } else {
            Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing -ErrorAction Stop
        }
        
        # Remove existing installation if present
        if (Test-Path $portableDir) {
            Remove-Item -Path $portableDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        
        _log "Extracting portable Quarto..." "INFO"
        Expand-Archive -Path $zipPath -DestinationPath $portableDir -Force
        
        # Update PATH to include portable installation
        Update-SessionPath
        $ok, $ver = Test-QuartoWorking
        if ($ok) { return ,@($true, "Portable", $ver) }
        
    } catch { 
        _log "Portable installation failed: $($_.Exception.Message)" "WARNING" 
    }
    return ,@($false, $null, $null)
}

function Install-QuartoViaMSI {
    _log "Method 7: Official MSI (fallback)..." "INFO"
    
    $arch = Get-Architecture
    $base = "https://quarto.org/download/latest"
    $msiUrl = if ($arch -eq 'arm64') { "$base/quarto-win-arm64.msi" } else { "$base/quarto-win.msi" }
    
    $downloadDir = Join-Path $env:TEMP "quarto-install"
    if (!(Test-Path $downloadDir)) { New-Item -ItemType Directory -Path $downloadDir | Out-Null }
    $msiPath = Join-Path $downloadDir ("quarto-latest-{0}.msi" -f $arch)
    
    try {
        _log "Downloading official MSI for $arch..." "INFO"
        if (Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue) {
            Start-BitsTransfer -Source $msiUrl -Destination $msiPath -RetryInterval 2 -ErrorAction Stop
        } else {
            Invoke-WebRequest -Uri $msiUrl -OutFile $msiPath -UseBasicParsing -ErrorAction Stop
        }
        
        $process = Start-Process msiexec.exe -ArgumentList @('/i', "`"$msiPath`"", '/qn', '/norestart', 'ALLUSERS=1') -Wait -PassThru
        if ($process.ExitCode -eq 0) {
            Start-Sleep 3
            $ok, $ver = Test-QuartoWorking
            if ($ok) { return ,@($true, "MSI", $ver) }
            _log "MSI installation succeeded but Quarto not on PATH yet (may need shell restart)" "WARNING"
        } else {
            _log "MSI installation returned exit code $($process.ExitCode)" "WARNING"
        }
    } catch { 
        _log "MSI installation failed: $($_.Exception.Message)" "WARNING" 
    }
    return ,@($false, $null, $null)
}

# --- Main Installation Logic ------------------------------------------------
Start-ModuleTranscript

try {
    _log "=== Quarto CLI Comprehensive Installation ===" "INFO"
    _log "Architecture: $(Get-Architecture)" "INFO"
    
    # Check for existing installation
    _log "Checking for existing Quarto installation..." "INFO"
    $ok, $ver = Test-QuartoWorking
    if ($ok -and -not $Global:ForceReinstallFlag) {
        _log "Quarto already installed and working: $ver" "SUCCESS"
        _log "Use -ForceReinstall flag to override existing installation" "INFO"
        $Global:QuartoInstall = [pscustomobject]@{ Success=$true; Method="Existing"; Version=$ver; Log=$moduleLog }
        $LASTEXITCODE = 0
        return
    }
    
    if ($Global:ForceReinstallFlag) {
        _log "ForceReinstall flag detected - proceeding with fresh installation" "WARNING"
    }
    
    # Try all installation methods in order of preference
    $installMethods = @(
        'Install-QuartoViaWinget',        # Most reliable for general users
        'Install-QuartoViaScoop',         # Great for developers
        'Install-QuartoViaConda',         # Important for data science users
        'Install-QuartoViaChocolatey',    # Good for enterprise
        'Install-QuartoViaGitHubAPI',     # More reliable than hardcoded URLs
        'Install-QuartoViaPortable',      # No admin rights needed
        'Install-QuartoViaMSI'            # Last resort fallback
    )
    
    foreach ($method in $installMethods) {
        try {
            _log "Attempting installation method: $method" "INFO"
            $result = & $method
            $success, $methodName, $version = $result
            
            if ($success) {
                _log "SUCCESS: Quarto installed via $methodName" "SUCCESS"
                _log "Version: $version" "SUCCESS"
                
                # Verify installation works
                $verifyOk, $verifyVer = Test-QuartoWorking
                if ($verifyOk) {
                    $Global:QuartoInstall = [pscustomobject]@{ 
                        Success = $true
                        Method = $methodName
                        Version = $verifyVer
                        Log = $moduleLog 
                    }
                    $LASTEXITCODE = 0
                    return
                } else {
                    _log "WARNING: Installation reported success but verification failed" "WARNING"
                }
            } else {
                _log "$method did not succeed, trying next method..." "INFO"
            }
        } catch {
            _log "ERROR in $method : $($_.Exception.Message)" "WARNING"
        }
    }
    
    # All methods failed
    _log "All automated installation methods failed" "ERROR"
    _log "Manual installation required:" "ERROR"
    _log "1. Visit: https://quarto.org/docs/get-started/" "ERROR"
    _log "2. Download and run the installer for your system" "ERROR"
    _log "3. Restart your PowerShell session after installation" "ERROR"
    
    $Global:QuartoInstall = [pscustomobject]@{ 
        Success = $false
        Method = $null
        Version = $null
        Log = $moduleLog 
    }
    $LASTEXITCODE = 1
    
} catch {
    _log "Unexpected error during Quarto installation: $($_.Exception.Message)" "ERROR"
    $Global:QuartoInstall = [pscustomobject]@{ 
        Success = $false
        Method = "Exception"
        Version = $null
        Log = $moduleLog 
    }
    $LASTEXITCODE = 1
    
} finally {
    Stop-ModuleTranscript
    if ($moduleLog) { 
        _log "Installation log saved to: $moduleLog" "INFO" 
    }
    
    # Final status report
    if ($Global:QuartoInstall.Success) {
        _log "=== INSTALLATION SUCCESSFUL ===" "SUCCESS"
        _log "Method: $($Global:QuartoInstall.Method)" "SUCCESS"  
        _log "Version: $($Global:QuartoInstall.Version)" "SUCCESS"
    } else {
        _log "=== INSTALLATION FAILED ===" "ERROR"
        _log "All automated methods were unsuccessful" "ERROR"
    }
}