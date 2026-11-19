Write-Host "Starting disk/IO watch... (first reading takes a couple seconds to calibrate)" -ForegroundColor Yellow
Write-Host "Note: this measures total I/O (disk + network + device), not disk alone - Windows doesn't expose pure per-process disk I/O." -ForegroundColor DarkGray
Write-Host "Multiple instances of the same app (e.g. browser tabs) are grouped and summed together." -ForegroundColor DarkGray
Start-Sleep -Seconds 2

$criticalProcesses = @(
    "System", "Idle", "Registry", "smss", "csrss", "wininit", "services",
    "lsass", "winlogon", "explorer", "dwm", "svchost", "MsMpEng",
    "SecurityHealthService", "fontdrvhost", "WUDFHost", "RuntimeBroker",
    "sihost", "ctfmon", "powershell", "pwsh", "conhost"
)

while ($true) {
    Clear-Host
    Write-Host "=== Top I/O Activity by App (grouped, approx. disk-heavy) ===" -ForegroundColor Cyan
    Write-Host "(refreshes every 3s, Ctrl+C to stop)" -ForegroundColor DarkGray
    Write-Host ""

    try {
        $samples = (Get-Counter '\Process(*)\IO Data Bytes/sec' -ErrorAction Stop).CounterSamples |
            Where-Object { $_.InstanceName -notin @("_total", "idle") -and $_.CookedValue -gt 0 }

        $grouped = $samples | ForEach-Object {
            [PSCustomObject]@{
                BaseName = ($_.InstanceName -replace '#\d+$', '')
                Value = $_.CookedValue
            }
        } | Where-Object { $criticalProcesses -notcontains $_.BaseName } |
          Group-Object BaseName | ForEach-Object {
            [PSCustomObject]@{
                Name = $_.Name
                TotalBytesPerSec = ($_.Group | Measure-Object -Property Value -Sum).Sum
                InstanceCount = $_.Count
            }
        } | Sort-Object TotalBytesPerSec -Descending | Select-Object -First 5

        if ($grouped.Count -eq 0) {
            Write-Host "No significant I/O activity detected right now."
        } else {
            foreach ($g in $grouped) {
                $mbps = [math]::Round($g.TotalBytesPerSec / 1MB, 2)
                $countLabel = if ($g.InstanceCount -gt 1) { " ($($g.InstanceCount) instances)" } else { "" }
                Write-Host ("{0,-20} {1,8} MB/s{2}" -f $g.Name, $mbps, $countLabel)
            }
        }
    } catch {
        Write-Host "Could not read I/O counters. Try running this from an admin PowerShell window."
    }

    Start-Sleep -Seconds 3
}
