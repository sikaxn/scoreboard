# Demo video capture

`demo_video_script.md` is the editorial source. These tools capture the real Debug
app with XCTest on an operator iPad, an audience Apple TV, and a remote-control iPad simulator. A capture-only copy of the
project seeds fictional teams, rosters, logos, scores, and a read-only receiver
status file. Production app sources and existing tests are not modified.

Requirements: Xcode with iOS and tvOS simulator runtimes, Python 3 with Pillow, ffmpeg,
macOS `say`, and Node.js with built-in `fetch` and `WebSocket` (this machine uses
Node 24). The current machine uses Xcode at
`/Applications/Xcode.app/Contents/Developer`; the shell's system developer
directory is left unchanged. Browser assets use the already installed Chromium
test browser specified in `record_demo_video.py`.
`capture_browser.mjs` waits for the live demo teams before saving browser shots,
so a connected page with an initial empty score does not enter the final edit.

```sh
python3 scripts/record_demo_video.py --operator OPERATOR_IPAD_UDID --receiver APPLE_TV_UDID --controller CONTROL_IPAD_UDID
python3 scripts/demo_video/prepare_narration.py --voice Samantha
python3 scripts/demo_video/render_demo.py --bezel '/path/to/iPad Pro (M5) 11" - Space Black - Landscape.png'
python3 scripts/demo_video/package_demo.py --archive
```

For the Simplified Chinese edition (聪明的计分板), run:

```sh
python3 scripts/demo_video/localize_demo.py
```

This reuses the existing `DemoVideo/raw/` recordings and writes Chinese titles,
device labels, Mandarin voiceover, subtitles, scene edits, and a separate asset
ZIP under `DemoVideo/zh-Hans/`. The recorded app and browser interfaces remain
in English. Editorial translations live in `scripts/demo_video/zh-Hans.json`.
The default Mandarin voice is the locally installed macOS Tingting voice.

For new recordings with the actual Chinese iPadOS and tvOS interface, use a
separate output folder so the previous Chinese edit stays intact:

```sh
python3 scripts/record_demo_video.py --language zh-Hans --output DemoVideo/zh-Hans-ios
python3 scripts/demo_video/render_demo.py --output DemoVideo/zh-Hans-ios
python3 scripts/demo_video/localize_demo.py --source DemoVideo/zh-Hans-ios --output DemoVideo/zh-Hans-ios --package-only --native-ui
```

Before rendering, copy `scenes.json`, `voiceover/`, and the two bezel PNGs from
the existing edition into the new output folder. The recording runner stages
Chinese demo identities and looks up visible XCTest labels from the app's real
Simplified Chinese string catalog; accessibility identifiers remain stable.
For a fully Chinese system status bar and keyboard, set the dedicated
simulators' preferred language to Simplified Chinese and region to China, then
reboot them before recording. Recording-only app-name metadata uses 聪明的计分板.

Use fresh simulators to keep personal simulator sessions separate. `simctl`
commands cannot target physical devices. The simulator IDs default to the three
dedicated devices created for this recording session. The tvOS build uses arm64 on this Apple Silicon Mac. You can capture one scene
with `--only test04AudienceViews`, reuse a completed build with `--skip-build`,
or exclude completed methods with `--skip test01Result`. After changing the
capture test, build again before using `--skip-build`.

The runner keeps a local coordinator on `127.0.0.1:18765` while tests execute.
XCTest starts and ends scene recordings, marks shots, and operates actual app
controls. The audience receiver is the real tvOS app, discovered over Bonjour and paired
using its current four-digit code. Score assertions inspect the receiver's live
state. The separate `DemoReceiverUITests` case is run on the additional iPad by the coordinator,
after the owner grants control; it is excluded from the ordinary capture class.

Outputs are in `DemoVideo/` (git-ignored):

- `smart-scoreboard-demo-full.mp4`, `-15s.mp4`, `-60s.mp4`: 1080p review edits.
- `raw/`: original operator/audience MOV recordings, PNG stills, and shot times.
- Each scene's `capture.json` also records actual touch positions and timing.
  The review edits show a cyan tap pulse, including on the authorized remote iPad.
  Original MOV files stay clean for later editing; touch data is kept separately.
- `voiceover/`: individual 48 kHz/24-bit WAVs, full WAV/MP3, short cuts,
  narration text, and sentence subtitles with estimated timing.
- `web/`: real built-in scoreboard, overlay, and commentator browser captures.
- `sound-effects/`: a separate Classic Buzzer WAV regenerated from the app's
  procedural sound parameters; this is an edit asset, not recorded app audio.
- `graphics/`: local bezel copy and edit artwork; `edit/`: individual scene edits
  and editable cut decisions.
- `capture-*.xcresult` and `tests-*.log`: XCTest evidence; `media-validation.json`
  describes the rendered streams and durations.

The full cut is 3:08, including the 3-second end card. The first 15 and 60 seconds
are complete standalone cuts. Scene footage is condensed for the review edit;
the original device recordings retain actual timing. Simulator MOVs are silent;
the voiceover is synthesized locally with the named macOS voice. No backing music
is added. Physical AirPlay/TV output and offline host handoff are outside this
capture. The paired-device permission scene shows a second iPad controlling the game while the Apple TV displays the scoreboard. The Apple bezels come from the user's local download.
