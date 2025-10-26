# Script: modules/Install-RecilienceScan.ps1
# Purpose: Sets up RecilienceScan project and runs SystemTest.qmd verification

Write-Host "Setting up RecilienceScan project environment..." -ForegroundColor Yellow

# Configuration - use fixed paths since no parameters
$installPath = Join-Path $env:USERPROFILE "RecilienceScan"
$repoUrl = "https://github.com/Windesheim-A-I-Support/RecilienceScan.git"
$repoPath = Join-Path $installPath "RecilienceScan"

# Test function availability
function Test-CommandAvailable {
    param([string]$Command)
    try {
        $null = Get-Command $Command -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

# Update PATH for current session
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
    Write-Host "Project path: $installPath" -ForegroundColor Gray
    Write-Host "Repository URL: $repoUrl" -ForegroundColor Gray
    
    # STEP 1: Check Prerequisites
    Write-Host "Checking prerequisites for RecilienceScan..." -ForegroundColor Cyan
    
    $missingTools = @()
    $prerequisites = @("git", "python", "R")
    
    foreach ($tool in $prerequisites) {
        if (-not (Test-CommandAvailable $tool)) {
            $missingTools += $tool
        } else {
            Write-Host "  + $tool available" -ForegroundColor Green
        }
    }
    
    if ($missingTools.Count -gt 0) {
        Write-Host "Missing required tools: $($missingTools -join ', ')" -ForegroundColor Red
        Write-Host "These should have been installed by previous modules." -ForegroundColor Yellow
        return  # Don't use exit in modules
    }
    
    # STEP 2: Create Project Directory (non-interactive)
    Write-Host "Setting up project directory..." -ForegroundColor Cyan
    
    if (-not (Test-Path $installPath)) {
        try {
            New-Item -Path $installPath -ItemType Directory -Force | Out-Null
            Write-Host "  + Created directory: $installPath" -ForegroundColor Green
        } catch {
            Write-Host "  - Failed to create directory: $($_.Exception.Message)" -ForegroundColor Red
            return
        }
    } else {
        Write-Host "  + Directory exists: $installPath" -ForegroundColor Green
    }
    
    # STEP 3: Clone RecilienceScan Repository
    Write-Host "Cloning RecilienceScan repository..." -ForegroundColor Cyan
    
    try {
        if (Test-Path $repoPath) {
            Write-Host "  + Repository already exists. Updating..." -ForegroundColor Yellow
            $currentLocation = Get-Location
            Set-Location $repoPath
            git pull origin main 2>&1 | Out-Null
            Set-Location $currentLocation
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  + Repository updated successfully" -ForegroundColor Green
            } else {
                Write-Host "  ! Repository update failed, continuing..." -ForegroundColor Yellow
            }
        } else {
            git clone $repoUrl $repoPath 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  + Repository cloned successfully" -ForegroundColor Green
            } else {
                Write-Host "  - Git clone failed with exit code $LASTEXITCODE" -ForegroundColor Red
                return
            }
        }
    } catch {
        Write-Host "  - Failed to clone repository: $($_.Exception.Message)" -ForegroundColor Red
        return
    }
    
    # STEP 4: Install Dependencies
    Write-Host "Installing dependencies..." -ForegroundColor Cyan
    
    # Check for requirements files
    $requirementsFiles = @(
        @{ Path = Join-Path $repoPath "requirements.txt"; Type = "Python" }
        @{ Path = Join-Path $repoPath "renv.lock"; Type = "R (renv)" }
        @{ Path = Join-Path $repoPath "DESCRIPTION"; Type = "R (package)" }
    )
    
    $foundRequirements = $false
    foreach ($reqFile in $requirementsFiles) {
        if (Test-Path $reqFile.Path) {
            $foundRequirements = $true
            Write-Host "  + Found $($reqFile.Type) requirements" -ForegroundColor Cyan
            
            try {
                switch ($reqFile.Type) {
                    "Python" {
                        Write-Host "    Installing Python packages..." -ForegroundColor Gray
                        pip install -r $reqFile.Path --quiet 2>&1 | Out-Null
                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "    + Python packages installed" -ForegroundColor Green
                        } else {
                            Write-Host "    ! Python package installation had warnings" -ForegroundColor Yellow
                        }
                    }
                    "R (renv)" {
                        Write-Host "    Setting up R environment with renv..." -ForegroundColor Gray
                        $currentLocation = Get-Location
                        Set-Location $repoPath
                        R -e "if (!require('renv', quietly=TRUE)) install.packages('renv'); renv::restore()" --quiet 2>&1 | Out-Null
                        Set-Location $currentLocation
                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "    + R environment restored" -ForegroundColor Green
                        } else {
                            Write-Host "    ! R environment setup had warnings" -ForegroundColor Yellow
                        }
                    }
                    "R (package)" {
                        Write-Host "    Installing R package dependencies..." -ForegroundColor Gray
                        $currentLocation = Get-Location
                        Set-Location $repoPath
                        R -e "if (!require('devtools', quietly=TRUE)) install.packages('devtools'); devtools::install_deps()" --quiet 2>&1 | Out-Null
                        Set-Location $currentLocation
                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "    + R dependencies installed" -ForegroundColor Green
                        } else {
                            Write-Host "    ! R dependency installation had warnings" -ForegroundColor Yellow
                        }
                    }
                }
            } catch {
                Write-Host "    - Failed to install $($reqFile.Type) dependencies: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
    
    # Install basic R packages if no specific requirements found
    if (-not $foundRequirements) {
        Write-Host "  Installing essential R packages..." -ForegroundColor Cyan
        try {
            $rPackages = @("tidyverse", "knitr", "rmarkdown", "readxl", "openxlsx", "DT", "plotly")
            $packageList = "c('" + ($rPackages -join "','") + "')"
            R -e "install.packages($packageList, repos='https://cran.rstudio.com/', dependencies=TRUE, quiet=TRUE)" --quiet 2>&1 | Out-Null
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  + Essential R packages installed" -ForegroundColor Green
            } else {
                Write-Host "  ! R package installation completed with warnings" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "  - Failed to install R packages: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    # STEP 5: System Test with Quarto Render
    Write-Host "Running system test & verification..." -ForegroundColor Cyan
    
    # Check for SystemTest.qmd in repository
    $systemTestPath = Join-Path $repoPath "SystemTest.qmd"
    $testOutputPath = Join-Path $installPath "SystemTest.pdf"
    
    if (Test-Path $systemTestPath) {
        Write-Host "  + Found SystemTest.qmd in repository" -ForegroundColor Green
        
        # Check if Quarto is available for rendering
        if (Test-CommandAvailable "quarto") {
            Write-Host "  Running SystemTest.qmd with Quarto..." -ForegroundColor Cyan
            
            try {
                # Change to repository directory for proper context
                $originalLocation = Get-Location
                Set-Location $repoPath
                
                Write-Host "    Executing: quarto render SystemTest.qmd --to pdf" -ForegroundColor Gray
                $renderOutput = quarto render SystemTest.qmd --to pdf 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "    + SystemTest.qmd rendered successfully!" -ForegroundColor Green
                    
                    # Check if output was created and copy it
                    $outputFile = Join-Path $repoPath "SystemTest.pdf"
                    if (Test-Path $outputFile) {
                        try {
                            Copy-Item $outputFile $testOutputPath -Force
                            Write-Host "    + System test report: $testOutputPath" -ForegroundColor Green
                        } catch {
                            Write-Host "    ! Could not copy system test report" -ForegroundColor Yellow
                        }
                    }
                    
                } else {
                    Write-Host "    - SystemTest.qmd render failed" -ForegroundColor Red
                    Write-Host "    Output: $renderOutput" -ForegroundColor Gray
                }
                
            } catch {
                Write-Host "    - System test render error: $($_.Exception.Message)" -ForegroundColor Red
            } finally {
                Set-Location $originalLocation
            }
            
        } else {
            Write-Host "  ! Quarto not available - cannot run system test" -ForegroundColor Yellow
        }
        
    } else {
        Write-Host "  ! SystemTest.qmd not found in repository" -ForegroundColor Yellow
    }
    
    # Create basic project structure
    $projectDirs = @("data", "output", "reports", "scripts")
    foreach ($dir in $projectDirs) {
        $dirPath = Join-Path $installPath $dir
        if (-not (Test-Path $dirPath)) {
            try {
                New-Item -Path $dirPath -ItemType Directory -Force | Out-Null
                Write-Host "  + Created directory: $dir" -ForegroundColor Green
            } catch {
                Write-Host "  ! Could not create directory: $dir" -ForegroundColor Yellow
            }
        }
    }
    
    Write-Host "RecilienceScan project setup completed!" -ForegroundColor Green
    Write-Host "  Project location: $installPath" -ForegroundColor Gray
    Write-Host "  Repository: $repoPath" -ForegroundColor Gray
    
    # Success - use exit 0 for module success
    exit 0
    
} catch {
    Write-Host "ERROR: RecilienceScan setup failed: $($_.Exception.Message)" -ForegroundColor Red
    # Use exit 1 for module failure
    exit 1
}