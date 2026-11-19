<#
.SYNOPSIS
    Flushes DNS, resets ARP cache, clears NetBIOS, and renews IP lease.
.CATEGORY
    Maintenance
#>
Write-Host "=== Refreshing Network Stack ===" -ForegroundColor Cyan
Write-Host ""

Write-Host "1. Clearing DNS resolver cache..." -ForegroundColor Yellow
Clear-DnsClientCache
ipconfig /flushdns | Out-Null

Write-Host "2. Clearing ARP address cache..." -ForegroundColor Yellow
try {
    arp -d * 2>$null | Out-Null
} catch {}

Write-Host "3. Reloading NetBIOS name cache..." -ForegroundColor Yellow
nbtstat -R 2>$null | Out-Null

Write-Host "4. Releasing and renewing DHCP lease..." -ForegroundColor Yellow
ipconfig /renew | Out-Null

Write-Host ""
Write-Host "Network stack successfully refreshed!" -ForegroundColor Green
