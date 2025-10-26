# Script: modules/Test-InternetConnection.ps1
# Purpose: Tests internet connectivity for downloading packages and tools

Write-Host "Testing internet connectivity..." -ForegroundColor Yellow

# Test multiple methods for reliability
$connectionTests = @()
$overallSuccess = $false

try {
    # Test 1: Ping Google DNS (fast, reliable)
    Write-Host "Testing DNS connectivity (8.8.8.8)..." -ForegroundColor Cyan
    
    try {
        $dnsTest = Test-NetConnection -ComputerName "8.8.8.8" -Port 53 -InformationLevel Quiet -WarningAction SilentlyContinue -ErrorAction Stop
        if ($dnsTest) {
            Write-Host "  + DNS connectivity successful" -ForegroundColor Green
            $connectionTests += "DNS: Success"
            $overallSuccess = $true
        } else {
            Write-Host "  - DNS connectivity failed" -ForegroundColor Red
            $connectionTests += "DNS: Failed"
        }
    } catch {
        Write-Host "  - DNS test error: $($_.Exception.Message)" -ForegroundColor Red
        $connectionTests += "DNS: Error"
    }
    
    # Test 2: HTTP connection to a reliable site
    Write-Host "Testing HTTP connectivity..." -ForegroundColor Cyan
    
    try {
        # Test connection to google.com (reliable, fast)
        $webTest = Invoke-WebRequest -Uri "http://www.google.com" -Method Head -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
        if ($webTest.StatusCode -eq 200) {
            Write-Host "  + HTTP connectivity successful" -ForegroundColor Green
            $connectionTests += "HTTP: Success"
            $overallSuccess = $true
        } else {
            Write-Host "  - HTTP connectivity failed (Status: $($webTest.StatusCode))" -ForegroundColor Red
            $connectionTests += "HTTP: Failed"
        }
    } catch {
        Write-Host "  - HTTP test error: $($_.Exception.Message)" -ForegroundColor Red
        $connectionTests += "HTTP: Error"
    }
    
    # Test 3: HTTPS connection (important for secure downloads)
    Write-Host "Testing HTTPS connectivity..." -ForegroundColor Cyan
    
    try {
        # Ensure TLS 1.2 is available
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12
        
        $httpsTest = Invoke-WebRequest -Uri "https://www.google.com" -Method Head -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
        if ($httpsTest.StatusCode -eq 200) {
            Write-Host "  + HTTPS connectivity successful" -ForegroundColor Green
            $connectionTests += "HTTPS: Success"
            $overallSuccess = $true
        } else {
            Write-Host "  - HTTPS connectivity failed (Status: $($httpsTest.StatusCode))" -ForegroundColor Red
            $connectionTests += "HTTPS: Failed"
        }
    } catch {
        Write-Host "  - HTTPS test error: $($_.Exception.Message)" -ForegroundColor Red
        $connectionTests += "HTTPS: Error"
    }
    
    # Test 4: Package manager sources (if applicable)
    Write-Host "Testing package manager connectivity..." -ForegroundColor Cyan
    
    try {
        # Test chocolatey.org (important for choco packages)
        $chocoTest = Invoke-WebRequest -Uri "https://chocolatey.org" -Method Head -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
        if ($chocoTest.StatusCode -eq 200) {
            Write-Host "  + Chocolatey.org reachable" -ForegroundColor Green
            $connectionTests += "Chocolatey: Success"
        } else {
            Write-Host "  - Chocolatey.org not reachable" -ForegroundColor Yellow
            $connectionTests += "Chocolatey: Failed"
        }
    } catch {
        Write-Host "  - Chocolatey test error (not critical)" -ForegroundColor Yellow
        $connectionTests += "Chocolatey: Error"
    }
    
    try {
        # Test python.org (important for Python downloads)
        $pythonTest = Invoke-WebRequest -Uri "https://www.python.org" -Method Head -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
        if ($pythonTest.StatusCode -eq 200) {
            Write-Host "  + Python.org reachable" -ForegroundColor Green
            $connectionTests += "Python.org: Success"
        } else {
            Write-Host "  - Python.org not reachable" -ForegroundColor Yellow
            $connectionTests += "Python.org: Failed"
        }
    } catch {
        Write-Host "  - Python.org test error (not critical)" -ForegroundColor Yellow
        $connectionTests += "Python.org: Error"
    }
    
} catch {
    Write-Host "ERROR: Unexpected error during connectivity testing." -ForegroundColor Red
    Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
}

# Summary
Write-Host ""
Write-Host ("=" * 50) -ForegroundColor Cyan
Write-Host "INTERNET CONNECTIVITY SUMMARY" -ForegroundColor Cyan
Write-Host ("=" * 50) -ForegroundColor Cyan

Write-Host "Test results:" -ForegroundColor Gray
foreach ($test in $connectionTests) {
    Write-Host "  $test" -ForegroundColor Gray
}

if ($overallSuccess) {
    Write-Host ""
    Write-Host "Internet connectivity is available!" -ForegroundColor Green
    Write-Host "Downloads and package installations should work." -ForegroundColor Green
    
    # Additional network info
    try {
        $networkInfo = Get-NetConnectionProfile -ErrorAction SilentlyContinue
        if ($networkInfo) {
            $connectedProfile = $networkInfo | Where-Object { $_.NetworkCategory -ne "DomainAuthenticated" } | Select-Object -First 1
            if ($connectedProfile) {
                Write-Host ""
                Write-Host "Network details:" -ForegroundColor Cyan
                Write-Host "  Network: $($connectedProfile.Name)" -ForegroundColor Gray
                Write-Host "  Category: $($connectedProfile.NetworkCategory)" -ForegroundColor Gray
            }
        }
    } catch {
        # Network profile info not critical
    }
    
    exit 0  # Success
    
} else {
    Write-Host ""
    Write-Host "Internet connectivity issues detected!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting suggestions:" -ForegroundColor Yellow
    Write-Host "1. Check your network connection" -ForegroundColor Yellow
    Write-Host "2. Verify firewall settings allow outbound connections" -ForegroundColor Yellow
    Write-Host "3. Check if you're behind a corporate proxy" -ForegroundColor Yellow
    Write-Host "4. Try connecting to a different network" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Installation may fail or require manual downloads." -ForegroundColor Red
    
    # Don't fail the installation for connectivity issues - some tools might work offline
    # or user might have alternative download methods
    exit 0  # Continue anyway, but with warning
}