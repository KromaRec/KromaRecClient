# Installing KromaRec Client

1. Obtain the original Steam 20230414 depot using the pinned command in [BUILDING.md](BUILDING.md). Put it in a dedicated user-writable folder outside your current Steam installation.
2. Close Rec Room. Run `KromaRecSetup-20230414.exe` and select the depot directory. Setup checks four critical files against manifest 6426603215211043630.
3. Enter the HTTPS discovery and match origins, Luxon UDP host/port, region and Realtime UUID. See [CONFIGURATION.md](CONFIGURATION.md).
4. For the platform baseline, start the licensed game from Steam after confirming its installed folder and supported build match the selected depot. The Screen shortcut starts the executable directly. VR uses the original RecFlare launch argument and remains to be verified. If Steam ownership or initialization fails, capture the exact error from the genuine Steam flow. Setup leaves Steam app identity and credentials alone.

Setup installs BepInEx 6.0.0-pre.2 IL2CPP when needed. A pre-existing installation is reused when its pinned loader payload matches. RecFlare plugin copies must be removed from `BepInEx/plugins` before using KromaRec.

**Repair** by closing the game and running the same installer again against the same folder. It repairs installed files that Setup owns and preserves the configuration. For a pre-existing loader that no longer matches, restore that loader from the pinned archive before retrying.

**Uninstall** through Windows Installed apps or the uninstaller in the selected game folder. It removes installer-owned files and shortcuts. Your game, generated interop, logs, and user-editable config remain. A loader already present before setup remains available to other mods.
