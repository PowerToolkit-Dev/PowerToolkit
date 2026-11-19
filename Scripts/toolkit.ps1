Clear-Host
$scriptDir = $PSScriptRoot

Write-Host "==========================================================================================" -ForegroundColor Cyan
Write-Host "                                POWERSHELL TOOLKIT DASHBOARD                              " -ForegroundColor Cyan
Write-Host "==========================================================================================" -ForegroundColor Cyan
Write-Host "Directory: $scriptDir" -ForegroundColor DarkGray
Write-Host "Shortcuts: Type 'T' or 'home' for Dashboard  |  Type 'h' or 'history' for Command History`n" -ForegroundColor DarkGray
Write-Host "To remove the toolkit, type 'uninstall' - don't delete this folder by hand, it won't undo your PATH or execution policy changes.`n" -ForegroundColor DarkYellow

# Built-in description registry
$defaults = @{
    "battery"       = @{ Cat = "Monitoring";  Desc = "Live battery stats, power draw, voltage, and health wear level." }
    "diskkill"      = @{ Cat = "App Control"; Desc = "Close high I/O apps and prevent them from reopening." }
    "diskwatch"     = @{ Cat = "Monitoring";  Desc = "Live view of top apps generating disk and network I/O." }
    "elevate"       = @{ Cat = "App Control"; Desc = "Open an elevated Administrator terminal in current folder." }
    "export"        = @{ Cat = "Maintenance"; Desc = "Export entire toolkit into a portable setup file on Desktop." }
    "filescan"      = @{ Cat = "File Search"; Desc = "Universal file search: patterns (R*, *.pdf), dates, and Explorer jump." }
    "findfiles"     = @{ Cat = "File Search"; Desc = "Alias pointing to universal filescan engine." }
    "flushnet"      = @{ Cat = "Maintenance"; Desc = "Flushes DNS, resets ARP cache, clears NetBIOS, and renews IP lease." }
    "history"       = @{ Cat = "Monitoring";  Desc = "Display clean terminal session command history (or type 'h')." }
    "internetspeed" = @{ Cat = "Monitoring";  Desc = "High-accuracy download speed test, true ICMP latency, and jitter." }
    "lockhunt"      = @{ Cat = "App Control"; Desc = "Find and terminate processes locking a stuck file or folder." }
    "off"           = @{ Cat = "App Control"; Desc = "Turn system features off (e.g. 'off sudo')." }
    "on"            = @{ Cat = "App Control"; Desc = "Turn system features on (e.g. 'on sudo')." }
    "openfile"      = @{ Cat = "File Search"; Desc = "Alias pointing to universal filescan engine." }
    "overview"      = @{ Cat = "Monitoring";  Desc = "Full dashboard: battery, CPU, RAM, disk, uptime, and alerts." }
    "portwatch"     = @{ Cat = "App Control"; Desc = "Find which process is occupying a port and optionally kill it." }
    "quickclean"    = @{ Cat = "Maintenance"; Desc = "Deep clean temp files, Windows Update cache, crash dumps, and Recycle Bin." }
    "ramkill"       = @{ Cat = "App Control"; Desc = "Close top 3 RAM apps + watchdog to prevent reopen." }
    "ramtop"        = @{ Cat = "App Control"; Desc = "Popup showing top 3 RAM-consuming apps." }
    "sudo"          = @{ Cat = "App Control"; Desc = "Run command as Admin (use 'on sudo' and 'off sudo')." }
    "sysaudit"      = @{ Cat = "Monitoring";  Desc = "Security posture check: Antivirus, Firewall, BitLocker, and UAC." }
    "underhood"     = @{ Cat = "Dev Tools";   Desc = "Inspect, edit, and test ANY script in the toolkit." }
    "uninstall"     = @{ Cat = "Maintenance"; Desc = "Removes the toolkit: files, PATH entry, and execution policy restore." }
}

# Exclude internal shortcuts from cluttering the A-Z list
$files = Get-ChildItem -Path $scriptDir -Filter "*.ps1" -File -ErrorAction SilentlyContinue |
    Where-Object { $_.BaseName -notmatch '^(t|home|toolkit|sudoon|sudooff)$' }

$catalog = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($file in $files) {
    $name = $file.BaseName.ToLower()
    $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue

    $synopsis = ""
    $category = ""

    if ($content -match '(?si)\.SYNOPSIS\s*\r?\n\s*(.*?)(?=\r?\n\s*(\.[a-z]+|#>))') {
        $synopsis = ($matches[1].Trim() -split "[\r\n]+")[0].Trim()
    }

    if ($content -match '(?si)\.CATEGORY\s*\r?\n\s*(.*?)(?=\r?\n\s*(\.[a-z]+|#>))') {
        $category = ($matches[1].Trim() -split "[\r\n]+")[0].Trim()
    }

    if ([string]::IsNullOrWhiteSpace($synopsis) -and $defaults.ContainsKey($name)) {
        $synopsis = $defaults[$name].Desc
    }
    if ([string]::IsNullOrWhiteSpace($category) -and $defaults.ContainsKey($name)) {
        $category = $defaults[$name].Cat
    }

    if ([string]::IsNullOrWhiteSpace($synopsis)) { $synopsis = "Custom script in $scriptDir" }
    if ([string]::IsNullOrWhiteSpace($category)) { $category = "General" }

    $catalog.Add([PSCustomObject]@{
        Name        = $file.BaseName
        Category    = $category
        Description = $synopsis
    })
}

# Strict Global Alphabetical Sort (A to Z) across ALL items
$sortedAll = $catalog | Sort-Object Name

Write-Host ("{0,-15} | {1,-13} | {2}" -f "COMMAND", "CATEGORY", "DESCRIPTION") -ForegroundColor DarkYellow
Write-Host ("-" * 90) -ForegroundColor DarkGray

foreach ($item in $sortedAll) {
    Write-Host ("{0,-15}" -f $item.Name) -ForegroundColor Green -NoNewline
    Write-Host " | " -ForegroundColor DarkGray -NoNewline
    Write-Host ("{0,-13}" -f $item.Category) -ForegroundColor Cyan -NoNewline
    Write-Host " | " -ForegroundColor DarkGray -NoNewline
    Write-Host $item.Description -ForegroundColor Gray
}

Write-Host ("-" * 90) -ForegroundColor DarkGray
Write-Host "Tip: Type 'underhood <command>' to view code or test parameters." -ForegroundColor DarkGray
Write-Host ""

