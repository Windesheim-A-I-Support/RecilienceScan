# modules/Install-PortableApps.ps1
# Install PortableApps platform for portable application management
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
    
    # Add PortableApps paths
    $portablePaths = @(
        "$env:USERPROFILE\PortableApps\PortableApps.com",
        "$env:LOCALAPPDATA\PortableApps\PortableApps.com",
        "D:\PortableApps\PortableApps.com",
        "E:\PortableApps\PortableApps.com"
    ) | Where-Object { Test-Path "$_\PortableAppsPlatform.exe" -ErrorAction SilentlyContinue }
    
    if ($portablePaths) {
        $env:PATH = @($env:PATH; $portablePaths) -join ';'
    }
}

function Test-PortableAppsWorking {
    try {
        Update-SessionPath
        
        # Look for PortableApps Platform executable
        $platformPaths = @(
            "$env:USERPROFILE\PortableApps\PortableApps.com\PortableAppsPlatform.exe",
            "$env:LOCALAPPDATA\PortableApps\PortableApps.com\PortableAppsPlatform.exe",
            "D:\PortableApps\PortableApps.com\PortableAppsPlatform.exe",
            "E:\PortableApps\PortableApps.com\PortableAppsPlatform.exe"
        )
        
        foreach ($path in $platformPaths) {
            if (Test-Path $path -ErrorAction SilentlyContinue) {
                $version = (Get-Item $path).VersionInfo.FileVersion
                return ,@($true, $version, $path)
            }
        }
    } catch {}
    return ,@($false, $null, $null)
}

function Start-ModuleTranscript {
    try {
        $dir = Join-Path $env:TEMP "portable-apps-install"
        if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
        $script:moduleLog = Join-Path $dir ("portable-apps-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))
        Start-Transcript -Path $script:moduleLog -Force | Out-Null
    } catch {}
}

function Stop-ModuleTranscript { 
    try { Stop-Transcript | Out-Null } catch {} 
}

# --- Installation Methods ---------------------------------------------------

function Install-PortableAppsViaScoop {
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) { 
        return ,@($false, $null, $null) 
    }
    
    _log "Method 1: Installing PortableApps via Scoop..." "INFO"
    try {
        scoop bucket add extras 2>$null | Out-Null
        scoop install portableapps-platform 2>$null | Out-Null
        
        Start-Sleep 2
        $ok, $ver, $path = Test-PortableAppsWorking
        if ($ok) { return ,@($true, "Scoop", $ver) }
    } catch { 
        _log "Scoop installation failed: $($_.Exception.Message)" "WARNING" 
    }
    return ,@($false, $null, $null)
}

function Install-PortableAppsViaChocolatey {
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) { 
        return ,@($false, $null, $null) 
    }
    
    _log "Method 2: Installing PortableApps via Chocolatey..." "INFO"
    try {
        choco install portableapps --yes --no-progress 2>$null | Out-Null
        Start-Sleep 2
        $ok, $ver, $path = Test-PortableAppsWorking
        if ($ok) { return ,@($true, "Chocolatey", $ver) }
    } catch { 
        _log "Chocolatey installation failed: $($_.Exception.Message)" "WARNING" 
    }
    return ,@($false, $null, $null)
}

function Install-PortableAppsViaDirectDownload {
    _log "Method 3: Installing PortableApps via direct download..." "INFO"
    
    $downloadUrl = "https://portableapps.com/downloading/?app=platform&portable_file=PortableApps.com_Platform_Setup_15.1.paf.exe"
    $downloadDir = Join-Path $env:TEMP "portable-apps-install"
    if (!(Test-Path $downloadDir)) { New-Item -ItemType Directory -Path $downloadDir | Out-Null }
    $installerPath = Join-Path $downloadDir "PortableAppsPlatformSetup.exe"
    
    try {
        _log "Downloading PortableApps Platform..." "INFO"
        if (Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue) {
            Start-BitsTransfer -Source $downloadUrl -Destination $installerPath -ErrorAction Stop
        } else {
            Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -UseBasicParsing -ErrorAction Stop
        }
        
        # Install to user profile by default
        $installPath = "$env:USERPROFILE\PortableApps"
        
        _log "Installing PortableApps Platform to $installPath..." "INFO"
        $process = Start-Process $installerPath -ArgumentList @("/S", "/D=$installPath") -Wait -PassThru
        
        if ($process.ExitCode -eq 0) {
            Start-Sleep 3
            $ok, $ver, $path = Test-PortableAppsWorking
            if ($ok) { 
                Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
                return ,@($true, "Direct Download", $ver) 
            }
        } else {
            _log "PortableApps installer returned exit code $($process.ExitCode)" "WARNING"
        }
    } catch { 
        _log "Direct download installation failed: $($_.Exception.Message)" "WARNING" 
    }
    return ,@($false, $null, $null)
}

function Install-PortableAppsViaZip {
    _log "Method 4: Installing PortableApps via ZIP extraction..." "INFO"
    
    $zipUrl = "https://portableapps.com/downloading/?app=platform&portable_file=PortableApps.com_Platform_15.1.zip"
    $downloadDir = Join-Path $env:TEMP "portable-apps-install"
    if (!(Test-Path $downloadDir)) { New-Item -ItemType Directory -Path $downloadDir | Out-Null }
    $zipPath = Join-Path $downloadDir "PortableAppsPlatform.zip"
    $installPath = "$env:USERPROFILE\PortableApps"
    
    try {
        _log "Downloading PortableApps Platform ZIP..." "INFO"
        if (Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue) {
            Start-BitsTransfer -Source $zipUrl -Destination $zipPath -ErrorAction Stop
        } else {
            Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing -ErrorAction Stop
        }
        
        if (Test-Path $installPath) {
            Remove-Item $installPath -Recurse -Force -ErrorAction SilentlyContinue
        }
        
        _log "Extracting PortableApps Platform to $installPath..." "INFO"
        Expand-Archive -Path $zipPath -DestinationPath $installPath -Force
        
        Start-Sleep 2
        $ok, $ver, $path = Test-PortableAppsWorking
        if ($ok) { 
            Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
            return ,@($true, "ZIP Extract", $ver) 
        }
    } catch { 
        _log "ZIP installation failed: $($_.Exception.Message)" "WARNING" 
    }
    return ,@($false, $null, $null)
}

# --- Main Installation Logic ------------------------------------------------
Start-ModuleTranscript

try {
    _log "=== PortableApps Platform Installation ===" "INFO"
    
    # Check for existing installation
    _log "Checking for existing PortableApps installation..." "INFO"
    $ok, $ver, $path = Test-PortableAppsWorking
    if ($ok -and -not $Global:ForceReinstallFlag) {
        _log "PortableApps Platform already installed: $ver" "SUCCESS"
        _log "Location: $path" "SUCCESS"
        $Global:PortableAppsInstall = [pscustomobject]@{ Success=$true; Method="Existing"; Version=$ver; Path=$path; Log=$moduleLog }
        $LASTEXITCODE = 0
        return
    }
    
    if ($Global:ForceReinstallFlag) {
        _log "ForceReinstall flag detected - proceeding with installation" "WARNING"
    }
    
    # Try installation methods
    $installMethods = @(
        'Install-PortableAppsViaScoop',
        'Install-PortableAppsViaChocolatey',
        'Install-PortableAppsViaDirectDownload',
        'Install-PortableAppsViaZip'
    )
    
    foreach ($method in $installMethods) {
        try {
            _log "Attempting: $method" "INFO"
            $result = & $method
            $success, $methodName, $version = $result
            
            if ($success) {
                _log "SUCCESS: PortableApps installed via $methodName" "SUCCESS"
                _log "Version: $version" "SUCCESS"
                
                # Get the installation path
                $ok, $ver, $installPath = Test-PortableAppsWorking
                
                _log "PortableApps Platform is ready for use" "SUCCESS"
                _log "You can now install portable applications through the platform" "INFO"
                
                $Global:PortableAppsInstall = [pscustomobject]@{ 
                    Success = $true
                    Method = $methodName
                    Version = $version
                    Path = $installPath
                    Log = $moduleLog 
                }
                $LASTEXITCODE = 0
                return
            }
        } catch {
            _log "ERROR in $method : $($_.Exception.Message)" "WARNING"
        }
    }
    
    _log "All PortableApps installation methods failed" "ERROR"
    _log "Manual installation: https://portableapps.com/download" "ERROR"
    
    $Global:PortableAppsInstall = [pscustomobject]@{ 
        Success = $false
        Method = $null
        Version = $null
        Path = $null
        Log = $moduleLog 
    }
    $LASTEXITCODE = 1
    
} catch {
    _log "Unexpected error: $($_.Exception.Message)" "ERROR"
    $Global:PortableAppsInstall = [pscustomobject]@{ 
        Success = $false
        Method = "Exception"
        Version = $null
        Path = $null
        Log = $moduleLog 
    }
    $LASTEXITCODE = 1
    
} finally {
    Stop-ModuleTranscript
    
    if ($Global:PortableAppsInstall.Success) {
        _log "=== PORTABLEAPPS INSTALLATION SUCCESSFUL ===" "SUCCESS"
        _log "Platform ready for portable application management" "INFO"
    } else {
        _log "=== PORTABLEAPPS INSTALLATION FAILED ===" "ERROR"
    }
}