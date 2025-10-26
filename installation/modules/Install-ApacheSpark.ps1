# modules/Install-ApacheSpark.ps1
# Install Apache Spark and Hadoop for big data processing
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
    
    # Add Spark/Hadoop paths
    $sparkPaths = @(
        "$env:SPARK_HOME\bin",
        "$env:HADOOP_HOME\bin",
        "$env:ProgramFiles\Apache\spark\bin",
        "$env:USERPROFILE\spark\bin"
    ) | Where-Object { $_ -and (Test-Path $_ -ErrorAction SilentlyContinue) }
    
    if ($sparkPaths) {
        $env:PATH = @($env:PATH; $sparkPaths) -join ';'
    }
}

function Test-JavaAvailable {
    try {
        Update-SessionPath
        $javaVersion = java -version 2>&1
        if ($javaVersion -match "version") {
            # Extract version number
            $versionMatch = $javaVersion | Select-String 'version "(.+?)"'
            if ($versionMatch) {
                return ,@($true, $versionMatch.Matches[0].Groups[1].Value)
            }
            return ,@($true, "Unknown version")
        }
    } catch {}
    return ,@($false, $null)
}

function Test-SparkWorking {
    try {
        Update-SessionPath
        
        # Test if spark-submit is available
        $sparkSubmit = Get-Command "spark-submit" -ErrorAction SilentlyContinue
        if (-not $sparkSubmit) {
            return ,@($false, $null)
        }
        
        # Try to get Spark version
        $sparkVersion = & spark-submit --version 2>&1
        if ($sparkVersion -match "version (\d+\.\d+\.\d+)") {
            return ,@($true, $matches[1])
        }
        
        return ,@($true, "Unknown version")
    } catch {}
    return ,@($false, $null)
}

function Get-LatestSparkRelease {
    try {
        _log "Fetching latest Spark release information..." "INFO"
        $api = "https://api.github.com/repos/apache/spark/releases/latest"
        $release = Invoke-RestMethod -Uri $api -UseBasicParsing -ErrorAction Stop
        
        # Find Hadoop 3.3 compatible release (most common)
        $asset = $release.assets | Where-Object { 
            $_.name -like "*hadoop3.3*" -and $_.name -like "*.tgz" 
        } | Select-Object -First 1
        
        if (-not $asset) {
            # Fallback to any tgz asset
            $asset = $release.assets | Where-Object { $_.name -like "*.tgz" } | Select-Object -First 1
        }
        
        if ($asset) {
            return ,@($true, $release.tag_name, $asset.browser_download_url, $asset.name)
        }
    } catch {
        _log "Failed to fetch release info: $($_.Exception.Message)" "WARNING"
    }
    
    # Fallback to known stable version
    $fallbackVersion = "3.5.0"
    $fallbackUrl = "https://archive.apache.org/dist/spark/spark-$fallbackVersion/spark-$fallbackVersion-bin-hadoop3.tgz"
    $fallbackName = "spark-$fallbackVersion-bin-hadoop3.tgz"
    return ,@($false, $fallbackVersion, $fallbackUrl, $fallbackName)
}

function Start-ModuleTranscript {
    try {
        $dir = Join-Path $env:TEMP "spark-install"
        if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
        $script:moduleLog = Join-Path $dir ("spark-install-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))
        Start-Transcript -Path $script:moduleLog -Force | Out-Null
    } catch {}
}

function Stop-ModuleTranscript { 
    try { Stop-Transcript | Out-Null } catch {} 
}

function Install-JavaIfMissing {
    _log "Checking for Java installation (required for Spark)..." "INFO"
    
    $ok, $ver = Test-JavaAvailable
    if ($ok) {
        _log "Java already available: $ver" "SUCCESS"
        return $true
    }
    
    _log "Java not found - attempting to install Java..." "WARNING"
    
    # Try to install Java via available package managers
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        try {
            _log "Installing Java via Winget..." "INFO"
            winget install Microsoft.OpenJDK.11 --silent --accept-package-agreements --accept-source-agreements 2>$null | Out-Null
            Start-Sleep 3
            Update-SessionPath
            $ok, $ver = Test-JavaAvailable
            if ($ok) {
                _log "Java installed via Winget: $ver" "SUCCESS"
                return $true
            }
        } catch {}
    }
    
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        try {
            _log "Installing Java via Chocolatey..." "INFO"
            choco install openjdk11 --yes --no-progress 2>$null | Out-Null
            Start-Sleep 3
            Update-SessionPath
            $ok, $ver = Test-JavaAvailable
            if ($ok) {
                _log "Java installed via Chocolatey: $ver" "SUCCESS"
                return $true
            }
        } catch {}
    }
    
    _log "Could not install Java automatically - Spark installation may fail" "WARNING"
    _log "Manual Java installation: https://adoptium.net/" "WARNING"
    return $false
}

# --- Installation Methods ---------------------------------------------------

function Install-SparkViaWinget {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { 
        return ,@($false, $null, $null) 
    }
    
    _log "Method 1: Installing Spark via Winget..." "INFO"
    try {
        winget install Apache.Spark --silent --accept-package-agreements --accept-source-agreements 2>$null | Out-Null
        Start-Sleep 3
        $ok, $ver = Test-SparkWorking
        if ($ok) { return ,@($true, "Winget", $ver) }
    } catch { 
        _log "Winget installation failed: $($_.Exception.Message)" "WARNING" 
    }
    return ,@($false, $null, $null)
}

function Install-SparkViaChocolatey {
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) { 
        return ,@($false, $null, $null) 
    }
    
    _log "Method 2: Installing Spark via Chocolatey..." "INFO"
    try {
        choco install apache-spark --yes --no-progress 2>$null | Out-Null
        Start-Sleep 3
        $ok, $ver = Test-SparkWorking
        if ($ok) { return ,@($true, "Chocolatey", $ver) }
    } catch { 
        _log "Chocolatey installation failed: $($_.Exception.Message)" "WARNING" 
    }
    return ,@($false, $null, $null)
}

function Install-SparkViaDirectDownload {
    _log "Method 3: Installing Spark via direct download..." "INFO"
    
    # Get latest release info
    $useLatest, $version, $downloadUrl, $fileName = Get-LatestSparkRelease
    
    $downloadDir = Join-Path $env:TEMP "spark-install"
    if (!(Test-Path $downloadDir)) { New-Item -ItemType Directory -Path $downloadDir | Out-Null }
    $archivePath = Join-Path $downloadDir $fileName
    
    # Installation directory
    $installBaseDir = "$env:ProgramFiles\Apache"
    $sparkDir = Join-Path $installBaseDir "spark"
    
    try {
        _log "Downloading Spark $version..." "INFO"
        _log "URL: $downloadUrl" "INFO"
        
        if (Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue) {
            Start-BitsTransfer -Source $downloadUrl -Destination $archivePath -ErrorAction Stop
        } else {
            Invoke-WebRequest -Uri $downloadUrl -OutFile $archivePath -UseBasicParsing -ErrorAction Stop
        }
        
        _log "Extracting Spark archive..." "INFO"
        
        # Extract using tar (available in Windows 10+)
        if (Get-Command tar -ErrorAction SilentlyContinue) {
            # Create installation directory
            if (!(Test-Path $installBaseDir)) { New-Item -ItemType Directory -Path $installBaseDir -Force | Out-Null }
            
            # Extract to temp location first
            $extractTemp = Join-Path $downloadDir "extracted"
            if (Test-Path $extractTemp) { Remove-Item $extractTemp -Recurse -Force }
            New-Item -ItemType Directory -Path $extractTemp | Out-Null
            
            Set-Location $extractTemp
            tar -xzf $archivePath
            
            # Find the extracted directory
            $extractedDir = Get-ChildItem -Directory | Select-Object -First 1
            if ($extractedDir) {
                # Remove existing Spark installation
                if (Test-Path $sparkDir) {
                    Remove-Item $sparkDir -Recurse -Force -ErrorAction SilentlyContinue
                }
                
                # Move to final location
                Move-Item $extractedDir.FullName $sparkDir -Force
                
                _log "Setting up environment variables..." "INFO"
                
                # Set SPARK_HOME environment variable
                [Environment]::SetEnvironmentVariable("SPARK_HOME", $sparkDir, [EnvironmentVariableTarget]::Machine)
                $env:SPARK_HOME = $sparkDir
                
                # Add to PATH
                $currentPath = [Environment]::GetEnvironmentVariable("PATH", [EnvironmentVariableTarget]::Machine)
                $sparkBinPath = Join-Path $sparkDir "bin"
                
                if ($currentPath -notlike "*$sparkBinPath*") {
                    $newPath = "$currentPath;$sparkBinPath"
                    [Environment]::SetEnvironmentVariable("PATH", $newPath, [EnvironmentVariableTarget]::Machine)
                }
                
                # Update current session
                Update-SessionPath
                
                # Test installation
                $ok, $ver = Test-SparkWorking
                if ($ok) {
                    # Cleanup
                    Remove-Item $archivePath -Force -ErrorAction SilentlyContinue
                    Remove-Item $extractTemp -Recurse -Force -ErrorAction SilentlyContinue
                    
                    return ,@($true, "Direct Download", $ver)
                }
            }
        } else {
            _log "tar command not available - cannot extract Spark archive" "ERROR"
        }
        
    } catch { 
        _log "Direct download installation failed: $($_.Exception.Message)" "WARNING" 
    }
    return ,@($false, $null, $null)
}

function Install-SparkViaScoop {
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) { 
        return ,@($false, $null, $null) 
    }
    
    _log "Method 4: Installing Spark via Scoop..." "INFO"
    try {
        scoop bucket add java 2>$null | Out-Null
        scoop install spark 2>$null | Out-Null
        
        Start-Sleep 3
        $ok, $ver = Test-SparkWorking
        if ($ok) { return ,@($true, "Scoop", $ver) }
    } catch { 
        _log "Scoop installation failed: $($_.Exception.Message)" "WARNING" 
    }
    return ,@($false, $null, $null)
}

# --- Main Installation Logic ------------------------------------------------
Start-ModuleTranscript

try {
    _log "=== Apache Spark & Hadoop Installation ===" "INFO"
    
    # Check for existing installation
    _log "Checking for existing Spark installation..." "INFO"
    $ok, $ver = Test-SparkWorking
    if ($ok -and -not $Global:ForceReinstallFlag) {
        _log "Spark already installed: $ver" "SUCCESS"
        $Global:SparkInstall = [pscustomobject]@{ Success=$true; Method="Existing"; Version=$ver; Log=$moduleLog }
        $LASTEXITCODE = 0
        return
    }
    
    if ($Global:ForceReinstallFlag) {
        _log "ForceReinstall flag detected - proceeding with installation" "WARNING"
    }
    
    # Ensure Java is available
    $javaAvailable = Install-JavaIfMissing
    if (-not $javaAvailable) {
        _log "Java installation failed - Spark requires Java to function" "ERROR"
        # Continue anyway - user might install Java manually later
    }
    
    # Try Spark installation methods
    $installMethods = @(
        'Install-SparkViaWinget',
        'Install-SparkViaChocolatey',
        'Install-SparkViaScoop',
        'Install-SparkViaDirectDownload'
    )
    
    foreach ($method in $installMethods) {
        try {
            _log "Attempting: $method" "INFO"
            $result = & $method
            $success, $methodName, $version = $result
            
            if ($success) {
                _log "SUCCESS: Spark installed via $methodName" "SUCCESS"
                _log "Version: $version" "SUCCESS"
                
                # Provide usage information
                _log "Spark is ready for use" "SUCCESS"
                _log "Start Spark shell: spark-shell" "INFO"
                _log "Submit Spark jobs: spark-submit <app.py|app.jar>" "INFO"
                _log "Spark UI available at: http://localhost:4040 (when running)" "INFO"
                
                $Global:SparkInstall = [pscustomobject]@{ 
                    Success = $true
                    Method = $methodName
                    Version = $version
                    JavaAvailable = $javaAvailable
                    Log = $moduleLog 
                }
                $LASTEXITCODE = 0
                return
            }
        } catch {
            _log "ERROR in $method : $($_.Exception.Message)" "WARNING"
        }
    }
    
    _log "All Spark installation methods failed" "ERROR"
    _log "Manual installation steps:" "ERROR"
    _log "1. Install Java 8/11: https://adoptium.net/" "ERROR"
    _log "2. Download Spark: https://spark.apache.org/downloads.html" "ERROR"
    _log "3. Extract and set SPARK_HOME environment variable" "ERROR"
    
    $Global:SparkInstall = [pscustomobject]@{ 
        Success = $false
        Method = $null
        Version = $null
        JavaAvailable = $javaAvailable
        Log = $moduleLog 
    }
    $LASTEXITCODE = 1
    
} catch {
    _log "Unexpected error: $($_.Exception.Message)" "ERROR"
    $Global:SparkInstall = [pscustomobject]@{ 
        Success = $false
        Method = "Exception"
        Version = $null
        JavaAvailable = $false
        Log = $moduleLog 
    }
    $LASTEXITCODE = 1
    
} finally {
    Stop-ModuleTranscript
    
    if ($Global:SparkInstall.Success) {
        _log "=== APACHE SPARK INSTALLATION SUCCESSFUL ===" "SUCCESS"
        _log "Use 'spark-shell' to start interactive Spark session" "INFO"
    } else {
        _log "=== APACHE SPARK INSTALLATION FAILED ===" "ERROR"
    }
}