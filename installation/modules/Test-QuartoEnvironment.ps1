# modules/Simple-Test-Quarto.ps1
# Minimal Quarto environment smoke test (module-safe). No transcripts, no optional checks.

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$LASTEXITCODE = 1

function Write-Info($msg){ Write-Host "[INFO] $msg" -ForegroundColor Gray }
function Write-Ok($msg){ Write-Host "[OK]   $msg" -ForegroundColor Green }
function Write-Warn($msg){ Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Err($msg){ Write-Host "[ERR]  $msg" -ForegroundColor Red }

try {
    Write-Info "Checking for 'quarto' on PATH..."
    $q = Get-Command quarto -ErrorAction SilentlyContinue
    if (-not $q) {
        Write-Err "Quarto not found on PATH."
        return
    }
    Write-Ok "Quarto executable: $($q.Source)"

    Write-Info "Getting Quarto version..."
    $qver = (& quarto --version) 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $qver) {
        Write-Warn "Could not read Quarto version."
    } else {
        $line = ($qver -split "`r?`n")[0].Trim()
        Write-Ok "Quarto version: $line"
    }

    # Prepare a temp working directory
    $work = Join-Path $env:TEMP "quarto-smoke"
    if (Test-Path $work) { Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue }
    New-Item -ItemType Directory -Path $work | Out-Null

    # Minimal QMD (no R/Python blocks to avoid engine deps)
    $qmd = @'
---
title: "Quarto Smoke Test"
format: html
---

# Hello

This page was rendered by **Quarto**.
'@

    $qmdPath = Join-Path $work "test.qmd"
    Set-Content -Path $qmdPath -Value $qmd -Encoding UTF8

    Write-Info "Rendering HTML with Quarto..."
    $proc = Start-Process -FilePath "quarto" -ArgumentList @("render", "`"$qmdPath`"", "--to", "html") -Wait -PassThru
    if ($proc.ExitCode -ne 0) {
        Write-Err "Quarto render failed (exit $($proc.ExitCode))."
        return
    }

    $htmlPath = Join-Path $work "test.html"
    if (Test-Path $htmlPath) {
        Write-Ok "HTML render succeeded: $htmlPath"
        $LASTEXITCODE = 0
    } else {
        Write-Err "Render reported success but output not found: $htmlPath"
        $LASTEXITCODE = 1
    }

} catch {
    Write-Err ("Unexpected error: " + $_.Exception.Message)
    $LASTEXITCODE = 1
}
