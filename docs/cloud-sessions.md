# Match sharing and cloud sessions — Smart Scoreboard 1.8

The cloud service is in the sibling `scoreboard-cloud` repository. Its README covers deployment and Google OAuth. Deploy the matching Worker before using the new native invitation and match APIs. Dashboard variables and secrets remain untouched by these changes.

## App experience

The control board is based on pre-cloud commit `4bcbeac661fcd4144730f017f471f080d1bf9969`. The discarded implementation is preserved on branch `backup/cloud-rework-287aab9`; its navigation is replaced, while its match identity, authenticated local transport, and deployed cloud API adapter remain.

**App Mode** starts at **Home**: New Scoreboard, Open Scoreboard, Connect to Scoreboard. A searchable local file list supports import, export, rename, duplicate, and delete. Opening a file resumes its scores. New Scoreboard from Setup creates another identity with reset gameplay. A fresh installation does not create a file just by visiting Home. Once a file is opened, its host advertises nearby. Local file saving belongs to a view-independent repository, so presenting settings or connecting to another scoreboard cannot redirect autosave into a different file.

**Kiosk Mode** only joins an existing scoreboard, as a display or controller. Apple TV always runs this mode. iPhone, iPad and Mac can switch in App Settings; local files from App Mode stay private and preserved. Kiosks advertise a separate `canHostSession: false` capability, refuse host preparation and local file creation, and clear received state, image caches and pending controls on disconnect. Pairing identity/credentials are separate from game data and can support reconnecting.

Apple TV, Mac and iPad reuse one kiosk landing page, settings flow and control board. The layout changes to a vertical stack in narrow windows and split-screen. iPhone keeps the compact kiosk joining screen. Both app and kiosk homes display the installed version/build and the selected cloud service’s live connection status; displaying them does not create cloud traffic. Entrance, interaction and state-change animations respect Reduce Motion. Apple TV retains focus-based navigation. D-pad arrows navigate, Select activates a button, Back opens connection options from the live view or returns through setup, and Play/Pause toggles the main clock only with fresh approved control access. Its Settings page includes Public Cloud/self-hosted URL, full-width connection preferences, pairing management and confirmed Factory Default. Factory Default clears local cloud access, pairings, files and settings, without changing the remote host’s scoreboard; an unresolved legacy hosted match must first be returned or explicitly discarded.

**Game Settings** and **App Settings** are separate panels. Game Settings includes teams, rules, clocks, rosters, logos, backgrounds, and date/time overlays saved in the scoreboard file. App Settings includes device mode, account/cloud server, connection preferences, sound, theme, physical display directions, integrations, shortcuts, backup and logs. The board’s Settings menu opens either panel. Home opens App Settings; participant controls cannot edit the owner’s file.

The external/public display shows “Start or join a scoreboard on your main device.” while the main device is on Home. Opening a file or receiving a joined match changes it to the scoreboard.

### Joining and sharing

Nearby joining discovers host scoreboards over `_scorebrd-join._tcp`. The client can ask the host to confirm, or supply the host’s six-digit PIN. The host can also discover a kiosk and pair using its four-digit device PIN, preserving the previous Remote Display workflow. Both arrange the existing authenticated host-to-client connection. Approval-only requests carry no game data, time out, and cannot silently grant control. PIN-based control requests still require host approval. Codes and metadata are scoped to the current match; duplicate announcements are merged by physical device ID.

Online participants enter a fixed session code and password, without signing in. Only the owner signs in. **Connect Devices** on the open scoreboard provides nearby PIN/QR, participant permissions, cloud sharing and failover. Cloud relay remains explicit and requires an enabled service, owner account, and relay entitlement. The code remains fixed across publishing reconnects and password updates; saving the same password preserves participant grants. An explicit password change or revocation removes previous invitation access. A new scoreboard has its own session/code. Deploy the matching Worker change for this stable-code behavior.

Cloud joining is staged: failed/cancelled joins preserve the personal document, and controls switch after joining. Nearby discovery and pairing do not need internet. Guests receive only match-scoped access, including cloud failover credentials where enabled.

## Accounts, guests and relay access

Only the match owner needs to sign in. Accounts have a User or Admin service role, plus an independent cloud relay entitlement. An entitlement can expire at a specific time or have no expiry. New accounts have no relay entitlement; Admin access alone does not grant relay access. Normal accounts list their own sessions. The backend is available to Admins and records account/entitlement changes in its audit log.

Guest participants have match-scoped access, not permanent owner-account registration or an account-wide session menu. Native installations keep a separate P-256 signing identity in Keychain. Scoped native credentials require a signed request/upgrade proof, preventing a copied bearer token from authorizing another device. Browser guests use a separate HttpOnly participant cookie, preserving the owner's login. Invitation rotation and individual participant removal revoke access; public viewing links have separate revocation.

## Local and cloud together

The engine, timers and command validation remain on the selected native host. LAN, nearby and cloud participants can coexist. Only the publishing host and participants actually using cloud need internet. Local Web API, Companion and LAN/nearby links continue independently during an outage. Cloud commands use the same UUID deduplication and match validation as local commands. Commands are never automatically replayed on a different route.

Cloud has a global off switch: disabling it cancels cloud transport and link polling, and prevents new cloud requests. Online sharing is opt-in for each match and new matches start unshared. The endpoint is either **Public Cloud (Experimental)** at `https://scoreboardcloud.studenttechsupport.com` or a user-supplied self-hosted URL. A match linked to one service cannot silently publish to a different service.

| Remote policy | Behavior |
| --- | --- |
| LAN Only | Local network only |
| LAN + Nearby | Local network and Apple peer-to-peer Wi-Fi |
| Prefer LAN + Nearby | Prefer a fresh local path; use this match's cloud path when needed |
| Prefer Cloud | Prefer a fresh relay path; use the same match's local path when needed |

Cloud Failover provisions scoped credentials to trusted local peers over the existing authenticated channel. Enrollment is encrypted with P-256/AES-GCM and bound to the pairing secret and both device identities. It carries the local control permission for this match and never sends an owner credential. The remote still controls whether cloud is enabled. Local clients can remain offline.

Client diagnostics distinguish route (This Device, LAN, Nearby, Direct, Cloud) from method (in-process, WebSocket, WebRTC), and distinguish the active path from available standby links. Cloud always means relay WebSocket. WebRTC is a direct path and is never labelled Cloud. Native key matching prevents an untrusted claimed device ID from merging with a trusted LAN row.

## Hosting and public viewing

The device that opens the file hosts the scoreboard. Kiosk Mode, including Apple TV, rejects hosting; legacy hosted data has an explicit recovery/discard path. The fenced manual host-transfer protocol is retained internally for compatibility with App Mode devices; the new kiosk workflow offers no host selection. When the owner is online, a match/runtime/next-epoch publishing grant can be prepared for a trusted venue host. It is encrypted to that device and becomes active only after the owner observes and commits the completed native handoff. The old publisher is fenced. A venue device does not need the owner's account. The owner can pause/resume publishing without moving game authority.

Public read-only links independently open the scoreboard, OBS overlay or commentator page without login. Private participant views retain match-scoped authorization. Public output is sanitized: game/player details and gameplay commentary may appear, while file operations and account/device identities are excluded. Public tokens are carried in URL fragments, then authorization headers/socket subprotocols.

## Validation and remaining device checks

Focused native regressions cover local file saving/overwrite protection, staged join cancellation, and kiosk capabilities/disconnect clearing. A single iPad navigation test exercises Home, file creation, the separate settings panels, join/back/cancel and kiosk mode. Worker tests cover a stable session code, unchanged-password grant preservation, explicit password revocation and independent public viewing links. Use individual test filters; do not run the full native or UI suites.

Real-device verification remains necessary for camera scanning, LAN/nearby interface changes, WebRTC negotiation, cloud failover and multi-device host handoff. Universal links require deployment of the association response and an appropriately signed app. Fully offline signed owner delegation, cloud file sync, VPS runtime/traditional login, media delivery, mesh routing and full cloud Web API v2 parity remain future work. The portable relay interfaces preserve the option of a VPS adapter and another identity provider.
