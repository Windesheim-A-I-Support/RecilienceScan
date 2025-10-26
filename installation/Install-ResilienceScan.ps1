# Main-Installer.ps1 - Production Data Science Environment Installer
# Comprehensive installer for Windows data science and research pipeline environment
# REQUIRES: Administrator privileges

param(
    [switch]$SkipChecks = $false,
    [switch]$ForceReinstall = $false,
    [switch]$Verbose = $false,
    [string]$Profile = "",
    [string]$LogPath = ""
)

#Requires -RunAsAdministrator

Clear-Host
$AsciiArt = @"
███████╗██╗   ██╗██████╗ ██████╗ ██╗  ██╗   ██╗     ██████╗██╗  ██╗ █████╗ ██╗███╗   ██╗
██╔════╝██║   ██║██╔══██╗██╔══██╗██║  ╚██╗ ██╔╝    ██╔════╝██║  ██║██╔══██╗██║████╗  ██║
███████╗██║   ██║██████╔╝██████╔╝██║   ╚████╔╝     ██║     ███████║███████║██║██╔██╗ ██║
╚════██║██║   ██║██╔═══╝ ██╔═══╝ ██║    ╚██╔╝      ██║     ██╔══██║██╔══██║██║██║╚██╗██║
███████║╚██████╔╝██║     ██║     ███████╗██║       ╚██████╗██║  ██║██║  ██║██║██║ ╚████║
╚══════╝ ╚═════╝ ╚═╝     ╚═╝     ╚══════╝╚═╝        ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝

███████╗██╗███╗   ██╗ █████╗ ███╗   ██╗ ██████╗███████╗
██╔════╝██║████╗  ██║██╔══██╗████╗  ██║██╔════╝██╔════╝
█████╗  ██║██╔██╗ ██║███████║██╔██╗ ██║██║     █████╗  
██╔══╝  ██║██║╚██╗██║██╔══██║██║╚██╗██║██║     ██╔══╝  
██║     ██║██║ ╚████║██║  ██║██║ ╚████║╚██████╗███████╗
╚═╝     ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝╚══════╝

           L E C T O R A A T   S U P P L Y   C H A I N   F I N A N C E
      Comprehensive Data Science & Research Pipeline Environment Setup
"@

Write-Host $AsciiArt -ForegroundColor Cyan
Write-Host ("=" * 80)
Write-Host "Version 2.0 - Production Environment Installer" -ForegroundColor Yellow
Write-Host "Automated setup for Data Science, AI/ML, and Research workflows on Windows" -ForegroundColor Yellow
Write-Host ("=" * 80)

# --- Global Configuration ---
$Global:ScriptStartTime = Get-Date
$Global:MainInstallerBaseDir = $PSScriptRoot
$Global:ModulesDir = Join-Path -Path $Global:MainInstallerBaseDir -ChildPath "modules"
$Global:RequirementsDir = Join-Path -Path $Global:MainInstallerBaseDir -ChildPath "requirements"
$Global:AssetsDir = Join-Path -Path $Global:MainInstallerBaseDir -ChildPath "assets"

# Logging configuration
if (-not $LogPath) {
    $LogPath = Join-Path $Global:MainInstallerBaseDir "Installation-Report-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
}
$Global:LogPath = $LogPath

# Installation tracking
$Global:InstallationResults = @{}
$Global:OverallSuccess = $true
$Global:CriticalFailureOccurred = $false
$Global:ModulesExecuted = 0
$Global:ModulesSucceeded = 0
$Global:ModulesFailed = 0
$Global:ModulesSkipped = 0

# Profile definitions with comprehensive component mapping
# Add this new profile to your $Global:ProfileDefinitions in Main-Installer.ps1

# Profile definitions with comprehensive component mapping
$Global:ProfileDefinitions = @{
    "Essential" = @{
        Description = "Basic tools for coding and version control"
        Components = @("Prerequisites", "PackageManagers", "Git", "VSCode", "WindowsTerminal")
    }
    "RecilienceScan" = @{
        Description = "Minimal setup for RecilienceScan report automation pipeline"
        Components = @("Prerequisites", "PackageManagers", "BasicPackages", "VSCode", "R",  "Git", "Python", "Quarto")
    }
    "Minimal" = @{
        Description = "Document authoring with Python/R basics and Quarto"
        Components = @("Prerequisites", "PackageManagers", "Git", "VSCode", "Python", "R", "Quarto", "BasicPackages")
    }
    "DataScience" = @{
        Description = "Complete data science environment with Python, R, and analysis tools"
        Components = @("Prerequisites", "PackageManagers", "Git", "VSCode", "WindowsTerminal", "Python", "R", "RStudio", "Quarto", "DataSciencePackages", "DatabaseTools", "Utilities")
    }
    "AI_ML" = @{
        Description = "Advanced AI/ML stack with deep learning frameworks and NLP tools"
        Components = @("Prerequisites", "PackageManagers", "Git", "VSCode", "WindowsTerminal", "Python", "R", "RStudio", "Quarto", "DataSciencePackages", "AI_MLPackages", "NLPPackages", "DatabaseTools", "Utilities")
    }
    "BigData" = @{
        Description = "Big data processing with Spark, distributed computing, and cloud tools"
        Components = @("Prerequisites", "PackageManagers", "Git", "VSCode", "WindowsTerminal", "Python", "R", "RStudio", "Quarto", "DataSciencePackages", "AI_MLPackages", "BigDataStack", "DatabaseTools", "Utilities")
    }
    "Full" = @{
        Description = "Complete installation with all available components"
        Components = @("Prerequisites", "PackageManagers", "Git", "VSCode", "WindowsTerminal", "Python", "R", "RStudio", "Quarto", "DataSciencePackages", "AI_MLPackages", "NLPPackages", "BigDataStack", "DatabaseTools", "Utilities", "CustomFonts", "OptionalTools")
    }
}

# --- Logging Functions ---
Function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [switch]$NoConsole
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Write to log file
    try {
        Add-Content -Path $Global:LogPath -Value $logMessage -Encoding UTF8
    } catch {
        # Fallback if logging fails
    }
    
    # Write to console unless suppressed
    if (-not $NoConsole) {
        switch ($Level) {
            "ERROR" { Write-Host $logMessage -ForegroundColor Red }
            "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
            "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
            "INFO" { Write-Host $logMessage -ForegroundColor White }
            default { Write-Host $logMessage }
        }
    }
}

Function Write-Section {
    param([string]$Title)
    Write-Log ""
    Write-Log ("=" * 80)
    Write-Log "  $Title"
    Write-Log ("=" * 80)
}

# --- Helper Functions ---
Function Test-ComponentIncluded {
    param([string]$ComponentName)
    $profileComponents = $Global:ProfileDefinitions[$Global:SelectedProfile].Components
    return $ComponentName -in $profileComponents
}

Function Invoke-ModuleWithErrorHandling {
    param(
        [string]$ModuleName,
        [string]$Description,
        [string]$Component,
        [switch]$Critical = $false,
        [hashtable]$Parameters = @{}
    )
    
    # Check if this component should be installed for the selected profile
    if (-not (Test-ComponentIncluded -ComponentName $Component)) {
        Write-Log "Skipping $Description (not included in $($Global:SelectedProfile) profile)" -Level "INFO"
        $Global:InstallationResults[$ModuleName] = @{
            Status = "Skipped"
            Reason = "Not included in profile"
            Component = $Component
            Description = $Description
        }
        $Global:ModulesSkipped++
        return $true
    }
    
    # Skip if previous critical failure occurred and this is critical
    if ($Global:CriticalFailureOccurred -and $Critical -and -not $ForceReinstall) {
        Write-Log "Skipping critical module $Description due to previous critical failure" -Level "WARNING"
        $Global:InstallationResults[$ModuleName] = @{
            Status = "Skipped"
            Reason = "Previous critical failure"
            Component = $Component
            Description = $Description
        }
        $Global:ModulesSkipped++
        return $false
    }
    
    $Global:ModulesExecuted++
    Write-Log "Executing: $Description..." -Level "INFO"
    
    $ModulePath = Join-Path -Path $Global:ModulesDir -ChildPath $ModuleName
    $success = $false
    $errorMessage = ""
    $executionTime = 0
    
    try {
        # Check if module exists
        if (-not (Test-Path $ModulePath)) {
            throw "Module file not found: $ModulePath"
        }
        
        # Execute module with timing
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        
        # Set global variables that modules might need
        $Global:CurrentModuleParameters = $Parameters
        $Global:ForceReinstallFlag = $ForceReinstall
        $Global:VerboseFlag = $Verbose
        
        # Change to modules directory and execute
        $originalLocation = Get-Location
        try {
            Set-Location $Global:ModulesDir
            
            # Execute the module script
            & $ModulePath
            
            $exitCode = $LASTEXITCODE
            if ($exitCode -eq 0 -or $null -eq $exitCode) {
                $success = $true
            } else {
                throw "Module exited with code: $exitCode"
            }
        } finally {
            Set-Location $originalLocation
        }
        
        $stopwatch.Stop()
        $executionTime = $stopwatch.ElapsedMilliseconds
        
        Write-Log "Completed: $Description (${executionTime}ms)" -Level "SUCCESS"
        
        $Global:InstallationResults[$ModuleName] = @{
            Status = "Success"
            Component = $Component
            Description = $Description
            ExecutionTime = $executionTime
            ExitCode = $exitCode
        }
        $Global:ModulesSucceeded++
        
    } catch {
        if ($stopwatch) { $stopwatch.Stop() }
        $executionTime = if ($stopwatch) { $stopwatch.ElapsedMilliseconds } else { 0 }
        $errorMessage = $_.Exception.Message
        
        Write-Log "Failed: $Description - $errorMessage" -Level "ERROR"
        
        $Global:InstallationResults[$ModuleName] = @{
            Status = "Failed"
            Component = $Component
            Description = $Description
            ExecutionTime = $executionTime
            ErrorMessage = $errorMessage
            ExitCode = $LASTEXITCODE
        }
        $Global:ModulesFailed++
        $Global:OverallSuccess = $false
        
        if ($Critical) {
            $Global:CriticalFailureOccurred = $true
            Write-Log "CRITICAL FAILURE in $Description - This may affect subsequent installations" -Level "ERROR"
        }
    }
    
    return $success
}

Function Show-ProgressSummary {
    param([string]$Phase, [int]$Current, [int]$Total)
    $percent = [math]::Round(($Current / $Total) * 100, 1)
    Write-Progress -Activity "Data Science Environment Setup" -Status "$Phase ($Current/$Total modules)" -PercentComplete $percent
    Write-Log "Progress: $Phase - $Current/$Total modules completed (${percent}%)" -Level "INFO"
}

# --- Profile Selection ---
if ($Profile -and $Global:ProfileDefinitions.ContainsKey($Profile)) {
    $Global:SelectedProfile = $Profile
    Write-Log "Profile specified via parameter: $Profile" -Level "INFO"
} else {
    Write-Section "INSTALLATION PROFILE SELECTION"
    
    Write-Host "`nAvailable Installation Profiles:" -ForegroundColor Cyan
    $profileKeys = $Global:ProfileDefinitions.Keys | Sort-Object
    for ($i = 0; $i -lt $profileKeys.Count; $i++) {
        $key = $profileKeys[$i]
        $profile = $Global:ProfileDefinitions[$key]
        Write-Host "[$($i+1)] $key" -ForegroundColor White
        Write-Host "    $($profile.Description)" -ForegroundColor Gray
        Write-Host "    Components: $($profile.Components.Count) modules" -ForegroundColor Gray
        Write-Host ""
    }
    
    do {
        $selection = Read-Host "Select profile (1-$($profileKeys.Count)) or Q to quit"
        if ($selection -eq 'Q' -or $selection -eq 'q') {
            Write-Log "Installation cancelled by user" -Level "INFO"
            exit 0
        }
        
        if ($selection -match '^\d+$' -and [int]$selection -ge 1 -and [int]$selection -le $profileKeys.Count) {
            $Global:SelectedProfile = $profileKeys[[int]$selection - 1]
            break
        }
        
        Write-Host "Invalid selection. Please enter a number between 1 and $($profileKeys.Count), or Q to quit." -ForegroundColor Red
    } while ($true)
}

$selectedProfileInfo = $Global:ProfileDefinitions[$Global:SelectedProfile]
Write-Log "Selected Profile: $($Global:SelectedProfile)" -Level "SUCCESS"
Write-Log "Description: $($selectedProfileInfo.Description)" -Level "INFO"
Write-Log "Components to install: $($selectedProfileInfo.Components -join ', ')" -Level "INFO"

# --- Pre-Installation Summary ---
Write-Section "PRE-INSTALLATION SUMMARY"
Write-Log "Installation Target: $($Global:SelectedProfile) Profile" -Level "INFO"
Write-Log "Base Directory: $($Global:MainInstallerBaseDir)" -Level "INFO"
Write-Log "Modules Directory: $($Global:ModulesDir)" -Level "INFO"
Write-Log "Requirements Directory: $($Global:RequirementsDir)" -Level "INFO"
Write-Log "Log File: $($Global:LogPath)" -Level "INFO"
Write-Log "Force Reinstall: $ForceReinstall" -Level "INFO"
Write-Log "Skip Checks: $SkipChecks" -Level "INFO"

if (-not $SkipChecks) {
    Write-Host "`nPress Enter to begin installation, or Ctrl+C to cancel..." -ForegroundColor Yellow
    Read-Host
}

# --- INSTALLATION EXECUTION ---
Write-Section "BEGINNING INSTALLATION PROCESS"
$installationStartTime = Get-Date

# PART 1: System Prerequisites & Initial Setup
Write-Section "PART 1: SYSTEM PREREQUISITES & INITIAL SETUP"
Invoke-ModuleWithErrorHandling -ModuleName "Verify-AdminPrivileges.ps1" -Description "Administrator Privileges Verification" -Component "Prerequisites" -Critical
Invoke-ModuleWithErrorHandling -ModuleName "Set-ExecutionPolicyForProcess.ps1" -Description "PowerShell Execution Policy Configuration" -Component "Prerequisites" -Critical
Invoke-ModuleWithErrorHandling -ModuleName "Test-InternetConnection.ps1" -Description "Internet Connectivity Check" -Component "Prerequisites"
Invoke-ModuleWithErrorHandling -ModuleName "Test-SystemRequirements.ps1" -Description "System Requirements Validation" -Component "Prerequisites"

Show-ProgressSummary -Phase "System Prerequisites" -Current 4 -Total 50

# PART 2: Core Package Managers
Write-Section "PART 2: PACKAGE MANAGERS & SYSTEM TOOLS"
Invoke-ModuleWithErrorHandling -ModuleName "Install-Chocolatey.ps1" -Description "Chocolatey Package Manager" -Component "PackageManagers" -Critical
Invoke-ModuleWithErrorHandling -ModuleName "Install-Scoop.ps1" -Description "Scoop Package Manager" -Component "PackageManagers"
Invoke-ModuleWithErrorHandling -ModuleName "Install-Winget.ps1" -Description "Winget Package Manager" -Component "PackageManagers"
Invoke-ModuleWithErrorHandling -ModuleName "Install-Corda.ps1" -Description "Corda Package" -Component "PackageManagers"
Invoke-ModuleWithErrorHandling -ModuleName "Install-PortableApps.ps1" -Description "Windows Package Manager Verification" -Component "PackageManagers"
Invoke-ModuleWithErrorHandling -ModuleName "Install-PortableApps.ps1" -Description "Windows Package Manager Verification" -Component "PackageManagers"
Invoke-ModuleWithErrorHandling -ModuleName "Install-GitHubCLI.ps1" -Description "Windows Package Manager Verification" -Component "PackageManagers"

Invoke-ModuleWithErrorHandling -ModuleName "Test-WingetAvailability.ps1" -Description "Windows Package Manager Verification" -Component "PackageManagers"

# Invoke-ModuleWithErrorHandling -ModuleName "Refresh-PathAndEnvironment.ps1" -Description "Environment Variables Refresh" -Component "PackageManagers" -Critical

Show-ProgressSummary -Phase "Package Managers" -Current 8 -Total 50

# PART 3: Essential Developer Tools
Write-Section "PART 3: ESSENTIAL DEVELOPER TOOLS"
Invoke-ModuleWithErrorHandling -ModuleName "Install-Git.ps1" -Description "Git Version Control System" -Component "Git" -Critical
Invoke-ModuleWithErrorHandling -ModuleName "Install-VSCode.ps1" -Description "Visual Studio Code Editor" -Component "VSCode"
Invoke-ModuleWithErrorHandling -ModuleName "Install-WindowsTerminal.ps1" -Description "Windows Terminal" -Component "WindowsTerminal"
Invoke-ModuleWithErrorHandling -ModuleName "Install-7Zip.ps1" -Description "7-Zip File Archiver" -Component "Utilities"
Invoke-ModuleWithErrorHandling -ModuleName "Install-DrawIO.ps1" -Description "Draw.io Desktop Diagramming" -Component "Utilities"

Show-ProgressSummary -Phase "Developer Tools" -Current 13 -Total 50

# PART 4: Python Core Environment
Write-Section "PART 4: PYTHON ENVIRONMENT SETUP"
Invoke-ModuleWithErrorHandling -ModuleName "Install-PythonCore.ps1" -Description "Python Interpreter & Package Manager" -Component "Python" -Critical
Invoke-ModuleWithErrorHandling -ModuleName "Install-PythonBasicPackages.ps1" -Description "Python Essential Packages" -Component "BasicPackages"
Invoke-ModuleWithErrorHandling -ModuleName "Install-PythonDataSciencePackages.ps1" -Description "Python Data Science Stack" -Component "DataSciencePackages"
Invoke-ModuleWithErrorHandling -ModuleName "Install-PythonAIMLPackages.ps1" -Description "Python AI/ML Frameworks" -Component "AI_MLPackages"
Invoke-ModuleWithErrorHandling -ModuleName "Install-PythonNLPPackages.ps1" -Description "Python NLP & Text Processing" -Component "NLPPackages"

Show-ProgressSummary -Phase "Python Environment" -Current 18 -Total 50

# PART 5: R Environment Setup
Write-Section "PART 5: R STATISTICAL ENVIRONMENT SETUP"
Invoke-ModuleWithErrorHandling -ModuleName "Install-RCore.ps1" -Description "R Statistical Computing Language" -Component "R" -Critical
Invoke-ModuleWithErrorHandling -ModuleName "Install-RTools.ps1" -Description "R Development Tools (Rtools)" -Component "R"
Invoke-ModuleWithErrorHandling -ModuleName "Install-RBasicPackages.ps1" -Description "R Essential Packages" -Component "BasicPackages"
Invoke-ModuleWithErrorHandling -ModuleName "Install-RDataSciencePackages.ps1" -Description "R Data Science & Visualization" -Component "DataSciencePackages"
Invoke-ModuleWithErrorHandling -ModuleName "Install-RAdvancedPackages.ps1" -Description "R Advanced Statistics & ML" -Component "AI_MLPackages"

Show-ProgressSummary -Phase "R Environment" -Current 23 -Total 50

# PART 6: Integrated Development Environments
Write-Section "PART 6: DEVELOPMENT ENVIRONMENTS"
Invoke-ModuleWithErrorHandling -ModuleName "Install-RStudio.ps1" -Description "RStudio IDE" -Component "RStudio"
Invoke-ModuleWithErrorHandling -ModuleName "Install-JupyterLab.ps1" -Description "JupyterLab Interactive Environment" -Component "DataSciencePackages"
Invoke-ModuleWithErrorHandling -ModuleName "Configure-VSCodeExtensions.ps1" -Description "VS Code Extensions for Data Science" -Component "VSCode"

Show-ProgressSummary -Phase "Development Environments" -Current 26 -Total 50

# PART 7: Publishing & Documentation Stack
Write-Section "PART 7: PUBLISHING & DOCUMENTATION TOOLS"
Invoke-ModuleWithErrorHandling -ModuleName "Install-QuartoCLI.ps1" -Description "Quarto Publishing System" -Component "Quarto" -Critical
Invoke-ModuleWithErrorHandling -ModuleName "Install-TinyTeX.ps1" -Description "TinyTeX LaTeX Distribution" -Component "Quarto"
Invoke-ModuleWithErrorHandling -ModuleName "Install-Pandoc.ps1" -Description "Pandoc Document Converter" -Component "Quarto"
Invoke-ModuleWithErrorHandling -ModuleName "Install-QuartoExtensions.ps1" -Description "Quarto Extensions" -Component "Quarto"

Show-ProgressSummary -Phase "Publishing Tools" -Current 30 -Total 50

# PART 8: Database & Data Management Tools
Write-Section "PART 8: DATABASE & DATA MANAGEMENT TOOLS"
Invoke-ModuleWithErrorHandling -ModuleName "Install-DatabaseTools.ps1" -Description "Database GUI Tools (DBeaver, etc.)" -Component "DatabaseTools"
Invoke-ModuleWithErrorHandling -ModuleName "Install-SQLiteTools.ps1" -Description "SQLite Database Tools" -Component "DatabaseTools"
Invoke-ModuleWithErrorHandling -ModuleName "Install-DataConnectors.ps1" -Description "Database Connectors & Drivers" -Component "DatabaseTools"

Show-ProgressSummary -Phase "Database Tools" -Current 33 -Total 50

# PART 9: Big Data & Distributed Computing Stack
Write-Section "PART 9: BIG DATA & DISTRIBUTED COMPUTING"
Invoke-ModuleWithErrorHandling -ModuleName "Install-JavaJDK.ps1" -Description "Java Development Kit" -Component "BigDataStack" -Critical
Invoke-ModuleWithErrorHandling -ModuleName "Install-ApacheSpark.ps1" -Description "Apache Spark & Hadoop" -Component "BigDataStack"
Invoke-ModuleWithErrorHandling -ModuleName "Install-SparkConnectors.ps1" -Description "Spark Python/R Integration" -Component "BigDataStack"
Invoke-ModuleWithErrorHandling -ModuleName "Install-CloudTools.ps1" -Description "Cloud Platform Tools" -Component "BigDataStack"

Show-ProgressSummary -Phase "Big Data Stack" -Current 37 -Total 50

# PART 10: Specialized Tools & Utilities
Write-Section "PART 10: SPECIALIZED TOOLS & UTILITIES"
Invoke-ModuleWithErrorHandling -ModuleName "Install-CustomFonts.ps1" -Description "Custom Fonts for Publications" -Component "CustomFonts"
Invoke-ModuleWithErrorHandling -ModuleName "Install-FFmpeg.ps1" -Description "Media Processing Tools" -Component "OptionalTools"
Invoke-ModuleWithErrorHandling -ModuleName "Install-GraphvizTools.ps1" -Description "Graph Visualization Tools" -Component "OptionalTools"
Invoke-ModuleWithErrorHandling -ModuleName "Install-DockerDesktop.ps1" -Description "Docker Containerization" -Component "OptionalTools"

Show-ProgressSummary -Phase "Specialized Tools" -Current 41 -Total 50

# PART 11: System Configuration & Optimization
Write-Section "PART 11: SYSTEM CONFIGURATION & OPTIMIZATION"
Invoke-ModuleWithErrorHandling -ModuleName "Configure-EnvironmentVariables.ps1" -Description "Environment Variables Configuration" -Component "Prerequisites"
Invoke-ModuleWithErrorHandling -ModuleName "Configure-PathOptimization.ps1" -Description "PATH Environment Optimization" -Component "Prerequisites"
Invoke-ModuleWithErrorHandling -ModuleName "Configure-PowerShellProfile.ps1" -Description "PowerShell Profile Configuration" -Component "Prerequisites"
Invoke-ModuleWithErrorHandling -ModuleName "Install-WindowsFeatures.ps1" -Description "Optional Windows Features" -Component "Prerequisites"

Show-ProgressSummary -Phase "System Configuration" -Current 45 -Total 50

# PART 12: Final Verification & Testing

Write-Section "PART 12: FINAL VERIFICATION & TESTING"
Invoke-ModuleWithErrorHandling -ModuleName "Test-PythonEnvironment.ps1" -Description "Python Environment Verification" -Component "Python"
Invoke-ModuleWithErrorHandling -ModuleName "Test-REnvironment.ps1" -Description "R Environment Verification" -Component "R"
Invoke-ModuleWithErrorHandling -ModuleName "Test-QuartoEnvironment.ps1" -Description "Quarto Publishing Verification" -Component "Quarto"
Invoke-ModuleWithErrorHandling -ModuleName "Test-DatabaseConnections.ps1" -Description "Database Connectivity Tests" -Component "DatabaseTools"

# ADD THIS LINE FOR RECILIENCESCAN PROFILE
Invoke-ModuleWithErrorHandling -ModuleName "Install-RecilienceScan.ps1" -Description "RecilienceScan Project Setup & SystemTest" -Component "Prerequisites"

Invoke-ModuleWithErrorHandling -ModuleName "Generate-EnvironmentReport.ps1" -Description "Environment Status Report Generation" -Component "Prerequisites" -Critical

Show-ProgressSummary -Phase "Final Verification" -Current 50 -Total 50

# --- INSTALLATION COMPLETE ---
Write-Progress -Activity "Data Science Environment Setup" -Completed

$installationEndTime = Get-Date
$totalInstallationTime = $installationEndTime - $installationStartTime

Write-Section "INSTALLATION SUMMARY"
Write-Log "Installation completed in $($totalInstallationTime.ToString('hh\:mm\:ss'))" -Level "INFO"
Write-Log "Modules executed: $Global:ModulesExecuted" -Level "INFO"
Write-Log "Modules succeeded: $Global:ModulesSucceeded" -Level "SUCCESS"
Write-Log "Modules failed: $Global:ModulesFailed" -Level $(if ($Global:ModulesFailed -gt 0) { "ERROR" } else { "INFO" })
Write-Log "Modules skipped: $Global:ModulesSkipped" -Level "INFO"

# Generate detailed results
Write-Log "" -Level "INFO"
Write-Log "DETAILED RESULTS BY COMPONENT:" -Level "INFO"
$componentResults = @{}
foreach ($result in $Global:InstallationResults.Values) {
    if (-not $componentResults.ContainsKey($result.Component)) {
        $componentResults[$result.Component] = @{ Success = 0; Failed = 0; Skipped = 0 }
    }
    switch ($result.Status) {
        "Success" { $componentResults[$result.Component].Success++ }
        "Failed" { $componentResults[$result.Component].Failed++ }
        "Skipped" { $componentResults[$result.Component].Skipped++ }
    }
}

foreach ($component in $componentResults.Keys | Sort-Object) {
    $stats = $componentResults[$component]
    $total = $stats.Success + $stats.Failed + $stats.Skipped
    Write-Log "$component`: $($stats.Success) success, $($stats.Failed) failed, $($stats.Skipped) skipped (Total: $total)" -Level "INFO"
}

# Final status determination
if ($Global:OverallSuccess -and $Global:ModulesFailed -eq 0) {
    Write-Log "" -Level "SUCCESS"
    Write-Log "Installation completed successfully!" -Level "SUCCESS"
    Write-Log "Your $($Global:SelectedProfile) data science environment is ready to use." -Level "SUCCESS"
    
    if ($Global:CriticalFailureOccurred) {
        Write-Log "Note: Some critical components failed, but installation continued" -Level "WARNING"
    }
} elseif ($Global:ModulesFailed -lt ($Global:ModulesExecuted * 0.2)) {
    Write-Log "" -Level "WARNING"
    Write-Log "Installation completed with minor issues" -Level "WARNING"
    Write-Log "Most components installed successfully. Review failed modules above." -Level "WARNING"
} else {
    Write-Log "" -Level "ERROR"
    Write-Log "Installation completed with significant issues" -Level "ERROR"
    Write-Log "Multiple components failed. Environment may not be fully functional." -Level "ERROR"
}

Write-Log "" -Level "INFO"
Write-Log "Detailed installation log saved to: $Global:LogPath" -Level "INFO"
Write-Log "To verify your installation, run: python verify_setup.py" -Level "INFO"
Write-Log "Documentation: Check README.md for usage instructions" -Level "INFO"

# Save comprehensive results to JSON for potential programmatic access
try {
    $resultsJson = @{
        ProfileSelected = $Global:SelectedProfile
        InstallationStartTime = $installationStartTime
        InstallationEndTime = $installationEndTime
        TotalDuration = $totalInstallationTime.TotalMinutes
        OverallSuccess = $Global:OverallSuccess
        CriticalFailures = $Global:CriticalFailureOccurred
        Statistics = @{
            ModulesExecuted = $Global:ModulesExecuted
            ModulesSucceeded = $Global:ModulesSucceeded
            ModulesFailed = $Global:ModulesFailed
            ModulesSkipped = $Global:ModulesSkipped
        }
        ComponentResults = $componentResults
        DetailedResults = $Global:InstallationResults
    } | ConvertTo-Json -Depth 10
    
    $jsonPath = Join-Path $Global:MainInstallerBaseDir "Installation-Results-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $resultsJson | Out-File -FilePath $jsonPath -Encoding UTF8
    Write-Log "Machine-readable results saved to: $jsonPath" -Level "INFO"
} catch {
    Write-Log "Could not save JSON results: $($_.Exception.Message)" -Level "WARNING"
}

Write-Host "`nPress Enter to exit..." -ForegroundColor Yellow
Read-Host

# End of script