param(
    [Parameter(Position=0, Mandatory=$false)]
    [string]$Command
)

$scriptDir = $PSScriptRoot

function Get-AvailableCommands {
    # Includes toolkit.ps1 (only excludes underhood itself from inspecting itself)
    $files = Get-ChildItem -Path $scriptDir -Filter "*.ps1" -File -ErrorAction SilentlyContinue |
        Where-Object { $_.BaseName -ne 'underhood' }
    
    $map = @{}
    foreach ($f in $files) {
        $map[$f.BaseName.ToLower()] = $f.FullName
    }
    return $map
}

$commandMap = Get-AvailableCommands

if ([string]::IsNullOrWhiteSpace($Command) -or -not $commandMap.ContainsKey($Command.ToLower())) {
    Clear-Host
    if ($Command) {
        Write-Host "Unknown command: '$Command'" -ForegroundColor Red
        Write-Host ""
    }
    
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "               UNDERHOOD: Managed Commands                  " -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "Directory: $scriptDir" -ForegroundColor DarkGray
    Write-Host "Discovered programs ($($commandMap.Count)):`n" -ForegroundColor DarkGray
    
    $sortedKeys = $commandMap.Keys | Sort-Object
    if ($sortedKeys.Count -eq 0) {
        Write-Host "No scripts found in $scriptDir." -ForegroundColor Yellow
        exit 1
    }

    foreach ($name in $sortedKeys) {
        Write-Host "  underhood " -ForegroundColor DarkGray -NoNewline
        Write-Host ("{0,-16}" -f $name) -ForegroundColor Green -NoNewline
        if ($name -eq "toolkit") { Write-Host " (Dashboard & Menu)" -ForegroundColor DarkGray }
        else { Write-Host "" }
    }
    Write-Host ""
    
    $Command = Read-Host "Select a command to inspect (e.g., toolkit, lockhunt)"
    if ([string]::IsNullOrWhiteSpace($Command) -or -not $commandMap.ContainsKey($Command.ToLower())) {
        Write-Host "Exited." -ForegroundColor DarkGray
        exit 0
    }
}

$commandKey = $Command.ToLower()
$scriptPath = $commandMap[$commandKey]

function Show-Script {
    Clear-Host
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " UNDERHOOD: $commandKey" -ForegroundColor Cyan
    Write-Host " Path: $scriptPath" -ForegroundColor DarkGray
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""

    $lineNumber = 1
    Get-Content -Path $scriptPath | ForEach-Object {
        Write-Host ("{0,4} | {1}" -f $lineNumber, $_)
        $lineNumber++
    }
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
}

function Read-Action {
    Write-Host ""
    Write-Host "[E] Edit  |  [T] Test  |  [Q] Quit" -ForegroundColor Yellow
    Write-Host ""

    while ($true) {
        $key = [Console]::ReadKey($true)
        switch ($key.Key) {
            ([ConsoleKey]::E) { return "edit" }
            ([ConsoleKey]::T) { return "test" }
            ([ConsoleKey]::Q) { return "quit" }
            ([ConsoleKey]::Escape) { return "quit" }
        }
        if ($key.Key -eq [ConsoleKey]::C -and ($key.Modifiers -band [ConsoleModifiers]::Control)) {
            return "quit"
        }
    }
}

function Test-Script {
    Clear-Host
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host " TESTING: $commandKey" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host ""

    try {
        $ast = [System.Management.Automation.Language.Parser]::ParseInput((Get-Content $scriptPath -Raw), [ref]$null, [ref]$null)
        if ($ast.ParamBlock -and $ast.ParamBlock.Parameters.Count -gt 0) {
            Write-Host "Parameters for this script:" -ForegroundColor Cyan
            foreach ($p in $ast.ParamBlock.Parameters) {
                Write-Host "  -$($p.Name.VariablePath.UserPath) ($($p.StaticType.Name))" -ForegroundColor DarkYellow
            }
            Write-Host ""
        }
    } catch {}

    $arguments = Read-Host "Enter arguments (or press ENTER for none)"

    Write-Host ""
    Write-Host "---------------- Running ----------------" -ForegroundColor DarkGray
    Write-Host ""

    if ([string]::IsNullOrWhiteSpace($arguments)) {
        & $scriptPath
    } else {
        $tokens = [regex]::Matches($arguments, '(?:"([^"]*)"|''([^'']*)''|(\S+))') | ForEach-Object {
            if ($_.Groups[1].Success) { $_.Groups[1].Value }
            elseif ($_.Groups[2].Success) { $_.Groups[2].Value }
            else { $_.Groups[3].Value }
        }
        & $scriptPath @tokens
    }

    Write-Host ""
    Write-Host "---------------- Finished ---------------" -ForegroundColor DarkGray
    Read-Host "Press Enter to return to UnderHood"
}

while ($true) {
    Show-Script
    $action = Read-Action
    switch ($action) {
        "edit" {
            Start-Process -FilePath "notepad.exe" -ArgumentList "`"$scriptPath`"" -Wait
        }
        "test" {
            Test-Script
        }
        "quit" {
            Clear-Host
            exit 0
        }
    }
}
