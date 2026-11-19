<#
.SYNOPSIS
    Deep clean temp files, Windows Update cache, crash dumps, and Recycle Bin.
.CATEGORY
    Maintenance
#>
Add-Type -AssemblyName System.Windows.Forms

Write-Host "Scanning deep cache directories..." -ForegroundColor Yellow

$cleanTargets = @(
    $env:TEMP,
    "$env:SystemRoot\Temp",
    "$env:SystemRoot\SoftwareDistribution\Download",
    "$env:LOCALAPPDATA\CrashDumps",
    "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
)

$totalBytes = 0
foreach ($path in $cleanTargets) {
    if (Test-Path $path) {
        try {
            $files = [System.IO.Directory]::EnumerateFiles($path, "*", [System.IO.SearchOption]::AllDirectories)
            foreach ($f in $files) {
                try { $totalBytes += (New-Object System.IO.FileInfo($f)).Length } catch {}
            }
        } catch {}
    }
}

$totalMB = [math]::Round($totalBytes / 1MB, 1)
$totalGB = [math]::Round($totalBytes / 1GB, 2)
$displaySize = if ($totalGB -ge 1) { "$totalGB GB" } else { "$totalMB MB" }

$shell = New-Object -ComObject Shell.Application
$recycleBin = $shell.NameSpace(10)
$recycleCount = $recycleBin.Items().Count

$msg = @"
Found across cache & temp locations:
- Junk & Update Cache: ~$displaySize
- Recycle Bin Items:   $recycleCount item(s)

Locations targeted:
• User & System Temp files
• Windows Update Download Cache (SoftwareDistribution)
• Application Crash Dumps
• Windows Explorer Thumbnail caches
• Empty Recycle Bin

Clean all items now?
"@

$res = [System.Windows.Forms.MessageBox]::Show($msg, "Deep Clean", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)

if ($res -eq [System.Windows.Forms.DialogResult]::Yes) {
    Write-Host "Cleaning..." -ForegroundColor Cyan

    foreach ($path in $cleanTargets) {
        if (Test-Path $path) {
            Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
                Where-Object { -not $_.PSIsContainer } |
                Remove-Item -Force -ErrorAction SilentlyContinue
        }
    }

    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    [System.Windows.Forms.MessageBox]::Show("Cleanup complete! Recovered ~$displaySize of disk space.", "Done", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
} else {
    Write-Host "Cancelled - nothing was deleted." -ForegroundColor DarkGray
}
