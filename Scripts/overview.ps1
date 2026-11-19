<#
.SYNOPSIS
    Full live dashboard: battery, CPU, RAM, disk, uptime, and high-drain alerts.
.CATEGORY
    Monitoring
#>

Add-Type -AssemblyName System.Windows.Forms, System.Drawing

$notifyIcon = [System.Windows.Forms.NotifyIcon]::new()
$notifyIcon.Icon = [System.Drawing.SystemIcons]::Information
$notifyIcon.Visible = $true

$ramAlerted = $false
$dischargeAlerted = $false

function Show-Alert($title, $message) {
    $notifyIcon.BalloonTipTitle = $title
    $notifyIcon.BalloonTipText = $message
    $notifyIcon.ShowBalloonTip(5000)
}

[Console]::CursorVisible = $false
Clear-Host

try {
    while ($true) {
        # Fast CPU calculation via Counter
        $cpuCounter = Get-Counter '\Processor(_Total)\% Processor Time' -ErrorAction SilentlyContinue
        $cpuLoad = if ($cpuCounter) { [math]::Round($cpuCounter.CounterSamples[0].CookedValue, 1) } else { 0 }

        # Query OS, Battery, and Disk
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -Property TotalVisibleMemorySize, FreePhysicalMemory, LastBootUpTime
        $battery = Get-CimInstance -ClassName BatteryStatus -Namespace "root\wmi" -ErrorAction SilentlyContinue
        $batteryInfo = Get-CimInstance -ClassName Win32_Battery -Property EstimatedRunTime, EstimatedChargeRemaining -ErrorAction SilentlyContinue
        $disk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='C:'" -Property Size, FreeSpace

        # Battery metrics
        $powerWatts = 0
        $status = "AC Connected / Idle"
        $voltageVolts = if ($battery) { [math]::Round($battery.Voltage / 1000, 2) } else { 0 }
        
        if ($battery.Charging) {
            $status = "Charging"
            $rate = if ($battery.ChargeRate) { $battery.ChargeRate } else { $battery.Rate }
            $powerWatts = [math]::Round($rate / 1000, 1)
        } elseif ($battery.Discharging) {
            $status = "Discharging"
            $rate = if ($battery.DischargeRate) { $battery.DischargeRate } else { $battery.Rate }
            $powerWatts = -[math]::Round($rate / 1000, 1)
        }

        $timeRemaining = if (-not $batteryInfo -or $batteryInfo.EstimatedRunTime -eq 71582788) { "N/A" } else { "$($batteryInfo.EstimatedRunTime) min" }

        # CPU Temp
        $cpuTemp = try {
            $temp = Get-CimInstance -ClassName MSAcpi_ThermalZoneTemperature -Namespace "root\wmi" -ErrorAction Stop | Select-Object -First 1
            [math]::Round(($temp.CurrentTemperature / 10) - 273.15, 1)
        } catch { "N/A (needs admin)" }

        # Memory & Disk
        $totalRamGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
        $freeRamGB  = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
        $usedRamGB  = [math]::Round($totalRamGB - $freeRamGB, 2)
        $ramPercent = [math]::Round(($usedRamGB / $totalRamGB) * 100, 1)

        $totalDiskGB = [math]::Round($disk.Size / 1GB, 1)
        $freeDiskGB  = [math]::Round($disk.FreeSpace / 1GB, 1)

        $uptime = (Get-Date) - $os.LastBootUpTime
        $uptimeString = "{0}d {1}h {2}m" -f $uptime.Days, $uptime.Hours, $uptime.Minutes

        # Top 3 processes
        $topProcesses = Get-Process | Sort-Object CPU -Descending | Select-Object -First 3 -Property ProcessName,
            @{Name="CPU(s)";Expression={[math]::Round($_.CPU, 1)}},
            @{Name="RAM(MB)";Expression={[math]::Round($_.WorkingSet64 / 1MB, 1)}}

        # RAM Alert (>80%)
        if ($ramPercent -ge 80) {
            if (-not $ramAlerted) {
                Show-Alert "High RAM Usage" "RAM is at $ramPercent%"
                $ramAlerted = $true
            }
        } else {
            $ramAlerted = $false
        }

        # Unusual Battery Drain Alert (Discharging >= 15W while CPU <= 20%)
        if ($status -eq "Discharging" -and [math]::Abs($powerWatts) -ge 15 -and $cpuLoad -le 20) {
            if (-not $dischargeAlerted) {
                Show-Alert "Unusual Battery Drain" "Discharging at $([math]::Abs($powerWatts))W while CPU is only $cpuLoad% - check for background processes"
                $dischargeAlerted = $true
            }
        } else {
            $dischargeAlerted = $false
        }

        # Smooth, flicker-free redraw
        [Console]::SetCursorPosition(0, 0)
        
        $output = @"
============================================================
                     SYSTEM OVERVIEW                        
============================================================
=== Battery ===
Status:              $status
Power Rate:          $powerWatts W
Voltage:             $voltageVolts V
Charge Remaining:    $($batteryInfo.EstimatedChargeRemaining)%
Est. Time Remaining: $timeRemaining

=== CPU & Uptime ===
Load:                $cpuLoad%
Temp:                $cpuTemp °C
Uptime:              $uptimeString

=== Memory & Disk ===
RAM Used:            $usedRamGB GB / $totalRamGB GB ($ramPercent%)
Disk (C:) Free:      $freeDiskGB GB / $totalDiskGB GB

=== Top 3 Processes (CPU) ===
$($topProcesses | Format-Table -AutoSize | Out-String)
============================================================
(Refreshes every 3s, alerts active, press Ctrl+C to stop)
"@
        Write-Host $output
        Start-Sleep -Seconds 3
    }
}
finally {
    [Console]::CursorVisible = $true
    $notifyIcon.Dispose()
}
