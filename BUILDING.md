# Building KromaRec Client

Use Windows x64 (Windows 10 build 17763 or newer), Windows PowerShell 5.1 or PowerShell 7, Inno Setup 6.4.3, and a KromaRec Patch 0.3.1 DLL built against the 20230414 interop. Use the official BepInEx 6.0.0-pre.2 Windows x64 IL2CPP zip.

## Obtain the Steam manifest and game

Run from the client repo root with a Steam account that can access the depot. The QR flow may ask you to authenticate for both the text manifest and the game. Keep the game and the manifest output in separate folders.

```powershell
.\scripts\Get-Game.ps1 -GamePath 'C:\Games\KromaRec-20230414' -ManifestDirectory 'C:\KR\manifest'
```

If you already have the clean depot, use the same command with `-ManifestOnly`. It generates `manifest_471711_6426603215211043630.txt`. The script pins and checks the DepotDownloader 3.4.0 ZIP SHA-256 before invoking it with the official app, depot and manifest IDs.

## Build patch and installer

Install the pinned BepInEx in the build copy and run the game once to generate interop. In the following example the client and patch repos are siblings:

```powershell
..\KromaRec-Patch\build.ps1 -GamePath 'C:\Games\KromaRec-20230414'
.\scripts\Build-Installer.ps1 -PatchDll '..\KromaRec-Patch\bin\Release\net6.0\KromaRec.Patch.dll' -DepotManifest 'C:\KR\manifest\manifest_471711_6426603215211043630.txt' -Iscc 'C:\Program Files (x86)\Inno Setup 6\ISCC.exe'
```

The builder checks the DLL name/version, pins the BepInEx ZIP by SHA-256, stages the loader entries, and embeds the selected DLL's SHA-256 and four Steam file SHA-1s. The installed plugin is checked against the embedded hash. `-BepInExZip <path>` permits an already-downloaded official ZIP. `-StageOnly` validates and stages the inputs without invoking Inno Setup.

Output is `Output/KromaRecSetup-20230414.exe`. The setup payload contains the loader and plugin. The four game binary hashes come from the locally obtained Steam manifest. Keep the manifest on the build machine and source it directly from Steam. The resulting exe is unsigned unless you sign it as a separate release step.
