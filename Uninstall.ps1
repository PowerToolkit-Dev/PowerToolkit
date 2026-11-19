<#
.SYNOPSIS
    Power Toolkit Uninstaller - removes installed scripts, cleans up PATH,
    and restores your execution policy to whatever it was before install.
.DESCRIPTION
    Nothing here is hidden or encoded - open this file in any text editor
    to see exactly what it does.
#>

Add-Type -AssemblyName System.Windows.Forms

$InstallDir = Join-Path $env:LOCALAPPDATA "PowerToolkit"
$backupFile = Join-Path $InstallDir ".policy-backup.txt"

$report = @()

# ------------------------------------------------------------
# 1. Restore the execution policy, if we saved one
# ------------------------------------------------------------
if (Test-Path $backupFile) {
    $originalPolicy = (Get-Content -Path $backupFile -Raw).Trim()
    try {
        Set-ExecutionPolicy -ExecutionPolicy $originalPolicy -Scope CurrentUser -Force -ErrorAction Stop
        $report += "Execution policy (CurrentUser) restored to: $originalPolicy"
    } catch {
        $report += "COULD NOT restore execution policy automatically."
        $report += "To do it yourself, open PowerShell and run:"
        $report += "    Set-ExecutionPolicy -ExecutionPolicy $originalPolicy -Scope CurrentUser -Force"
    }
} else {
    $report += "No policy backup found - skipping policy restore."
    $report += "If you want to reset it to Windows' out-of-the-box default, run:"
    $report += "    Set-ExecutionPolicy -ExecutionPolicy Undefined -Scope CurrentUser -Force"
}

# ------------------------------------------------------------
# 2. Remove from PATH
# ------------------------------------------------------------
try {
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($currentPath -split ";" -contains $InstallDir) {
        $newPath = ($currentPath -split ";" | Where-Object { $_ -ne $InstallDir }) -join ";"
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
        $report += "Removed $InstallDir from your PATH."
    } else {
        $report += "PATH did not contain $InstallDir - nothing to remove there."
    }
} catch {
    $report += "COULD NOT update PATH automatically. You may want to check it manually (System Properties > Environment Variables)."
}

# ------------------------------------------------------------
# 3. Delete the install folder
# ------------------------------------------------------------
if (Test-Path $InstallDir) {
    try {
        Remove-Item -Path $InstallDir -Recurse -Force -ErrorAction Stop
        $report += "Deleted $InstallDir"
    } catch {
        $report += "COULD NOT delete $InstallDir automatically. Try deleting it by hand."
    }
} else {
    $report += "$InstallDir does not exist - nothing to delete."
}

# ------------------------------------------------------------
# 4. Show a summary - always, whether everything succeeded or not
# ------------------------------------------------------------
$summary = ($report -join "`n")

[System.Windows.Forms.MessageBox]::Show(
    "$summary`n`nOpen a new terminal for the PATH change to take effect.",
    "Power Toolkit Uninstaller", "OK", "Information") | Out-Null

Write-Host $summary
