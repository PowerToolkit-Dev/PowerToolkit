<#
.SYNOPSIS
    Turn system features off (e.g. 'off sudo').
.CATEGORY
    App Control
.REQUIRESADMIN
    True
#>
param([Parameter(Position=0)][string]$Target = "sudo")

if ($Target -eq "sudo") {
    $confirm = Read-Host "Are you sure you want to turn OFF Windows Sudo? [Y/N]"
    if ($confirm -match '^[Yy]$') {
        Write-Host "Disabling Windows Sudo..." -ForegroundColor Yellow
        Start-Process powershell -Verb RunAs -ArgumentList "-Command", "reg add HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Sudo /v Enabled /t REG_DWORD /d 0 /f" -Wait
        Write-Host "Windows Sudo is now DISABLED." -ForegroundColor DarkGray
    } else {
        Write-Host "Cancelled." -ForegroundColor DarkGray
    }
} else {
    Write-Host "Unknown target: '$Target'. Example: off sudo" -ForegroundColor Yellow
}
