# Check and display items in Outlook Outbox
$outlook = New-Object -ComObject Outlook.Application
$namespace = $outlook.GetNamespace("MAPI")
$outbox = $namespace.GetDefaultFolder(4)  # 4 = olFolderOutbox

Write-Host "===== OUTLOOK OUTBOX ====="
Write-Host "Total items in Outbox: $($outbox.Items.Count)"

if ($outbox.Items.Count -gt 0) {
    Write-Host "`nItems in Outbox:"
    foreach ($item in $outbox.Items) {
        Write-Host "  - To: $($item.To)"
        Write-Host "    Subject: $($item.Subject)"
        Write-Host "    Created: $($item.CreationTime)"
        Write-Host ""
    }

    $response = Read-Host "`nDo you want to DELETE all items in Outbox? (yes/no)"
    if ($response -eq "yes") {
        $count = $outbox.Items.Count
        for ($i = $count; $i -gt 0; $i--) {
            $outbox.Items.Item($i).Delete()
        }
        Write-Host "Deleted $count items from Outbox"
    }
} else {
    Write-Host "Outbox is empty"
}

# Check Drafts folder too
$drafts = $namespace.GetDefaultFolder(16)  # 16 = olFolderDrafts
Write-Host "`n===== OUTLOOK DRAFTS ====="
Write-Host "Total items in Drafts: $($drafts.Items.Count)"

if ($drafts.Items.Count -gt 0) {
    Write-Host "`nItems in Drafts (last 10):"
    $count = [Math]::Min(10, $drafts.Items.Count)
    for ($i = 1; $i -le $count; $i++) {
        $item = $drafts.Items.Item($i)
        Write-Host "  - To: $($item.To)"
        Write-Host "    Subject: $($item.Subject)"
        Write-Host ""
    }
}

Write-Host "`nDone. Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
