# Script: modules/Configure-VSCodeExtensions.ps1
# Purpose: Installs essential VS Code extensions for data science and research workflows

Write-Host "Configuring VS Code extensions for data science..." -ForegroundColor Yellow

# Function to test if VS Code is available
function Test-VSCodeAvailable {
    try {
        $codeVersion = code --version 2>&1
        if ($codeVersion -and $codeVersion -notlike "*not recognized*") {
            return $true
        }
    } catch {
        return $false
    }
    return $false
}

# Function to install VS Code extension with error handling
function Install-VSCodeExtension {
    param(
        [string]$ExtensionId,
        [string]$DisplayName = $ExtensionId
    )
    
    try {
        Write-Host "  Installing $DisplayName..." -ForegroundColor Cyan
        
        # Install extension silently
        code --install-extension $ExtensionId --force 2>$null
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    + $DisplayName installed successfully" -ForegroundColor Green
            return $true
        } else {
            Write-Host "    - $DisplayName installation failed (exit code: $LASTEXITCODE)" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "    - $DisplayName installation error: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to check if extension is already installed
function Test-VSCodeExtensionInstalled {
    param([string]$ExtensionId)
    
    try {
        $installedExtensions = code --list-extensions 2>$null
        return $installedExtensions -contains $ExtensionId
    } catch {
        return $false
    }
}

try {
    # Check if VS Code is available
    if (-not (Test-VSCodeAvailable)) {
        Write-Host "VS Code is not available. Cannot install extensions." -ForegroundColor Red
        Write-Host "Please ensure VS Code is installed and in PATH." -ForegroundColor Yellow
        exit 1
    }
    
    Write-Host "VS Code is available. Proceeding with extension installation..." -ForegroundColor Green
    
    # Get VS Code version info
    try {
        $vscodeVersion = (code --version 2>$null)[0]
        Write-Host "VS Code version: $vscodeVersion" -ForegroundColor Gray
    } catch {
        Write-Host "VS Code version: Could not determine" -ForegroundColor Gray
    }
    
    # Define essential extensions for data science
    $essentialExtensions = @(
        @{ Id = "ms-python.python"; Display = "Python (Official Python support)" },
        @{ Id = "ms-python.pylint"; Display = "Pylint (Python linting)" },
        @{ Id = "ms-python.flake8"; Display = "Flake8 (Python code quality)" },
        @{ Id = "ms-toolsai.jupyter"; Display = "Jupyter (Notebook support)" },
        @{ Id = "ms-toolsai.jupyter-keymap"; Display = "Jupyter Keymap" },
        @{ Id = "ms-toolsai.jupyter-renderers"; Display = "Jupyter Notebook Renderers" },
        @{ Id = "REditorSupport.r"; Display = "R Language Support" },
        @{ Id = "quarto.quarto"; Display = "Quarto (Publishing system)" },
        @{ Id = "yzhang.markdown-all-in-one"; Display = "Markdown All in One" },
        @{ Id = "davidanson.vscode-markdownlint"; Display = "markdownlint (Markdown linting)" },
        @{ Id = "ms-vscode.vscode-json"; Display = "JSON Language Features" },
        @{ Id = "redhat.vscode-yaml"; Display = "YAML Language Support" },
        @{ Id = "mechatroner.rainbow-csv"; Display = "Rainbow CSV (CSV file highlighting)" },
        @{ Id = "ms-vscode.powershell"; Display = "PowerShell Language Support" },
        @{ Id = "eamodio.gitlens"; Display = "GitLens (Git supercharged)" },
        @{ Id = "github.vscode-pull-request-github"; Display = "GitHub Pull Requests" },
        @{ Id = "ms-vscode-remote.remote-containers"; Display = "Dev Containers" },
        @{ Id = "ms-vscode.theme-tomorrow-night-blue"; Display = "Tomorrow Night Blue Theme" },
        @{ Id = "pkief.material-icon-theme"; Display = "Material Icon Theme" }
    )
    
    # Optional/advanced extensions
    $advancedExtensions = @(
        @{ Id = "ms-vscode.vscode-typescript-next"; Display = "TypeScript Nightly" },
        @{ Id = "bradlc.vscode-tailwindcss"; Display = "Tailwind CSS IntelliSense" },
        @{ Id = "ms-vscode-remote.remote-ssh"; Display = "Remote - SSH" },
        @{ Id = "alefragnani.bookmarks"; Display = "Bookmarks" },
        @{ Id = "streetsidesoftware.code-spell-checker"; Display = "Code Spell Checker" }
    )
    
    # Track installation results
    $successCount = 0
    $failureCount = 0
    $skippedCount = 0
    $totalExtensions = $essentialExtensions.Count
    
    Write-Host "Installing $totalExtensions essential extensions..." -ForegroundColor Yellow
    Write-Host "This may take several minutes depending on internet speed..." -ForegroundColor Gray
    Write-Host ""
    
    # Install essential extensions
    foreach ($ext in $essentialExtensions) {
        # Check if already installed
        if (Test-VSCodeExtensionInstalled -ExtensionId $ext.Id) {
            Write-Host "  $($ext.Display) is already installed" -ForegroundColor Gray
            $skippedCount++
        } else {
            if (Install-VSCodeExtension -ExtensionId $ext.Id -DisplayName $ext.Display) {
                $successCount++
            } else {
                $failureCount++
            }
        }
    }
    
    # Ask about advanced extensions
    Write-Host ""
    Write-Host "Essential extensions completed. Install advanced extensions? (y/N)" -ForegroundColor Yellow
    $installAdvanced = Read-Host
    
    if ($installAdvanced -eq 'y' -or $installAdvanced -eq 'Y') {
        Write-Host "Installing advanced extensions..." -ForegroundColor Yellow
        foreach ($ext in $advancedExtensions) {
            if (Test-VSCodeExtensionInstalled -ExtensionId $ext.Id) {
                Write-Host "  $($ext.Display) is already installed" -ForegroundColor Gray
            } else {
                Install-VSCodeExtension -ExtensionId $ext.Id -DisplayName $ext.Display | Out-Null
            }
        }
        $totalExtensions += $advancedExtensions.Count
    }
    
    # Summary
    Write-Host ""
    Write-Host ("=" * 70) -ForegroundColor Cyan
    Write-Host "VS CODE EXTENSIONS INSTALLATION SUMMARY" -ForegroundColor Cyan
    Write-Host ("=" * 70) -ForegroundColor Cyan
    
    Write-Host "Total extensions processed: $totalExtensions" -ForegroundColor Gray
    Write-Host "Successfully installed: $successCount" -ForegroundColor Green
    Write-Host "Already installed (skipped): $skippedCount" -ForegroundColor Gray
    Write-Host "Failed: $failureCount" -ForegroundColor $(if ($failureCount -gt 0) { "Red" } else { "Gray" })
    
    # List all installed extensions
    Write-Host ""
    Write-Host "Checking final extension status..." -ForegroundColor Cyan
    
    try {
        $installedExtensions = code --list-extensions 2>$null
        $dataScientistExtensions = $essentialExtensions | Where-Object { $installedExtensions -contains $_.Id }
        
        Write-Host "Data science extensions installed: $($dataScientistExtensions.Count)" -ForegroundColor Green
        foreach ($ext in $dataScientistExtensions) {
            Write-Host "  + $($ext.Display)" -ForegroundColor Green
        }
        
        $missingExtensions = $essentialExtensions | Where-Object { $installedExtensions -notcontains $_.Id }
        if ($missingExtensions.Count -gt 0) {
            Write-Host ""
            Write-Host "Extensions that failed to install:" -ForegroundColor Yellow
            foreach ($ext in $missingExtensions) {
                Write-Host "  - $($ext.Display)" -ForegroundColor Yellow
            }
        }
    } catch {
        Write-Host "Could not verify final extension status" -ForegroundColor Yellow
    }
    
    # Configuration recommendations
    Write-Host ""
    Write-Host "VS Code Configuration Recommendations:" -ForegroundColor Cyan
    Write-Host "1. Configure Python interpreter path if needed" -ForegroundColor Yellow
    Write-Host "2. Set up R path in settings if R extension was installed" -ForegroundColor Yellow
    Write-Host "3. Configure Git user name and email for GitHub integration" -ForegroundColor Yellow
    Write-Host "4. Consider setting up SSH keys for remote development" -ForegroundColor Yellow
    
    # Final status
    if ($failureCount -eq 0) {
        Write-Host ""
        Write-Host "VS Code is configured for data science development!" -ForegroundColor Green
        exit 0
    } elseif ($failureCount -lt ($totalExtensions * 0.3)) {
        Write-Host ""
        Write-Host "VS Code configuration completed with minor issues." -ForegroundColor Yellow
        Write-Host "Most essential extensions are installed and ready to use." -ForegroundColor Yellow
        exit 0
    } else {
        Write-Host ""
        Write-Host "VS Code configuration completed with several failures." -ForegroundColor Red
        Write-Host "You may need to install some extensions manually." -ForegroundColor Red
        exit 0
    }
    
} catch {
    Write-Host "ERROR: Unexpected error during VS Code extension installation." -ForegroundColor Red
    Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "You can install extensions manually by:" -ForegroundColor Yellow
    Write-Host "1. Opening VS Code" -ForegroundColor Yellow
    Write-Host "2. Going to Extensions (Ctrl+Shift+X)" -ForegroundColor Yellow
    Write-Host "3. Searching for: Python, Jupyter, R, Quarto, GitLens" -ForegroundColor Yellow
    exit 1
}