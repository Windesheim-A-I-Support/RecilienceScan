# Script: modules/Install-Pandoc.ps1
# Purpose: Installs Pandoc document converter (often bundled with Quarto)

Write-Host "Checking Pandoc document converter installation..." -ForegroundColor Yellow

# Function to test if Pandoc is available
function Test-PandocAvailable {
    try {
        $pandocVersion = pandoc --version 2>&1
        if ($pandocVersion -and $pandocVersion -match "pandoc") {
            return $true
        }
    } catch {
        return $false
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

# Function to refresh PATH for current session
function Update-SessionPath {
    $systemPath = [Environment]::GetEnvironmentVariable("PATH", [EnvironmentVariableTarget]::Machine)
    $userPath = [Environment]::GetEnvironmentVariable("PATH", [EnvironmentVariableTarget]::User)
    
    if ($userPath) {
        $env:PATH = "$systemPath;$userPath"
    } else {
        $env:PATH = $systemPath
    }
}

try {
    # Check if Pandoc is already available
    Write-Host "Checking for existing Pandoc installation..." -ForegroundColor Cyan
    
    if (Test-PandocAvailable) {
        Write-Host "Pandoc is already installed and working." -ForegroundColor Green
        
        # Show Pandoc version info
        try {
            $pandocVersionInfo = pandoc --version 2>$null | Select-Object -First 1
            Write-Host "Pandoc version: $pandocVersionInfo" -ForegroundColor Gray
        } catch {
            Write-Host "Pandoc is available but version check failed" -ForegroundColor Yellow
        }
        
        exit 0  # Already installed
    }
    
    Write-Host "Pandoc not found. Checking installation options..." -ForegroundColor Yellow
    
    # Check if Quarto is available (Pandoc often comes with Quarto)
    Write-Host "Checking if Pandoc is available via Quarto..." -ForegroundColor Cyan
    
    try {
        $quartoVersion = quarto --version 2>$null
        if ($quartoVersion) {
            Write-Host "Quarto is installed. Refreshing PATH in case Pandoc is bundled..." -ForegroundColor Cyan
            Update-SessionPath
            Start-Sleep -Seconds 1
            
            if (Test-PandocAvailable) {
                Write-Host "Pandoc found via Quarto installation!" -ForegroundColor Green
                $pandocVersionInfo = pandoc --version 2>$null | Select-Object -First 1
                Write-Host "Pandoc version: $pandocVersionInfo" -ForegroundColor Gray
                exit 0
            }
        }
    } catch {
        Write-Host "Quarto not available or PATH refresh didn't help" -ForegroundColor Gray
    }
    
    # Install Pandoc via Chocolatey if available
    if (Test-ChocolateyAvailable) {
        Write-Host "Installing Pandoc via Chocolatey..." -ForegroundColor Cyan
        Write-Host "This may take a few minutes..." -ForegroundColor Gray
        
        try {
            Write-Host "Executing: choco install pandoc -y --no-progress" -ForegroundColor Gray
            choco install pandoc -y --no-progress
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Pandoc installation command completed successfully." -ForegroundColor Green
                
                # Refresh PATH and verify
                Update-SessionPath
                Start-Sleep -Seconds 2
                
                if (Test-PandocAvailable) {
                    Write-Host "Pandoc installation verified!" -ForegroundColor Green
                    $pandocVersionInfo = pandoc --version 2>$null | Select-Object -First 1
                    Write-Host "Pandoc version: $pandocVersionInfo" -ForegroundColor Gray
                    exit 0
                } else {
                    Write-Host "Pandoc installation completed but not immediately available." -ForegroundColor Yellow
                    Write-Host "May require a new terminal session to be recognized." -ForegroundColor Yellow
                    exit 0
                }
            } else {
                Write-Host "Pandoc installation via Chocolatey failed with exit code: $LASTEXITCODE" -ForegroundColor Red
                throw "Chocolatey installation failed"
            }
        } catch {
            Write-Host "Chocolatey installation failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "Chocolatey not available for Pandoc installation." -ForegroundColor Yellow
    }
    
    # Manual installation fallback
    Write-Host ""
    Write-Host "Manual Pandoc installation options:" -ForegroundColor Yellow
    Write-Host "1. Download from: https://github.com/jgm/pandoc/releases" -ForegroundColor Yellow
    Write-Host "2. Install via winget: winget install pandoc" -ForegroundColor Yellow
    Write-Host "3. Pandoc may already be bundled with Quarto (try restarting terminal)" -ForegroundColor Yellow
    Write-Host ""
    
    # Check if this is critical for the workflow
    Write-Host "Note: Pandoc is often used by Quarto automatically." -ForegroundColor Cyan
    Write-Host "If Quarto is working, document conversion may still function properly." -ForegroundColor Cyan
    
    # Don't fail the installation - Pandoc might be available via Quarto even if not in PATH
    Write-Host "Continuing installation without standalone Pandoc..." -ForegroundColor Green
    exit 0
    
} catch {
    Write-Host "ERROR: Unexpected error during Pandoc installation check." -ForegroundColor Red
    Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Pandoc installation is not critical if Quarto is working." -ForegroundColor Yellow
    Write-Host "Document conversion may still work through Quarto." -ForegroundColor Yellow
    
    # Don't fail the installation
    exit 0
}