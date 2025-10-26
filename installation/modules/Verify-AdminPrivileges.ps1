# Script: modules/Verify-AdminPrivileges.ps1
# Purpose: Verifies that the script is running with Administrator privileges
# Critical: This module is essential for the entire installation process

Write-Host "Verifying Administrator privileges..." -ForegroundColor Yellow

try {
    # Get the current Windows identity
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    
    # Check if the current user is in the Administrator role
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if ($isAdmin) {
        Write-Host "Administrator privileges confirmed." -ForegroundColor Green
        Write-Host "User: $($currentUser.Name)" -ForegroundColor Gray
        exit 0  # Success
    } else {
        Write-Host "ERROR: This script requires Administrator privileges." -ForegroundColor Red
        Write-Host "Current user: $($currentUser.Name)" -ForegroundColor Gray
        Write-Host "" -ForegroundColor Red
        Write-Host "Please:" -ForegroundColor Yellow
        Write-Host "1. Close this PowerShell window" -ForegroundColor Yellow
        Write-Host "2. Right-click on PowerShell or Windows Terminal" -ForegroundColor Yellow
        Write-Host "3. Select 'Run as Administrator'" -ForegroundColor Yellow
        Write-Host "4. Re-run the installation script" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Installation cannot continue without Administrator privileges." -ForegroundColor Red
        exit 1  # Failure
    }
} catch {
    Write-Host "ERROR: Failed to verify Administrator privileges." -ForegroundColor Red
    Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
    exit 1  # Failure
}