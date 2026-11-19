<#
.SYNOPSIS
    Run command as Admin (use 'on sudo' and 'off sudo').
.CATEGORY
    App Control
.REQUIRESADMIN
    True
#>
param(
    [switch]$Off,
    [switch]$On,
    [Parameter(ValueFromRemainingArguments=$true)][string[]]$Command
)

# 1. Turn Sudo OFF
if ($Off -or ($Command -contains "-off")) {
    $confirm = Read-Host "Are you sure you want to turn OFF (disable) Windows Sudo? [Y/N]"
    if ($confirm -match '^[Yy]$') {
        Start-Process powershell -Verb RunAs -ArgumentList "-Command", "reg add HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Sudo /v Enabled /t REG_DWORD /d 0 /f" -Wait
        Write-Host "Windows Sudo is now DISABLED." -ForegroundColor Yellow
    } else {
        Write-Host "Cancelled." -ForegroundColor DarkGray
    }
    return
}

# 2. Turn Sudo ON
if ($On -or ($Command -contains "-on")) {
    Start-Process powershell -Verb RunAs -ArgumentList "-Command", "reg add HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Sudo /v Enabled /t REG_DWORD /d 1 /f" -Wait
    Write-Host "Windows Sudo is now ENABLED." -ForegroundColor Green
    return
}

# 3. Check if Sudo is currently disabled
$sudoReg = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Sudo" -ErrorAction SilentlyContinue).Enabled
if ($sudoReg -eq 0) {
    Write-Host "Windows Sudo is currently DISABLED." -ForegroundColor Yellow
    $ans = Read-Host "Turn it ON now? [Y/N]"
    if ($ans -match '^[Yy]$') {
        Start-Process powershell -Verb RunAs -ArgumentList "-Command", "reg add HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Sudo /v Enabled /t REG_DWORD /d 1 /f" -Wait
        Write-Host "Windows Sudo enabled!" -ForegroundColor Green
    } else {
        Write-Host "Command aborted." -ForegroundColor DarkGray
        return
    }
}

# 4. Execute elevated command or open elevated terminal
if ($Command) {
    $cmdString = $Command -join " "
    Start-Process powershell.exe -ArgumentList "-NoExit", "-Command", "cd '$PWD'; $cmdString" -Verb RunAs
} else {
    Start-Process powershell.exe -ArgumentList "-NoExit", "-Command", "cd '$PWD'" -Verb RunAs
}

