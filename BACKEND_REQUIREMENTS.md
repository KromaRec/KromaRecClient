Current contract: see the 0.10.3 integration report in the client project. The following is historical.

# KromaRec Phase 2 backend requirements

The baseline is the KromaRec **0.7.0** source and its patched **Luxon 1.5**, upstream server commit `e4bab98d8d6b3aee9ecf4035309a78a59b584f93`. Target PC game build **20230414** is Steam app **471710**, depot **471711**, manifest **6426603215211043630**. Phase 1 targets the existing contract. Phase 2 should reproduce the contract before expanding it.

**Evidence.** The mappings below come from the 0.7.0 Rust source, Luxon admission patch and actual local HTTP/UDP regression run. DTO shapes and result codes are server-observed. Which requests the native 20230414 game makes, in what order, and what it displays still require a Windows client trace. The [static audit](COMPATIBILITY.md) identifies the inherited client hooks.

## HTTP routing and bootstrap

- Serve discovery via `GET /` on the configured HTTPS NameServer origin. The patch substitutes this origin for the original `ns.rec.net` requests and preserves the path/query. Discovery should return a JSON map of service labels to HTTPS URLs. Critical labels include `API`, `Auth`, `Accounts`, `Matchmaking`, `Rooms`, `Notifications`, `PlayerSettings`, and `CDN`. Their 0.7 defaults resolve to `api`, `auth`, `accounts`, `match`, `rooms`, `notify`, `playersettings`, and `cdn` under `KROMAREC_DOMAIN`. Keep the advertised match origin identical to the client's `Backend.MatchUrl`.
- Terminate TLS with certificates trusted by the game machine. Preserve Host on the HTTP/1.1 proxy hop to KromaRec and preserve WebSocket upgrades. Use final URLs for discovery, token exchanges and connection-info because the plugin disables redirects there. Keep passwords, Authorization, query tokens and connection-info bodies out of diagnostics.
- `api GET /api/versioncheck/v4?v=20230414` returns `{"VersionStatus":0,"UpdateNotificationStage":0,"IsVersionIslanded":false,"IsCrossPlayDisabled":false}`. The version parser accepts the `20230414` prefix before a dot and marks other builds with `VersionStatus:1`. `GET /api/versioncheck/islandedversions` returns `[]`.
- Preserve `api GET /api/config/v2`, `/api/gameconfigs/v1/all`, `/api/config/v1/amplitude`, `/api/config/v1/backtrace`, `/api/config/v1/azurespeech` and `accounts GET /emojiConfig/whitelistedEmojis`. Use the 0.7.0 `src/bootstrap.rs` and `compat` fixtures for exact wire DTOs. Keep analytics credentials empty and disable the telemetry feature flags. Keep CDN assets served by their advertised origin and preserve both media type and case-sensitive path.
- Keep account profiles and player settings available during bootstrap. `accounts GET /account/me` returns the authenticated profile, including stable numeric `accountId` and `username`. `playersettings GET /playersettings` returns rows with `Key` and `Value`. `PUT /playersettings` accepts `key` and `value`; `DELETE /playersettings` removes a key. Use the 0.7 route matrix for additional routes and check against captured live traffic before marking one as required.

## HTTP identity and session lifecycle

| Service and route | Request | 0.7.0 response and behavior |
| --- | --- | --- |
| `auth GET/POST /cachedlogin/forplatformid/{platform}/{id}` | Platform and ID in path | JSON `[]` for the local-account deployment, allowing manual login. Steam/Meta ownership proofs and linked cached login remain Phase 2 work if needed. |
| `auth POST /connect/token` | Form `grant_type=password`, `account_id` or `username`, `password`, `ver=20230414`; a blank grant is treated as password | 200 JSON `access_token`, `refresh_token`, `expires_in` (86400), `token_type:"Bearer"`, `scope`, and legacy `key`. Responses carry `Cache-Control: no-store`. Preserve the full 0.7 claim set when testing the real client's OAuth parser. |
| Same token endpoint, provisioning | Form `grant_type=create_account`, `password` of 8–128 bytes, optional numeric `platform`, and `ver=20230414` | Same response when `KROMAREC_PASSWORD_SIGNUP=true`. Creates the local profile and initial Orientation state. Rejects supplied platform ID/proof fields in this flow. |
| Same token endpoint, refresh | Form `grant_type=refresh_token`, `refresh_token`, `ver=20230414` | Atomically consumes old refresh token and returns a replacement. Refresh TTL is 30 days with hashes stored in SQLite. |
| `match POST /player/login`, `/player/exclusivelogin` | Bearer plus form `LoginLock` (up to 128 characters) | Login normally returns empty 200. Exclusive returns `{"errorCode":0}` for a present lock, or `-1` when absent. A new lock supersedes the old. |
| `match POST /player/verifylock`, `/player/heartbeat` | Bearer plus optional form `LoginLock`; verify needs the active lock | Verify returns 200 or 409. Heartbeat returns the player-presence DTO with `roomInstance` or null. Extend active presence and reservation from 5 minutes remaining to 15 minutes. An obsolete lock cannot extend the superseding session. |
| `match POST /player/logout` | Bearer plus optional form `LoginLock` | Empty 200. Clears presence and current reservation for the active lock, excluding Orientation. An obsolete lock cannot clear the newer session. 0.7 logout does not revoke all OAuth/JWT credentials. |
| `auth POST /account/me/changepassword` | Bearer plus form `oldPassword`, `newPassword` | 200 `{"success":true}` and invalidates refresh tokens for the account. Bad input or old password returns 400 with a failure JSON envelope. |

Use numeric, stable account IDs with canonical decimal JWT subjects. The 0.7 access JWT is HS256 with `sub`, `iat`, `nbf`, `exp`, `iss`, `aud`, `auth_time`, `amr`, `client_id`, `idp`, platform claims, `rn.ver`, `rn.plat`, `role`, `scope`, and `jti` (see `src/auth.rs`). 0.7's legacy OAuth issuer/audience literals are `https://auth.recflare.net`; capture whether the client expects those values before changing them. Tickets carrying `rn.env` are rejected as HTTP Bearer credentials. The game owns bearer storage, refresh, and the authenticated request sequence.

HTTP status conventions in 0.7 are 400 with OAuth `{"error":"invalid_grant"|"unsupported_grant_type","error_description":"..."}` on grant failures, 401 for missing/invalid credentials on protected endpoints, 403 for access denial, 404 for an unsupported route and 503 for unavailable authenticated services. `/player/login` and `/player/logout` are exceptions that accept unauthenticated calls with empty 200. Keep endpoint-specific JSON casing and avoid returning HTML errors.

## Photon ticket contract

**`match GET /player/connection-info`** takes the game's HTTP Bearer token and no request body. A 200 successful response requires `Cache-Control: no-store` and this structure:

```json
{
  "success": true,
  "error": null,
  "value": {
    "photonAuthToken": "<short-lived HS256 JWT>",
    "photonRealtimeAppId": "7a6eafd9-8a49-47bd-98da-c743525a3e72",
    "photonVoiceAppId": "",
    "photonChatAppId": "",
    "photonRegion": "us",
    "photonRoomId": "",
    "voiceConnectionInfo": "",
    "voiceServerId": "",
    "experiments": {
      "networkTransformSyncInterval": 10.0,
      "shouldUseUnreliableOnChange": false,
      "shouldAvoidDiscontinuityRPCs": true,
      "shouldAvoidRedundantDiscontinuity": false,
      "r2RuntimeStaticBaking": true,
      "r2AutoEmbodiment": true,
      "r2RuntimeStaticBakingMinShapeThreshold": 1,
      "r2UseCheapReplicas": true,
      "shouldUseGameServerNetworking": false
    }
  }
}
```

- Set `photonRoomId` to the server's room reservation when present and `""` when absent. Keep the Realtime UUID and region identical in the backend, plugin, and Luxon region configuration. The value above is the 0.7 sample UUID.
- Mint compact, unpadded base64url HS256 JWTs at most 8192 bytes long. Payload includes `sub` as the account ID string, `aud` equal to the configured Realtime app ID, `exp` as integer Unix seconds (issued for 900 seconds in 0.7), `kromarec_use:"photon-realtime"`, `rn.env:"prod"`, `rn.platid:""`, `rn.plat:"0"`, and `rn.deviceclass:"0"`. Client checks expected shape, audience, region, purpose and expiry with a five-second margin. The gate verifies the signature and owns all authorization decisions.
- The observed response must arrive before NameServer authentication. The plugin clears its cached ticket at connection-info request start, OAuth exchanges, login, exclusive login, and logout. Late results cannot repopulate a superseded cache. Invalid/expired tickets, unavailable backend or mismatched identity stop fresh patched NameServer auth. Validate the real game order and trigger for fetching new connection-info on retry and natural expiry. A finished HTTP response by itself does not prove the Unity client advanced.
- 0.7 gate binds an IPv4 loopback address. Luxon sends `key NUL action NUL app NUL jwt NUL room` over TCP and half-closes its write side. `action=auth` has an empty room, `action=join` a nonempty room. Returning ASCII decimal account ID authorizes; `0` or outage denies. Match the 64-hex-digit gate key in both services, leave JWT signing material exclusively in the backend, bound request size to 12288 bytes and the gate exchange to 750 ms. Require account existence, a live ticket, correct audience/purpose, no active ban and a live exact room reservation for join.

## Luxon and admission

- Serve UDP NameServer **5058**, Master **5055**, and Game **5056** in the example and advertise client-reachable IP/ports for each handoff. Preserve the region list (`us` by default), UDP initialization/encryption handshake, expected binary protocol, and encrypted auth response behavior. The inherited encrypted path must be verified with the target client, including when it chooses AuthenticateOnce.
- Accept NameServer Authenticate **230** and AuthenticateOnce **231**. String parameter **216** is exactly `token=<JWT>`, byte **217** is custom auth type **0**, **224** is AppId, **220** is AppVersion, and **225** is the optional client-supplied UserId. Preserve the game's AppVersion. Gate identity overrides any spoofed client UserId. The response uses **225** for the canonical identity, **230** for the next address, and **221** for the opaque Photon handoff token.
- Keep native **221** authentication on Master and Game and reauthorize the associated ticket on handoff. Check signed identity plus room reservation at Master routing and at Game admission to handle revocation in flight. Room name is **255** for JoinGame **226** in the wire harness. Keep sender/actor identity, reliable routing, two-way relay, leave/rejoin and occupancy consistent across hops.
- Preserve meaningful failures. Invalid KromaRec credential returns Photon `InvalidAuthentication` (**32767**), a missing/expired native handoff can return `AuthenticationTokenExpired` (**32753**), and admission failures use the operation's established Photon return codes, including `ServerForbidden` (**32761**). Never include the ticket or credentials in error strings. Phase 2 should verify whether the client surfaces those codes and distinguish ticket expiry from a revoked room reservation.

## Matchmaking, room data, and notifications

All match calls below are on the match service; protected routes use the HTTP bearer. Send nonempty room/match write bodies as `application/x-www-form-urlencoded` (maximum 8192 bytes). Matchmaking looks up `JoinMode` and `CorrelationId` case-insensitively. Room metadata uses the casing defined by each endpoint. Unsupported content types return 415 where body parsing is required.

| Route | Contract |
| --- | --- |
| `POST /matchmake/none`, `/matchmake/dorm` | `none` resumes an active instance, serves Orientation for new profiles (room 13, instance -2, Photon room `rec.13`), or allocates the caller's dorm. `dorm` explicitly allocates or reuses that dorm. |
| `POST /matchmake/room/{idOrName}[/{subRoomId}]` | Accept numeric ID or name with optional leading caret. `JoinMode=2` asks for a private instance. Default public admission respects accessibility, capacity and in-progress state. 0.7 accepts the optional subroom segment and uses the room's primary subroom. |
| `POST /matchmake/player/{id}`, `/matchmake/instance/{id}` | Enforce visibility, room access or invite, then capacity. On success record one authoritative live reservation per account. |
| `GET/POST /player`; `GET /room/{id}/instances` | Repeated `id` query/form values for player lookup; preserve visibility redaction. Instance listings contain instance data and player IDs for authorized viewers. |
| `POST /invite` | `playerId` and `roomInstanceId`; caller must occupy that instance. 200 returns `RoomInviteId`, `FromPlayerId`, `ToPlayerId`, and `RoomId`; 400 for invalid target and 403 for denied access. Persist the invite for 300 seconds. |
| `PUT /roominstance/{id}/inprogress`, `POST /roominstance/{id}/reportjoinresult` | Form `inProgress=true|false` on PUT with empty 200 or 404 if the caller is elsewhere. Report is a 0.7 empty 200 stub. |
| `rooms GET /dormroom/me`, `GET /rooms/{id}`, `GET/POST /rooms/bulk` | Return stable dorm ID, room DTO, and bulk room DTOs. Preserve room IDs, subroom and scene location, capacity, accessibility, owner and role information. |
| `rooms POST /rooms/create`, `PUT /rooms/{id}/accessibility` | Create with `name` and applicable room fields. Publish with `accessibility=1` where allowed. Use the 0.7 endpoint forms/envelopes; metadata writes use mixed legacy casing. |
| `rooms GET /photon_access_token` | Return `{"Permissions":[...],"PhotonAccessToken":"","RoomInstanceId":...}`. This is room permission metadata. The NameServer JWT comes from connection-info. |
| `notify POST /hub/v1/negotiate?negotiateVersion=1`, `GET /hub/v1` | Return JSON negotiation with `connectionId`, `connectionToken`, `negotiateVersion` and Text WebSockets transport. Upgrade with Bearer or `access_token` query. SignalR JSON v1 uses U+001E separators, `OnConnect`, and ping type 6. Deliver `Notification` wrappers for room updates, presence, and invite event `Id:"2"` with the declared invite fields. Missing Bearer gets 401 on upgrade, missing upgrade gets 426. |

Matchmake returns HTTP 200 JSON `{"errorCode":0,"result":0,"roomInstance":{...},"correlationId":"..."}`. Echo `CorrelationId` from form or query, otherwise return the zero UUID. Failure instances are null, with result and errorCode **3** full, **20** absent/not visible, **25** denied room access, or **55** banned. The required instance fields are `roomInstanceId`, `roomId`, `subRoomId`, `roomInstanceType`, `location` (scene ID), `dataBlob`, `eventId`, `clubId`, `roomCode`, `photonRegion`, `photonRegionId`, `photonRoomId`, `name`, `maxCapacity`, `isFull`, `isPrivate`, `isInProgress`, and `EncryptVoiceChat`. Use the same reservation across HTTP and Luxon. Reserve for 900 seconds and keep empty instances for a 120-second grace window before sweeping. A second user joining an available public instance should receive the same instance, Photon room, scene and region. An uninvited user cannot join by guessing a private Photon room ID.

## Remaining evidence and known gaps

1. Launch the real game with exact Steam manifest and regenerated interop; validate every critical method and that HTTPS discovery and OAuth work with the stock certificate checks. Record the first failed request or hook if either stalls.
2. Test manual password login and account switching. The 0.7 `PlayerReporting/v1/deviceId` route is missing and the inherited client-side DUID workaround bypasses the migration branch. If the account flow still requires that route, capture its exact body, origin and expected reply before implementing a server fix. Platform-linked Steam/Meta authentication remains open.
3. Confirm connection-info order, header use, ticket refresh on an expired or invalid session, and the game native Photon handoff. The passed wire harness exercised both auth opcodes over loopback with plaintext parameters. It did not verify what 20230414 serializes, AuthOnce encryption initialization or whether the game's Photon endpoint string matches the configured NameServer exactly. Luxon 0.7 accepts the plaintext probe on its private test interface; enforcing encrypted admission server-side requires confirming compatibility first.
4. Run two actual clients through login, Orientation/dorm, public room, bidirectional motion, leave/rejoin and private invite denial. Capture the first failed status/return code and any missing scene ID. Distinguish backend DTO issues and Unity clients failing to render the scene. Arbitrary uploaded room saves, custom signed images, Photon Voice/Chat and full route parity remain outside the verified integration.
