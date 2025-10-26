# Script: modules/Install-QuartoExtensions.ps1
# Purpose: Installs useful Quarto extensions for enhanced publishing capabilities

Write-Host "Installing Quarto extensions..." -ForegroundColor Yellow

# Function to test if Quarto is available
function Test-QuartoAvailable {
    try {
        $quartoVersion = quarto --version 2>&1
        if ($quartoVersion -and $quartoVersion -notlike "*not recognized*") {
            return $true
        }
    } catch {
        return $false
    }
    return $false
}

# Function to install a Quarto extension with error handling
function Install-QuartoExtension {
    param(
        [string]$ExtensionName,
        [string]$DisplayName = $ExtensionName
    )
    
    try {
        Write-Host "  Installing $DisplayName..." -ForegroundColor Cyan
        
        # Install extension using quarto add
        $output = quarto add $ExtensionName --no-prompt 2>&1
        
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

try {
    # Check if Quarto is available
    if (-not (Test-QuartoAvailable)) {
        Write-Host "Quarto is not available. Cannot install extensions." -ForegroundColor Red
        Write-Host "Please ensure Quarto is installed and in PATH." -ForegroundColor Yellow
        Write-Host "Quarto extensions installation will be skipped." -ForegroundColor Yellow
        exit 0  # Don't fail the main installation
    }
    
    Write-Host "Quarto is available. Proceeding with extension installation..." -ForegroundColor Green
    
    # Get Quarto version info
    try {
        $quartoVersionInfo = quarto --version 2>$null
        Write-Host "Quarto version: $quartoVersionInfo" -ForegroundColor Gray
    } catch {
        Write-Host "Quarto version: Could not determine" -ForegroundColor Gray
    }
    
    # Define useful extensions for research and data science
    $extensions = @(
        @{ Name = "quarto-ext/lightbox"; Display = "Lightbox (Image galleries)" },
        @{ Name = "quarto-ext/include-code-files"; Display = "Include Code Files" },
        @{ Name = "quarto-ext/fontawesome"; Display = "Font Awesome Icons" },
        @{ Name = "jmbuhr/quarto-qrcode"; Display = "QR Code Generator" },
        @{ Name = "quarto-ext/attribution"; Display = "Attribution (Citations)" }
    )
    
    # Optional/advanced extensions
    $advancedExtensions = @(
        @{ Name = "quarto-ext/shinylive"; Display = "Shiny Live (Interactive R/Python)" },
        @{ Name = "coatless/quarto-webr"; Display = "WebR (R in browser)" },
        @{ Name = "quarto-ext/fancy-text"; Display = "Fancy Text Formatting" }
    )
    
    # Track installation results
    $successCount = 0
    $failureCount = 0
    $totalExtensions = $extensions.Count
    
    Write-Host "Installing $totalExtensions useful Quarto extensions..." -ForegroundColor Yellow
    Write-Host "This may take several minutes depending on internet speed..." -ForegroundColor Gray
    Write-Host ""
    
    # Install basic extensions
    foreach ($ext in $extensions) {
        if (Install-QuartoExtension -ExtensionName $ext.Name -DisplayName $ext.Display) {
            $successCount++
        } else {
            $failureCount++
        }
    }
    
    # Ask about advanced extensions
    Write-Host ""
    Write-Host "Basic extensions completed. Install advanced extensions? (y/N)" -ForegroundColor Yellow
    $installAdvanced = Read-Host
    
    if ($installAdvanced -eq 'y' -or $installAdvanced -eq 'Y') {
        Write-Host "Installing advanced extensions..." -ForegroundColor Yellow
        foreach ($ext in $advancedExtensions) {
            Install-QuartoExtension -ExtensionName $ext.Name -DisplayName $ext.Display | Out-Null
        }
        $totalExtensions += $advancedExtensions.Count
    }
    
    # Summary
    Write-Host ""
    Write-Host ("=" * 70) -ForegroundColor Cyan
    Write-Host "QUARTO EXTENSIONS INSTALLATION SUMMARY" -ForegroundColor Cyan
    Write-Host ("=" * 70) -ForegroundColor Cyan
    
    Write-Host "Total extensions processed: $totalExtensions" -ForegroundColor Gray
    Write-Host "Successfully installed: $successCount" -ForegroundColor Green
    Write-Host "Failed: $failureCount" -ForegroundColor $(if ($failureCount -gt 0) { "Red" } else { "Gray" })
    
    # List installed extensions
    Write-Host ""
    Write-Host "Checking installed Quarto extensions..." -ForegroundColor Cyan
    
    try {
        $installedExtensions = quarto list extensions 2>$null
        if ($installedExtensions) {
            Write-Host "Extensions available in current directory:" -ForegroundColor Green
            Write-Host $installedExtensions -ForegroundColor Gray
        } else {
            Write-Host "No extensions found (may need to be in a Quarto project directory)" -ForegroundColor Gray
        }
    } catch {
        Write-Host "Could not list installed extensions" -ForegroundColor Yellow
    }
    
    # Usage information
    Write-Host ""
    Write-Host "Extension Usage Notes:" -ForegroundColor Cyan
    Write-Host "1. Extensions are typically installed per-project, not globally" -ForegroundColor Yellow
    Write-Host "2. Use 'quarto add <extension>' to add extensions to specific projects" -ForegroundColor Yellow
    Write-Host "3. See extension documentation for usage in .qmd files" -ForegroundColor Yellow
    Write-Host "4. Extensions enhance Quarto's capabilities for specialized output" -ForegroundColor Yellow
    
    # Final status
    if ($failureCount -eq 0) {
        Write-Host ""
        Write-Host "Quarto extensions installation completed successfully!" -ForegroundColor Green
        exit 0
    } elseif ($failureCount -lt ($totalExtensions * 0.5)) {
        Write-Host ""
        Write-Host "Quarto extensions installation completed with minor issues." -ForegroundColor Yellow
        Write-Host "Most extensions are available for use." -ForegroundColor Yellow
        exit 0
    } else {
        Write-Host ""
        Write-Host "Quarto extensions installation completed with several failures." -ForegroundColor Red
        Write-Host "Basic Quarto functionality should still work." -ForegroundColor Red
        
        # Don't fail the main installation
        exit 0
    }
    
} catch {
    Write-Host "ERROR: Unexpected error during Quarto extensions installation." -ForegroundColor Red
    Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Quarto extensions are optional enhancements." -ForegroundColor Yellow
    Write-Host "Basic Quarto functionality should still work without them." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "You can install extensions manually later:" -ForegroundColor Yellow
    Write-Host "1. Navigate to a Quarto project directory" -ForegroundColor Yellow
    Write-Host "2. Run: quarto add <extension-name>" -ForegroundColor Yellow
    Write-Host "3. See: https://quarto.org/docs/extensions/" -ForegroundColor Yellow
    
    # Don't fail the main installation
    exit 0
}