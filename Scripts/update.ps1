<#
.SYNOPSIS
    Check GitHub for a newer toolkit version and install it (runs only when you type 'update').
.CATEGORY
    Maintenance
.DESCRIPTION
    Nothing runs in the background. When you type 'update' this script:
      1. Reads version.txt from your GitHub repo (one small web request).
      2. Compares it to the version installed on this PC.
      3. If newer, asks you, then downloads the repo as a zip, backs up your
         current scripts, and copies the new versions over.
    Use 'update -Check' to only look for an update without installing.
#>
param([switch]$Check)

# ---- Settings: change these to match your repo ----
$Owner  = 'PowerToolkit-Dev'
$Repo   = 'PowerToolkit'
$Branch = 'main'
# ---------------------------------------------------

$InstallDir  = $PSScriptRoot
$VersionFile = Join-Path $InstallDir 'version.txt'
$Headers     = @{ 'User-Agent' = 'PowerToolkit-Updater' }

# Windows PowerShell 5.1 needs TLS 1.2 switched on to talk to GitHub
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function ConvertTo-Ver([string]$text) {
    try { [version]($text.Trim().TrimStart('v')) } catch { [version]'0.0.0' }
}

$localVersion = if (Test-Path $VersionFile) { ConvertTo-Ver (Get-Content $VersionFile -Raw) } else { [version]'0.0.0' }

# ------------------------------------------------------------
# 1. Ask GitHub what the newest version is
# ------------------------------------------------------------
Write-Host "Checking GitHub for updates..." -ForegroundColor Cyan
$versionUrl = "https://raw.githubusercontent.com/$Owner/$Repo/$Branch/version.txt"

try {
    $resp = Invoke-WebRequest -Uri $versionUrl -Headers $Headers -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop
    $remoteText    = ([string]$resp.Content).Trim()
    $remoteVersion = ConvertTo-Ver $remoteText
} catch {
    Write-Host "Could not reach GitHub: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Check your internet connection and that the repo is public." -ForegroundColor DarkGray
    return
}

Write-Host "Installed: $localVersion   |   Latest: $remoteVersion"

if ($remoteVersion -le $localVersion) {
    Write-Host "You're up to date." -ForegroundColor Green
    return
}

Write-Host "A newer version is available." -ForegroundColor Yellow
if ($Check) { return }

$answer = Read-Host "Download and install version $remoteVersion now? [Y/N]"
if ($answer -notmatch '^[Yy]$') {
    Write-Host "Cancelled. Nothing was changed." -ForegroundColor DarkGray
    return
}

# ------------------------------------------------------------
# 2. Download the repo as a zip into a temp folder
# ------------------------------------------------------------
$tmp = Join-Path $env:TEMP ("PowerToolkit-update-" + [guid]::NewGuid().ToString('N'))
$zip = "$tmp.zip"

try {
    Write-Host "Downloading..." -ForegroundColor Cyan
    $zipUrl = "https://github.com/$Owner/$Repo/archive/refs/heads/$Branch.zip"
    Invoke-WebRequest -Uri $zipUrl -Headers $Headers -UseBasicParsing -OutFile $zip -ErrorAction Stop
    Expand-Archive -Path $zip -DestinationPath $tmp -Force

    # GitHub zips contain one top folder named <repo>-<branch>
    $root = (Get-ChildItem -Path $tmp -Directory | Select-Object -First 1).FullName
    $src  = Join-Path $root 'Scripts'
    if (-not (Test-Path $src)) {
        Write-Host "The download has no 'Scripts' folder - repo layout is wrong. Nothing was changed." -ForegroundColor Red
        return
    }

    # --------------------------------------------------------
    # 3. Back up, then replace only the scripts already installed
    # --------------------------------------------------------
    $backup = Join-Path $InstallDir ("backup\v{0}-{1}" -f $localVersion, (Get-Date -Format 'yyyyMMdd-HHmmss'))
    New-Item -ItemType Directory -Path $backup -Force | Out-Null

    $installed = Get-ChildItem -Path $InstallDir -Filter '*.ps1' -File
    $updated = @()

    # update.ps1 itself goes last so it isn't replaced while running
    $ordered = $installed | Sort-Object { $_.Name -eq 'update.ps1' }, Name

    foreach ($file in $ordered) {
        $newFile = Join-Path $src $file.Name
        if ($file.Name -ieq 'uninstall.ps1') { $newFile = Join-Path $root 'Uninstall.ps1' }
        if (-not (Test-Path $newFile)) { continue }

        Copy-Item -Path $file.FullName -Destination (Join-Path $backup $file.Name) -Force
        Copy-Item -Path $newFile -Destination $file.FullName -Force
        $updated += $file.Name
    }

    Get-ChildItem -Path $InstallDir -Filter '*.ps1' -File | Unblock-File -ErrorAction SilentlyContinue
    Set-Content -Path $VersionFile -Value $remoteText -Encoding ASCII

    # --------------------------------------------------------
    # 4. Report
    # --------------------------------------------------------
    Write-Host ""
    Write-Host "Updated $($updated.Count) script(s) to version $remoteVersion." -ForegroundColor Green
    Write-Host "Old versions saved in: $backup" -ForegroundColor DarkGray

    $newScripts = Get-ChildItem -Path $src -Filter '*.ps1' -File |
        Where-Object { -not (Test-Path (Join-Path $InstallDir $_.Name)) }
    if ($newScripts) {
        Write-Host ""
        Write-Host "New tools available but not installed (re-run the installer to add them):" -ForegroundColor Yellow
        $newScripts | ForEach-Object { Write-Host "  - $($_.BaseName)" }
    }
}
catch {
    Write-Host "Update failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Your installed scripts were not changed unless a backup folder says otherwise." -ForegroundColor DarkGray
}
finally {
    Remove-Item -Path $tmp, $zip -Recurse -Force -ErrorAction SilentlyContinue
}
