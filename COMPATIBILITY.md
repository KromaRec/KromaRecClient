# Installer compatibility and verification

| Component | Pin or scope |
| --- | --- |
| Rec Room Windows x64 IL2CPP | 20230414; app 471710, depot 471711, manifest 6426603215211043630 |
| RecFlare reference | Client `master` at beff81c. `2025` and default `2026` were audited and excluded. |
| BepInEx | Official 6.0.0-pre.2 Windows x64 IL2CPP ZIP. SHA-256 `616ec7eb06cf11b2a0000e8fcef04d1b12bb58e84a2e0bdac9523234fc193ceb`. |
| DepotDownloader | Windows x64 3.4.0. SHA-256 `41c9e9f0df54b3ad02e67a11726756e5c73283bd7c2e1b04acfa5ae4c2ed3767`. |
| KromaRec Patch | 0.3.1 compiled against this game's generated interop |
| Windows | Windows 10 build 17763+ and Windows 11 x64 target. Native installation/repair/uninstall require a Windows test. |

The upstream installer pinned the correct Steam manifest at the selected revision but also included a separate community mirror, an unpinned patch download, and a Steam app-ID override. KromaRec preserves the Windows wizard and Screen/VR launch modes. It stages the official loader, checks the plugin, validates core game binaries against the trusted Steam manifest and lets Inno track installed files for repair or removal.

PowerShell staging ran with the official, hash-verified BepInEx package and synthetic Steam manifest and plugin fixtures. The genuine game interop and manifest were unavailable. Wine aborted before Inno Setup could launch in the current Linux environment. The source installer is ready for Windows compilation once the two genuine inputs are available. An installer built with synthetic inputs is for validation only.

Validate on Windows in a clean 20230414 folder and a folder with matching pre-existing BepInEx. Try an incorrect build, a modified game binary and an unrecognized loader. Confirm repair restores the installed DLL without replacing the edited config. Uninstall and inspect which files remain. The [Phase 2 handoff](BACKEND_REQUIREMENTS.md) lists gameplay acceptance checks.

Staging validation checked 225 loader payload paths and SHA-256 values. The build script rejected an alternate manifest ID and a corrupted loader archive. PowerShell parsed the build/acquisition scripts. No installer executable was produced.
