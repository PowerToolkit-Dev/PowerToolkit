<#
.SYNOPSIS
    Export a plug-and-play toolkit installer (folder + .bat) to Desktop.
.CATEGORY
    Maintenance
#>

Clear-Host
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "          PLUG & PLAY TOOLKIT EXPORT                       " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# Confirmation 1
$c1 = Read-Host "Export plug-and-play installer to your Desktop? [Y/N]"
if ($c1 -notmatch '^[Yy]$') {
    Write-Host "Cancelled." -ForegroundColor DarkGray
    return
}

# Confirmation 2
$c2 = Read-Host "Confirm: build 'PowerShell-Toolkit' folder on Desktop? [Y/N]"
if ($c2 -notmatch '^[Yy]$') {
    Write-Host "Cancelled on second confirmation." -ForegroundColor DarkGray
    return
}

# Locate Desktop reliably
$desktop = [Environment]::GetFolderPath([Environment+SpecialFolder]::Desktop)
if (-not (Test-Path $desktop)) { $desktop = Join-Path $env:USERPROFILE "Desktop" }

$exportRoot = Join-Path $desktop "PowerShell-Toolkit"
$exportScripts = Join-Path $exportRoot "Scripts"

Write-Host "`nBuilding plug-and-play export folder..." -ForegroundColor Yellow

# Fresh export folder each time
if (Test-Path $exportRoot) { Remove-Item $exportRoot -Recurse -Force }
New-Item -ItemType Directory -Path $exportScripts -Force | Out-Null

# ------------------------------------------------------------
# 1. Copy every tool script over as-is (no encoding, fully readable)
# ------------------------------------------------------------
$allScripts = Get-ChildItem -Path $PSScriptRoot -Filter "*.ps1" -File
foreach ($s in $allScripts) {
    Copy-Item -Path $s.FullName -Destination (Join-Path $exportScripts $s.Name) -Force
}
Write-Host "  -> Copied $($allScripts.Count) scripts to Scripts\" -ForegroundColor DarkGray

# ------------------------------------------------------------
# 2. Write the plain-text installer (install.ps1)
# ------------------------------------------------------------
$installLines = @'
<#
.SYNOPSIS
    Installs the PowerShell Toolkit into your user AppData folder and adds
    it to your PATH.
.DESCRIPTION
    Copies every .ps1 file from the "Scripts" folder next to this installer
    into %LOCALAPPDATA%\PowerToolkit, then adds that folder to your user
    PATH. Nothing here is hidden or encoded - open this file in any text
    editor to see exactly what it does. No admin rights needed - this only
    touches your own user profile, never C:\ system folders.
#>

$target = Join-Path $env:LOCALAPPDATA "PowerToolkit"
$sourceDir = Join-Path $PSScriptRoot "Scripts"

Clear-Host
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "        INSTALLING POWERSHELL TOOLKIT (PLUG & PLAY)        " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $sourceDir)) {
    Write-Host "ERROR: Could not find the 'Scripts' folder next to this installer." -ForegroundColor Red
    Write-Host "Expected it at: $sourceDir" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

if (-not (Test-Path $target)) {
    New-Item -ItemType Directory -Path $target -Force | Out-Null
}

$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($currentPath -split ";" -notcontains $target) {
    [Environment]::SetEnvironmentVariable("Path", "$currentPath;$target", "User")
    $env:Path += ";$target"
    Write-Host "Configured Windows PATH variable." -ForegroundColor Green
}

Get-ChildItem -Path $sourceDir -Filter "*.ps1" -File | ForEach-Object {
    Copy-Item -Path $_.FullName -Destination (Join-Path $target $_.Name) -Force
    Write-Host "  -> Installed: $($_.Name)" -ForegroundColor DarkGray
}

Write-Host "`nInstallation Successful! Launching dashboard..." -ForegroundColor Green
Start-Sleep -Seconds 1
& "$target\toolkit.ps1"
'@

Set-Content -Path (Join-Path $exportRoot "install.ps1") -Value $installLines -Encoding UTF8 -Force
Write-Host "  -> Wrote install.ps1" -ForegroundColor DarkGray

# ------------------------------------------------------------
# 3. Write the double-click launcher (Install-Toolkit.bat)
#    Just calls install.ps1 in PowerShell - no hidden payload,
#    no marker parsing, no Invoke-Expression.
# ------------------------------------------------------------
$batLines = @(
    '@echo off',
    'title Installing PowerShell Toolkit...',
    'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"'
)
[System.IO.File]::WriteAllLines((Join-Path $exportRoot "Install-Toolkit.bat"), $batLines)
Write-Host "  -> Wrote Install-Toolkit.bat" -ForegroundColor DarkGray

Write-Host ""
Write-Host "Plug & Play Export Created!" -ForegroundColor Green
Write-Host "Folder: $exportRoot" -ForegroundColor Cyan
Write-Host "Send the whole 'PowerShell-Toolkit' folder (zip it first) - the .bat" -ForegroundColor DarkGray
Write-Host "needs its Scripts\ folder sitting right next to it to work." -ForegroundColor DarkGray
Write-Host "Opening File Explorer..." -ForegroundColor DarkGray

Start-Sleep -Milliseconds 500
explorer.exe $exportRoot
