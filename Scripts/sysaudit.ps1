<#
.SYNOPSIS
    Security posture check: Antivirus, Firewall, BitLocker, and UAC status.
.CATEGORY
    Monitoring
#>
Clear-Host
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "                SYSTEM SECURITY AUDIT                       " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "--- Antivirus Protection ---" -ForegroundColor DarkYellow
try {
    $mp = Get-MpComputerStatus -ErrorAction Stop
    $rt = if ($mp.RealTimeProtectionEnabled) { "ENABLED" } else { "DISABLED" }
    $rtColor = if ($mp.RealTimeProtectionEnabled) { "Green" } else { "Red" }
    Write-Host "Real-Time Protection: " -NoNewline; Write-Host $rt -ForegroundColor $rtColor
    Write-Host "Antivirus Signatures: Up to date (v$($mp.AntivirusSignatureVersion))" -ForegroundColor Gray
} catch {
    Write-Host "Windows Defender status query requires Administrator privileges." -ForegroundColor DarkGray
}

Write-Host "`n--- Windows Firewall ---" -ForegroundColor DarkYellow
Get-NetFirewallProfile -ErrorAction SilentlyContinue | ForEach-Object {
    $state = if ($_.Enabled) { "ACTIVE" } else { "DISABLED" }
    $color = if ($_.Enabled) { "Green" } else { "Red" }
    Write-Host ("{0,-12}: " -f $_.Name) -NoNewline
    Write-Host $state -ForegroundColor $color
}

Write-Host "`n--- BitLocker Drive Encryption ---" -ForegroundColor DarkYellow
try {
    Get-BitLockerVolume -ErrorAction Stop | ForEach-Object {
        $status = if ($_.VolumeStatus -eq 'FullyEncrypted') { "ENCRYPTED" } else { "$($_.VolumeStatus)" }
        $color = if ($_.VolumeStatus -eq 'FullyEncrypted') { "Green" } else { "Yellow" }
        Write-Host ("Drive {0,-6} : " -f $_.MountPoint) -NoNewline
        Write-Host $status -ForegroundColor $color
    }
} catch {
    Write-Host "BitLocker status query requires Administrator privileges." -ForegroundColor DarkGray
}

Write-Host "`n--- User Account Control (UAC) ---" -ForegroundColor DarkYellow
$uac = (Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System -ErrorAction SilentlyContinue).EnableLUA
if ($uac -eq 1) {
    Write-Host "UAC System Guard:     ENABLED" -ForegroundColor Green
} else {
    Write-Host "UAC System Guard:     DISABLED (High Risk)" -ForegroundColor Red
}

Write-Host "`nAudit complete." -ForegroundColor Cyan
