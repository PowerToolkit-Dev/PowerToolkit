<#
.SYNOPSIS
    Find which process is occupying a port (e.g., 'portwatch 3000') and optionally kill it.
.CATEGORY
    App Control
#>
param(
    [Parameter(Position=0, Mandatory=$false)]
    [int]$Port
)

if ($Port) {
    Write-Host "Searching for process listening on port $Port..." -ForegroundColor Yellow
    $conn = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue | Select-Object -First 1

    if (-not $conn) {
        Write-Host "Port $Port is free (no processes listening)." -ForegroundColor Green
        return
    }

    $proc = Get-Process -Id $conn.OwningProcess -ErrorAction SilentlyContinue
    $procName = if ($proc) { $proc.ProcessName } else { "Unknown" }

    Write-Host ""
    Write-Host "Port $Port is IN USE:" -ForegroundColor Red
    Write-Host "  Process Name: $procName" -ForegroundColor Cyan
    Write-Host "  Process ID:   $($conn.OwningProcess)" -ForegroundColor Cyan
    Write-Host "  State:        $($conn.State)" -ForegroundColor Cyan
    Write-Host ""

    $choice = Read-Host "Terminate this process to free port $Port? [Y/N]"
    if ($choice -match '^[Yy]$') {
        Stop-Process -Id $conn.OwningProcess -Force -ErrorAction SilentlyContinue
        Write-Host "Process $($conn.OwningProcess) ($procName) terminated. Port $Port is now free." -ForegroundColor Green
    } else {
        Write-Host "Process kept running." -ForegroundColor DarkGray
    }
} else {
    Write-Host "=== Active Listening Ports ===" -ForegroundColor Cyan
    $connections = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue

    if (-not $connections) {
        Write-Host "No listening TCP connections found." -ForegroundColor Yellow
        return
    }

    $connections | Select-Object LocalPort, 
        @{Name="Process"; Expression={(Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName}}, 
        OwningProcess |
        Sort-Object LocalPort -Unique |
        Format-Table LocalPort, Process, OwningProcess -AutoSize
        
    Write-Host "Tip: Run 'portwatch <port>' to target and kill a specific stuck port (e.g., portwatch 3000)." -ForegroundColor DarkGray
}
