# Run in PowerShell on Windows. Steam authentication is handled by DepotDownloader.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$GamePath,
    [Parameter(Mandatory)][string]$ManifestDirectory,
    [switch]$ManifestOnly
)
$ErrorActionPreference = 'Stop'
$game = [IO.Path]::GetFullPath($GamePath)
$manifest = [IO.Path]::GetFullPath($ManifestDirectory)
$work = Join-Path ([IO.Path]::GetTempPath()) ("KromaRec-Steam-" + [guid]::NewGuid())
$null = New-Item -ItemType Directory -Path $work
try {
    $zip = Join-Path $work 'DepotDownloader.zip'
    $url = 'https://github.com/SteamRE/DepotDownloader/releases/download/DepotDownloader_3.4.0/DepotDownloader-windows-x64.zip'
    Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $zip
    if ((Get-FileHash -LiteralPath $zip).Hash -ne '41c9e9f0df54b3ad02e67a11726756e5c73283bd7c2e1b04acfa5ae4c2ed3767') {
        throw 'DepotDownloader 3.4.0 SHA-256 mismatch.'
    }
    Expand-Archive -LiteralPath $zip -DestinationPath $work
    $exe = Join-Path $work 'DepotDownloader.exe'
    $depotArgs = @('-app', '471710', '-depot', '471711', '-manifest', '6426603215211043630', '-qr')
    Push-Location -LiteralPath $work
    try {
        $null = New-Item -ItemType Directory -Force -Path $manifest
        & $exe @depotArgs -dir $manifest -manifest-only
        if ($LASTEXITCODE -ne 0 -or !(Test-Path -LiteralPath (Join-Path $manifest 'manifest_471711_6426603215211043630.txt'))) {
            throw 'Steam did not supply the 20230414 manifest. Check depot access and Steam sign-in.'
        }
        if (!$ManifestOnly) {
            if ((Test-Path -LiteralPath $game) -and @(Get-ChildItem -LiteralPath $game -Force).Count -gt 0) {
                throw 'Choose an empty directory for the Steam download. For an existing depot, run Setup directly.'
            }
            $null = New-Item -ItemType Directory -Force -Path $game
            & $exe @depotArgs -dir $game -validate
            if ($LASTEXITCODE -ne 0 -or !(Test-Path -LiteralPath (Join-Path $game 'GameAssembly.dll'))) {
                throw 'The Steam download failed or did not produce an IL2CPP game installation.'
            }
        }
    } finally {
        Pop-Location
    }
} finally {
    Remove-Item -LiteralPath $work -Recurse -Force
}
