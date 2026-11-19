Add-Type -AssemblyName System.Windows.Forms

$criticalProcesses = @(
    "System", "Idle", "Registry", "smss", "csrss", "wininit", "services",
    "lsass", "winlogon", "explorer", "dwm", "svchost", "MsMpEng",
    "SecurityHealthService", "fontdrvhost", "WUDFHost", "RuntimeBroker",
    "sihost", "ctfmon", "powershell", "pwsh", "conhost"
)

$topProcesses = Get-Process |
    Where-Object { $criticalProcesses -notcontains $_.ProcessName } |
    Sort-Object WorkingSet64 -Descending |
    Select-Object -First 3 -Property ProcessName, Id, @{Name="RAM_MB";Expression={[math]::Round($_.WorkingSet64/1MB,1)}}

$message = "Top 3 RAM-using apps:`n`n"
$i = 1
foreach ($p in $topProcesses) {
    $message += "$i. $($p.ProcessName) (PID $($p.Id)) - $($p.RAM_MB) MB`n"
    $i++
}

[System.Windows.Forms.MessageBox]::Show($message, "Top RAM Usage", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
