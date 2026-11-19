<#
.SYNOPSIS
    Find and terminate processes locking a stuck file or folder.
.CATEGORY
    App Control
#>
param(
    [Parameter(Position=0, Mandatory=$false)]
    [string]$FilePath
)

# If user didn't provide a path, ask them in plain English
if ([string]::IsNullOrWhiteSpace($FilePath)) {
    Write-Host ""
    Write-Host "=== LockHunt: File Unlocker ===" -ForegroundColor Cyan
    Write-Host "What file is stuck or giving you an 'In use by another program' error?" -ForegroundColor Yellow
    Write-Host "Tip: You can drag and drop the stuck file directly into this window." -ForegroundColor DarkGray
    Write-Host ""
    $FilePath = Read-Host "File path"
}

# Clean quotes if user dragged-and-dropped the file
$FilePath = $FilePath.Trim('"').Trim("'")

if (-not (Test-Path -LiteralPath $FilePath)) {
    Write-Host ""
    Write-Host "File not found: $FilePath" -ForegroundColor Red
    return
}

$resolved = (Resolve-Path -LiteralPath $FilePath).Path
Write-Host ""
Write-Host "Scanning for processes locking: $resolved" -ForegroundColor Yellow

# Look for processes referencing this file module or handle
$lockedProcesses = Get-Process -ErrorAction SilentlyContinue | Where-Object {
    try {
        $_.Modules.FileName -contains $resolved
    } catch {
        $false
    }
}

if ($lockedProcesses) {
    Write-Host ""
    Write-Host "Found program(s) holding an active lock on this file:" -ForegroundColor Red
    Write-Host ""
    $lockedProcesses | Format-Table Id, ProcessName, MainWindowTitle -AutoSize

    $choice = Read-Host "Terminate these locking processes now? [Y/N]"
    if ($choice -match '^[Yy]$') {
        foreach ($p in $lockedProcesses) {
            Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
            Write-Host "Closed: $($p.ProcessName) (PID $($p.Id))" -ForegroundColor Green
        }
        Write-Host "`nFile should now be unlocked and ready to delete or edit." -ForegroundColor Green
    } else {
        Write-Host "No processes were closed." -ForegroundColor DarkGray
    }
} else {
    Write-Host ""
    Write-Host "No standard process module locks found." -ForegroundColor Green
    Write-Host "If the file still won't delete, it may be locked by a Windows System Service (e.g., Search Indexer, Antivirus) or File Explorer itself." -ForegroundColor DarkGray
}
