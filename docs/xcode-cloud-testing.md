# Xcode Cloud test setup

The shared schemes and test plans are checked into the project. Xcode Cloud
workflow settings live in Xcode Cloud; adding these files does not activate a
workflow or upload the working tree.

## Plans

| Scheme | Test plan | Coverage | Suggested workflow |
| --- | --- | --- | --- |
| `smartScoreboardTests` | `CoreRegression` | All Swift Testing core, HTTP, and localization regressions | Pull requests and branch changes |
| `smartScoreboardUITests` | `SmokeUI` | Two control/display smoke scenarios | Pull requests or manual |
| `smartScoreboardUITests` | `FocusedUI` | Eight cases covering preloaded editors, Chess/Volleyball, Debate starting side/template copies, Custom editing, Soccer, and Settings warnings | Manual validation of current repairs |
| `smartScoreboardUITests` | `OperatorWorkflows` | 51 event-mode, Debate/Custom editing, settings, and display/layout cases | Nightly or manual |
| `smartScoreboardUITests` | `IntegrationRecovery` | Companion HTTP recovery and remote-client Bonjour/WebSocket recovery | Nightly or manual |
| `smartScoreboardUITests` | `AllUI` (default) | All 53 UI cases, including both network recovery cases | Full local or cloud validation |

UI plans run the target serially and enable bounded test execution. Their local
peers use real sockets in the test runner, so no external Companion installation,
receiver app, or server is required. The first cloud run must still validate
Bonjour access on the cloud simulator.

The latest full local run passed 46 of 53 cases. Its seven Debate failures shared
a navigation issue, now repaired with two focused Debate checks passing. See the
[validation handoff](ui-testing-handoff.md) for the exact scope and results. AllUI
remains the default; FocusedUI and SmokeUI provide smaller selections. Named
configurations are bundled resources, so preloading works without runtime
source-checkout access. A successful full Cloud UI run is still unverified.

## Create the workflows

After the project changes are committed and available in the connected remote
repository:

1. In Xcode, select the `smartScoreboard` app scheme, then open **Report navigator
   (⌘9) → Cloud → Get Started**. The app scheme enables Archive for initial product
   discovery. If the app already uses Xcode Cloud, edit or add a workflow in Xcode
   or App Store Connect instead.
2. Choose a cloud Xcode version compatible with the project. The local validation
   uses Xcode 27.1. Choose **macOS** for `CoreRegression`. For the UI scheme choose
   **iOS Simulator** with an **iPad** destination, such as iPad Pro or iPad mini.
   Choose iPadOS 26 or newer to include the window-resize scenario.
3. Add a **Test** action, select the scheme and the named test plan from the table,
   and choose the matching Mac or iPad simulator destination. A separate Build action is not needed
   for the same test action.
4. Configure start conditions: pull requests for core tests, and a schedule or
   manual start for the longer UI plans. Run the first UI build manually and
   inspect its results before marking that action **Required To Pass**.

Use core regressions for fast checks without UI interactions, and `SmokeUI` for
a smaller UI check. Choose `AllUI` when a single UI action should run the complete suite. Choose the
two smaller plans when the workflow should report operator and network recovery
results separately. Each test action builds and executes its own test products.

Apple documents [test action configuration](https://developer.apple.com/documentation/xcode/configuring-your-xcode-cloud-workflow-s-actions)
and [organizing tests with test plans](https://developer.apple.com/documentation/xcode/organizing-tests-to-improve-feedback).

## A build error before any UI tests run

Errors about `Environment`'s generic `Value` or an unresolved key path at
`toolbarVerticalEdge` occur while compiling the iOS app, before UI tests launch.
The macOS core action does not compile that iOS-only view, so it can pass while
the iOS action fails. WebRTC Sendable warnings are separate from this error.

The 27.1 toolbar and reserved-region code now requires the verified SwiftUICore
SDK module version `8.0.85.29`, in addition to its compiler and runtime checks.
The toolbar environment key path and its optional `HorizontalEdge` type are also
explicit. Older SDK modules compile the existing layout fallback. A Swift
compiler version check alone does not establish that an SDK contains an API.
Focused compile checks passed for arm64/x86_64 simulator targets and for a forced
fallback branch; no full app build or UI suite was run for this compatibility fix.

Inspect the failing build's own environment and SDK path in its logs. The current
workflow editor can show settings saved after that build started. An iOS 27.0
simulator destination is a runtime choice and does not by itself explain an SDK
compile error. Commit and push the compatibility change, save the workflow, and
start a new build on that commit; existing failed builds retain their old results.

## Cloud execution and resources

Xcode Cloud separates `build-for-testing` from `test-without-building`; the source
checkout is unavailable during test execution. The core target copies the actual
`Localizable.xcstrings` catalog into its test bundle using a native Copy Files
build phase. The test loads that resource through `Bundle`, with no source-path
fallback. A separate native Copy Files phase bundles the built app's Info.plist as UI
peer compatibility metadata. This also works when the iOS app and UI runner are
installed in separate simulator containers.

To reproduce the cloud's two-phase execution locally:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build-for-testing \
  -project smartScoreboard/smartScoreboard.xcodeproj \
  -scheme smartScoreboardUITests -testPlan AllUI \
  -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5),OS=27.0' \
  -derivedDataPath /tmp/scoreboard-cloud-ui

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test-without-building \
  -project smartScoreboard/smartScoreboard.xcodeproj \
  -scheme smartScoreboardUITests -testPlan AllUI \
  -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5),OS=27.0' \
  -derivedDataPath /tmp/scoreboard-cloud-ui
```

Use the project's normal signing configuration locally and in Xcode Cloud.
Approve any local macOS signing-key or developer-tools prompts interactively.
No custom CI shell scripts are needed.

The app declares its Bonjour services and local network usage in its Info.plist.
The Xcode-generated simulator runner hosts the HTTP/WebSocket peers itself, so
a Test action needs only one iPad simulator. A second simulated app/device is not coordinated by these
plans; receiver-app UI verification remains a separate device scenario.

## Results and coverage boundaries

Open a cloud run's test report in Xcode or App Store Connect. Failed cases retain
their app-window screenshot, accessibility hierarchy, and local-peer diagnostics
in the result bundle. Local and cloud UI runs use the selected iPad simulator. The core
scheme continues to use a Mac test process without UI automation.

Physical AirPlay/external displays, native Mac windows, Split View arrangements, actual production equipment, other devices' own UIs, RTC negotiation,
and Companion TCP/UDP need separate device validation.
See [the UI test guide](ui-testing.md) for scenario details and regression history.
