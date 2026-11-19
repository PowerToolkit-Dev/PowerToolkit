<#
.SYNOPSIS
    Alias forwarding to the unified filescan engine.
.CATEGORY
    File Search
#>
& (Join-Path $PSScriptRoot "filescan.ps1") @args
