# modules/_Shared-InstallProviders.ps1
# Shared provider helpers for all modules (Scoop, Chocolatey, WinGet, GitHub CLI, Portable, MSI)
# - Pure function library: defines helpers only. Does not set $LASTEXITCODE or exit.
# - Safe to dot-source from any module:  . "$PSScriptRoot\_Shared-InstallProviders.ps1"

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ---------------- Logging shim ----------------
function Use-Logger {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Message,
        [ValidateSet('INFO','SUCCESS','WARNING','ERROR')][string]$Level = 'INFO'
    )
    if (Get-Command -Name Write-Log -ErrorAction SilentlyContinue) {
        Write-Log -Message $Message -Level $Level
    } else {
        $Color = switch ($Level) {
            'SUCCESS' { 'Green' }
            'WARNING' { 'Yellow' }
            'ERROR'   { 'Red' }
            default   { 'Gray' }
        }
        Write-Host "[$Level] $Message" -ForegroundColor $Color
    }
}

# ---------------- Utilities ----------------
function Update-SessionPath {
    [CmdletBinding()]
    param(
        [string[]]$AlsoInclude = @()
    )
    $mach = [Environment]::GetEnvironmentVariable('PATH','Machine')
    $user = [Environment]::GetEnvironmentVariable('PATH','User')
    $env:PATH = @($mach,$user) -join ';'
    foreach ($p in $AlsoInclude) {
        if ($p -and (Test-Path $p)) { $env:PATH = "$env:PATH;$p" }
    }
}

function Test-IsAdmin {
    [CmdletBinding()]
    param()
    $id  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $pri = [Security.Principal.WindowsPrincipal]$id
    return $pri.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-External {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$FilePath,
        [string[]]$Arguments = @(),
        [int]$TimeoutSec = 7200
    )
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FilePath
    $psi.Arguments = ($Arguments -join ' ')
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi
    $null = $p.Start()
    if (-not $p.WaitForExit($TimeoutSec * 1000)) {
        try { $p.Kill() } catch {}
        return [pscustomobject]@{ ExitCode = -1; StdOut = ''; StdErr = "Timed out after $TimeoutSec seconds" }
    }
    return [pscustomobject]@{
        ExitCode = $p.ExitCode
        StdOut   = $p.StandardOutput.ReadToEnd()
        StdErr   = $p.StandardError.ReadToEnd()
    }
}

function Get-File {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Url,
        [Parameter(Mandatory=$true)][string]$OutFile
    )
    try {
        # ensure TLS 1.2+ for older PowerShell
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        if (Get-Command -Name Start-BitsTransfer -ErrorAction SilentlyContinue) {
            Start-BitsTransfer -Source $Url -Destination $OutFile -ErrorAction Stop
        } else {
            Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing -ErrorAction Stop
        }
        return $true
    } catch {
        Use-Logger "Download failed: $Url — $($_.Exception.Message)" 'WARNING'
        return $false
    }
}

function Expand-ZipArchive {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$ZipPath,
        [Parameter(Mandatory=$true)][string]$Destination
    )
    if (-not (Test-Path $Destination)) { New-Item -ItemType Directory -Path $Destination | Out-Null }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $Destination, $true)
}

function Verify-Command {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Command,
        [string[]]$Args = @('--version'),
        [string]$MatchRegex = '\d+\.\d+'
    )
    try {
        $res = Invoke-External -FilePath $Command -Arguments $Args -TimeoutSec 120
        if ($res.ExitCode -eq 0 -and $res.StdOut -match $MatchRegex) {
            return ,@($true, ($res.StdOut -split '\r?\n')[0].Trim())
        }
    } catch {}
    return ,@($false, $null)
}

# ---------------- Providers ----------------
function Try-ScoopInstall {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Package,
        [string]$Bucket
    )
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) { return $false }
    try {
        if ($Bucket) {
            Invoke-External -FilePath 'scoop' -Arguments @('bucket','add',$Bucket) | Out-Null
        }
        $r = Invoke-External -FilePath 'scoop' -Arguments @('install',$Package)
        return ($r.ExitCode -eq 0)
    } catch { return $false }
}

function Try-ChocoInstall {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Package,
        [string[]]$ExtraParams = @()
    )
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) { return $false }
    try {
        $args = @('install',$Package,'--yes','--no-progress') + $ExtraParams
        $r = Invoke-External -FilePath 'choco' -Arguments $args -TimeoutSec 7200
        return ($r.ExitCode -eq 0 -or $r.ExitCode -eq 3010)
    } catch { return $false }
}

function Try-WingetInstall {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Id,
        [switch]$Exact,
        [switch]$Silent,
        [switch]$ScopeMachineIfAdmin,
        [string]$Source
    )
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { return $false }
    try {
        $args = @('install','--id',$Id,'--accept-package-agreements','--accept-source-agreements')
        if ($Exact)  { $args += '-e' }
        if ($Silent) { $args += '--silent' }
        if ($Source) { $args += '--source',$Source }
        if ($ScopeMachineIfAdmin -and (Test-IsAdmin)) { $args += '--scope','machine' }
        $r = Invoke-External -FilePath 'winget' -Arguments $args -TimeoutSec 7200
        return ($r.ExitCode -eq 0)
    } catch { return $false }
}

function Try-GHReleaseDownload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Repo,     # e.g. 'OWNER/REPO'
        [Parameter(Mandatory=$true)][string]$Pattern,  # e.g. '*.msi' or 'tool-win64.zip'
        [Parameter(Mandatory=$true)][string]$OutDir,
        [string]$Tag # optional; omit for latest
    )
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { return $false, $null }
    if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir | Out-Null }
    try {
        $args = @('release','download')
        if ($Tag) { $args += $Tag }
        $args += @('-R',$Repo,'--pattern',$Pattern,'-D',$OutDir)
        $r = Invoke-External -FilePath 'gh' -Arguments $args -TimeoutSec 7200
        return ($r.ExitCode -eq 0), $OutDir
    } catch { return $false, $null }
}

function Silent-InstallMSI {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$MsiPath)
    $args = @('/i',"`"$MsiPath`"","/qn","/norestart")
    $r = Invoke-External -FilePath 'msiexec.exe' -Arguments $args -TimeoutSec 7200
    return ($r.ExitCode -eq 0)
}

function Silent-InstallExe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$ExePath,
        [string[]]$Arguments = @('/S')  # NSIS /S is common; override per-app if needed
    )
    $r = Invoke-External -FilePath $ExePath -Arguments $Arguments -TimeoutSec 7200
    return ($r.ExitCode -eq 0)
}
