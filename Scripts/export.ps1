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

$installDir = $PSScriptRoot
$packageDir = Join-Path $installDir "package"

# The installer saves its own files into "package" when you run it.
if (-not (Test-Path (Join-Path $packageDir "install.ps1"))) {
    Write-Host "Export needs the installer files, and this install doesn't have them yet." -ForegroundColor Red
    Write-Host "Run the toolkit installer once more (Install-Toolkit.bat), then try 'export' again." -ForegroundColor Yellow
    return
}

# Work out the version for the folder name
$version = ""
foreach ($vf in @((Join-Path $installDir "version.txt"), (Join-Path $packageDir "version.txt"))) {
    if (Test-Path $vf) {
        $version = ((Get-Content $vf -Raw) -replace '[^\w\.\-]', '')
        break
    }
}
if ([string]::IsNullOrWhiteSpace($version)) { $version = "unknown" }
$folderName = "PowerShell-Toolkit-v$version"

# Confirmation 1
$c1 = Read-Host "Export plug-and-play installer to your Desktop? [Y/N]"
if ($c1 -notmatch '^[Yy]$') {
    Write-Host "Cancelled." -ForegroundColor DarkGray
    return
}

# Confirmation 2
$c2 = Read-Host "Confirm: build '$folderName' folder on Desktop? [Y/N]"
if ($c2 -notmatch '^[Yy]$') {
    Write-Host "Cancelled on second confirmation." -ForegroundColor DarkGray
    return
}

# Locate Desktop reliably
$desktop = [Environment]::GetFolderPath([Environment+SpecialFolder]::Desktop)
if (-not (Test-Path $desktop)) { $desktop = Join-Path $env:USERPROFILE "Desktop" }

$exportRoot    = Join-Path $desktop $folderName
$exportScripts = Join-Path $exportRoot "Scripts"

# Never delete a folder that isn't clearly an old export of this toolkit
if (Test-Path $exportRoot) {
    $looksLikeExport = (Test-Path (Join-Path $exportRoot "install.ps1")) -and (Test-Path (Join-Path $exportRoot "Scripts"))
    if (-not $looksLikeExport) {
        Write-Host "A folder named '$exportRoot' already exists and doesn't look like a toolkit export." -ForegroundColor Red
        Write-Host "Not touching it. Rename or move it, then try again." -ForegroundColor Yellow
        return
    }
    $replace = Read-Host "An export with this name already exists. Replace it? [Y/N]"
    if ($replace -notmatch '^[Yy]$') {
        Write-Host "Cancelled. Nothing was changed." -ForegroundColor DarkGray
        return
    }
    Remove-Item $exportRoot -Recurse -Force
}

Write-Host "`nBuilding plug-and-play export folder..." -ForegroundColor Yellow
New-Item -ItemType Directory -Path $exportScripts -Force | Out-Null

# ------------------------------------------------------------
# 1. Copy every installed script (not the uninstaller copy)
# ------------------------------------------------------------
$allScripts = Get-ChildItem -Path $installDir -Filter "*.ps1" -File |
    Where-Object { $_.Name -ine "uninstall.ps1" }
foreach ($s in $allScripts) {
    Copy-Item -Path $s.FullName -Destination (Join-Path $exportScripts $s.Name) -Force
}
Write-Host "  -> Copied $($allScripts.Count) scripts to Scripts\" -ForegroundColor DarkGray

# ------------------------------------------------------------
# 2. Copy the real installer files saved by the installer
# ------------------------------------------------------------
foreach ($f in @("install.ps1", "Uninstall.ps1", "Install-Toolkit.bat", "Uninstall-Toolkit.bat", "version.txt")) {
    $p = Join-Path $packageDir $f
    if (Test-Path $p) {
        Copy-Item -Path $p -Destination (Join-Path $exportRoot $f) -Force
        Write-Host "  -> Copied $f" -ForegroundColor DarkGray
    } else {
        Write-Host "  -> Missing $f (skipped)" -ForegroundColor Yellow
    }
}

# 3. Stamp the export with the version that is installed right now
$currentVersionFile = Join-Path $installDir "version.txt"
if (Test-Path $currentVersionFile) {
    Copy-Item -Path $currentVersionFile -Destination (Join-Path $exportRoot "version.txt") -Force
}

Write-Host ""
Write-Host "Plug & Play Export Created!" -ForegroundColor Green
Write-Host "Folder: $exportRoot" -ForegroundColor Cyan
Write-Host "Send the whole '$folderName' folder (zip it first) - Install-Toolkit.bat" -ForegroundColor DarkGray
Write-Host "needs its Scripts\ folder sitting right next to it to work." -ForegroundColor DarkGray
Write-Host "Opening File Explorer..." -ForegroundColor DarkGray

Start-Sleep -Milliseconds 500
Start-Process explorer.exe -ArgumentList "`"$exportRoot`""