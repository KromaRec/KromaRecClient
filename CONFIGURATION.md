# Configuration

Edit `BepInEx/config/net.kromarec.patch.cfg` as BepInEx INI with unquoted values. Restart after editing. [Example config](config/net.kromarec.patch.cfg).

| Key | Example | Meaning |
| --- | --- | --- |
| `General.Enabled` | `true` | Enables KromaRec hooks for this game process. |
| `General.Debug` | `false` | Adds route categories, status codes and authentication stages. |
| `Backend.BaseUrl` | `https://ns.rec.test` | HTTPS discovery origin. Discovery advertises the individual service URLs. |
| `Backend.MatchUrl` | `https://match.rec.test` | Exact HTTPS origin used to recognize the match service, including its port. |
| `Photon.NameServerHost` | `127.0.0.1` | Luxon NameServer DNS name or IPv4 address. Use the address reachable from this Windows machine. |
| `Photon.NameServerPort` | `5058` | UDP port. |
| `Photon.Region` | `us` | Lowercase region matching both KromaRec and Luxon. |
| `Photon.RealtimeAppId` | `7a6eafd9-8a49-47bd-98da-c743525a3e72` | The same lowercase Realtime UUID as `KROMAREC_PHOTON_REALTIME_APP_ID`. |
| `Analytics.DisableTelemetry` | `true` | Enables RecFlare's managed filters and attempts Unity's opt-out. Native Unity telemetry may still run. |

For 0.10.3, put a trusted HTTPS reverse proxy in front of the loopback Rust listener. Configure DNS and trusted certificates for discovery and every advertised service name. Preserve Host and WebSocket upgrades. Keep the gate private. Chat and Voice App IDs are empty in Phase 1. JWT signing keys stay on the server.
