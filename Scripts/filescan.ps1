<#
.SYNOPSIS
    Universal file search: smart patterns (D*, *.pdf), date ranges, and Explorer launcher.
.CATEGORY
    File Search
#>
[CmdletBinding()]
param(
    [Alias('a')]
    [switch]$All,

    [Parameter(Position=0, ValueFromRemainingArguments=$true)]
    [string[]]$SearchTerms
)

# ------------------------------------------------------------
# 1. Parse Arguments & Switches
# ------------------------------------------------------------
$numbers = [System.Collections.Generic.List[double]]::new()
$Pattern = "*"
$searchAll = $All.IsPresent

if ($SearchTerms) {
    foreach ($item in $SearchTerms) {
        # Check if -a or -All was passed as loose text
        if ($item -match '^--?(a|all)$') {
            $searchAll = $true
            continue
        }

        $num = 0.0
        if ([double]::TryParse($item, [ref]$num)) {
            $numbers.Add($num)
        } else {
            $Pattern = $item
        }
    }
}

# If no pattern was specified at all, prompt the user
if ($Pattern -eq "*" -and $numbers.Count -eq 0) {
    $Pattern = Read-Host "Enter search name or pattern (e.g. R*, *.pdf, resume)"
    if ([string]::IsNullOrWhiteSpace($Pattern)) { $Pattern = "*" }
}

# Date setup
$useDateFilter = $false
$MinMonths = 0.0
$MaxMonths = 0.0

if ($numbers.Count -ge 2) {
    $useDateFilter = $true
    $sorted = $numbers | Sort-Object
    $MinMonths = $sorted[0]
    $MaxMonths = $sorted[1]
} elseif ($numbers.Count -eq 1) {
    $useDateFilter = $true
    $MinMonths = 0.0
    $MaxMonths = $numbers[0]
}

# If user typed wildcards (* or ?), use as-is. Otherwise wrap in *word*
$filter = if ($Pattern -match '[\*\?]') { $Pattern } else { "*$Pattern*" }

# ------------------------------------------------------------
# 2. Scope: User Profile (Fast) vs All Drives (Full System)
# ------------------------------------------------------------
$directories = [System.Collections.Generic.Stack[string]]::new()

if ($searchAll) {
    Write-Host "`n[Scope: FULL SYSTEM SCAN (All Drives)]" -ForegroundColor Magenta
    Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -match '^[A-Za-z]:\\$' } | ForEach-Object {
        $directories.Push($_.Root)
    }
} else {
    Write-Host "`n[Scope: User Folders & OneDrive] (Tip: Add -a for full system)" -ForegroundColor DarkCyan
    $directories.Push($env:USERPROFILE)
}

# Excluded system directories (only pruned on full drive scans)
$excludeDirs = @(
    "$env:SystemRoot\",
    "$env:ProgramFiles\",
    "${env:ProgramFiles(x86)}\",
    "$env:ProgramData\",
    "$env:SystemDrive\`$Recycle.Bin\",
    "$env:SystemDrive\System Volume Information\",
    "$env:SystemDrive\Recovery\",
    "$env:USERPROFILE\AppData\",
    "$env:USERPROFILE\Application Data\"
)

function Test-FastExclude([string]$p) {
    foreach ($ex in $excludeDirs) {
        if ($p.StartsWith($ex, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
    }
    return $false
}

# Date Display
if ($useDateFilter) {
    $now = [datetime]::Now
    $oldBound = $now.AddDays(-$MaxMonths * 30.4375)
    $newBound = $now.AddDays(-$MinMonths * 30.4375)
    Write-Host "Pattern: $filter" -ForegroundColor Yellow
    Write-Host "Dates:   $($oldBound.ToString('yyyy-MM-dd')) to $($newBound.ToString('yyyy-MM-dd'))" -ForegroundColor Yellow
} else {
    Write-Host "Pattern: $filter" -ForegroundColor Yellow
}
Write-Host ""

$results = [System.Collections.Generic.List[object]]::new()
$scanned = 0

# ------------------------------------------------------------
# 3. Traversal Engine
# ------------------------------------------------------------
while ($directories.Count -gt 0) {
    $current = $directories.Pop()
    if (Test-FastExclude $current) { continue }

    # Subdirectories
    try {
        foreach ($d in [System.IO.Directory]::EnumerateDirectories($current)) {
            try {
                if (Test-FastExclude $d) { continue }

                $attr = [System.IO.File]::GetAttributes($d)
                if ($attr.HasFlag([System.IO.FileAttributes]::System)) { continue }
                if ($attr.HasFlag([System.IO.FileAttributes]::Hidden)) { continue }

                $directories.Push($d)
            } catch { continue }
        }
    } catch { continue }

    # Files
    try {
        foreach ($f in [System.IO.Directory]::EnumerateFiles($current)) {
            $scanned++
            if ($scanned % 4000 -eq 0) {
                Write-Host "  ...scanned $scanned files | matched $($results.Count)" -ForegroundColor DarkGray
            }

            $fileName = [System.IO.Path]::GetFileName($f)
            if (-not ($fileName -like $filter)) { continue }

            try {
                $attr = [System.IO.File]::GetAttributes($f)
                if ($attr.HasFlag([System.IO.FileAttributes]::System)) { continue }

                $writeTime  = [System.IO.File]::GetLastWriteTime($f)
                $accessTime = [System.IO.File]::GetLastAccessTime($f)
                $effectiveDate = if ($writeTime -gt $accessTime) { $writeTime } else { $accessTime }

                if ($useDateFilter) {
                    $inRange = ($writeTime -ge $oldBound -and $writeTime -le $newBound) -or 
                               ($accessTime -ge $oldBound -and $accessTime -le $newBound)
                    if (-not $inRange) { continue }
                }

                $fileLen = (New-Object System.IO.FileInfo($f)).Length

                $results.Add([PSCustomObject]@{
                    Index        = $results.Count
                    Name         = $fileName
                    Owner        = ""
                    Modified     = $effectiveDate.ToString("yyyy-MM-dd HH:mm")
                    SizeMB       = [math]::Round($fileLen / 1MB, 2)
                    Path         = $f
                })
            } catch { continue }
        }
    } catch { continue }
}

Write-Host "`nScanned $scanned files. Found $($results.Count) match(es)." -ForegroundColor Cyan

if ($results.Count -eq 0) {
    if (-not $searchAll) {
        Write-Host "No matches in user folders. Try again with '-a' for a full PC scan." -ForegroundColor DarkGray
    }
    return
}

# ------------------------------------------------------------
# 4. Result Actions
# ------------------------------------------------------------
if ($results.Count -eq 1) {
    Write-Host "`nFound 1 match -> Opening in File Explorer:" -ForegroundColor Green
    Write-Host $results[0].Path -ForegroundColor Yellow
    explorer.exe /select,"$($results[0].Path)"
    return
}

Write-Host ""
$results | Format-Table @{Label="#"; Expression={"[$($_.Index)]"}}, Name, Modified, SizeMB, Path -AutoSize

Write-Host "Enter [#] to open in Explorer (or press Enter to exit):" -ForegroundColor Yellow
while ($true) {
    $choice = Read-Host "Select file"
    if ([string]::IsNullOrWhiteSpace($choice) -or $choice -match '^[Qq]$') { break }

    if ($choice -match '^\d+$' -and [int]$choice -lt $results.Count) {
        $selected = $results[[int]$choice].Path
        Write-Host "Opening: $selected" -ForegroundColor Green
        explorer.exe /select,"$selected"
        break
    } else {
        Write-Host "Invalid number. Choose 0 to $($results.Count - 1)." -ForegroundColor Red
    }
}
