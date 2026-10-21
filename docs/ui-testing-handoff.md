# UI test validation checkpoint — 2026-10-17

The UI target now runs on an iPad simulator. Native Mac UI automation was removed
from this target at the user's request. All changes are uncommitted.
See [UI scenarios](ui-testing.md) and [Cloud setup](xcode-cloud-testing.md).

**2026-10-20 addition:** Eight control board station scenarios and core mode/connection
regressions have been added without a build or test run, at the user's request.
`FocusedUI` now selects fourteen cases; `OperatorWorkflows` includes the station
class. The results and case counts below describe the earlier validation checkpoint.

## Current implementation

Current suite: **53 UI cases**. The user's latest completed run passed **46** and
failed **7**, all in Debate. All Custom, event-mode, operator, display, and
integration cases passed. Validation of the current fix is limited to two
focused Debate cases; no full rerun is being performed.

All seven failures occurred after leaving the Debate Designer for the live board
and reopening Settings. The app retained `isDebateDesignerVisible` even though
it selected Game Setup. Four cases searched that designer for its own launcher;
three searched it for the overview's Preset picker. Accessibility attachments
confirmed the designer's Back button, template list, and segment editors remained
visible. The initial editor actions, live clocks, and custom changes had worked.

`ContentView.selectGameSettingsPane()` now clears the nested designer state so
Settings consistently starts at the Game Setup overview. Debate helpers assert
the overview's Preset picker exists before looking for overview controls, making
a future navigation regression fail directly instead of scrolling a long flow.

Latest full-run evidence (46 passed, 7 failed before this navigation fix):
`/Users/nathan/Library/Developer/Xcode/DerivedData/smartScoreboard-fqhfbijzeyhhdoafbwhkgmpxgrhc/Logs/Test/Test-smartScoreboardUITests-2026.10.17_18-36-43--0400.xcresult`.

## Debate navigation validation

Two distinct cases were checked; no full suite was rerun:

- `testCustomDebateDualClockStartsOnGuestWithoutSwitching` passed in **82.7
  seconds**. It verifies the Guest clock runs, side switching is disabled,
  settings reopen at the overview, the designer retains the saved options,
  and changing away from Dual resets its dependent options.
- `testPolicyTemplateCanBeEditedWithoutChangingBuiltInFormat` passed in **62.6
  seconds**. It edits the twelve-block Policy copy, switches to the untouched
  built-in format, switches back to the edited custom copy, then reopens Designer.
  Result: `/tmp/scoreboard-debate-template-recheck.xcresult`.

The first two-case attempt hit a File Error alert with only about 400 MB free on
the Mac; its result bundle was incomplete. Its action log records the Guest case
passing and the template case failing after the file alert. The complete console
was recovered to `/tmp/scoreboard-debate-navigation-console.txt`. Removing an old
temporary diagnostic export created during this task freed about 2 GB. The same
template test then passed without any further code changes. Original user test
results were retained. The app/UI build and `git diff --check` passed.

## Previous repairs

- Nineteen failures opened preloaded Chess, Volleyball, Debate, or Custom events
  as fresh setup. Initial Simple drafts replaced their selected sport, leaving
  tests searching for controls absent from that mode. Fixtures now launch an
  existing event, then enter its editor through the real Settings action.
- Picker helpers reveal an untyped identifier before checking its style, so a
  lazy offscreen segmented picker is not mistaken for a missing menu button.
- Native alert actions can report conflicting Button/PopUpButton types. Alert
  helpers resolve the action by label within the alert and tap its coordinate,
  avoiding XCTest's fallback interruption handler pressing Cancel.
- The focused Chess check exposed clock labels without identifiers in the native
  Chess team-control layout. Both side clocks now carry the same identifiers as
  the other dual-clock layouts, allowing the existing value assertions to work.
- An eight-second Serve timer expired while the test scrolled to its transient
  Pause button. The test now uses Serve Reset, which stops and restores the
  clock. Shot's shared Pause/Reset button is resolved across both labels.
- Soccer's timeout began with repeated 60-second native animation-idle waits
  after submitting a team name. Settings text submission now commits and releases
  field focus, dismissing the keyboard before subsequent navigation.

- Stepper actions now use the actual `settings.stepper.<title>-Increment` and
  `-Decrement` child identifiers. Toggle changes tap the inner switch thumb.
- Text replacement places the caret at the field's trailing edge, deletes the
  previous contents, verifies emptiness, then types and verifies the replacement.
  It no longer relies on the failing Cmd+A path.
- Scrolling uses the owning container, checks clipped frames before hittability,
  searches upward for unrealized items, then downward once, and detects lack of
  progress. A missing child of an already-visible small anchor fails immediately.
- Policy expectations now include all 12 segments and the five-minute `1NR`.
- Production setup snapshots now respect a new/edited Debate flow's opening
  side while preserving the operator's live turn during unrelated edits. A new
  parameterized Swift Testing regression covers both starting sides.
- `Fixtures/EventConfigurations.json` contains 28 named profiles. The Debug app
  accepts their JSON through `SCOREBOARD_UI_TEST_CONFIGURATION`, gated by the
  isolated test UUID, and loads it through the normal saved-game path. The
  resource is bundled with the UI target; no cross-container path is required.
- All 16 Custom clock/scoring cases preload their starting configuration and
  retain live controls and rendered-state assertions. A dedicated complete
  editor case plus the dependency case retain real UI editing. Event and Debate
  cases preload unrelated identity/preset state while preserving editing flows.
- `FocusedUI` selects eight cases for checking these repairs and preloading.
  AllUI remains the default. A local command can limit either plan further with
  `-only-testing`; avoid a full run for routine helper fixes.

- `EventModeUITests`: 14 cases covering all event modes, volleyball format/timer
  combinations, every Chess preset, scoring corrections, confirmations, and mode
  changes in both directions.
- `DebateEditingUITests`: 11 cases covering built-in sequences, custom segments,
  labels, timing flags, prep clocks, both dual-clock starting sides, side-switch
  gating, template copies, and add/reorder/delete workflows.
- `CustomModeEditingUITests`: 18 cases covering the full 4 × 4 clock/scoring
  matrix, varied tracking modules, repeated edits, and dependency resets.
- `OperatorWorkflows` selects all event/display classes (51 cases); `AllUI` includes
  all 53 cases and is the default. `SmokeUI` still selects two when chosen.
- Settings helpers now handle warnings from every timer type and return to
  timerless, Debate, and Chess boards. Additional accessibility identifiers expose
  picker/stepper values, segment editors, and side/prep clocks.

## Previous focused validation

Only two distinct cases were completed for validation:

- `EventWorkflowUITests/testSettingsWarningAndUneditedReturnPreserveRunningEvent`
  passed in **27.4 seconds**, including canceling and confirming the native alert
  and retaining the running clock and score. Result: `/tmp/scoreboard-ui-two-checks.xcresult`.
- `EventModeUITests/testChessBulletWithUnequalOpeningClocks` passed in **93.0
  seconds** after adding the missing native-layout identifiers. It checks the
  preloaded editor, preset changes, unequal clocks, real timer advancement,
  switching turns, cancel/reset, and settings persistence. Result:
  `/tmp/scoreboard-ui-chess-recheck.xcresult`.

The first two-case bundle contains the earlier Chess identifier failure as well
as the passing settings case; the separate Chess recheck is the passing result.
The app and UI target compiled successfully. JSON plans, scheme XML, selected
method names, and `git diff --check` passed static checks. At that checkpoint the
full suite had not been rerun. The subsequent user run above passed all non-Debate
cases, including the Serve and Soccer repairs. Full-suite status after the new
Debate navigation fix remains unverified.

Earlier completed full-run evidence (31 passed, 22 failed before these repairs):
`/Users/nathan/Library/Developer/Xcode/DerivedData/smartScoreboard-fqhfbijzeyhhdoafbwhkgmpxgrhc/Logs/Test/Test-smartScoreboardUITests-2026.10.17_17-23-32--0400.xcresult`.

Earlier baseline coverage:

- Four operator scenarios cover setup, scoring, the real clock, settings warnings,
  official pauses, and Debate/Custom percent-containing names.
- Four display/layout scenarios cover rotation with merged controls, actual iPad
  window resizing, scrolling while the clock runs, and full-screen display
  exit/reopen plus backgrounding.
- Two integration scenarios exercise real Companion HTTP and remote-display
  Bonjour/WebSocket pairing, disconnects, offline scoring, and reconnection.
- Network peers run inside the simulator UI runner. They use production transports
  and do not inject app connection state. A second simulator is not required.
- Built app metadata is copied into the UI bundle through a native Copy Files
  phase, so peer version checks do not depend on source or app-container paths.
- The five UI plans use an iPad configuration; AllUI is the default. CoreRegression remains a separate
  Mac Swift Testing plan.

## User's stopped expanded run (before these repairs)

Result bundle:
`/Users/nathan/Library/Developer/Xcode/DerivedData/smartScoreboard-fqhfbijzeyhhdoafbwhkgmpxgrhc/Logs/Test/Test-smartScoreboardUITests-2026.10.17_16-28-55--0400.xcresult`.
It reports five passed and 37 failed, including one canceled case; ten of the
then-52 cases were not reached. The failures grouped into 18 stepper lookups,
10 text replacements, five template/sport reachability failures, one switch tap,
one Policy fixture mismatch, one real Debate starting-side bug, and cancellation.
All four display/layout cases and the Custom dependency case passed.

The diagnosis used the existing logs, accessibility attachments, and saved test
games. The Guest-start failure had `startingSide: guest` but
`activeChessClockSide: home`; the screenshot showed Home counting down while
Guest remained unchanged. No run was started to diagnose or repair it.

## Previous validation (before the 42-case expansion)

All **10 iPad UI tests passed together** on the dedicated iPad Pro 11-inch (M5)
simulator running iPadOS 27.0: 255.5 seconds, zero failures. The final command used
`test-without-building` from a relocated copy of the test products in a separate
working directory, without a project argument. This verifies the bundle metadata
and resources used during separate build/test execution.

The run covered event setup and text entry, scoring and real clocks, repeated
settings warning/confirmation, official pauses, Debate/Custom percent names,
portrait/landscape changes, actual iPad window resizing, scrolling, full-screen
display exit/reopen and backgrounding, Companion failure/recovery, and the complete
remote pairing/offline/reconnect/Disconnect/Connect sequence.

UIKit animations retain their normal behavior. Globally disabling them interfered
with repeated native alert interactions, so that change was removed. Empty fields
no longer receive unnecessary Select All shortcuts. Short controlled scroll drags
reveal lazy score grids without flinging past them. The app's local scoreboard
now exposes its accessibility label on a container, preserving child score and
clock labels.

All **24 core Swift Testing cases passed** after the Mac restart (6.1 seconds).
The browser checks passed earlier; the iOS app also builds as part of the UI run.
Project plist, all five test plans, shared schemes, and `git diff --check` passed.
Native Xcode enumeration confirms SmokeUI enables exactly its two intended cases.

Run from Xcode with **smartScoreboardUITests → an iPad simulator → ⌘U**. The default
`AllUI` plan enables all 53 cases; choose `FocusedUI` for eight repair checks or
`SmokeUI` for two control/display cases.
Use **smartScoreboardTests → My Mac → ⌘U** for fast direct-code checks without UI
interaction. Keep the simulator free of manual interaction during workflow tests.

Local result bundle: `/tmp/scoreboard-ipad-final.xcresult` (temporary; not committed).

The shared Cloud plans and bundle resources are prepared. No Cloud workflow has
been activated or run. After committing and pushing, select the UI scheme with an
iPad destination in the connected Cloud account and inspect the first run.

Mac window borders, Split View arrangements, physical displays,
other devices' receiver UI, RTC, and Companion TCP/UDP remain separate checks.
