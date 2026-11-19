<#
.SYNOPSIS
    Display clean, styled terminal command history with durations.
.CATEGORY
    Monitoring
#>

$history = Get-History -ErrorAction SilentlyContinue

if (-not $history -or $history.Count -eq 0) {
    Write-Host "No command history recorded in this session." -ForegroundColor Yellow
    return
}

Clear-Host
Write-Host "==========================================================================================" -ForegroundColor Cyan
Write-Host "                               TERMINAL COMMAND HISTORY                                   " -ForegroundColor Cyan
Write-Host "==========================================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host ("{0,-5} | {1,-10} | {2,-10} | {3}" -f "ID", "TIME", "DURATION", "COMMAND") -ForegroundColor DarkYellow
Write-Host ("-" * 90) -ForegroundColor DarkGray

foreach ($entry in $history) {
    $time = if ($entry.StartExecutionTime) { $entry.StartExecutionTime.ToString("HH:mm:ss") } else { "--:--:--" }
    $duration = if ($entry.EndExecutionTime -and $entry.StartExecutionTime) {
        "{0:N2}s" -f ($entry.EndExecutionTime - $entry.StartExecutionTime).TotalSeconds
    } else { "0.00s" }

    Write-Host ("{0,-5}" -f "[$($entry.Id)]") -ForegroundColor Cyan -NoNewline
    Write-Host " | " -ForegroundColor DarkGray -NoNewline
    Write-Host ("{0,-10}" -f $time) -ForegroundColor Gray -NoNewline
    Write-Host " | " -ForegroundColor DarkGray -NoNewline
    Write-Host ("{0,-10}" -f $duration) -ForegroundColor DarkCyan -NoNewline
    Write-Host " | " -ForegroundColor DarkGray -NoNewline
    Write-Host $entry.CommandLine -ForegroundColor Green
}

Write-Host ("-" * 90) -ForegroundColor DarkGray
Write-Host "Tip: Type 'h' for quick raw history, or 'cmdlog' for this styled table." -ForegroundColor DarkGray
Write-Host ""
