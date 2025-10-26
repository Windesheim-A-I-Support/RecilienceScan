# Script: modules/Test-SystemRequirements.ps1
# Purpose: Validates system meets minimum requirements for data science environment

Write-Host "Validating system requirements..." -ForegroundColor Yellow

# Initialize results
$allRequirementsMet = $true
$warnings = @()
$errors = @()

try {
    # Check Windows version
    Write-Host "Checking Windows version..." -ForegroundColor Cyan
    
    $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
    $windowsVersion = [System.Environment]::OSVersion.Version
    
    Write-Host "  OS: $($osInfo.Caption)" -ForegroundColor Gray
    Write-Host "  Version: $($windowsVersion.Major).$($windowsVersion.Minor) (Build $($osInfo.BuildNumber))" -ForegroundColor Gray
    
    # Check for Windows 10/11 (minimum requirement)
    if ($windowsVersion.Major -lt 10) {
        $errors += "Windows 10 or higher is required. Found: $($osInfo.Caption)"
        $allRequirementsMet = $false
    } else {
        Write-Host "  + Windows version is compatible" -ForegroundColor Green
    }
    
    # Check system architecture
    Write-Host "Checking system architecture..." -ForegroundColor Cyan
    
    $architecture = $osInfo.OSArchitecture
    Write-Host "  Architecture: $architecture" -ForegroundColor Gray
    
    if ($architecture -notlike "*64*") {
        $warnings += "64-bit Windows is recommended for optimal performance. Found: $architecture"
    } else {
        Write-Host "  + 64-bit architecture detected" -ForegroundColor Green
    }
    
    # Check available memory
    Write-Host "Checking system memory..." -ForegroundColor Cyan
    
    $totalMemoryGB = [math]::Round($osInfo.TotalVisibleMemorySize / 1MB, 2)
    $freeMemoryGB = [math]::Round($osInfo.FreePhysicalMemory / 1MB, 2)
    
    Write-Host "  Total RAM: $totalMemoryGB GB" -ForegroundColor Gray
    Write-Host "  Available RAM: $freeMemoryGB GB" -ForegroundColor Gray
    
    if ($totalMemoryGB -lt 4) {
        $errors += "Minimum 4 GB RAM required. Found: $totalMemoryGB GB"
        $allRequirementsMet = $false
    } elseif ($totalMemoryGB -lt 8) {
        $warnings += "8 GB RAM recommended for optimal performance. Found: $totalMemoryGB GB"
        Write-Host "  ! Memory meets minimum but below recommended" -ForegroundColor Yellow
    } else {
        Write-Host "  + Memory requirements met" -ForegroundColor Green
    }
    
    # Check available disk space
    Write-Host "Checking disk space..." -ForegroundColor Cyan
    
    $systemDrive = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object { $_.DeviceID -eq $env:SystemDrive }
    $freeSpaceGB = [math]::Round($systemDrive.FreeSpace / 1GB, 2)
    $totalSpaceGB = [math]::Round($systemDrive.Size / 1GB, 2)
    
    Write-Host "  System drive ($($env:SystemDrive)): $freeSpaceGB GB free of $totalSpaceGB GB total" -ForegroundColor Gray
    
    if ($freeSpaceGB -lt 5) {
        $errors += "Minimum 5 GB free disk space required. Found: $freeSpaceGB GB"
        $allRequirementsMet = $false
    } elseif ($freeSpaceGB -lt 10) {
        $warnings += "10 GB free disk space recommended. Found: $freeSpaceGB GB"
        Write-Host "  ! Disk space meets minimum but below recommended" -ForegroundColor Yellow
    } else {
        Write-Host "  + Disk space requirements met" -ForegroundColor Green
    }
    
    # Check PowerShell version
    Write-Host "Checking PowerShell version..." -ForegroundColor Cyan
    
    $psVersion = $PSVersionTable.PSVersion
    Write-Host "  PowerShell version: $($psVersion.Major).$($psVersion.Minor)" -ForegroundColor Gray
    
    if ($psVersion.Major -lt 5) {
        $errors += "PowerShell 5.0 or higher required. Found: $($psVersion.Major).$($psVersion.Minor)"
        $allRequirementsMet = $false
    } else {
        Write-Host "  + PowerShell version is compatible" -ForegroundColor Green
    }
    
    # Check .NET Framework (required for many tools)
    Write-Host "Checking .NET Framework..." -ForegroundColor Cyan
    
    try {
        $dotNetVersion = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full\" -ErrorAction SilentlyContinue
        if ($dotNetVersion -and $dotNetVersion.Release -ge 461808) {
            Write-Host "  + .NET Framework 4.7.2+ detected" -ForegroundColor Green
        } else {
            $warnings += ".NET Framework 4.7.2 or higher recommended for compatibility"
            Write-Host "  ! .NET Framework version may be outdated" -ForegroundColor Yellow
        }
    } catch {
        $warnings += "Could not verify .NET Framework version"
        Write-Host "  ! Could not verify .NET Framework" -ForegroundColor Yellow
    }
    
    # Check execution policy
    Write-Host "Checking PowerShell execution policy..." -ForegroundColor Cyan
    
    $executionPolicy = Get-ExecutionPolicy
    Write-Host "  Current execution policy: $executionPolicy" -ForegroundColor Gray
    
    if ($executionPolicy -eq "Restricted") {
        $warnings += "PowerShell execution policy is Restricted. This may be updated during installation."
        Write-Host "  ! Execution policy is restricted (will be handled during installation)" -ForegroundColor Yellow
    } else {
        Write-Host "  + Execution policy allows script execution" -ForegroundColor Green
    }
    
    # Check internet connectivity (basic)
    Write-Host "Checking internet connectivity..." -ForegroundColor Cyan
    
    try {
        $webTest = Test-NetConnection -ComputerName "8.8.8.8" -Port 53 -InformationLevel Quiet -WarningAction SilentlyContinue
        if ($webTest) {
            Write-Host "  + Internet connectivity detected" -ForegroundColor Green
        } else {
            $warnings += "Internet connectivity test failed. Downloads may not work."
            Write-Host "  ! Internet connectivity test failed" -ForegroundColor Yellow
        }
    } catch {
        $warnings += "Could not test internet connectivity"
        Write-Host "  ! Could not verify internet connectivity" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "ERROR: Failed to validate system requirements." -ForegroundColor Red
    Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "This may indicate system compatibility issues." -ForegroundColor Yellow
    exit 1
}

# Summary
Write-Host ""
Write-Host ("=" * 60) -ForegroundColor Cyan
Write-Host "SYSTEM REQUIREMENTS SUMMARY" -ForegroundColor Cyan
Write-Host ("=" * 60) -ForegroundColor Cyan

if ($allRequirementsMet) {
    Write-Host "All minimum requirements met!" -ForegroundColor Green
    
    if ($warnings.Count -gt 0) {
        Write-Host ""
        Write-Host "Warnings:" -ForegroundColor Yellow
        foreach ($warning in $warnings) {
            Write-Host "  ! $warning" -ForegroundColor Yellow
        }
        Write-Host ""
        Write-Host "Installation can proceed, but consider addressing warnings for optimal performance." -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "System is ready for data science environment installation." -ForegroundColor Green
    exit 0
    
} else {
    Write-Host "System requirements not met!" -ForegroundColor Red
    
    Write-Host ""
    Write-Host "Errors that must be resolved:" -ForegroundColor Red
    foreach ($errorMsg in $errors) {
        Write-Host "  X $errorMsg" -ForegroundColor Red
    }
    
    if ($warnings.Count -gt 0) {
        Write-Host ""
        Write-Host "Additional warnings:" -ForegroundColor Yellow
        foreach ($warning in $warnings) {
            Write-Host "  ! $warning" -ForegroundColor Yellow
        }
    }
    
    Write-Host ""
    Write-Host "Please resolve the errors above before proceeding with installation." -ForegroundColor Red
    exit 1
}