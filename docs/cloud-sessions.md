# Match sharing and cloud sessions — Smart Scoreboard 1.8

The cloud service is in the sibling `scoreboard-cloud` repository. Its README covers deployment and Google OAuth. Deploy the matching Worker before using the new native invitation and match APIs. Dashboard variables and secrets remain untouched by these changes.

## App experience

The control board is based on pre-cloud commit `4bcbeac661fcd4144730f017f471f080d1bf9969`. The discarded implementation is preserved on branch `backup/cloud-rework-287aab9`; its navigation is replaced, while its match identity, authenticated local transport, and deployed cloud API adapter remain.

**App Mode** starts at **Home** with New Scoreboard and Connect to Scoreboard. The single **Open Scoreboard** section lists local files; **Open File…** opens a file elsewhere, importing a local copy when needed. The searchable list also supports export, rename, duplicate and delete. Opening a file resumes its scores. New Scoreboard from Setup creates another identity with reset gameplay. A fresh installation does not create a file just by visiting Home. Once a file is opened, its host advertises nearby when connections are enabled. Local file saving belongs to a view-independent repository, so presenting settings or connecting to another scoreboard cannot redirect autosave into a different file.

**App Settings** fills the app workspace and preserves the underlying Home/control board state. Its **LAN & Cloud** page has independent **Enable LAN & Nearby** and **Enable Cloud** switches. Disabling LAN/nearby stops discovery, native local peers, local Web API and Companion; cloud hosting/joining remains available independently. Disabling cloud cancels its relay socket and HTTP requests. Turning both off keeps scoreboards completely local. Local games, saving, timers and attached displays continue; account credentials and pairing identities are preserved. Web API and Companion need explicit enabling after local networking is restored. A legacy delegated/following host must complete or return its handoff before local connections can be disabled.

The preferred-route choices follow these switches: LAN Only / LAN + Nearby with cloud disabled, Cloud Only with LAN/nearby disabled, and Prefer LAN + Nearby / Prefer Cloud with both enabled. Changing either switch normalizes the selected preference; startup and backup restoration preserve these constraints. Cloud Only never opens a local discovery/listener or falls back to LAN.

The control board’s status badge and **Connect Devices** menu open the same device manager. Host/owner status and the connected/disconnected roster come first, with each device’s route, transport, link diagnostics and applicable control permission in one row. Nearby pairing, cloud sharing, public viewing links and existing owner recovery actions follow. Participants use the same status/roster presentation without host sharing controls. LAN & Cloud Settings opens the full app settings page; score shortcuts are suspended while the device manager is open.

Nearby discovery handles Bonjour authorization/policy errors with Local Network permission guidance rather than raw `NoAuth` codes. Failed browser instances can be recreated with **Try Again**, and discovery retries when returning from system settings. All browsed service types and the local-network usage description are declared in the app’s Info.plist; an OS denial still requires the user to allow access.

**Kiosk Mode** only joins an existing scoreboard, as a display or controller. Apple TV always runs this mode. iPhone, iPad and Mac can switch in App Settings; local files from App Mode stay private and preserved. Kiosks advertise a separate `canHostSession: false` capability, refuse host preparation and local file creation, and clear received state, image caches and pending controls on disconnect. Pairing identity/credentials are separate from game data and can support reconnecting.

App Mode Home closes local clients and Web API sockets and pauses cloud hosting. Startup cannot advertise or publish a scoreboard before it is opened. Reopening restores hosting for the same saved match, including its fixed cloud code/password. Returning Home saves the document; a delegated/following host must finish its handoff first. Cloud pause closes relay sockets and rejects new joins until hosting resumes.

Apple TV, Mac and iPad reuse one kiosk landing page and settings flow, adapting to narrow windows and split-screen. iPhone keeps the compact joining screen. Apple TV is display-only: native permissions, cloud invitations/grants and command dispatch reject control, including old saved grants. Approved iPhone, iPad and Mac controllers use the standard app control board; the separate kiosk controller has been removed. Both home screens show version/build and cloud status, with animations respecting Reduce Motion. Apple TV keeps D-pad/Select/Back navigation for joining and settings. Kiosk cloud joining uses the server selected in App Settings, with no editable URL field; invitations for another origin require changing that setting first. Settings retains Public Cloud/self-hosted URL, pairing management and Factory Default. Reset clears only this device’s credentials, pairings, files and settings; an unresolved legacy hosted match must first be returned or explicitly discarded.

**Game Settings** and **App Settings** are separate panels. Game Settings includes teams, rules, clocks, rosters, logos, backgrounds, and date/time overlays saved in the scoreboard file. App Settings includes device mode, account/cloud server, connection preferences, sound, theme, physical display directions, integrations, shortcuts, backup and logs. The board’s Settings menu opens either panel. Home opens App Settings; participant controls cannot edit the owner’s file.

The external/public display shows “Start or join a scoreboard on your main device.” while the main device is on Home. Opening a file or receiving a joined match changes it to the scoreboard.

### Joining and sharing

Nearby joining discovers host scoreboards over `_scorebrd-join._tcp`. The client can ask the host to confirm, or supply the host’s six-digit PIN. The host can also discover a kiosk and pair using its four-digit device PIN, preserving the previous Remote Display workflow. Both arrange the existing authenticated host-to-client connection. Approval-only requests carry no game data, time out, and cannot silently grant control. PIN-based control requests still require host approval. Codes and metadata are scoped to the current match; duplicate announcements are merged by physical device ID.

Previously paired nearby devices reconnect with saved trust, without another PIN, password or join approval. The Nearby section hides pairing inputs for these devices, and selecting a nearby Recent Connection reconnects directly. A matching invitation code/link can reuse that nearby pairing too. A fresh challenge authenticates both devices and binds the request to the selected host, match and client before the existing transport reconnects. Approved control permission is preserved; new control requests still require owner approval. Removed/reset pairings and expired invitation revisions require pairing again. Both apps must support this reconnect exchange; older hosts retain the existing pairing flow. No internet or cloud account is required.

Online participants enter a fixed session code and password, without signing in. Only the owner signs in. **Connect Devices** on the open scoreboard provides nearby PIN/QR, participant permissions, cloud sharing and failover. Cloud relay remains explicit and requires an enabled service, owner account, and relay entitlement. The code remains fixed across publishing reconnects and password updates; saving the same password preserves participant grants. An explicit password change or revocation removes previous invitation access. A new scoreboard has its own session/code. Deploy the matching Worker change for this stable-code behavior.

Cloud joining is staged: failed/cancelled joins preserve the personal document, and controls switch after joining. Nearby discovery and pairing do not need internet. Guests receive only match-scoped access, including cloud failover credentials where enabled.

**Recent Connections** retains the advertised cloud origin/code for ordinary nearby PIN and confirmed joins too. With cloud enabled, a recent match can reconnect online after relaunch even if Wi-Fi and Bluetooth are off and internet is available through cellular or Ethernet. Route selection follows Prefer LAN + Nearby / Prefer Cloud. Cloud Failover enrollment includes the match identity and session ID; valid participant grants stay in device-only Keychain separately from history and game files. Reconnection validates the grant and match before switching workspaces. Older grants can recover missing metadata from the authenticated service listing. Expired or revoked access requires a fresh invitation/password; the publishing host must still have online sharing enabled.

Use **Clear Recent Connections** on the Connect page to erase all history, or a row's context menu to remove one entry. Clearing history preserves local files and device authorization, and background refresh does not recreate cleared entries. Signing out or resetting this device removes its cached cloud grants.

## Using a cloud invitation nearby

A native guest can enter the same fixed cloud invitation code/password or scan its invitation link while offline. **Enable LAN & Nearby** on both devices and allow nearby joining on the open host scoreboard. The guest needs no account, internet connection, cloud setup, or matching cloud URL in its settings. A link identifies its own service for local matching; entering just the code discovers that service from the nearby host. Joining never changes the guest's configured cloud host.

The publishing host must first synchronize this invitation with the updated Worker while online. It caches a salted SRP verifier in Keychain, scoped to the cloud account/service, local host and match. Both devices can subsequently use it without internet. Nearby-only six-digit PIN and owner-confirmed pairing remain available independently, including on hosts that have never used cloud.

The nearby advertisement contains the invitation code and service origin, not a password or verifier. SRP-6a (3072-bit group, SHA-256) authenticates both sides, and an authenticated encrypted message supplies the guest's temporary device PIN. Controllers still require owner approval; Apple TV remains display-only. Invitation-derived trust is limited to the current match and password revision. Received scores and files stay in the joined workspace, separate from the guest's local scoreboard.

With both routes enabled, the selected preference determines whether cloud or nearby is attempted first. A nearby join can prepare a matching cloud fallback in the background when that cloud service is enabled and configured; failing to prepare it does not block local use. Cloud-only mode never starts local discovery. Password changes/revocation take effect on offline hosts when they next synchronize; a host that has not synchronized cannot learn a remote change.

## Cloud agreement consent

Enabling Cloud first shows a data-sharing disclosure. Continuing fetches the selected service's versioned agreement; no match/API traffic starts until explicit acceptance. Receipts are saved per service in Keychain. A different self-hosted service needs its own agreement. Startup revalidates an existing acceptance silently, without a loading popup. During an internet outage, a valid saved receipt remains usable for retrying cloud requests; the server still rejects outdated receipts. Without a receipt, an unavailable policy pauses cloud traffic and retries in the background while local use remains available. **Use App Offline** dismisses an explicit loading/failure screen without turning Cloud off. Declining an agreement disables Cloud. Local files, scoring, LAN and nearby pairing do not require cloud consent.

The initial cloud placeholder is the supplied Managed Cloud AUP, labelled version **0.1**. Service admins can publish replacement versions from the web Administration page; published versions cannot be changed or reused. Every new version requires fresh account/device acceptance and pauses active cloud connections. Google signup also requires acceptance. Public viewing links remain read-only and login-free.

Deploy the matching app and Worker together. The Worker enforces agreement acceptance on protected API requests, uploads and relay connections, and records the accepted version and timestamp. No deployment secrets or dashboard variables are changed.

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

Focused native regressions cover local file saving/overwrite protection, staged join cancellation, and kiosk capabilities/disconnect clearing. Focused iPad navigation checks exercise Home, file creation, the separate settings panels, join/back/cancel, kiosk mode, and the shared connection/device manager from both entry points. Worker tests cover a stable session code, unchanged-password grant preservation, explicit password revocation and independent public viewing links. Use individual test filters; do not run the full native or UI suites.

Real-device verification remains necessary for camera scanning, LAN/nearby interface changes, WebRTC negotiation, cloud failover and multi-device host handoff. Universal links require deployment of the association response and an appropriately signed app. Fully offline signed owner delegation, cloud file sync, VPS runtime/traditional login, media delivery, mesh routing and full cloud Web API v2 parity remain future work. The portable relay interfaces preserve the option of a VPS adapter and another identity provider.

### Game completion and View Only clients

`game.complete` accepts `text` values `homeWin`, `guestWin`, `tie`, or `aborted` through the shared command path. It stops all timers and adds a frozen `game.completion` result to saved files, v1/v2 state, cloud updates, reconnect snapshots, and host checkpoints. Completed matches reject every game command except `game.undoComplete` with a conflict. Undo requires the existing control permission and preserves scores with timers stopped. The existing Game State box contains the result and undo control.

Non-kiosk clients use the same native board for the **View Only** role, with editing controls disabled. The top bar, board layout selection, display preview, and player navigation remain available, including after completion. Permission changes enable the existing editing controls without switching presentations. View-only rosters show the public lineup when the transport omits full roster data. Kiosk clients use the fullscreen public scoreboard, including final-result displays.
