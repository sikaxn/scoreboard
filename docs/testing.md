# Testing Smart Scoreboard

## Run in Xcode

1. Open `smartScoreboard/smartScoreboard.xcodeproj`.
2. Select the **smartScoreboardTests** scheme and **My Mac** destination.
3. Choose **Product → Test** (⌘U).
4. Open the Test navigator (⌘6) to run a single test or inspect a failed expectation.

The main **smartScoreboard** scheme also includes the unit target when testing on
My Mac. Testing with the dedicated test scheme builds just the core and tests.
The **Run** button (▶ / ⌘R) launches the app in either scheme; use **Product → Test**
(⌘U) to run the tests. Use the Xcode version required by the app's build instructions.

From the repository root:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project smartScoreboard/smartScoreboard.xcodeproj \
  -scheme smartScoreboardTests \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
```

These are native [Swift Testing](https://developer.apple.com/documentation/testing)
tests (`@Test`, `#expect`, and `#require`), run through Xcode or `xcodebuild`.
The repository is an Xcode app project, so the `swift test` package command does
not apply.

## Coverage

| File in `smartScoreboard/smartScoreboardTests` | Regression coverage |
| --- | --- |
| `ScoringTests.swift` | Score corrections, team independence, new-game reset, timer fractions and expiry, storage isolation |
| `RosterCSVTests.swift` | CSV escaping, Unicode, player state, and malformed rows |
| `ControlBoardModeTests.swift` | Per-sport presets and capability changes, custom module ordering, team scope, shortcut execution, default summary visibility/persistence, pane-width column layouts, empty layouts, preference reset and legacy/future data |
| `ConnectionStatusTests.swift` | Non-host owner as a client, host exclusion, owner link telemetry/disconnects, legacy lists, duplicate peers, consistent client counts |
| `RemoteControlTests.swift` | All sport capability gates, command validation and retries, timer delay compensation, controller permissions, wire compatibility, mirror updates, pending commands and disconnects |
| `PauseTimerTests.swift` | Keyboard controls, all sport pause capabilities, allowances, fractional countdowns, expiry, saved games and backups, remote projection, indefinite pauses, sounds and Companion actions |
| `SessionAuthorityTests.swift` | Authority epochs, identity conflicts, clean disconnect rules, hosted storage, corrupt recovery, checkpoint compatibility and sport handoff encoding |
| `SessionLogTests.swift` | Page limits, cursors, missing and duplicate pages, conflicting history, persistence and host promotion |
| `SetupNavigationTests.swift` | Settings confirmation, unchanged navigation, live clock fractions, actual edits, initial setup and delegated-host forwarding |
| `WebAPIIntegrationTests.swift` | Live HTTP catalog, authentication, malformed input, command retries, sport conflicts and key revocation |
| `LocalizationTests.swift` | All catalog placeholders, formatter ABI, positional arguments and English/Chinese/missing/malformed bundles |

All Swift checks now live in the native test target. There is no command-line Swift
compiler harness or runtime extraction of source code. Settings navigation uses
`ScoreboardSetupEditing`, the production implementation shared with `ContentView`;
`SetupNavigationFixture` supplies only state storage and UI/file callbacks.

Browser DOM tests live in [`tests/web`](../tests/web/README.md), with a pinned
`jsdom` dependency and lockfile:

```sh
npm ci --prefix tests/web
npm test --prefix tests/web
```

Both browser tests locate their app assets relative to their own files, so they
also run from the test directory. `scripts/` contains only App Store preview
utilities.

The **smartScoreboardUITests → an iPad simulator** scheme adds real iPad operator, display/layout,
Companion, and remote-client workflows. See [UI tests and regression history](ui-testing.md)
for scenarios, fixtures, and running a selected group. These UI tests are separate
from the faster core suite above. `AllUI` is the default and enables all
scenarios, including all event modes and expanded Debate/Custom
editing combinations and control board station layouts. `FocusedUI` selects fourteen cases for the recent repairs and station modes;
JSON fixtures preload repeated setup for the larger configuration matrix.
Current repairs and preloading have not been built or run, at the user's request.
The new control board mode and connection-status regressions have also been added
without running tests or a build, at the user's request.
The core setup suite also includes a parameterized regression for Debate's
opening side and preservation of the live turn after unrelated edits.
AirPlay, physical devices, RTC negotiation, and
native Mac windows and tvOS UI behavior retain their device/manual verification.

## Isolation and test design

The hostless unit bundle compiles the selected production core files directly;
it does not rewrite or copy their implementations. The **Core sources under test**
group in Xcode lists their target membership. Test files are picked up automatically
from the synchronized `smartScoreboardTests` folder.

Only this target defines `SCOREBOARD_TESTING`. This enables a unique temporary
storage root, a separate preference suite, an in-memory receiver wire, private
state fixtures, and explicit timer advancement. The HTTP test starts the real API
on OS-assigned ports with Bonjour advertising disabled, so it can run alongside
the app without skipping checks or occupying its normal ports. App targets continue using their
normal preferences, storage, networking, and run-loop timers. Temporary files and
preferences are removed when the test process exits normally.

`ScoreboardTests` is `@MainActor` and `.serialized` because the store and log manager
are shared singletons. Each test starts from factory settings and a new basketball
game, with sound and integrations disabled and known paired-device fixtures.
Parameterized tests reset the fixture for each sport or input. Keep new tests in
this suite until their dependencies can be instantiated independently.

When changing behavior:

1. Add a focused `@Test` in the relevant suite extension, named for the behavior.
2. Reproduce the failing input through the store or shared command entry point.
3. Use `#expect` for outcomes and `try #require` before depending on optional data.
4. Advance clocks with `advanceControlTestTimers(by:)`; reserve real waiting for
   the receiver acknowledgement-timeout scenario.
5. Run ⌘U. Run the browser tests as well when changing the Web API demo pages.

If a new core source file is required, add it to the test target's Sources build
phase as well as the app. Add test cases for the expected result and rejected or
boundary inputs, so failures explain which contract changed.
