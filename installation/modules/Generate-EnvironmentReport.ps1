# Script: modules/Generate-EnvironmentReport.ps1
# Purpose: Generates comprehensive environment report and verifies installation
# Critical: Final verification step for the entire installation process

Write-Host "Generating comprehensive environment report..." -ForegroundColor Yellow

# Initialize report data
$reportData = @{
    GeneratedAt = Get-Date
    MachineName = $env:COMPUTERNAME
    UserName = $env:USERNAME
    Tools = @{}
    EnvironmentVariables = @{}
    Profiles = @{}
    Summary = @{
        TotalToolsChecked = 0
        ToolsAvailable = 0
        ToolsMissing = 0
        CriticalIssues = @()
        Warnings = @()
    }
}

# Function to test a tool and get version
function Test-ToolAvailability {
    param(
        [string]$ToolName,
        [string]$VersionCommand,
        [string]$Description,
        [bool]$Critical = $false
    )
    
    $result = @{
        Name = $ToolName
        Description = $Description
        Available = $false
        Version = "Not found"
        Path = ""
        Critical = $Critical
    }
    
    try {
        $tool = Get-Command $ToolName -ErrorAction SilentlyContinue
        if ($tool) {
            $result.Available = $true
            $result.Path = $tool.Source
            
            # Try to get version
            if ($VersionCommand) {
                try {
                    $versionOutput = Invoke-Expression "$VersionCommand 2>&1" | Out-String
                    $result.Version = ($versionOutput -split "`n")[0].Trim()
                } catch {
                    $result.Version = "Available (version check failed)"
                }
            } else {
                $result.Version = "Available"
            }
        }
    } catch {
        # Tool not found
    }
    
    return $result
}

# Function to check environment variable
function Test-EnvironmentVariable {
    param(
        [string]$VarName,
        [string]$Description
    )
    
    $value = [Environment]::GetEnvironmentVariable($VarName)
    return @{
        Name = $VarName
        Description = $Description
        Value = $value
        IsSet = (-not [string]::IsNullOrEmpty($value))
    }
}

try {
    Write-Host "Testing tool availability..." -ForegroundColor Cyan
    
    # Define tools to check
    $toolsToCheck = @(
        @{ Name = "choco"; Version = "choco --version"; Description = "Chocolatey Package Manager"; Critical = $true },
        @{ Name = "scoop"; Version = "scoop --version"; Description = "Scoop Package Manager"; Critical = $false },
        @{ Name = "git"; Version = "git --version"; Description = "Git Version Control"; Critical = $true },
        @{ Name = "python"; Version = "python --version"; Description = "Python Interpreter"; Critical = $true },
        @{ Name = "pip"; Version = "pip --version"; Description = "Python Package Manager"; Critical = $true },
        @{ Name = "R"; Version = "R --version"; Description = "R Statistical Computing"; Critical = $true },
        @{ Name = "quarto"; Version = "quarto --version"; Description = "Quarto Publishing System"; Critical = $true },
        @{ Name = "java"; Version = "java -version"; Description = "Java Runtime Environment"; Critical = $false },
        @{ Name = "code"; Version = "code --version"; Description = "Visual Studio Code"; Critical = $false },
        @{ Name = "jupyter"; Version = "jupyter --version"; Description = "Jupyter Notebook"; Critical = $false },
        @{ Name = "node"; Version = "node --version"; Description = "Node.js Runtime"; Critical = $false },
        @{ Name = "npm"; Version = "npm --version"; Description = "Node Package Manager"; Critical = $false }
    )
    
    foreach ($tool in $toolsToCheck) {
        $result = Test-ToolAvailability -ToolName $tool.Name -VersionCommand $tool.Version -Description $tool.Description -Critical $tool.Critical
        $reportData.Tools[$tool.Name] = $result
        $reportData.Summary.TotalToolsChecked++
        
        if ($result.Available) {
            $reportData.Summary.ToolsAvailable++
            Write-Host "  + $($result.Name): $($result.Version)" -ForegroundColor Green
        } else {
            $reportData.Summary.ToolsMissing++
            if ($result.Critical) {
                $reportData.Summary.CriticalIssues += "$($result.Name) (Critical): $($result.Description)"
                Write-Host "  X $($result.Name): Missing (CRITICAL)" -ForegroundColor Red
            } else {
                $reportData.Summary.Warnings += "$($result.Name): $($result.Description)"
                Write-Host "  - $($result.Name): Missing" -ForegroundColor Yellow
            }
        }
    }
    
    Write-Host "`nChecking environment variables..." -ForegroundColor Cyan
    
    # Check important environment variables
    $envVarsToCheck = @(
        @{ Name = "PATH"; Description = "System PATH" },
        @{ Name = "JAVA_HOME"; Description = "Java Installation Directory" },
        @{ Name = "PYTHON_HOME"; Description = "Python Installation Directory" },
        @{ Name = "PYTHONPATH"; Description = "Python Module Search Path" },
        @{ Name = "R_HOME"; Description = "R Installation Directory" },
        @{ Name = "QUARTO_HOME"; Description = "Quarto Installation Directory" },
        @{ Name = "CHOCOLATEYINSTALL"; Description = "Chocolatey Installation Directory" }
    )
    
    foreach ($envVar in $envVarsToCheck) {
        $result = Test-EnvironmentVariable -VarName $envVar.Name -Description $envVar.Description
        $reportData.EnvironmentVariables[$envVar.Name] = $result
        
        if ($result.IsSet) {
            if ($envVar.Name -eq "PATH") {
                $pathCount = ($result.Value -split ';').Count
                Write-Host "  + $($result.Name): Set ($pathCount entries)" -ForegroundColor Green
            } else {
                Write-Host "  + $($result.Name): $($result.Value)" -ForegroundColor Green
            }
        } else {
            Write-Host "  - $($result.Name): Not set" -ForegroundColor Gray
        }
    }
    
    # Test Python packages
    Write-Host "`nTesting Python environment..." -ForegroundColor Cyan
    if ($reportData.Tools["python"].Available) {
        $pythonPackages = @("pandas", "numpy", "matplotlib", "scikit-learn", "jupyter")
        foreach ($package in $pythonPackages) {
            try {
                $packageTest = python -c "import $package; print('$package OK')" 2>$null
                if ($packageTest -like "*OK*") {
                    Write-Host "  + Python package '$package': Available" -ForegroundColor Green
                } else {
                    Write-Host "  - Python package '$package': Missing" -ForegroundColor Yellow
                }
            } catch {
                Write-Host "  - Python package '$package': Missing" -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "  - Python not available, skipping package checks" -ForegroundColor Yellow
    }
    
    # Test R packages
    Write-Host "`nTesting R environment..." -ForegroundColor Cyan
    if ($reportData.Tools["R"].Available) {
        try {
            $rVersion = R --slave -e "cat(R.version.string)" 2>$null
            Write-Host "  + R Version: $rVersion" -ForegroundColor Green
            
            # Test for common R packages
            $rTest = R --slave -e "cat(ifelse(require(ggplot2, quietly=TRUE), 'ggplot2 OK', 'ggplot2 MISSING'))" 2>$null
            if ($rTest -like "*OK*") {
                Write-Host "  + R package 'ggplot2': Available" -ForegroundColor Green
            } else {
                Write-Host "  - R package 'ggplot2': Missing" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "  - R package testing failed" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  - R not available, skipping package checks" -ForegroundColor Yellow
    }
    
    # Generate summary
    Write-Host "`n" + ("=" * 80) -ForegroundColor Cyan
    Write-Host "INSTALLATION SUMMARY REPORT" -ForegroundColor Cyan
    Write-Host ("=" * 80) -ForegroundColor Cyan
    
    Write-Host "Generated: $($reportData.GeneratedAt)" -ForegroundColor Gray
    Write-Host "Machine: $($reportData.MachineName)" -ForegroundColor Gray
    Write-Host "User: $($reportData.UserName)" -ForegroundColor Gray
    Write-Host ""
    
    $availablePercent = [math]::Round(($reportData.Summary.ToolsAvailable / $reportData.Summary.TotalToolsChecked) * 100, 1)
    Write-Host "Tools Status: $($reportData.Summary.ToolsAvailable)/$($reportData.Summary.TotalToolsChecked) available ($availablePercent%)" -ForegroundColor $(if ($availablePercent -gt 80) { "Green" } elseif ($availablePercent -gt 60) { "Yellow" } else { "Red" })
    
    if ($reportData.Summary.CriticalIssues.Count -gt 0) {
        Write-Host "`nCRITICAL ISSUES:" -ForegroundColor Red
        foreach ($issue in $reportData.Summary.CriticalIssues) {
            Write-Host "  ! $issue" -ForegroundColor Red
        }
    }
    
    if ($reportData.Summary.Warnings.Count -gt 0) {
        Write-Host "`nWARNINGS:" -ForegroundColor Yellow
        foreach ($warning in $reportData.Summary.Warnings) {
            Write-Host "  ? $warning" -ForegroundColor Yellow
        }
    }
    
    # Save detailed report to file
    $reportPath = Join-Path $PSScriptRoot "..\Environment-Report-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    try {
        $reportData | ConvertTo-Json -Depth 10 | Out-File -FilePath $reportPath -Encoding UTF8
        Write-Host "`nDetailed report saved to: $reportPath" -ForegroundColor Green
    } catch {
        Write-Host "`nFailed to save detailed report: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    # Final status
    if ($reportData.Summary.CriticalIssues.Count -eq 0) {
        Write-Host "`nENVIRONMENT STATUS: READY" -ForegroundColor Green
        Write-Host "Your data science environment is ready to use!" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "`nENVIRONMENT STATUS: ISSUES DETECTED" -ForegroundColor Red
        Write-Host "Please address critical issues before using the environment." -ForegroundColor Red
        exit 1
    }
    
} catch {
    Write-Host "ERROR: Failed to generate environment report." -ForegroundColor Red
    Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}