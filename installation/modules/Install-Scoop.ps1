# Check if running as Administrator (Scoop blocks this by default)
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if ($isAdmin) {
        Write-Host "WARNING: Running as Administrator. Scoop blocks admin installation by default." -ForegroundColor Yellow
        Write-Host "Attempting admin-approved installation method..." -ForegroundColor Cyan
        
        # Use the admin installation method
        try {
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12
            
            # Admin installation requires special approach
            $env:SCOOP_ADMIN = $true
            Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
            Write-Host "Scoop admin installation completed." -ForegroundColor Green
            
        } catch {
            Write-Host "Admin installation failed: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host ""
            Write-Host "Scoop installation failed due to administrator restrictions." -ForegroundColor Yellow
            Write-Host "Options:" -ForegroundColor Cyan
            Write-Host "1. Run this script in a non-administrator PowerShell window" -ForegroundColor Yellow
            Write-Host "2. Install Scoop manually: https://scoop.sh" -ForegroundColor Yellow
            Write-Host "3. Use Chocolatey or Winget instead" -ForegroundColor Yellow
            exit 1
        }
    } else {
        # Standard installation for non-admin users
        Write-Host "Installing Scoop package manager (non-admin)..." -ForegroundColor Cyan
        Write-Host "This may take a moment..." -ForegroundColor Gray
        
        try {
            # Ensure TLS 1.2 for secure download
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12
            
            # Use the official Scoop installation method
            Write-Host "Downloading and executing Scoop installer..." -ForegroundColor Gray
            
            # Method 1: Try the modern approach first
            try {
                Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
                Write-Host "Scoop installation script executed successfully." -ForegroundColor Green
            } catch {
                Write-Host "Modern installation method failed, trying alternative..." -ForegroundColor Yellow
                
                # Method 2: Fallback to traditional method
                Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://get.scoop.sh')
                Write-Host "Scoop installation script executed successfully (fallback method)." -ForegroundColor Green
            }
        } catch {
            Write-Host "Scoop installation failed: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host ""
            Write-Host "Manual installation options:" -ForegroundColor Yellow
            Write-Host "1. Visit https://scoop.sh for manual installation instructions" -ForegroundColor Yellow
            Write-Host "2. Use Chocolatey or Winget as alternative package managers" -ForegroundColor Yellow
            exit 1
        }
    }