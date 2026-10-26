# WebRTC transport

## Dependency and platforms

The app links the standalone [LiveKitWebRTC XCFramework](https://github.com/livekit/webrtc-xcframework) at tag `150.7871.03` (SwiftPM version `150.7871.3`), revision `a41df9e9bcc7ab1d62131fda75c123ea391e5188`. This is the WebRTC engine only: no LiveKit room SDK, account, server, or cloud service is used.

The release's XCFramework Info.plist includes:

- iOS devices and arm64/x86_64 simulators.
- macOS arm64/x86_64 and Mac Catalyst.
- tvOS arm64 devices and arm64 simulators, including Apple TV session hosts.

The stasel distribution was considered first, but its release lacks tvOS slices. Apple TV must use a native tvOS binary, rather than an iOS binary. Package resolution downloads the framework; no source build of WebRTC is required. Refer to the dependency repository for WebRTC license and third-party notices.

## First integration

`ScoreboardRTCTransport.swift` implements a shared, data-only peer. WebRTC creation, SDP/ICE work, sends, and teardown use a dedicated dispatch queue. There are no audio/video tracks or media permission requests. Each peer is tied to one existing WebSocket connection and one negotiation UUID.

| Traffic | Transport |
| --- | --- |
| Native pairing, authentication, heartbeats, clock offset | Existing WebSocket |
| Native state snapshots and control commands | RTC when ready; WebSocket fallback |
| Browser v1 state and control commands | Optional RTC; WebSocket/HTTP fallback |
| Command acknowledgements | Existing WebSocket |
| V2 browser resource subscriptions | Existing WebSocket |
| Host handoff, match/log sync, images, sound messages | Existing transports |

RTC is negotiated only after native pairing authentication succeeds and the client advertises protocol version 1. Old clients do not advertise support, so they continue using their existing connection. The current session host, including Apple TV, creates the native offer. Browsers create their offer over the host's existing Web API WebSocket.

RTC uses the reliable, ordered `scoreboard.reliable.v1` channel. The first version deliberately retains existing native clock synchronization and timer-offset compensation. Unordered/partially reliable clock packets are a possible later extension, not part of this integration.

No external STUN, TURN, or signaling service is configured. Direct connectivity is attempted using local ICE candidates. Networks that prevent a direct connection, or Apple's nearby networking paths that RTC cannot use, retain the old transport. This does not enable internet access.

## Fallback and integrity

- Negotiation has an 8-second deadline. Failure leaves WebSocket/HTTP available.
- RTC messages are limited to 48 KiB with bounded queued output. Larger snapshots and backpressure use WebSocket.
- Native hosts send a full snapshot at least once per second. A native receiver closes a stalled RTC path after 3 seconds without state, even when WebSocket heartbeats still arrive.
- Native command retries use the same UUID, timestamp, and parameters after 750 ms without acknowledgement. The existing command-result cache prevents double application. Browser commands similarly fall back to HTTP using the unchanged command.
- Native commands reuse per-device permissions, sport checks, host/session epoch validation, and timer compensation. Browser commands reuse the Web API enable switch and API-key checks on every command.
- Native clients and the control demo reject older snapshots within the same session and host epoch using `generatedAtUnixTime`.
- Disconnect, unpair, host promotion, and a replacement WebSocket invalidate the corresponding RTC peer. A new host requires a new connection and negotiation.
- The connection popover reports WebRTC/WebSocket for the local client and connected remote devices. A host is still labeled Hosting, with no self-ping.

## Browser protocol

See the bundled API documentation's Optional WebRTC transport section for SDP/ICE and command message examples. The control demo includes a WebRTC checkbox and visible transport status. The API key stays in page memory and accompanies each RTC command; it is never included in signaling or the URL.

Keep the signaling WebSocket open for acknowledgements and fallback. RTC v1 state retains the existing `scoreboard.state` envelope, whose full state is in `payload`. V2 subscribers stay on their existing resource stream. If the host changes, open the new host's API address and negotiate again, just as existing HTTP clients need the new host address.

## Manual verification (not yet run)

1. Resolve packages in Xcode, then build for Mac, iPad/iPhone, and Apple TV. Verify the Live Activity extension does not link WebRTC. Apple TV simulator support in this binary is arm64.
2. Pair a Mac with an iPad and Apple TV. Verify the popover changes from WebSocket to WebRTC after negotiation and that all display modes still render.
3. Make Apple TV the host, then use a remote control board. Change scores, start/pause clocks, operate players/cards/fouls and team pauses in every supported mode. Verify Companion runs only on the host.
4. Open `/demo/control` at the Apple TV host IP. Check WebRTC status, valid/invalid keys, key reset, Web Control off, game changes, and score/timer/player operations. Disable WebRTC in the page and repeat through HTTP.
5. Switch host with timers stopped. Verify clients close the old RTC peer, reconnect to the new host, and continue controlling it. Disconnect the owner while the host stays online, then reconnect and verify file/log synchronization.
6. Block UDP while allowing HTTP/WebSocket. Verify negotiation times out or an active RTC path falls back without freezing the interface or applying a command twice. Repeat with Wi-Fi loss and app suspension.
7. Load a large roster/state exceeding 48 KiB. Verify state falls back to WebSocket while controls continue to work, and no older state replaces newer RTC state.
8. Turn pairing off, discard a hosted match, and unpair a device. Verify no RTC updates or commands continue after the connection ends.
9. Connect an older app build and existing v1/v2 WebSocket clients. Verify their original routes and message formats still work.
