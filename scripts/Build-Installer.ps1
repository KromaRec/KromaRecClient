[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$PatchDll,
    [Parameter(Mandatory)][string]$DepotManifest,
    [string]$BepInExZip,
    [string]$Iscc = 'ISCC.exe',
    [switch]$StageOnly
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$patch = (Resolve-Path -LiteralPath $PatchDll).Path
$manifest = Get-Content -LiteralPath $DepotManifest
if (!($manifest -match '^Content Manifest for Depot 471711\s*$') -or
    !($manifest -match '^Manifest ID / date\s*:\s*6426603215211043630\s*/')) {
    throw 'Supply the text manifest produced by DepotDownloader 3.4.0 for depot 471711, manifest 6426603215211043630.'
}
$files = [ordered]@{
    RecRoomExe = 'RecRoom.exe'
    GameAssembly = 'GameAssembly.dll'
    UnityPlayer = 'UnityPlayer.dll'
    GlobalMetadata = 'RecRoom_Data\il2cpp_data\Metadata\global-metadata.dat'
}
$defines = foreach ($key in $files.Keys) {
    $name = [regex]::Escape($files[$key]).Replace('\\', '[\\/]')
    $line = @($manifest | Where-Object { $_ -match "^\s*\d+\s+\d+\s+([0-9a-f]{40})\s+[0-9a-f]+\s+$name\s*$" })
    if ($line.Count -ne 1) { throw "Expected exactly one depot SHA-1 for $($files[$key])." }
    $null = $line[0] -match '^\s*\d+\s+\d+\s+([0-9a-f]{40})\s+'
    '#define ' + $key + 'SHA1 "' + $Matches[1].ToLowerInvariant() + '"'
}
$identity = [Reflection.AssemblyName]::GetAssemblyName($patch)
if ($identity.Name -cne 'KromaRec.Patch' -or $identity.Version.ToString() -ne '0.3.1.0') {
    throw 'Build KromaRec.Patch 0.3.1 against 20230414 and pass its release DLL.'
}

$stage = Join-Path $root 'stage'
$work = Join-Path $root ('stage-' + [guid]::NewGuid())
$null = New-Item -ItemType Directory -Path $work
try {
    if (!$BepInExZip) {
        $BepInExZip = Join-Path $work 'BepInEx.zip'
        Invoke-WebRequest -UseBasicParsing -OutFile $BepInExZip -Uri 'https://github.com/BepInEx/BepInEx/releases/download/v6.0.0-pre.2/BepInEx-Unity.IL2CPP-win-x64-6.0.0-pre.2.zip'
    }
    if ((Get-FileHash -LiteralPath $BepInExZip).Hash -ne '616ec7eb06cf11b2a0000e8fcef04d1b12bb58e84a2e0bdac9523234fc193ceb') {
        throw 'BepInEx 6.0.0-pre.2 Windows x64 IL2CPP SHA-256 mismatch.'
    }
    $loader = Join-Path $work 'loader'
    Expand-Archive -LiteralPath $BepInExZip -DestinationPath $loader
    $expected = @('winhttp.dll', '.doorstop_version', 'doorstop_config.ini', 'dotnet/coreclr.dll',
                  'BepInEx/core/BepInEx.Unity.IL2CPP.dll', 'BepInEx/core/0Harmony.dll')
    foreach ($file in $expected) {
        if (!(Test-Path -LiteralPath (Join-Path $loader $file) -PathType Leaf)) {
            throw "BepInEx payload missing $file."
        }
    }
    $bundled = Get-ChildItem -LiteralPath $loader -File -Force -Recurse |
        Where-Object { $_.DirectoryName -ne $loader -or $_.Name -in @('winhttp.dll', '.doorstop_version', 'doorstop_config.ini') } |
        Sort-Object FullName
    $defines + @('#define PatchSHA256 "' + (Get-FileHash -LiteralPath $patch).Hash + '"') |
        Set-Content -Encoding Ascii -LiteralPath (Join-Path $work 'checksums.iss')
    $loaderEntries = foreach ($item in $bundled) {
        $relative = $item.FullName.Substring($loader.Length + 1).Replace('/', '\')
        $target = '{app}'
        $sub = [IO.Path]::GetDirectoryName($relative.Replace('\', '/'))
        if ($sub) { $target += '\' + $sub.Replace('/', '\') }
        'Source: "stage\loader\' + $relative + '"; DestDir: "' + $target + '"; Flags: ignoreversion; Check: InstallLoader'
    }
    $loaderEntries | Set-Content -Encoding Ascii -LiteralPath (Join-Path $work 'loader-files.iss')
    $bundled | ForEach-Object {
        (Get-FileHash -LiteralPath $_.FullName).Hash + ' ' + $_.FullName.Substring($loader.Length + 1).Replace('/', '\')
    } | Set-Content -Encoding Ascii -LiteralPath (Join-Path $work 'loader.sha256')

    Copy-Item -LiteralPath $patch -Destination (Join-Path $work 'KromaRec.Patch.dll')
    Set-Content -Encoding Ascii -LiteralPath (Join-Path $work 'loader.owner') -Value 'KromaRec Client loader 6.0.0-pre.2'
    if ($BepInExZip -eq (Join-Path $work 'BepInEx.zip')) { Remove-Item -LiteralPath $BepInExZip }
    if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
    Move-Item -LiteralPath $work -Destination $stage
    if (!$StageOnly) {
        & $Iscc (Join-Path $root 'KromaRecSetup.iss')
        if ($LASTEXITCODE -ne 0) { throw "Inno Setup failed with exit code $LASTEXITCODE." }
    }
} finally {
    if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
}
