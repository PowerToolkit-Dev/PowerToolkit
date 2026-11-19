<#
.SYNOPSIS
    Live battery stats, power draw, voltage, and health wear level.
.CATEGORY
    Monitoring
#>

$designCap = $null
try {
    $designCap = (Get-CimInstance -ClassName BatteryStaticData -Namespace "root\wmi" -ErrorAction Stop | Select-Object -First 1).DesignedCapacity
} catch {}

if (-not $designCap) {
    try {
        $tempFile = "$env:TEMP\batteryreport_temp.xml"
        powercfg /batteryreport /XML /output $tempFile | Out-Null
        if (Test-Path $tempFile) {
            $xml = Get-Content $tempFile -Raw
            if ($xml -match '<DesignCapacity>(\d+)</DesignCapacity>') {
                $designCap = [int]$matches[1]
            }
            Remove-Item $tempFile -ErrorAction SilentlyContinue
        }
    } catch {}
}

[Console]::CursorVisible = $false
Clear-Host

try {
    while ($true) {
        $battery = Get-CimInstance -ClassName BatteryStatus -Namespace "root\wmi" -ErrorAction SilentlyContinue
        $batteryInfo = Get-CimInstance -ClassName Win32_Battery -Property EstimatedRunTime, EstimatedChargeRemaining -ErrorAction SilentlyContinue

        $voltageVolts = if ($battery) { [math]::Round($battery.Voltage / 1000, 2) } else { 0 }
        $powerWatts = 0
        $status = "AC Connected / Idle"

        if ($battery.Charging) {
            $status = "Charging"
            $rate = if ($battery.ChargeRate) { $battery.ChargeRate } else { $battery.Rate }
            $powerWatts = [math]::Round($rate / 1000, 1)
        } elseif ($battery.Discharging) {
            $status = "Discharging"
            $rate = if ($battery.DischargeRate) { $battery.DischargeRate } else { $battery.Rate }
            $powerWatts = -[math]::Round($rate / 1000, 1)
        }

        # Wear & Health Calculation
        $healthString = "N/A"
        $wearString = "N/A"
        if ($designCap) {
            try {
                $fullCap = (Get-CimInstance -ClassName BatteryFullChargedCapacity -Namespace "root\wmi" -ErrorAction Stop | Select-Object -First 1).FullChargedCapacity
                if ($fullCap) {
                    $healthPercent = [math]::Round(($fullCap / $designCap) * 100, 1)
                    $wearPercent = [math]::Round(100 - $healthPercent, 1)
                    $healthString = "$healthPercent% ($fullCap mWh / $designCap mWh)"
                    $wearString   = if ($wearPercent -gt 0) { "$wearPercent% degraded from factory" } else { "0% (Factory Fresh)" }
                }
            } catch {}
        }

        # Smooth Repaint
        [Console]::SetCursorPosition(0, 0)
        $output = @"
============================================================
                     BATTERY DIAGNOSTIC                     
============================================================
Status:               $status
Power Draw / Charge:  $powerWatts W
Voltage:              $voltageVolts V
Current Charge:       $($batteryInfo.EstimatedChargeRemaining)%
Est. Time Remaining:  $($batteryInfo.EstimatedRunTime) minutes

--- Battery Health & Wear ---
Health Capacity:      $healthString
Wear Degradation:     $wearString
============================================================
(Refreshes every 2s, press Ctrl+C to exit)
"@
        Write-Host $output
        Start-Sleep -Seconds 2
    }
}
finally {
    [Console]::CursorVisible = $true
}
