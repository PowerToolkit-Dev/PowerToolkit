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
    $form.Text = "Process Reopened"
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

$topProcesses = Get-Process |
    Where-Object { $criticalProcesses -notcontains $_.ProcessName } |
    Sort-Object WorkingSet64 -Descending |
    Select-Object -First 3 -Property ProcessName, Id, @{Name="RAM_MB";Expression={[math]::Round($_.WorkingSet64/1MB,1)}}

if ($topProcesses.Count -eq 0) {
    [System.Windows.Forms.MessageBox]::Show("No closeable processes found.", "RAM Kill", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    exit
}

$message = "Close these top 3 RAM-using apps?`n`n"
$i = 1
foreach ($p in $topProcesses) {
    $message += "$i. $($p.ProcessName) (PID $($p.Id)) - $($p.RAM_MB) MB`n"
    $i++
}
$message += "`nUnsaved work in these apps will be lost.`nAfter closing, this window will keep watch and re-close them if they reopen (checked every 15s)."

$result = [System.Windows.Forms.MessageBox]::Show($message, "Confirm Close", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)

if ($result -ne [System.Windows.Forms.DialogResult]::Yes) {
    [System.Windows.Forms.MessageBox]::Show("Cancelled - nothing was closed.", "RAM Kill", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    exit
}

$targetNames = $topProcesses.ProcessName | Select-Object -Unique
foreach ($p in $topProcesses) {
    try { Stop-Process -Id $p.Id -Force -ErrorAction Stop } catch {}
}

$host.UI.RawUI.WindowTitle = "RAMKILL ACTIVE - close this window to stop"

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

[System.Windows.Forms.MessageBox]::Show("Watchdog stopped.", "RAM Kill", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
$host.UI.RawUI.WindowTitle = "Windows PowerShell"
