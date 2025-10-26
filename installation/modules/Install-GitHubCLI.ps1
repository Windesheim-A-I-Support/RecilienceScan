# modules/Install-GitHubCLI.ps1
# Install GitHub CLI and related development tools
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
    
    # Add common GitHub CLI paths
    $ghPaths = @(
        "$env:ProgramFiles\GitHub CLI",
        "$env:LOCALAPPDATA\Programs\GitHub CLI",
        "$env:USERPROFILE\scoop\shims",
        "$env:USERPROFILE\AppData\Local\GitHubCLI"
    ) | Where-Object { Test-Path $_ -ErrorAction SilentlyContinue }
    
    if ($ghPaths) {
        $env:PATH = @($env:PATH; $ghPaths) -join ';'
    }
}

function Test-GitHubCLIWorking {
    try {
        Update-SessionPath
        $version = (& gh --version) 2>$null
        if ($LASTEXITCODE -eq 0 -and $version -match 'gh version \d+\.\d+') {
            $cleanVersion = ($version -split '\n')[0] -replace 'gh version ', ''
            return ,@($true, $cleanVersion)
        }
    } catch {}
    return ,@($false, $null)
}

function Test-GitWorking {
    try {
        $version = (& git --version) 2>$null
        if ($LASTEXITCODE -eq 0 -and $version -match 'git version \d+\.\d+') {
            return ,@($true, $version.Trim())
        }
    } catch {}
    return ,@($false, $null)
}

function Start-ModuleTranscript {
    try {
        $dir = Join-Path $env:TEMP "github-cli-install"
        if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
        $script:moduleLog = Join-Path $dir ("github-cli-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))
        Start-Transcript -Path $script:moduleLog -Force | Out-Null
    } catch {}
}

function Stop-ModuleTranscript { 
    try { Stop-Transcript | Out-Null } catch {} 
}

# --- Installation Methods ---------------------------------------------------

function Install-GitHubCLIViaWinget {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { 
        return ,@($false, $null, $null) 
    }
    
    _log "Method 1: Installing GitHub CLI via Winget..." "INFO"
    try {
        winget source update 2>$null | Out-Null
        $process = Start-Process winget -ArgumentList @('install', 'GitHub.cli', '--silent', '--accept-package-agreements', '--accept-source-agreements') -WindowStyle Hidden -Wait -PassThru
        
        if ($process.ExitCode -eq 0) {
            Start-Sleep 3
            $ok, $ver = Test-GitHubCLIWorking
            if ($ok) { return ,@($true, "Winget", $ver) }
        }
    } catch { 
        _log "Winget installation failed: $($_.Exception.Message)" "WARNING" 
    }
    return ,@($false, $null, $null)
}

function Install-GitHubCLIViaScoop {
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) { 
        return ,@($false, $null, $null) 
    }
    
    _log "Method 2: Installing GitHub CLI via Scoop..." "INFO"
    try {
        scoop bucket add main 2>$null | Out-Null
        scoop install gh 2>$null | Out-Null
        
        Start-Sleep 2
        $ok, $ver = Test-GitHubCLIWorking
        if ($ok) { return ,@($true, "Scoop", $ver) }
    } catch { 
        _log "Scoop installation failed: $($_.Exception.Message)" "WARNING" 
    }
    return ,@($false, $null, $null)
}

function Install-GitHubCLIViaChocolatey {
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) { 
        return ,@($false, $null, $null) 
    }
    
    _log "Method 3: Installing GitHub CLI via Chocolatey..." "INFO"
    try {
        choco install gh --yes --no-progress 2>$null | Out-Null
        Start-Sleep 2
        $ok, $ver = Test-GitHubCLIWorking
        if ($ok) { return ,@($true, "Chocolatey", $ver) }
    } catch { 
        _log "Chocolatey installation failed: $($_.Exception.Message)" "WARNING" 
    }
    return ,@($false, $null, $null)
}

function Install-GitHubCLIViaGitHubReleases {
    _log "Method 4: Installing GitHub CLI via GitHub Releases..." "INFO"
    
    try {
        $api = "https://api.github.com/repos/cli/cli/releases/latest"
        $release = Invoke-RestMethod -Uri $api -UseBasicParsing -ErrorAction Stop
        
        # Find Windows MSI asset
        $asset = $release.assets | Where-Object { $_.name -like "*windows*amd64.msi" } | Select-Object -First 1
        if (-not $asset) {
            $asset = $release.assets | Where-Object { $_.name -like "*_windows_*.zip" } | Select-Object -First 1
        }
        
        if (-not $asset) {
            _log "No suitable Windows asset found in GitHub releases" "WARNING"
            return ,@($false, $null, $null)
        }
        
        $downloadDir = Join-Path $env:TEMP "github-cli-install"
        if (!(Test-Path $downloadDir)) { New-Item -ItemType Directory -Path $downloadDir | Out-Null }
        $downloadPath = Join-Path $downloadDir $asset.name
        
        _log "Downloading $($asset.name)..." "INFO"
        if (Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue) {
            Start-BitsTransfer -Source $asset.browser_download_url -Destination $downloadPath -ErrorAction Stop
        } else {
            Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $downloadPath -UseBasicParsing -ErrorAction Stop
        }
        
        if ($asset.name -like "*.msi") {
            # MSI installation
            $process = Start-Process msiexec.exe -ArgumentList @('/i', "`"$downloadPath`"", '/qn', '/norestart') -Wait -PassThru
            if ($process.ExitCode -eq 0) {
                Start-Sleep 3
                $ok, $ver = Test-GitHubCLIWorking
                if ($ok) { 
                    Remove-Item $downloadPath -Force -ErrorAction SilentlyContinue
                    return ,@($true, "GitHub Releases (MSI)", $ver) 
                }
            }
        } elseif ($asset.name -like "*.zip") {
            # ZIP extraction
            $extractPath = "$env:LOCALAPPDATA\Programs\GitHubCLI"
            if (Test-Path $extractPath) {
                Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue
            }
            
            Expand-Archive -Path $downloadPath -DestinationPath $extractPath -Force
            
            # Find the gh.exe in extracted contents
            $ghExe = Get-ChildItem -Path $extractPath -Name "gh.exe" -Recurse | Select-Object -First 1
            if ($ghExe) {
                $ghDir = Split-Path (Join-Path $extractPath $ghExe.FullName) -Parent
                $env:PATH = "$env:PATH;$ghDir"
                
                $ok, $ver = Test-GitHubCLIWorking
                if ($ok) { 
                    Remove-Item $downloadPath -Force -ErrorAction SilentlyContinue
                    return ,@($true, "GitHub Releases (ZIP)", $ver) 
                }
            }
        }
        
    } catch { 
        _log "GitHub Releases installation failed: $($_.Exception.Message)" "WARNING" 
    }
    return ,@($false, $null, $null)
}

function Install-GitIfMissing {
    _log "Checking for Git installation (required for GitHub CLI)..." "INFO"
    
    $ok, $ver = Test-GitWorking
    if ($ok) {
        _log "Git already available: $ver" "SUCCESS"
        return $true
    }
    
    _log "Git not found - attempting to install Git..." "WARNING"
    
    # Try to install Git via available package managers
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        try {
            winget install Git.Git --silent --accept-package-agreements --accept-source-agreements 2>$null | Out-Null
            Start-Sleep 3
            Update-SessionPath
            $ok, $ver = Test-GitWorking
            if ($ok) {
                _log "Git installed via Winget: $ver" "SUCCESS"
                return $true
            }
        } catch {}
    }
    
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        try {
            scoop install git 2>$null | Out-Null
            Start-Sleep 2
            $ok, $ver = Test-GitWorking
            if ($ok) {
                _log "Git installed via Scoop: $ver" "SUCCESS"
                return $true
            }
        } catch {}
    }
    
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        try {
            choco install git --yes --no-progress 2>$null | Out-Null
            Start-Sleep 2
            $ok, $ver = Test-GitWorking
            if ($ok) {
                _log "Git installed via Chocolatey: $ver" "SUCCESS"
                return $true
            }
        } catch {}
    }
    
    _log "Could not install Git automatically - GitHub CLI may not work fully" "WARNING"
    return $false
}

# --- Main Installation Logic ------------------------------------------------
Start-ModuleTranscript

try {
    _log "=== GitHub CLI Installation ===" "INFO"
    
    # Check for existing installation
    _log "Checking for existing GitHub CLI installation..." "INFO"
    $ok, $ver = Test-GitHubCLIWorking
    if ($ok -and -not $Global:ForceReinstallFlag) {
        _log "GitHub CLI already installed: $ver" "SUCCESS"
        
        # Still check/install Git if missing
        Install-GitIfMissing | Out-Null
        
        $Global:GitHubCLIInstall = [pscustomobject]@{ Success=$true; Method="Existing"; Version=$ver; Log=$moduleLog }
        $LASTEXITCODE = 0
        return
    }
    
    if ($Global:ForceReinstallFlag) {
        _log "ForceReinstall flag detected - proceeding with installation" "WARNING"
    }
    
    # Ensure Git is available first
    $gitAvailable = Install-GitIfMissing
    
    # Try GitHub CLI installation methods
    $installMethods = @(
        'Install-GitHubCLIViaWinget',
        'Install-GitHubCLIViaScoop',
        'Install-GitHubCLIViaChocolatey',
        'Install-GitHubCLIViaGitHubReleases'
    )
    
    foreach ($method in $installMethods) {
        try {
            _log "Attempting: $method" "INFO"
            $result = & $method
            $success, $methodName, $version = $result
            
            if ($success) {
                _log "SUCCESS: GitHub CLI installed via $methodName" "SUCCESS"
                _log "Version: $version" "SUCCESS"
                
                # Provide usage information
                _log "GitHub CLI is ready for use" "SUCCESS"
                _log "To authenticate: gh auth login" "INFO"
                _log "To clone repos: gh repo clone owner/repo" "INFO"
                _log "For help: gh --help" "INFO"
                
                $Global:GitHubCLIInstall = [pscustomobject]@{ 
                    Success = $true
                    Method = $methodName
                    Version = $version
                    GitAvailable = $gitAvailable
                    Log = $moduleLog 
                }
                $LASTEXITCODE = 0
                return
            }
        } catch {
            _log "ERROR in $method : $($_.Exception.Message)" "WARNING"
        }
    }
    
    _log "All GitHub CLI installation methods failed" "ERROR"
    _log "Manual installation: https://cli.github.com/" "ERROR"
    
    $Global:GitHubCLIInstall = [pscustomobject]@{ 
        Success = $false
        Method = $null
        Version = $null
        GitAvailable = $gitAvailable
        Log = $moduleLog 
    }
    $LASTEXITCODE = 1
    
} catch {
    _log "Unexpected error: $($_.Exception.Message)" "ERROR"
    $Global:GitHubCLIInstall = [pscustomobject]@{ 
        Success = $false
        Method = "Exception"
        Version = $null
        GitAvailable = $false
        Log = $moduleLog 
    }
    $LASTEXITCODE = 1
    
} finally {
    Stop-ModuleTranscript
    
    if ($Global:GitHubCLIInstall.Success) {
        _log "=== GITHUB CLI INSTALLATION SUCCESSFUL ===" "SUCCESS"
        _log "Use 'gh auth login' to authenticate with GitHub" "INFO"
    } else {
        _log "=== GITHUB CLI INSTALLATION FAILED ===" "ERROR"
    }
}# modules/Install-QuartoCLI.ps1
# BULLETPROOF Quarto CLI installer - tries every possible installation method
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

# --- AGGRESSIVE PATH MANAGEMENT ---------------------------------------------
function Update-SessionPath {
    # Get all possible paths
    $machinePath = [Environment]::GetEnvironmentVariable("PATH", 'Machine') -split ';' | Where-Object { $_ }
    $userPath = [Environment]::GetEnvironmentVariable("PATH", 'User') -split ';' | Where-Object { $_ }
    $processPath = $env:PATH -split ';' | Where-Object { $_ }
    
    # Combine and deduplicate
    $allPaths = ($machinePath + $userPath + $processPath) | Sort-Object -Unique
    
    # Add ALL possible Quarto installation locations
    $quartoLocations = @(
        # Standard installations
        "$env:ProgramFiles\Quarto\bin",
        "$env:LOCALAPPDATA\Programs\Quarto\bin",
        "${env:ProgramFiles(x86)}\Quarto\bin",
        
        # Package manager locations
        "$env:USERPROFILE\scoop\apps\quarto\current\bin",
        "$env:USERPROFILE\scoop\shims",
        "C:\ProgramData\chocolatey\lib\quarto\tools\bin",
        "C:\ProgramData\chocolatey\bin",
        
        # Conda locations  
        "$env:USERPROFILE\miniconda3\Scripts",
        "$env:USERPROFILE\miniconda3\condabin",
        "$env:USERPROFILE\anaconda3\Scripts",
        "$env:USERPROFILE\anaconda3\condabin",
        "$env:CONDA_PREFIX\Scripts",
        "$env:CONDA_PREFIX\bin",
        
        # Portable locations
        "$env:USERPROFILE\PortableApps\QuartoPortable\App\bin",
        "$env:USERPROFILE\portable\quarto\bin",
        
        # Manual installations
        "C:\Quarto\bin",
        "D:\Quarto\bin",
        "$env:USERPROFILE\tools\quarto\bin"
    ) | Where-Object { Test-Path $_ -ErrorAction SilentlyContinue }
    
    # Combine everything
    $finalPaths = ($allPaths + $quartoLocations) | Sort-Object -Unique
    $env:PATH = $finalPaths -join ';'
    
    # Force refresh of PowerShell's command cache
    if (Get-Command Get-Command -ErrorAction SilentlyContinue) {
        Get-Command quarto -ErrorAction SilentlyContinue | Out-Null
    }
}

function Test-QuartoWorking {
    # Try multiple approaches to find and test Quarto
    Update-SessionPath
    
    # Method 1: Direct command test
    try {
        $version = (& quarto --version) 2>$null
        if ($LASTEXITCODE -eq 0 -and $version -match '\d+\.\d+(\.\d+)?') {
            return ,@($true, ($version -split '\r?\n')[0].Trim(), "command")
        }
    } catch {}
    
    # Method 2: Test via cmd 
    try {
        $version = cmd /c "quarto --version" 2>$null
        if ($version -match '\d+\.\d+(\.\d+)?') {
            return ,@($true, $version.Trim(), "cmd")
        }
    } catch {}
    
    # Method 3: Direct executable search
    $quartoExes = @(
        "$env:ProgramFiles\Quarto\bin\quarto.exe",
        "$env:LOCALAPPDATA\Programs\Quarto\bin\quarto.exe",
        "$env:USERPROFILE\scoop\apps\quarto\current\bin\quarto.exe"
    ) | Where-Object { Test-Path $_ -ErrorAction SilentlyContinue }
    
    foreach ($exe in $quartoExes) {
        try {
            $version = (& $exe --version) 2>$null
            if ($version -match '\d+\.\d+(\.\d+)?') {
                # Add to PATH if not there
                $binDir = Split-Path $exe -Parent
                if ($env:PATH -notlike "*$binDir*") {
                    $env:PATH = "$env:PATH;$binDir"
                }
                return ,@($true, ($version -split '\r?\n')[0].Trim(), "direct")
            }
        } catch {}
    }
    
    # Method 4: Registry search (Windows installer)
    try {
        $uninstallKeys = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
        )
        
        foreach ($key in $uninstallKeys) {
            $quartoApp = Get-ItemProperty $key -ErrorAction SilentlyContinue | 
                         Where-Object { $_.DisplayName -like "*Quarto*" }
            
            if ($quartoApp -and $quartoApp.InstallLocation) {
                $possibleExe = Join-Path $quartoApp.InstallLocation "bin\quarto.exe"
                if (Test-Path $possibleExe) {
                    try {
                        $version = (& $possibleExe --version) 2>$null
                        if ($version -match '\d+\.\d+(\.\d+)?') {
                            $binDir = Split-Path $possibleExe -Parent
                            if ($env:PATH -notlike "*$binDir*") {
                                $env:PATH = "$env:PATH;$binDir"
                            }
                            return ,@($true, ($version -split '\r?\n')[0].Trim(), "registry")
                        }
                    } catch {}
                }
            }
        }
    } catch {}
    
    return ,@($false, $null, $null)
}

function Force-PathRefresh {
    # Nuclear option - completely rebuild PATH
    try {
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
        Update-SessionPath
        
        # Wait and try again
        Start-Sleep 2
        Update-SessionPath
        
        # One more aggressive attempt
        $allPossiblePaths = @(
            [System.Environment]::GetEnvironmentVariable("PATH", "Machine") -split ';',
            [System.Environment]::GetEnvironmentVariable("PATH", "User") -split ';',
            "$env:ProgramFiles\Quarto\bin",
            "$env:LOCALAPPDATA\Programs\Quarto\bin",
            "$env:USERPROFILE\scoop\shims"
        ) | Where-Object { $_ -and (Test-Path $_ -ErrorAction SilentlyContinue) } | Sort-Object -Unique
        
        $env:PATH = $allPossiblePaths -join ';'
        
        _log "Aggressive PATH refresh completed" "INFO"
        _log "PATH now contains $($allPossiblePaths.Count) valid directories" "INFO"
    } catch {
        _log "PATH refresh failed: $($_.Exception.Message)" "WARNING"
    }
}

# --- INSTALLATION METHODS (Enhanced with more options) ----------------------

function Install-QuartoViaWinget {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { 
        return ,@($false, $null, $null) 
    }
    
    _log "Method 1: Winget (multiple attempts)..." "INFO"
    
    # Try different winget approaches
    $wingetAttempts = @(
        @{ Args = @('install', '--id', 'Posit.Quarto', '-e', '--accept-package-agreements', '--accept-source-agreements', '--silent'); Desc = "Standard" },
        @{ Args = @('install', 'Quarto', '--accept-package-agreements', '--accept-source-agreements', '--silent'); Desc = "Simple name" },
        @{ Args = @('install', '--id', 'Posit.Quarto', '--force', '--accept-package-agreements', '--accept-source-agreements'); Desc = "Forced" }
    )
    
    foreach ($attempt in $wingetAttempts) {
        try {
            _log "  Trying winget $($attempt.Desc)..." "INFO"
            winget source update 2>$null | Out-Null
            
            $process = Start-Process winget -ArgumentList $attempt.Args -WindowStyle Hidden -Wait -PassThru -NoNewWindow
            if ($process.ExitCode -eq 0) {
                Start-Sleep 5
                Force-PathRefresh
                $ok, $ver, $method = Test-QuartoWorking
                if ($ok) { 
                    _log "Winget $($attempt.Desc) succeeded!" "SUCCESS"
                    return ,@($true, "Winget-$($attempt.Desc)", $ver) 
                }
            }
        } catch {
            _log "  Winget $($attempt.Desc) failed: $($_.Exception.Message)" "WARNING"
        }
    }
    return ,@($false, $null, $null)
}

function Install-QuartoViaChocolatey {
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) { 
        return ,@($false, $null, $null) 
    }
    
    _log "Method 2: Chocolatey (enhanced)..." "INFO"
    
    # Clean up any previous issues
    try {
        choco cache clear --force 2>$null | Out-Null
        Get-Process | Where-Object {$_.ProcessName -like "*choco*"} | Stop-Process -Force -ErrorAction SilentlyContinue
    } catch {}
    
    $chocoAttempts = @(
        @{ Args = @('install', 'quarto', '--yes', '--force', '--no-progress'); Desc = "Standard" },
        @{ Args = @('install', 'quarto', '--yes', '--ignore-checksums', '--force'); Desc = "Ignore checksums" },
        @{ Args = @('upgrade', 'quarto', '--yes', '--force'); Desc = "Upgrade" }
    )
    
    foreach ($attempt in $chocoAttempts) {
        try {
            _log "  Trying chocolatey $($attempt.Desc)..." "INFO"
            $process = Start-Process choco -ArgumentList $attempt.Args -WindowStyle Hidden -Wait -PassThru -NoNewWindow
            if ($process.ExitCode -eq 0) {
                Start-Sleep 5
                Force-PathRefresh
                $ok, $ver, $method = Test-QuartoWorking
                if ($ok) { 
                    return ,@($true, "Chocolatey-$($attempt.Desc)", $ver) 
                }
            }
        } catch {
            _log "  Chocolatey $($attempt.Desc) failed: $($_.Exception.Message)" "WARNING"
        }
    }
    return ,@($false, $null, $null)
}

function Install-QuartoViaScoop {
    _log "Method 3: Scoop (with auto-install)..." "INFO"
    
    # Install Scoop if needed
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        try {
            _log "  Installing Scoop first..." "INFO"
            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
            Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
            Update-SessionPath
            Start-Sleep 3
        } catch {
            _log "  Failed to install Scoop: $($_.Exception.Message)" "WARNING"
            return ,@($false, $null, $null)
        }
    }
    
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        try {
            scoop bucket add main 2>$null | Out-Null
            scoop update 2>$null | Out-Null
            scoop install quarto 2>$null | Out-Null
            
            Start-Sleep 3
            Force-PathRefresh
            $ok, $ver, $method = Test-QuartoWorking
            if ($ok) { return ,@($true, "Scoop", $ver) }
        } catch {
            _log "  Scoop installation failed: $($_.Exception.Message)" "WARNING"
        }
    }
    return ,@($false, $null, $null)
}

function Install-QuartoViaConda {
    $condaCmd = $null
    if (Get-Command conda -ErrorAction SilentlyContinue) {
        $condaCmd = "conda"
    } elseif (Get-Command mamba -ErrorAction SilentlyContinue) {
        $condaCmd = "mamba"
    } else {
        return ,@($false, $null, $null)
    }
    
    _log "Method 4: $condaCmd..." "INFO"
    try {
        $process = Start-Process $condaCmd -ArgumentList @('install', '-c', 'conda-forge', 'quarto', '--yes') -WindowStyle Hidden -Wait -PassThru -NoNewWindow
        
        if ($process.ExitCode -eq 0) {
            Start-Sleep 3
            Force-PathRefresh
            $ok, $ver, $method = Test-QuartoWorking
            if ($ok) { return ,@($true, "Conda-$condaCmd", $ver) }
        }
    } catch {
        _log "$condaCmd installation failed: $($_.Exception.Message)" "WARNING"
    }
    return ,@($false, $null, $null)
}

function Install-QuartoViaGitHubCLI {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { 
        return ,@($false, $null, $null) 
    }
    
    _log "Method 5: GitHub CLI..." "INFO"
    try {
        # Use GitHub CLI to download latest release
        $tempDir = Join-Path $env:TEMP "quarto-gh-install"
        if (!(Test-Path $tempDir)) { New-Item -ItemType Directory -Path $tempDir | Out-Null }
        
        Set-Location $tempDir
        gh release download --repo quarto-dev/quarto-cli --pattern "*win*.msi" 2>$null
        
        $msiFile = Get-ChildItem -Filter "*.msi" | Select-Object -First 1
        if ($msiFile) {
            $process = Start-Process msiexec.exe -ArgumentList @('/i', "`"$($msiFile.FullName)`"", '/qn', '/norestart', 'ALLUSERS=1') -Wait -PassThru
            if ($process.ExitCode -eq 0) {
                Start-Sleep 5
                Force-PathRefresh
                $ok, $ver, $method = Test-QuartoWorking
                if ($ok) { 
                    Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
                    return ,@($true, "GitHub-CLI", $ver) 
                }
            }
        }
        Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    } catch {
        _log "GitHub CLI installation failed: $($_.Exception.Message)" "WARNING"
    }
    return ,@($false, $null, $null)
}

function Install-QuartoViaPortableApps {
    # Check if PortableApps platform is available
    $portableAppsExe = @(
        "$env:USERPROFILE\PortableApps\PortableApps.com\PortableAppsPlatform.exe",
        "$env:LOCALAPPDATA\PortableApps\PortableApps.com\PortableAppsPlatform.exe"
    ) | Where-Object { Test-Path $_ -ErrorAction SilentlyContinue } | Select-Object -First 1
    
    if (-not $portableAppsExe) {
        return ,@($false, $null, $null)
    }
    
    _log "Method 6: PortableApps platform..." "INFO"
    try {
        # This is a placeholder - PortableApps doesn't have Quarto yet
        # But we can create a portable installation manually
        $portableDir = "$env:USERPROFILE\PortableApps\QuartoPortable"
        
        # Download and extract to PortableApps structure
        $zipUrl = "https://github.com/quarto-dev/quarto-cli/releases/latest/download/quarto-win.zip"
        $zipPath = Join-Path $env:TEMP "quarto-portable.zip"
        
        Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
        
        if (Test-Path $portableDir) { Remove-Item $portableDir -Recurse -Force }
        Expand-Archive -Path $zipPath -DestinationPath $portableDir -Force
        
        # Add to PATH
        $quartoPortableBin = Get-ChildItem -Path $portableDir -Recurse -Filter "quarto.exe" | Select-Object -First 1
        if ($quartoPortableBin) {
            $binDir = $quartoPortableBin.Directory.FullName
            $env:PATH = "$env:PATH;$binDir"
            
            $ok, $ver, $method = Test-QuartoWorking
            if ($ok) {
                Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
                return ,@($true, "PortableApps", $ver)
            }
        }
        
        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
    } catch {
        _log "PortableApps installation failed: $($_.Exception.Message)" "WARNING"
    }
    return ,@($false, $null, $null)
}

function Install-QuartoViaDirectMSI {
    _log "Method 7: Direct MSI (multiple sources)..." "INFO"
    
    $msiSources = @(
        @{ Url = "https://github.com/quarto-dev/quarto-cli/releases/latest/download/quarto-win.msi"; Desc = "GitHub Latest" },
        @{ Url = "https://quarto.org/download/latest/quarto-win.msi"; Desc = "Official Latest" }
    )
    
    foreach ($source in $msiSources) {
        try {
            _log "  Trying $($source.Desc)..." "INFO"
            $msiPath = Join-Path $env:TEMP "quarto-direct.msi"
            
            if (Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue) {
                Start-BitsTransfer -Source $source.Url -Destination $msiPath -ErrorAction Stop
            } else {
                Invoke-WebRequest -Uri $source.Url -OutFile $msiPath -UseBasicParsing -ErrorAction Stop
            }
            
            $process = Start-Process msiexec.exe -ArgumentList @('/i', "`"$msiPath`"", '/qn', '/norestart', 'ALLUSERS=1') -Wait -PassThru
            if ($process.ExitCode -eq 0) {
                Start-Sleep 5
                Force-PathRefresh
                $ok, $ver, $method = Test-QuartoWorking
                if ($ok) {
                    Remove-Item $msiPath -Force -ErrorAction SilentlyContinue
                    return ,@($true, "DirectMSI-$($source.Desc)", $ver)
                }
            }
            Remove-Item $msiPath -Force -ErrorAction SilentlyContinue
        } catch {
            _log "  $($source.Desc) failed: $($_.Exception.Message)" "WARNING"
        }
    }
    return ,@($false, $null, $null)
}

function Install-QuartoViaManualExtraction {
    _log "Method 8: Manual ZIP extraction..." "INFO"
    
    $extractLocations = @(
        "$env:LOCALAPPDATA\Programs\Quarto",
        "$env:USERPROFILE\tools\quarto",
        "C:\Quarto"
    )
    
    foreach ($location in $extractLocations) {
        try {
            _log "  Trying extraction to $location..." "INFO"
            
            $zipUrl = "https://github.com/quarto-dev/quarto-cli/releases/latest/download/quarto-win.zip"
            $zipPath = Join-Path $env:TEMP "quarto-manual.zip"
            
            Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
            
            if (Test-Path $location) { Remove-Item $location -Recurse -Force -ErrorAction SilentlyContinue }
            Expand-Archive -Path $zipPath -DestinationPath $location -Force
            
            # Find quarto.exe and add to PATH
            $quartoExe = Get-ChildItem -Path $location -Recurse -Filter "quarto.exe" | Select-Object -First 1
            if ($quartoExe) {
                $binDir = $quartoExe.Directory.FullName
                
                # Add to machine PATH permanently
                $currentPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
                if ($currentPath -notlike "*$binDir*") {
                    [Environment]::SetEnvironmentVariable("PATH", "$currentPath;$binDir", "Machine")
                }
                
                Force-PathRefresh
                $ok, $ver, $method = Test-QuartoWorking
                if ($ok) {
                    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
                    return ,@($true, "Manual-$($location -replace '.*\\', '')", $ver)
                }
            }
            Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
        } catch {
            _log "  Manual extraction to $location failed: $($_.Exception.Message)" "WARNING"
        }
    }
    return ,@($false, $null, $null)
}

# --- MAIN INSTALLATION LOGIC ------------------------------------------------
try {
    _log "=== BULLETPROOF QUARTO INSTALLATION ===" "INFO"
    _log "Trying every conceivable installation method..." "INFO"
    
    # Check for existing installation with aggressive detection
    _log "Checking for existing Quarto installation..." "INFO"
    Force-PathRefresh
    $ok, $ver, $method = Test-QuartoWorking
    if ($ok -and -not $Global:ForceReinstallFlag) {
        _log "Quarto already installed and working: $ver (detected via $method)" "SUCCESS"
        $Global:QuartoInstall = [pscustomobject]@{ Success=$true; Method="Existing-$method"; Version=$ver; Log=$moduleLog }
        $LASTEXITCODE = 0
        return
    }
    
    # Try ALL installation methods
    $installMethods = @(
        'Install-QuartoViaWinget',           # Try winget with multiple approaches
        'Install-QuartoViaChocolatey',       # Try choco with multiple approaches
        'Install-QuartoViaScoop',            # Scoop with auto-install
        'Install-QuartoViaConda',            # Conda/mamba
        'Install-QuartoViaGitHubCLI',        # GitHub CLI download
        'Install-QuartoViaPortableApps',     # PortableApps platform
        'Install-QuartoViaDirectMSI',        # Direct MSI from multiple sources
        'Install-QuartoViaManualExtraction'  # Manual ZIP extraction to multiple locations
    )
    
    foreach ($method in $installMethods) {
        try {
            _log "=== Attempting: $method ===" "INFO"
            $result = & $method
            $success, $methodName, $version = $result
            
            if ($success) {
                _log "SUCCESS: Quarto installed via $methodName" "SUCCESS"
                _log "Version: $version" "SUCCESS"
                
                # Triple-verify installation
                Force-PathRefresh
                Start-Sleep 2
                $verifyOk, $verifyVer, $verifyMethod = Test-QuartoWorking
                if ($verifyOk) {
                    _log "Installation verified via $verifyMethod" "SUCCESS"
                    
                    $Global:QuartoInstall = [pscustomobject]@{ 
                        Success = $true
                        Method = $methodName
                        Version = $verifyVer
                        VerificationMethod = $verifyMethod
                        Log = $moduleLog 
                    }
                    $LASTEXITCODE = 0
                    return
                } else {
                    _log "Installation succeeded but verification failed - continuing to next method" "WARNING"
                }
            }
        } catch {
            _log "ERROR in $method : $($_.Exception.Message)" "ERROR"
        }
    }
    
    # ULTIMATE FALLBACK - Nuclear option
    _log "All standard methods failed. Trying nuclear option..." "WARNING"
    try {
        # Download and extract to a guaranteed location
        $nuclearDir = "C:\QuartoFallback"
        $zipPath = Join-Path $env:TEMP "quarto-nuclear.zip"
        
        Invoke-WebRequest -Uri "https://github.com/quarto-dev/quarto-cli/releases/latest/download/quarto-win.zip" -OutFile $zipPath -UseBasicParsing
        
        if (Test-Path $nuclearDir) { Remove-Item $nuclearDir -Recurse -Force }
        Expand-Archive -Path $zipPath -DestinationPath $nuclearDir -Force
        
        # Manually add to system PATH
        $quartoExe = Get-ChildItem -Path $nuclearDir -Recurse -Filter "quarto.exe" | Select-Object -First 1
        if ($quartoExe) {
            $binDir = $quartoExe.Directory.FullName
            
            # Force add to both user and machine PATH
            $machPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
            $userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
            
            if ($machPath -notlike "*$binDir*") {
                [Environment]::SetEnvironmentVariable("PATH", "$machPath;$binDir", "Machine")
            }
            if ($userPath -notlike "*$binDir*") {
                [Environment]::SetEnvironmentVariable("PATH", "$userPath;$binDir", "User")
            }
            
            $env:PATH = "$env:PATH;$binDir"
            
            # Final test
            Start-Sleep 3
            $ok, $ver, $method = Test-QuartoWorking
            if ($ok) {
                _log "NUCLEAR OPTION SUCCESS: Quarto working from $nuclearDir" "SUCCESS"
                $Global:QuartoInstall = [pscustomobject]@{ 
                    Success = $true
                    Method = "Nuclear-Fallback"
                    Version = $ver
                    Location = $nuclearDir
                    Log = $moduleLog 
                }
                $LASTEXITCODE = 0
                return
            }
        }
    } catch {
        _log "Even nuclear option failed: $($_.Exception.Message)" "ERROR"
    }
    
    # Complete failure
    _log "ALL INSTALLATION METHODS FAILED" "ERROR"
    _log "Manual steps required:" "ERROR"
    _log "1. Download: https://quarto.org/docs/get-started/" "ERROR"
    _log "2. Run installer as administrator" "ERROR"  
    _log "3. Restart PowerShell completely" "ERROR"
    _log "4. Add to PATH if needed: [Environment]::SetEnvironmentVariable('PATH', \$env:PATH + ';C:\\Program Files\\Quarto\\bin', 'Machine')" "ERROR"
    
    $Global:QuartoInstall = [pscustomobject]@{ 
        Success = $false
        Method = $null
        Version = $null
        Log = $moduleLog 
    }
    $LASTEXITCODE = 1
    
} catch {
    _log "UNEXPECTED ERROR: $($_.Exception.Message)" "ERROR"
    $Global:QuartoInstall = [pscustomobject]@{ 
        Success = $false
        Method = "Exception"
        Version = $null
        Error = $_.Exception.Message
        Log = $moduleLog 
    }
    $LASTEXITCODE = 1
} finally {
    if ($Global:QuartoInstall.Success) {
        _log "=== QUARTO INSTALLATION SUCCESSFUL ===" "SUCCESS"
        _log "Final verification: quarto --version works" "SUCCESS"
    } else {
        _log "=== QUARTO INSTALLATION FAILED ===" "ERROR"
        _log "All 8+ methods attempted without success" "ERROR"
    }
}