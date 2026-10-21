# Operator workflow UI tests

The `smartScoreboardUITests` target uses XCTest and Apple's
[XCUIAutomation](https://developer.apple.com/documentation/xcuiautomation) to launch
and operate the real iPad app in an iOS Simulator. It is separate from the faster
Swift Testing core target.

## Run

Open the project, select **smartScoreboardUITests → an iPad simulator**, and press **⌘U**.
The Run button (⌘R) launches the app. The Test navigator (⌘6) can run one scenario.
Use a dedicated simulator, such as **iPad Pro 11-inch (M5)**, so the tests do not
share app data with your own simulator sessions. Tests synthesize touches and
keyboard input inside that simulator. Allow local network access if iPadOS asks;
the test interruption handler accepts the standard Allow prompt.

The scheme's default test plan is `AllUI` (all cases). Choose **Product → Test Plan**
for `SmokeUI` (two control/display cases), `FocusedUI` (fourteen cases covering the
recent helper repairs, preload path, and station modes), `OperatorWorkflows` (event/display/station cases), or
`IntegrationRecovery` (two network cases). The same checked-in plans are selectable in Xcode Cloud; see
[Xcode Cloud setup](xcode-cloud-testing.md).

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project smartScoreboard/smartScoreboard.xcodeproj \
  -scheme smartScoreboardUITests \
  -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5),OS=27.0'
```

The simulator build uses Xcode's normal signing settings. The test runner is an
iPad simulator app; it does not type into the Mac desktop or need a native Mac
UI-test runner. Replace the simulator name and OS with one installed in Xcode.

Use `-only-testing:smartScoreboardUITests/EventWorkflowUITests` (or
`EventModeUITests`, `DebateEditingUITests`, `CustomModeEditingUITests`,
`DisplayLayoutUITests`, `ControlBoardModeUITests`, `IntegrationRecoveryUITests`) to select a group. Tests run
serially within each simulator. They use actual controls and bounded
condition waits; missing or unreachable controls fail the test.

## Fast checks without UI interaction

Use **smartScoreboardTests → My Mac → ⌘U** for everyday code changes. These
Swift Testing cases call the production scoring, setup, pause, session, and
transport logic directly. They do not synthesize touches or keyboard events.
Keep logic assertions in that suite; use UI tests to verify controls, text input,
rendered state, gestures, and layout integration.

`SmokeUI` limits routine simulator automation to two existing scenarios. `AllUI`
retains full operator and recovery coverage for a scheduled/manual Cloud run.
A second simulator is useful for receiver-app UI validation, but is not required
for the existing deterministic socket recovery tests.

## Scenarios and regression history

The latest completed full run passed 46 of 53 cases; the remaining seven failures
were all Debate navigation cases. Reopening Settings retained the nested Debate
Designer, so tests searched the wrong page for Game Setup controls. Settings now
resets that nested page, and Debate checks assert the overview is present before
looking for its controls. Both focused Debate checks passed: Guest-start dual
clocks and editing a Policy template without changing its built-in format. The
full suite was not rerun; see the [validation handoff](ui-testing-handoff.md).
`SmokeUI` still selects the same two cases.
The eight new `ControlBoardModeUITests` scenarios and the accompanying core mode
and connection tests have not been run or built, at the user's request.
The station scenarios also check that the themed picker header stays at the top
and Done remains reachable after scrolling; the toolbar button exposes the current mode.
Additional checks cover roster columns, clock/score visibility, running clocks in
Merged View, separate Display Control navigation, and the shared hockey penalty picker.

| Added group | Cases | Coverage |
| --- | --- | --- |
| `EventModeUITests` | 14 | Simple, Basketball, Soccer, Hockey; Volleyball best-of-three/five × match timer on/off; all four Chess presets with unequal clocks; switch through all eight event modes in both directions |
| `DebateEditingUITests` | 11 | All built-in formats and their segment sequences; score/player/prep combinations; custom labels and durations; independent prep clocks; shared, dual, and untimed blocks; automatic segment start; both starting sides; side-switch gating; add/reorder/delete; editable copies of each built-in template; reset confirmations |
| `CustomModeEditingUITests` | 18 | All 16 combinations of four clock styles (countdown, count-up, disabled, chess) × four scoring layouts (off, +1, +1/+2, +1/+2/+3), plus a complete editor journey and dependent-option reset/re-enable checks |
| `ControlBoardModeUITests` | 8 | Dedicated shot controls preserve a running primary clock; custom modules and team scope; per-sport choices; roster identity editing and columns; empty layouts; summary visibility; Merged View clocks/columns; separate Display Control; shared penalty selection |

The Custom matrix also varies period tracking/wins, shot/serve/off secondary
timers, possession, player tracking/layout/fouls/cards, substitutions, pauses,
team fouls, and penalty timers. Cases operate applicable score and timer controls,
and check saved configuration. The editor case also edits the committed title again. The clock/scoring
cross product is exhaustive; the additional feature combinations are selected
coverage, not every possible toggle permutation. Text edits include literal
percent signs and `%@` to exercise the earlier formatting regressions.

| Scenario | What is checked | History motivating the test |
| --- | --- | --- |
| Event setup and operation | Select Basketball, enter event/team names, score independently, start and stop the real clock | Main operator workflow |
| Running-clock settings warning | Cancel the warning, confirm it, return without edits, retain scores and the running clock | `43cdfb1` — settings warning and live-state preservation |
| Official pause | Stop play, show an indefinite official pause, end it, restart only on operator action | `4a8c137` — pause timers and controls |
| Debate and Custom setup | Commit percent-containing event names and reopen both settings trees without crashing or corrupting text | `2e8729b`, `57b98ea` — localized formatting crashes and deep SwiftUI view trees |
| Merged view and rotation | Rotate the actual iPad viewport between portrait and both landscape orientations; keep scoring, header controls, and clock updates usable | `57b98ea`, `f9f89bc`, `f395c74` — compact layouts and wrapping toolbar fixes |
| Window resizing | Drag the actual iPadOS resize handle to shrink and restore the app window; retain scoring, clock updates, and settings access | Adaptive layout regressions; requires iPadOS 26+ |
| Scrolling during play | Scroll settings in both directions and retain an advancing, running match clock | `234db78` — timer updates stopped during scrolling |
| Full-screen display lifecycle | Show current scores and advancing clock, rotate, tap to return, score, background/foreground the app, reopen with current state | Display lifecycle and state synchronization |
| Companion recovery | Send a real HTTP event, stop the endpoint, see the failure while scoring remains usable, restart the endpoint, send the next event, disable output | `84d3617` — Companion queue and error handling |
| Remote client recovery | Discover through Bonjour, pair by code, publish actual scores, lose the client, score offline, reconnect with the saved secret, disconnect/connect through operator controls | `c8b48ff`, `cfe761b`, `1e3f5de` — disconnect responsiveness, discovery, and reconnection |

## Fixtures and isolation

Each launch passes a fresh UUID in `SCOREBOARD_UI_TEST_ID`. Debug builds use that
UUID for a dedicated preference suite and temporary game/log/session directories;
legacy file migration is skipped. AppStorage uses the same preference suite.
Release builds ignore these launch fixtures.

Named starting configurations live in
[`Fixtures/EventConfigurations.json`](../smartScoreboard/smartScoreboardUITests/Fixtures/EventConfigurations.json).
The UI bundle includes this resource. `launchFixture` reads a selected entry and
passes its JSON contents in `SCOREBOARD_UI_TEST_CONFIGURATION`; the Debug app
loads it through the normal saved-game snapshot path before showing the UI.
No app-container path or source checkout is needed at runtime.
Fixtures that need editing first launch the saved event, then open Settings
through its actual control. Fresh setup remains covered by the operator setup
test; combining fresh Simple drafts with a preloaded sport can overwrite it.

The 16 Custom matrix cases preload their clock, scoring, and module options.
They operate the live controls and verify the resulting Settings state. A
separate Custom editor case changes every module through the UI, and the
dependency case exercises resets, all scoring layouts, and clock-mode choices.
Event cases preload identity and starting state, then retain their actual edits
and live actions. Debate keeps a built-in-format editing journey, custom segment
editing, template selection, and operation of every preset sequence.

Edit a named JSON entry to change its initial configuration. For example,
`custom.countdown.two` supplies a countdown with `scoreStepPreset: "oneTwo"`;
`customSportConfig` uses the application's saved custom-sport field names.
Custom matrix assertions read their expected options from that same entry and
observe the app's rendered values. Keep each profile's sport and preset consistent
with its named test. Each case still launches an isolated app instance: a failure
in one configuration does not prevent the other cases from being attempted.
Shared setup is reused as data, rather than repeating all the setup gestures or
combining the matrix into one test that stops at its first failure.

The original display and recovery cases start from a saved Basketball configuration.
Companion scenarios
seed a localhost address, an ephemeral test port, and known event assignments;
the operator still enables Companion and triggers events through the UI. The
existing automation notice is accepted through its actual controls.

SwiftUI animations are disabled for these Debug fixture launches. Native UIKit
transitions retain their normal behavior; tests wait for alerts to dismiss. Real production clocks, persistence, views, network
services, and input handling are used. The unit-test-only `SCOREBOARD_TESTING`
flag is **not** set on the app or UI test target.

`LocalIntegrationPeers.swift` provides local network peers inside the simulator
test runner. A second simulator is not required for these protocol recovery cases:

- `CompanionPeer` implements the HTTP press endpoint, records paths, and can stop
  and restart on the same port.
- `RemoteDisplayPeer` advertises a unique Bonjour display, handles pairing and
  heartbeat messages over real WebSockets, checks saved pairing secrets, and
  records scoreboard updates. It omits RTC to exercise the supported WebSocket
  fallback (`50e6abf`). It does not replace the app's transport or set UI state.
  Compatibility metadata is copied from the built app into the test bundle by a
  native Copy Files phase, so the runner does not need the source checkout or
  access to the app's separate simulator installation directory.

Failures attach the app window screenshot and accessibility hierarchy to Xcode's
test report and `.xcresult` bundle. These artifacts help distinguish a UI
regression from a changed accessibility identifier.

Helpers use the stepper's actual child identifiers, tap the inner switch thumb,
and clear/verify existing text before replacing it. Scrolling follows the owning
container, reveals clipped frames before checking hittability, searches upward
for unrealized items before scanning downward, and fails when layout frames stop
moving. Pickers are revealed before their style is resolved. Native alert actions
use label-scoped coordinate taps, and short secondary clocks use controls whose
queries remain valid when the clock expires during scrolling.

## Coverage boundaries

This suite automates the iPad operator and on-device full-screen display. Run
the same plan on iPad Pro and iPad mini to cover different viewport sizes.
Rotation tests change the real app viewport. The resize case drags the iPadOS
Windowed Apps resize handle and checks the actual window frame; select iPadOS
26 or newer to include it. Split View arrangements remain separate checks.

The remote peer is a protocol fixture, and Companion uses its HTTP interface.
Physical AirPlay/external displays, native Mac window behavior, a second device's
receiver UI, actual production hardware, RTC negotiation, and Companion TCP/UDP
still need their transport/device verification.
The existing core, HTTP, localization, and browser tests remain complementary.
