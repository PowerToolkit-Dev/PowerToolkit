<#
.SYNOPSIS
    Power Toolkit Installer - auto-detects available scripts and lets the
    user choose which ones to install.
.DESCRIPTION
    Scans the "Scripts" folder next to this installer for .ps1 files, reads
    each one's comment-based help (.SYNOPSIS / .CATEGORY) if present, and
    shows a checklist so the user can pick exactly which tools to install.
    Nothing here is hidden or encoded - open this file in any text editor
    to see exactly what it does.

    To add a new tool later: just drop a new .ps1 file into the Scripts
    folder. It will show up automatically next time this installer runs -
    no changes to this file needed. Give it a comment header with
    .SYNOPSIS, .CATEGORY, and optionally .REQUIRESADMIN set to True.

    REQUIRESADMIN is just a label for the checklist - it does NOT elevate
    anything by itself. A script that needs admin rights should request
    elevation itself, only for the specific action that needs it, using
    Start-Process -Verb RunAs (see sudo.ps1 for the existing pattern).
    That way installing the toolkit never needs admin - only actually
    running an admin-only command does, and Windows' own UAC prompt is
    what the user approves, same as any normal app.
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

try {

$InstallDir = Join-Path $env:LOCALAPPDATA "PowerToolkit"
$SourceDir  = Join-Path $PSScriptRoot "Scripts"

# ------------------------------------------------------------
# 1. Auto-detect every script in the Scripts folder
# ------------------------------------------------------------
function Get-ScriptInfo {
    param([System.IO.FileInfo]$File)

    $synopsis = $File.BaseName
    $category = "General"
    $requiresAdmin = $false

    $raw = Get-Content -Path $File.FullName -Raw -ErrorAction SilentlyContinue
    if ($raw -match '(?s)<#(.*?)#>') {
        $block = $matches[1]
        if ($block -match '(?im)^\s*\.SYNOPSIS\s*\r?\n\s*(.+)') { $synopsis = $matches[1].Trim() }
        if ($block -match '(?im)^\s*\.CATEGORY\s*\r?\n\s*(.+)') { $category = $matches[1].Trim() }
        if ($block -match '(?im)^\s*\.REQUIRESADMIN\s*\r?\n\s*(.+)') {
            $adminValue = $matches[1].Trim().ToLower()
            if ($adminValue -eq "true" -or $adminValue -eq "yes" -or $adminValue -eq "1") {
                $requiresAdmin = $true
            }
        }
    }

    [PSCustomObject]@{
        Name          = $File.BaseName
        FileName      = $File.Name
        Path          = $File.FullName
        Synopsis      = $synopsis
        Category      = $category
        RequiresAdmin = $requiresAdmin
    }
}

if (-not (Test-Path $SourceDir)) {
    [System.Windows.Forms.MessageBox]::Show(
        "Could not find the 'Scripts' folder next to this installer.`nExpected: $SourceDir",
        "Power Toolkit Installer", "OK", "Error") | Out-Null
    exit 1
}

$available = Get-ChildItem -Path $SourceDir -Filter "*.ps1" -File |
    Sort-Object Name | ForEach-Object { Get-ScriptInfo $_ }

if ($available.Count -eq 0) {
    [System.Windows.Forms.MessageBox]::Show(
        "No scripts found in $SourceDir", "Power Toolkit Installer", "OK", "Warning") | Out-Null
    exit 1
}

# ------------------------------------------------------------
# 2. Build the checklist GUI
# ------------------------------------------------------------
$form = New-Object System.Windows.Forms.Form
$form.Text = "Power Toolkit Installer"
$form.Size = New-Object System.Drawing.Size(560, 520)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

$label = New-Object System.Windows.Forms.Label
$label.Text = "Choose which tools to install into $InstallDir :"
$label.AutoSize = $true
$label.Location = New-Object System.Drawing.Point(15, 15)
$form.Controls.Add($label)

$checklist = New-Object System.Windows.Forms.CheckedListBox
$checklist.Location = New-Object System.Drawing.Point(15, 40)
$checklist.Size = New-Object System.Drawing.Size(515, 380)
$checklist.CheckOnClick = $true
$checklist.HorizontalScrollbar = $true

$grouped = $available | Group-Object Category | Sort-Object Name
foreach ($group in $grouped) {
    foreach ($item in ($group.Group | Sort-Object Name)) {
        $adminTag = if ($item.RequiresAdmin) { " [Admin prompt on use]" } else { "" }
        [void]$checklist.Items.Add("[$($item.Category)] $($item.Name) - $($item.Synopsis)$adminTag", $true)
    }
}
$form.Controls.Add($checklist)

$hint = New-Object System.Windows.Forms.Label
$hint.Text = "Tools marked [Admin prompt on use] will ask Windows for permission only when you run them, not during install."
$hint.AutoSize = $false
$hint.Size = New-Object System.Drawing.Size(515, 30)
$hint.Location = New-Object System.Drawing.Point(15, 465)
$hint.ForeColor = [System.Drawing.Color]::DarkSlateGray
$hint.Font = New-Object System.Drawing.Font($hint.Font.FontFamily, 8)
$form.Controls.Add($hint)
$form.Size = New-Object System.Drawing.Size(560, 560)

$selectAllBtn = New-Object System.Windows.Forms.Button
$selectAllBtn.Text = "Select All"
$selectAllBtn.Location = New-Object System.Drawing.Point(15, 430)
$selectAllBtn.Size = New-Object System.Drawing.Size(100, 28)
$selectAllBtn.Add_Click({ for ($i=0; $i -lt $checklist.Items.Count; $i++) { $checklist.SetItemChecked($i, $true) } })
$form.Controls.Add($selectAllBtn)

$selectNoneBtn = New-Object System.Windows.Forms.Button
$selectNoneBtn.Text = "Select None"
$selectNoneBtn.Location = New-Object System.Drawing.Point(125, 430)
$selectNoneBtn.Size = New-Object System.Drawing.Size(100, 28)
$selectNoneBtn.Add_Click({ for ($i=0; $i -lt $checklist.Items.Count; $i++) { $checklist.SetItemChecked($i, $false) } })
$form.Controls.Add($selectNoneBtn)

$installBtn = New-Object System.Windows.Forms.Button
$installBtn.Text = "Install Selected"
$installBtn.Location = New-Object System.Drawing.Point(330, 430)
$installBtn.Size = New-Object System.Drawing.Size(100, 30)
$installBtn.DialogResult = [System.Windows.Forms.DialogResult]::OK
$form.Controls.Add($installBtn)
$form.AcceptButton = $installBtn

$cancelBtn = New-Object System.Windows.Forms.Button
$cancelBtn.Text = "Cancel"
$cancelBtn.Location = New-Object System.Drawing.Point(435, 430)
$cancelBtn.Size = New-Object System.Drawing.Size(95, 30)
$cancelBtn.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$form.Controls.Add($cancelBtn)
$form.CancelButton = $cancelBtn

$result = $form.ShowDialog()
if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
    exit 0
}

$chosenNames = @()
for ($i = 0; $i -lt $checklist.Items.Count; $i++) {
    if ($checklist.GetItemChecked($i)) { $chosenNames += $available[$i].FileName }
}

if ($chosenNames.Count -eq 0) {
    [System.Windows.Forms.MessageBox]::Show("Nothing selected - nothing installed.", "Power Toolkit Installer") | Out-Null
    exit 0
}

# ------------------------------------------------------------
# 3. Install the chosen scripts
# ------------------------------------------------------------
if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}

$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($currentPath -split ";" -notcontains $InstallDir) {
    [Environment]::SetEnvironmentVariable("Path", "$currentPath;$InstallDir", "User")
    $env:Path += ";$InstallDir"
}

foreach ($name in $chosenNames) {
    Copy-Item -Path (Join-Path $SourceDir $name) -Destination (Join-Path $InstallDir $name) -Force
}

# Copy the uninstaller itself into the install folder (not just the Scripts
# subfolder it came from) so it's always sitting right next to whatever
# gets installed - typing 'uninstall' or double-clicking it in that folder
# always works, even if the original download location is long gone.
$uninstallerSource = Join-Path $PSScriptRoot "Uninstall.ps1"
if (Test-Path $uninstallerSource) {
    Copy-Item -Path $uninstallerSource -Destination (Join-Path $InstallDir "uninstall.ps1") -Force
}

# Allow locally-installed scripts to run for this user, and strip the
# "downloaded from the internet" flag so PowerShell doesn't demand a
# digital signature for files that just came from a local zip extract.
# CurrentUser scope only - no admin rights needed. This step is wrapped
# separately so a failure here (e.g. a stricter policy already enforced
# by machine/group policy) doesn't undo the install that already happened.
#
# Before changing anything, save whatever the CurrentUser policy already
# was, so Uninstall.ps1 can put it back exactly instead of guessing.
try {
    $originalPolicy = Get-ExecutionPolicy -Scope CurrentUser
    $originalPolicy.ToString() | Out-File -FilePath (Join-Path $InstallDir ".policy-backup.txt") -Encoding UTF8 -Force
} catch {
    Write-Warning "Could not record the original execution policy for later restore."
}

try {
    # Deliberately not using -ErrorAction Stop here: if a Bypass policy is
    # already active for this process (from the .bat launcher), PowerShell
    # writes an informational "policy updated but overridden this session"
    # notice that looks like an error but isn't one - the CurrentUser value
    # is still saved to the registry correctly. Verify by re-reading it
    # afterward instead of trusting whether this line threw.
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | Out-Null
} catch {
    # Swallow here too - the real check is the verification read below.
}

$verifiedPolicy = Get-ExecutionPolicy -Scope CurrentUser
if ($verifiedPolicy -notin @("RemoteSigned", "Unrestricted", "Bypass")) {
    Write-Warning "Execution policy is still '$verifiedPolicy' (it may be controlled by a stricter machine or organization policy - see Get-ExecutionPolicy -List). Installed files are unaffected; you can set it yourself with: Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force"
}

try {
    Get-ChildItem -Path $InstallDir -Recurse | Unblock-File -ErrorAction Stop
} catch {
    Write-Warning "Could not unblock some files. If scripts refuse to run later, try Unblock-File manually."
}

[System.Windows.Forms.MessageBox]::Show(
    "Installed $($chosenNames.Count) script(s) to $InstallDir`n`nOpen a new terminal to use them (PATH was just updated).",
    "Power Toolkit Installer", "OK", "Information") | Out-Null

} catch {
    $errorText = $_ | Out-String
    $logPath = Join-Path $env:TEMP "PowerToolkit-install-error.log"
    $errorText | Out-File -FilePath $logPath -Encoding UTF8

    try {
        [System.Windows.Forms.MessageBox]::Show(
            "The installer hit an error and stopped:`n`n$errorText`n`nFull details saved to:`n$logPath",
            "Power Toolkit Installer - Error", "OK", "Error") | Out-Null
    } catch {
        # Windows Forms itself may have failed to load - fall back to console
        Write-Host "INSTALLER ERROR:" -ForegroundColor Red
        Write-Host $errorText -ForegroundColor Red
        Write-Host "Details saved to: $logPath" -ForegroundColor Yellow
        Read-Host "Press Enter to close"
    }
}
