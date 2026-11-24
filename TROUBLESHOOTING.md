# Troubleshooting

| Problem | Action |
| --- | --- |
| Steam cannot fetch the manifest | Verify access to app 471710 and historical depot 471711. Finish the Steam QR flow. |
| Wrong build or damaged file | Use the original Steam 20230414 depot. Restore any replaced `global-metadata.dat`, game DLLs, or executable. |
| Setup rejects an existing BepInEx loader | Pick a clean separate depot or restore the exact BepInEx 6.0.0-pre.2 IL2CPP package in the selected folder. |
| Setup finds RecFlare | Move the conflicting plugin outside `BepInEx/plugins`, including any duplicate copies in subfolders. |
| Repaired setup kept the old server | Edit the BepInEx config and restart. Setup preserves existing settings. |
| Plugin never appears in the log | Check the pinned loader, plugin path and game build. On a native Windows run inspect `BepInEx/LogOutput.log`. |
| HTTPS, login or Photon stage fails | Check DNS and trust, matching origin and UUID, and UDP ports 5058/5055/5056 as described in [BACKEND_REQUIREMENTS.md](BACKEND_REQUIREMENTS.md). Share only redacted diagnostics. |
