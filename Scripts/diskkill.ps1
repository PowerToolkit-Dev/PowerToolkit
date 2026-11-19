Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$criticalProcesses = @(
    "System", "Idle", "Registry", "smss", "csrss", "wininit", "services",
    "lsass", "winlogon", "explorer", "dwm", "svchost", "MsMpEng",
    "SecurityHealthService", "fontdrvhost", "WUDFHost", "RuntimeBroker",
    "sihost", "ctfmon", "powershell", "pwsh", "conhost"
)

function Show-ChoiceDialog {
    param($processName)

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "App Reopened"
    $form.Size = New-Object System.Drawing.Size(360, 160)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.TopMost = $true

    $label = New-Object System.Windows.Forms.Label
    $label.Text = "'$processName' was reopened. What do you want to do?"
    $label.SetBounds(15, 15, 320, 40)
    $form.Controls.Add($label)

    $script:choice = "Nevermind"

    $btnAgain = New-Object System.Windows.Forms.Button
    $btnAgain.Text = "Close Again"
    $btnAgain.SetBounds(15, 70, 100, 30)
    $btnAgain.Add_Click({ $script:choice = "CloseAgain"; $form.Close() })
    $form.Controls.Add($btnAgain)

    $btnPermanent = New-Object System.Windows.Forms.Button
    $btnPermanent.Text = "Close Permanently"
    $btnPermanent.SetBounds(125, 70, 120, 30)
    $btnPermanent.Add_Click({ $script:choice = "ClosePermanently"; $form.Close() })
    $form.Controls.Add($btnPermanent)

    $btnNevermind = New-Object System.Windows.Forms.Button
    $btnNevermind.Text = "Nevermind"
    $btnNevermind.SetBounds(255, 70, 90, 30)
    $btnNevermind.Add_Click({ $script:choice = "Nevermind"; $form.Close() })
    $form.Controls.Add($btnNevermind)

    $form.ShowDialog() | Out-Null
    return $script:choice
}

Write-Host "Measuring I/O activity..." -ForegroundColor Yellow

try {
    $samples = (Get-Counter '\Process(*)\IO Data Bytes/sec' -ErrorAction Stop).CounterSamples |
        Where-Object { $_.InstanceName -notin @("_total", "idle") -and $_.CookedValue -gt 0 }
} catch {
    [System.Windows.Forms.MessageBox]::Show("Could not read I/O counters. Try running as Administrator.", "Disk Kill", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    exit
}

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
    }
} | Sort-Object TotalBytesPerSec -Descending | Select-Object -First 3

if ($grouped.Count -eq 0) {
    [System.Windows.Forms.MessageBox]::Show("No closeable high-I/O apps found.", "Disk Kill", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    exit
}

$message = "Close these top I/O-heavy apps (all instances)?`n`n"
$i = 1
foreach ($g in $grouped) {
    $mbps = [math]::Round($g.TotalBytesPerSec / 1MB, 2)
    $message += "$i. $($g.Name) - $mbps MB/s combined`n"
    $i++
}
$message += "`nUnsaved work in these apps will be lost.`nAfter closing, this window will keep watch and re-close them if they reopen (checked every 15s)."

$result = [System.Windows.Forms.MessageBox]::Show($message, "Confirm Close", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)

if ($result -ne [System.Windows.Forms.DialogResult]::Yes) {
    [System.Windows.Forms.MessageBox]::Show("Cancelled - nothing was closed.", "Disk Kill", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    exit
}

$targetNames = $grouped.Name | Select-Object -Unique
foreach ($name in $targetNames) {
    Get-Process -Name $name -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}

$host.UI.RawUI.WindowTitle = "DISKKILL ACTIVE - close this window to stop"

Write-Host "Watchdog active for: $($targetNames -join ', ')"
Write-Host "Checking every 15 seconds. Press Ctrl+C to stop, or choose 'Nevermind' in a popup."

$permanentList = @()
$watchdogRunning = $true

while ($watchdogRunning) {
    Start-Sleep -Seconds 15
    foreach ($name in $targetNames) {
        $running = Get-Process -Name $name -ErrorAction SilentlyContinue
        if (-not $running) { continue }

        if ($permanentList -contains $name) {
            $running | Stop-Process -Force -ErrorAction SilentlyContinue
            Write-Host "$(Get-Date -Format 'HH:mm:ss') - Auto-closed '$name' (permanent)"
            continue
        }

        $choice = Show-ChoiceDialog -processName $name
        switch ($choice) {
            "CloseAgain" {
                $running | Stop-Process -Force -ErrorAction SilentlyContinue
                Write-Host "$(Get-Date -Format 'HH:mm:ss') - Closed '$name'"
            }
            "ClosePermanently" {
                $running | Stop-Process -Force -ErrorAction SilentlyContinue
                $permanentList += $name
                Write-Host "$(Get-Date -Format 'HH:mm:ss') - Closed '$name' and added to permanent list"
            }
            "Nevermind" {
                $watchdogRunning = $false
                Write-Host "$(Get-Date -Format 'HH:mm:ss') - Watchdog stopped by user"
            }
        }

        if (-not $watchdogRunning) { break }
    }
}

[System.Windows.Forms.MessageBox]::Show("Watchdog stopped.", "Disk Kill", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
$host.UI.RawUI.WindowTitle = "Windows PowerShell"
