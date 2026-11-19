while ($true) {
    Clear-Host
    $battery = Get-CimInstance -ClassName BatteryStatus -Namespace "root\wmi"
    $voltageVolts = $battery.Voltage / 1000
    $powerWatts = 0
    $status = "Unknown"
    if ($battery.Charging) {
        $status = "Charging"
        $rateMilliwatts = if ($null -ne $battery.ChargeRate -and $battery.ChargeRate -ne 0) { $battery.ChargeRate } else { $battery.Rate }
        $powerWatts = $rateMilliwatts / 1000
    } elseif ($battery.Discharging) {
        $status = "Discharging"
        $rateMilliwatts = if ($null -ne $battery.DischargeRate -and $battery.DischargeRate -ne 0) { $battery.DischargeRate } else { $battery.Rate }
        $powerWatts = -$rateMilliwatts / 1000
    }
    Write-Host "Battery Status: $status"
    Write-Host "Power Rate: $powerWatts W"
    Write-Host "Voltage: $voltageVolts V"
    Start-Sleep -Seconds 2
}
