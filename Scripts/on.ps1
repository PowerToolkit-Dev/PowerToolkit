<#
.SYNOPSIS
    Turn system features on (e.g. 'on sudo').
.CATEGORY
    App Control
.REQUIRESADMIN
    True
#>
param([Parameter(Position=0)][string]$Target = "sudo")

if ($Target -eq "sudo") {
    Write-Host "Enabling Windows Sudo..." -ForegroundColor Cyan
    Start-Process powershell -Verb RunAs -ArgumentList "-Command", "reg add HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Sudo /v Enabled /t REG_DWORD /d 1 /f" -Wait
    Write-Host "Windows Sudo is now ENABLED!" -ForegroundColor Green
} else {
    Write-Host "Unknown target: '$Target'. Example: on sudo" -ForegroundColor Yellow
}
