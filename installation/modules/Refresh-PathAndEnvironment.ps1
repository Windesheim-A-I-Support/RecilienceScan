# Script: modules/Refresh-PathAndEnvironment.ps1
# Purpose: Refreshes PATH and environment variables from registry to current session
# Critical: Ensures newly installed tools are immediately available without restart

Write-Host "Refreshing environment variables and PATH from registry..." -ForegroundColor Yellow

try {
    # Store original PATH for comparison
    $originalPath = $env:PATH
    
    # Get current PATH components count for comparison
    $originalPathCount = ($originalPath -split ';').Count
    
    Write-Host "Original PATH contains $originalPathCount entries" -ForegroundColor Gray
    
    # Refresh environment variables from registry
    Write-Host "Reading environment variables from registry..." -ForegroundColor Cyan
    
    # Get system environment variables
    $systemEnv = [Environment]::GetEnvironmentVariables([EnvironmentVariableTarget]::Machine)
    
    # Get user environment variables  
    $userEnv = [Environment]::GetEnvironmentVariables([EnvironmentVariableTarget]::User)
    
    # Build new PATH by combining system and user PATH
    $systemPath = $systemEnv["PATH"] -split ';' | Where-Object { $_ -ne "" }
    $userPath = $userEnv["PATH"] -split ';' | Where-Object { $_ -ne "" }
    
    # Combine paths (system first, then user) and remove duplicates
    $combinedPath = @()
    $combinedPath += $systemPath
    $combinedPath += $userPath
    $combinedPath = $combinedPath | Sort-Object -Unique
    
    # Set the new PATH
    $newPath = $combinedPath -join ';'
    $env:PATH = $newPath
    
    # Update other important environment variables that might have changed
    $importantVars = @('JAVA_HOME', 'PYTHON_HOME', 'PYTHONPATH', 'R_HOME', 'QUARTO_HOME', 'CHOCOLATEYINSTALL')
    
    foreach ($varName in $importantVars) {
        # Check system environment first
        if ($systemEnv.ContainsKey($varName)) {
            Set-Item -Path "env:$varName" -Value $systemEnv[$varName] -Force -ErrorAction SilentlyContinue
        }
        # User environment takes precedence
        elseif ($userEnv.ContainsKey($varName)) {
            Set-Item -Path "env:$varName" -Value $userEnv[$varName] -Force -ErrorAction SilentlyContinue
        }
    }
    
    # Count new PATH entries
    $newPathCount = ($env:PATH -split ';').Count
    
    # Report results
    if ($env:PATH -ne $originalPath) {
        Write-Host "PATH successfully refreshed!" -ForegroundColor Green
        Write-Host "PATH now contains $newPathCount entries (was $originalPathCount)" -ForegroundColor Green
        
        # Show newly added paths (if any)
        $newPaths = ($env:PATH -split ';') | Where-Object { $_ -notin ($originalPath -split ';') -and $_ -ne "" }
        if ($newPaths.Count -gt 0) {
            Write-Host "Newly available paths:" -ForegroundColor Cyan
            $newPaths | ForEach-Object { Write-Host "  + $_" -ForegroundColor Gray }
        }
    } else {
        Write-Host "No PATH changes detected." -ForegroundColor Gray
    }
    
    # Verify some common tools are now available
    Write-Host "Checking availability of common tools..." -ForegroundColor Cyan
    $toolsToCheck = @('choco', 'scoop', 'git', 'python', 'R', 'quarto')
    
    foreach ($tool in $toolsToCheck) {
        if (Get-Command $tool -ErrorAction SilentlyContinue) {
            Write-Host "  checkmark $tool is available" -ForegroundColor Green
        } else {
            Write-Host "  - $tool not found" -ForegroundColor Gray
        }
    }
    
    Write-Host "Environment refresh completed successfully." -ForegroundColor Green
    exit 0
    
} catch {
    Write-Host "ERROR: Failed to refresh environment variables." -ForegroundColor Red
    Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "This may cause newly installed tools to be unavailable until restart." -ForegroundColor Yellow
    Write-Host "You can try manually refreshing by closing and reopening your terminal." -ForegroundColor Yellow
    
    # Don't fail the installation for environment refresh issues
    exit 0
}