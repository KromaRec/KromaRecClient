# Diagnosing the Windows platform screen

The supplied screenshot reports “Failed to initialize Steam Platform”. No matching implementation or Steam initialization call was found in the installer or plugin source. The screenshot identifies the game/platform stage. The precise native caller, Steam API return and initialization order have not been captured. The platform message and the BestHTTP certificate rejection can both occur during the same launch.

| Candidate | Evidence and disposition |
| --- | --- |
| Steam client, account entitlement and launch context | User reported no Steam setup for this installation. Installer Screen and VR shortcuts start RecRoom.exe directly. These facts make platform context a plausible blocker. Direct launch alone does not establish which Steam prerequisite failed. |
| Missing native Steam runtime or wrong OS user | Unverified. Check the authorized install through Steam and run under the same Windows user/privilege level. Restore missing components only through the supported distribution. |
| Incorrect game build | App 471710, depot 471711, manifest 6426603215211043630 are the target. The supplied readiness result was GAME_BUILD_ID=UNVERIFIED. Matching interop signatures alone cannot establish depot identity. |
| Missing interop or failed patch initialization | User's earlier Windows run loaded patch 0.3.1, installed required hooks and executed the discovery callback. These stages succeeded in that run. Loader identified itself as be.697. The current package still targets 6.0.0-pre.2. |
| Backend configuration, platform initialization order | No observed causal link to the Steam error. Native discovery independently failed certificate validation after the time check succeeded. No more specific certificate mismatch code was observed. |
| Platform-free launch | No supported Steam-free startup route for this executable was established. A successful KromaRec password login in a protocol client cannot initialize Steam for the game. |

## Reproduce with a fresh log

1. Use a Steam installation/account authorized for the game and the exact archived build. Confirm Steam's installed folder for the game is the tested copy before using Play. If Steam selects a different version, mark the archived-build test BLOCKED. A launch of a current build cannot verify this depot.
2. Run the existing depot identity check against your trusted local manifest. With the game closed, record the start time in PowerShell. Use the game's supported launch flow. Record the visible screen and observe discovery independently.
3. While the game is open run the following from KromaRec-Client. Set the optional Player.log parameter to the actual Unity log for the tested game. The script prints stage labels and checks log file freshness. A log updated in place can contain older lines. Retain separate logs per run. A running Steam process alone does not establish sign-in or entitlement.

```powershell
$game = 'C:\Games\KromaRec-20230414'
# Before launching:
$start = Get-Date
# After the first screen:
.\scripts\Test-PlatformStartup.ps1 -GamePath $game -Since $start
# Supply -PlayerLog with the actual Player.log path to check the literal Steam error.
```

For a differential test use an authorized clean copy of the same depot under the same supported launch context. Record the first failed screen on both runs. If the clean copy cannot initialize Steam, resolve distribution/runtime prerequisites first. If platform startup passes only on the clean copy, compare verified file identity, BepInEx versions, plugin loading and order before changing integration code.

Steamworks initialization requirements: https://partner.steamgames.com/doc/sdk/api#SteamAPI_Init
