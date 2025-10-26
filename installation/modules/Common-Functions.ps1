# Framework: Common-InstallationFunctions.ps1
# Purpose: Shared functions implementing lessons learned from real-world usage

# LESSON 1: Keep it simple - create reusable patterns
function Install-WithPackageManager {
    param(
        [string]$SoftwareName,
        [hashtable]$PackageNames,  # @{ choco = "packagename"; winget = "Publisher.Package"; scoop = "packagename" }
        [string]$TestCommand,      # Command to test if installed (e.g., "python --version")
        [string]$ManualUrl        # Fallback URL for manual installation
    )
    
    Write-Host "Installing $SoftwareName..." -ForegroundColor Yellow
    
    # Test if already installed
    if ($TestCommand -and (Test-Command $TestCommand)) {
        Write-Host "$SoftwareName is already installed." -ForegroundColor Green
        return $true
    }
    
    # Try package managers in order of reliability
    $managers = @(
        @{ Command = "choco"; InstallCmd = "choco install {0} --yes --force"; Package = $PackageNames.choco },
        @{ Command = "winget"; InstallCmd = "winget install {0} --accept-package-agreements --accept-source-agreements"; Package = $PackageNames.winget },
        @{ Command = "scoop"; InstallCmd = "scoop install {0}"; Package = $PackageNames.scoop }
    )
    
    foreach ($manager in $managers) {
        if ($manager.Package -and (Get-Command $manager.Command -ErrorAction SilentlyContinue)) {
            Write-Host "Installing via $($manager.Command)..." -ForegroundColor Cyan
            try {
                $installCommand = $manager.InstallCmd -f $manager.Package
                Invoke-Expression $installCommand
                
                if ($LASTEXITCODE -eq 0) {
                    Update-SessionPath
                    Start-Sleep -Seconds 3
                    
                    if (-not $TestCommand -or (Test-Command $TestCommand)) {
                        Write-Host "$SoftwareName installed successfully!" -ForegroundColor Green
                        return $true
                    }
                }
            } catch {
                Write-Host "$($manager.Command) installation failed: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
    }
    
    # All package managers failed
    Write-Host "Package manager installation failed." -ForegroundColor Red
    if ($ManualUrl) {
        Write-Host "Manual installation required: $ManualUrl" -ForegroundColor Yellow
    }
    return $false
}

function Test-Command {
    param([string]$Command)
    try {
        # Handle complex commands like R's slave mode
        if ($Command -like '*"*') {
            # Use Invoke-Expression for quoted commands
            $result = Invoke-Expression $Command 2>$null
            return $LASTEXITCODE -eq 0 -and $result
        } else {
            # Simple command splitting
            $parts = $Command.Split(' ')
            $null = & $parts[0] @($parts[1..100]) 2>&1
            return $LASTEXITCODE -eq 0
        }
    } catch {
        return $false
    }
}

function Update-SessionPath {
    $systemPath = [Environment]::GetEnvironmentVariable("PATH", [EnvironmentVariableTarget]::Machine)
    $userPath = [Environment]::GetEnvironmentVariable("PATH", [EnvironmentVariableTarget]::User)
    if ($userPath) {
        $env:PATH = "$systemPath;$userPath"
    } else {
        $env:PATH = $systemPath
    }
}

# LESSON 2: Simplified installation scripts using the framework

# Simplified Python Installation
function Install-Python {
    Install-WithPackageManager -SoftwareName "Python" -PackageNames @{
        choco = "python"
        winget = "Python.Python.3.12"  # Use latest major version
        scoop = "python"
    } -TestCommand "python --version" -ManualUrl "https://www.python.org/downloads/"
}

# Simplified R Installation (corrected for Windows)
function Install-R {
    Install-WithPackageManager -SoftwareName "R" -PackageNames @{
        choco = "r.project"
        winget = "RProject.R"
        scoop = "r"
    } -TestCommand 'R --slave -e "cat(R.version.string)"' -ManualUrl "https://cran.r-project.org/bin/windows/base/"
}

# Simplified Quarto Installation (applying lessons learned)
function Install-Quarto {
    Install-WithPackageManager -SoftwareName "Quarto" -PackageNames @{
        choco = "quarto"
        winget = "Posit.Quarto"
        scoop = "quarto"
    } -TestCommand "quarto --version" -ManualUrl "https://quarto.org/docs/get-started/"
}

# Simplified Git Installation
function Install-Git {
    Install-WithPackageManager -SoftwareName "Git" -PackageNames @{
        choco = "git"
        winget = "Git.Git"
        scoop = "git"
    } -TestCommand "git --version" -ManualUrl "https://git-scm.com/download/win"
}

# LESSON 3: Main installer script applying all lessons
function Start-DevelopmentEnvironmentSetup {
    Write-Host "=== DEVELOPMENT ENVIRONMENT SETUP ===" -ForegroundColor Cyan
    Write-Host "Applying lessons learned from real-world usage patterns" -ForegroundColor Gray
    Write-Host ""
    
    # Results tracking
    $results = @{
        Successful = @()
        Failed = @()
    }
    
    # Essential tools installation (simplified approach)
    $installations = @(
        @{ Name = "Git"; Function = { Install-Git } },
        @{ Name = "Python"; Function = { Install-Python } },
        @{ Name = "R"; Function = { Install-R } },
        @{ Name = "Quarto"; Function = { Install-Quarto } }
    )
    
    foreach ($install in $installations) {
        Write-Host "[$($install.Name)]" -ForegroundColor Yellow -NoNewline
        Write-Host " Starting installation..." -ForegroundColor Gray
        
        try {
            if (& $install.Function) {
                $results.Successful += $install.Name
                Write-Host "✓ $($install.Name) - SUCCESS" -ForegroundColor Green
            } else {
                $results.Failed += $install.Name
                Write-Host "✗ $($install.Name) - FAILED" -ForegroundColor Red
            }
        } catch {
            $results.Failed += $install.Name
            Write-Host "✗ $($install.Name) - ERROR: $($_.Exception.Message)" -ForegroundColor Red
        }
        Write-Host ""
    }
    
    # Summary (lesson: provide clear feedback)
    Write-Host "=== INSTALLATION SUMMARY ===" -ForegroundColor Cyan
    Write-Host "Successful: $($results.Successful.Count) - $($results.Successful -join ', ')" -ForegroundColor Green
    Write-Host "Failed: $($results.Failed.Count) - $($results.Failed -join ', ')" -ForegroundColor Red
    
    if ($results.Failed.Count -eq 0) {
        Write-Host ""
        Write-Host "🎉 All installations completed successfully!" -ForegroundColor Green
        Write-Host "Your development environment is ready." -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "⚠️  Some installations failed. Check manual installation links above." -ForegroundColor Yellow
    }
}

# LESSON 4: Keep package management simple
function Install-PackageManager {
    param([string]$Manager)
    
    switch ($Manager) {
        "chocolatey" {
            if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
                Write-Host "Installing Chocolatey..." -ForegroundColor Cyan
                Set-ExecutionPolicy Bypass -Scope Process -Force
                [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
                Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
            }
        }
        "scoop" {
            if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
                Write-Host "Installing Scoop..." -ForegroundColor Cyan
                Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
                Invoke-RestMethod get.scoop.sh | Invoke-Expression
            }
        }
        default {
            Write-Host "Package manager '$Manager' not supported in simple installer" -ForegroundColor Yellow
        }
    }
}

# Usage Examples:
# Install-PackageManager -Manager "chocolatey"
# Start-DevelopmentEnvironmentSetup