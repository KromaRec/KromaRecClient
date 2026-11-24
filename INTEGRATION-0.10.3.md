# Client integration for KromaRec 0.10.3

Reference: supplied KromaRec-0.10.3-Linux-x86_64.zip, SHA-256 c0bbca1e6c2f6d63fba75f2185ec265f86878ce0a1dae1716e3cc07e9f936dc2. Checked the package checksum manifest before executing disposable tests. The installer stages Patch 0.3.1. The earlier 0.7–0.10.1 reports in the source trees describe earlier baselines.

## Backend contract and compatibility matrix

| Stage and owner | Required contract | Evidence |
| --- | --- | --- |
| KromaRec HTTPS discovery | GET / on configured ns origin with original Host. Absolute HTTPS service origins, one distinct authority per service. Matchmaking must match configured MatchUrl. The patch validates the directory used for diagnostics and ticket handling. Native requests continue through BestHTTP. | Managed discovery parser exercised against actual 0.10.3. Earlier native discovery failed TLS. |
| Version and game bootstrap | API GET /api/versioncheck/v4?v=20230414, VersionStatus=0. Version before first dot must be 20230414 and total length at most 32 bytes. GET /api/config/v2 and /api/gameconfigs/v1/all, Accounts /emojiConfig/whitelistedEmojis, CDN /config/LoadingScreenTipData. | Backend smoke. Local game assets and scene rendering require the genuine installation. |
| KromaRec OAuth | Auth POST /connect/token with URL-encoded grant_type=password, username or account_id, password and ver. Optional create_account needs enabled signup and a password. Platform proof is unsupported by signup. Refresh uses grant_type=refresh_token and refresh_token. Response fields access_token, expires_in, token_type, refresh_token, scope, key. Access TTL 86400 s, refresh TTL 30 days and one-use rotation. Game owns bearer storage and refresh. | Backend smoke and disposable managed signup test. |
| Profile and session | Accounts GET /account/me with Bearer token. DTO includes numeric accountId, username, displayName, profileImage, bannerImage, displayEmoji, isJunior, platforms, personalPronouns, identityFlags and createdAt. Match /player/login, /player/exclusivelogin, /player/verifylock, /player/heartbeat and /player/logout handle presence/lock lifecycle. Respect stale locks and the Orientation logout exception. Reacquire connection-info after identity change. | Synthetic HTTP and managed profile retrieval. Native login pending. |
| Room and instance | Rooms GET /rooms/13 returns Orientation RoomId and SubRooms with UnitySceneId. Match POST /matchmake/none or /matchmake/dorm selects startup destination. /matchmake/room/{nameOrId} accepts repeated AdditionalPlayerIds; /matchmake/player/{id} and /matchmake/instance/{id} check admission. Read errorCode and roomInstance identifiers (roomId, roomInstanceId, photonRoomId); preserve repeated party inputs and private invitations via POST /invite. Local assets render the selected scene. | Synthetic admission, invitation and scene metadata. No rendered scene observed. |
| Connection-info | Match GET /player/connection-info with bearer, no-store. success/value envelope with photonAuthToken, photonRealtimeAppId, photonRegion and photonRoomId. HS256 ticket exp ~900 s, sub canonical account ID, aud Realtime UUID, kromarec_use=photon-realtime, rn.env=prod, account access and Photon generations. Patch filters shape, purpose, audience, region and freshness. Backend validates signature, identity, generation and reservation. | Actual 0.10.3 response accepted by managed cache with profile ID match. |
| Luxon 1.5 | Configured UDP Name/Master/Game defaults 5058/5055/5056, region us. Discover region, authenticate via operation 230 or 231 with Custom=0 and string parameter 216 containing token=<ticket>. Preserve native handoff token parameter 221 and server-provided addresses. Gate stays server-side. Rejoin requires valid current authorization. | Encrypted synthetic NameServer accepted both opcodes. Synthetic Master/Game admission, expiry/denial, disconnect, rejoin verified. Game-side encrypted handoff and serialization remain guarded. |
| Notifications | Notifications POST /hub/v1/negotiate?negotiateVersion=1; connectionId, connectionToken, WebSockets/Text. GET /hub/v1?id=… over WSS with authorized bearer. JSON handshake protocol=json/version=1, records separated by 0x1e. Observe OnConnect and type 1 invocations, type 6 keepalive. Renegotiate after session invalidation. | Backend synthetic SignalR tests. Native callbacks pending. |
| Steam platform | Local Steam runtime, licensed app context, compatible distribution. KromaRec's local accounts, JWT and Luxon gate operate independently. | See STEAM-STARTUP.md. Native initialization and two-client gameplay BLOCKED. |

Default discovery hosts under rec.test (ns is the directory, plus 33 advertised services):

| Directory key | Default hostname |
| --- | --- |
| Accounts | accounts.rec.test |
| AI | ai.rec.test |
| API | api.rec.test |
| Auth | auth.rec.test |
| Cards | cards.rec.test |
| CDN | cdn.rec.test |
| Chat | chat.rec.test |
| Clubs | clubs.rec.test |
| CMS | cms.rec.test |
| Commerce | commerce.rec.test |
| Data | data.rec.test |
| Discovery | discovery.rec.test |
| Econ | econ.rec.test |
| Geo | geo.rec.test |
| Images | img.rec.test |
| Leaderboard | leaderboard.rec.test |
| Link | link.rec.test |
| Lists | lists.rec.test |
| Matchmaking | match.rec.test |
| Moderation | moderation.rec.test |
| Notifications | notify.rec.test |
| PlatformNotifications | platformnotifications.rec.test |
| PlayerSettings | playersettings.rec.test |
| RoomComments | roomcomments.rec.test |
| RoomieIntegrations | roomieintegrations.rec.test |
| Rooms | rooms.rec.test |
| Storage | storage.rec.test |
| Strings | strings.rec.test |
| StringsCDN | strings-cdn.rec.test |
| Studio | studio.rec.test |
| Thorn | thorn.rec.test |
| Videos | videos.rec.test |
| WWW | www.rec.test |

KROMAREC_SUBDOMAINS can override these names. Use the configured Auth origin for token requests. The OAuth issuer string in a token is not a destination. Config examples in both projects use the archive's Realtime UUID 7a6eafd9-8a49-47bd-98da-c743525a3e72. On another machine set NameServerHost to the reachable Luxon host and configure its advertised Master/Game addresses. Port, region and AppId come from config/server.env.example and packaging/luxon.config.example.yml; the directory does not advertise a Photon UDP address. Operators must supply their deployment values. Keep the JWT signing secret and gate key on the server.

## Verification on this workspace

- PASS: .NET SDK 6.0.428 managed protocol suite including ambiguous directory origins, ticket expiry/reconnect, pinned BepInEx configuration and Mono.Cecil synthetic metadata tests. PowerShell script syntax, depot identity fixtures, build failure classification and sanitized readiness passed. Standalone PhotonAuthProbe compiled (0 warnings/errors).
- PASS: live managed consumer against the supplied musl backend with a temporary SQLite database. It read the actual directory, created a synthetic account, retrieved /account/me and accepted connection-info for that account. Reproduce from KromaRec-Patch with `python3 tests/backend103.py <extracted-Linux-release>` and dotnet 6.0.428 on PATH.
- PASS: both release backends' HTTP smoke tests; rooms_smoke with bundled Luxon; patch encrypted_luxon_probe.py with musl backend (36 Authenticate and 1 AuthenticateOnce accepted). Ten synthetic peers on the RecCenter instance produced 900 expected event deliveries. These observations do not measure player spawning, gestures or movement rendering.
- Caddy-specific 33-host HTTPS and WSS checks: PASS in the attached archive's own verification report; BLOCKED for a rerun here because Caddy was unavailable. Deployment DNS, trust and routing on each Windows machine remain separate checks.
- Main DLL build attempted: BLOCKED at KRBUILD_INTEROP with 0 warnings and 1 prerequisite error; no authorized game or generated interop here. Previous successful local builds used an earlier source revision. Installer staging with a genuine new plugin and Windows installation are NOT TESTED. The included readiness and Steam diagnostics can run before native compilation.
- Native trial on 0.10.3: BLOCKED for platform initialization, login, profile, rendered Orientation/dorm, encrypted Photon admission, private room admission, two-client interaction and reconnect. Earlier Windows evidence on the prior deployment shows TLS time=True and request=False before any HTTP response. The exact trust criterion is unknown. No supported additional CA setting for the game's verifier has been established. Device acknowledgement on POST /api/PlayerReporting/v1/deviceId also lacks a verified success contract.

## Windows operator sequence

1. Extract into a new folder. Preserve existing working trees and configuration. Use the backend release's tools/https_preflight.py from Windows with the advertised origins and trusted public CA. Expect both Orientation room and SignalR negotiation to pass. See BUILDING.md and INSTALLATION.md.
2. Confirm authorized Steam access, exact depot manifest and baseline launch using STEAM-STARTUP.md. Run KromaRec-Patch/scripts/Test-NativeReadiness.ps1 with -GamePath and the trusted -ManifestPath, then KromaRec-Patch/build.ps1 with the same paths. Close the game before installing. Back up the existing plugin outside BepInEx/plugins before replacement.
3. Enable optional Debug for one launch. Record the UTC time, last completed screen, fixed stage labels and HTTP/Photon return codes. Compare discovery independently of Steam startup. Native TLS rejection or platform startup failure blocks subsequent milestones.
4. After successful discovery measure native login, profile, Orientation/dorm, encrypted NameServer, Master/Game handoffs, same instance with two independent accounts, bidirectional motion and interaction, leave and rejoin. The current Photon guard blocks admission until native semantics and encryption are verified. Mark each unexecuted step BLOCKED or NOT TESTED.
