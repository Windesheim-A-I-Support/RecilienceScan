# Script: modules/Set-ExecutionPolicyForProcess.ps1
# Purpose: Sets PowerShell execution policy for the current process to allow script execution
# Critical: Required for all subsequent PowerShell scripts to run properly

Write-Host "Configuring PowerShell execution policy for installation process..." -ForegroundColor Yellow

try {
    # Get current execution policy for reference
    $currentPolicy = Get-ExecutionPolicy -Scope Process
    Write-Host "Current process execution policy: $currentPolicy" -ForegroundColor Gray
    
    # Check if we already have a permissive policy
    if ($currentPolicy -eq "Bypass" -or $currentPolicy -eq "Unrestricted") {
        Write-Host "Execution policy is already permissive for this process." -ForegroundColor Green
        exit 0
    }
    
    # Set execution policy to Bypass for current process only
    # This is safe because it only affects the current PowerShell session
    Write-Host "Setting execution policy to 'Bypass' for current process..." -ForegroundColor Cyan
    
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
    
    # Verify the change
    $newPolicy = Get-ExecutionPolicy -Scope Process
    
    if ($newPolicy -eq "Bypass") {
        Write-Host "Execution policy successfully set to: $newPolicy" -ForegroundColor Green
        Write-Host "This change only affects the current PowerShell session." -ForegroundColor Gray
        exit 0  # Success
    } else {
        Write-Host "WARNING: Execution policy change verification failed." -ForegroundColor Yellow
        Write-Host "Expected: Bypass, Got: $newPolicy" -ForegroundColor Yellow
        Write-Host "Installation will continue, but some scripts may fail." -ForegroundColor Yellow
        exit 0  # Continue anyway, but with warning
    }
    
} catch {
    Write-Host "ERROR: Failed to set PowerShell execution policy." -ForegroundColor Red
    Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "This may cause subsequent script executions to fail." -ForegroundColor Yellow
    Write-Host "You may need to manually run:" -ForegroundColor Yellow
    Write-Host "Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force" -ForegroundColor Cyan
    
    # Don't exit with failure for execution policy issues
    # as the installation might still work
    exit 0
}