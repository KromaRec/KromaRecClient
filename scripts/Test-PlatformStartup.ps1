[CmdletBinding()]
param([Parameter(Mandatory)][string]$GamePath, [Parameter(Mandatory)][datetime]$Since,
      [string]$PlayerLog)
$ErrorActionPreference = 'Stop'
function Read-Stage([string]$File, [string]$Pattern) {
    if (!$File -or !(Test-Path -LiteralPath $File -PathType Leaf)) { return 'MISSING' }
    if ((Get-Item -LiteralPath $File).LastWriteTime -lt $Since) { return 'STALE' }
    if (Select-String -LiteralPath $File -Pattern $Pattern -Quiet) { return 'OBSERVED' }
    return 'UNOBSERVED'
}
$bep = Join-Path $GamePath 'BepInEx/LogOutput.log'
$steam = @(Get-Process -Name steam -ErrorAction SilentlyContinue)
$game = @(Get-Process -Name RecRoom -ErrorAction SilentlyContinue)
$exe = Join-Path $GamePath 'RecRoom.exe'
[pscustomobject]@{
    SteamRunningNow = $steam.Count -gt 0
    SelectedGameRunningNow = $exe -in $game.Path
    GameExecutablePresent = Test-Path -LiteralPath $exe -PathType Leaf
    SteamInitFailure = Read-Stage $PlayerLog 'Failed to initialize Steam Platform'
    PatchLoaded = Read-Stage $bep 'Loading \[KromaRec Patch'
    HooksInstalled = Read-Stage $bep 'Required Harmony hook installation completed'
    DiscoveryTlsRejected = Read-Stage $bep 'TLS discovery request=False'
    DiscoveryAccepted = Read-Stage $bep 'RecNet discovery: service origins accepted'
}
