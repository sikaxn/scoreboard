# App Store Previews

Version 1.6 captures and previews use English and Simplified Chinese:

| Family | Preview size |
| --- | --- |
| iPhone | 1284 × 2778, portrait and landscape combined |
| iPhoneDuo/Folded | 1398 × 2034, native outer display |
| iPhoneDuo/Unfolded | 2007 × 2853, native inner display |
| iPhoneDuo/Combined | 2853 × 2007, folded and unfolded views together |
| iPad | 2752 × 2064 |
| Mac | 2880 × 1800 |
| AppleTV | 3840 × 2160 |

## Capture through Device Hub

Use Xcode 27 or later. Device Hub's CLI is `xcrun devicectl`, not a separate
`device-hub` executable. Select the installed Xcode using `DEVELOPER_DIR` rather
than changing the system developer directory. For example:

```bash
export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
python3 -m pip install -r AppStorePreviews/requirements.txt
xcrun devicectl list devices
```

Start the desired simulators in Device Hub first. This installed `devicectl`
version does not expose a boot command. The capture script deliberately does
not fall back to `simctl`: it requires a running simulator and reports CLI
errors. Physical devices are rejected before installing or applying demo data.

The complete configuration-driven workflow is:

```bash
python3 scripts/run_app_store_previews.py
```

Edit `capture-plan.json` to select devices, version, fixture, rendering delay,
and explicitly reused source families. The workflow builds once, installs the
same `.app` on each simulator, applies the fixture and screen selection,
captures both languages, copies approved reused assets, and renders previews.
Use `--app /path/to/smartScoreboard.app` to skip rebuilding.
The Duo entries explicitly select `folded` and `unfolded`. When the requested
display is inactive, the script waits up to five minutes for its pose to change
in Device Hub. This CLI can monitor hinge angles but cannot set them, so the
posture switch currently needs Device Hub; app navigation remains automatic.

Build the current branch once; use the printed app path for each capture command
and install that same app bundle on every simulator:

```bash
python3 scripts/run_app_store_previews.py --build-only

python3 scripts/capture_app_store_previews.py --version 1.6 \
  --device 'iPhone 18 Pro Max' --platform iPhone \
  --app /path/printed/by/build-only/smartScoreboard.app
python3 scripts/capture_app_store_previews.py --version 1.6 \
  --device 'iPad Pro 13-inch (M5)' --platform iPad \
  --app /path/printed/by/build-only/smartScoreboard.app
python3 scripts/capture_app_store_previews.py --version 1.6 \
  --device 'iPhone Duo' --platform iPhoneDuo \
  --app /path/printed/by/build-only/smartScoreboard.app
python3 scripts/capture_app_store_previews.py --version 1.6 \
  --device 'iPhone Duo' --platform iPhoneDuo --duo-state unfolded \
  --app /path/printed/by/build-only/smartScoreboard.app
```

Installation, orientation, status bar setup, launch, display discovery, and
screenshot capture all use `devicectl`. Use a simulator UDID if names are
ambiguous. Optional `--language English`, `--screen game`, and
`--settle-seconds 6` narrow captures or allow more rendering time.

`fixtures/demo.json` is the reusable capture configuration: ISA vs AISG,
67–6, Super Playoff, Simple mode, 10:00, Default theme for controls and Night
for settings. Basketball and player tracking are enabled only for rosters.
The script passes this JSON and the requested screen through launch environment
variables. The simulator Debug build reads the fixture before loading its state
and navigates directly to the requested screen. These hooks do not exist in
Release builds or on physical devices. No manual screen navigation is needed.
The Swift capture additions are commented out in the working tree. The runner
copies the Xcode project into a temporary directory and enables those marked
blocks only in that copy before building. Normal app builds keep the hooks
disabled. Use the runner's `--build-only` option to prepare an app for individual
capture commands.

`--screen merged` captures Merged View (Beta) explicitly on iPad and Duo.
The complete run includes it automatically and resets the merged-view setting
for other screens, so prior simulator settings cannot affect the layout.

Each source folder includes `capture.json` with the device, displays, commit,
locale, orientation, theme, and image size. Duo has separate folded and unfolded
output folders, each using the native display size. Folded sources are directly
under `images/<version>/<Language>/iPhoneDuo/`; unfolded sources are in its
`Unfolded/` subfolder. The script discovers display IDs on each run, since they
change after simulator restarts. `--display <unique-id>` can select a capture display;
inspect displays with `xcrun devicectl device info displays --device 'iPhone Duo'`.
An inactive inner display must be activated in Device Hub before capture.
Both sizes follow [Apple's screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications).

macOS runs natively and is not an emulator. Mac and Apple TV assets can be
reused explicitly when appropriate; record the source and reason in
`images/<version>/reused-assets.json`. The 1.6 set reuses the 1.2 Mac, Apple TV,
and common external scoreboard assets. `images/demo_obs.png` remains the shared
OBS output example. Reused assets are not represented as new branch captures.

## Render previews

```bash
python3 scripts/generate_app_store_previews.py --version 1.6
python3 scripts/generate_app_store_previews.py --version 1.6 --platform iPhoneDuo
python3 scripts/generate_app_store_previews.py --version 1.6 --platform iPhoneDuoUnfolded
python3 scripts/generate_app_store_previews.py --version 1.6 --platform iPhoneDuoCombined
```

Once both Duo captures exist, the normal renderer also generates six combined
store previews plus Merged View per language in `iPhoneDuo/Combined/`. Each pairs the same app
screen on the unfolded inner display and folded outer display, preserves both
complete screenshots, and labels each posture.

Sources live in `images/<version>/<Language>/<Family>/` and outputs in
`AppStorePreviews/<version>/<Language>/<Family>/`. Capture filenames match
preview names; standard iPhone sources append `-portrait` or `-landscape`.
The generator prefers these semantic names, with legacy filename compatibility
for historical sets. Missing inputs fail before rendering a language's output.

Copy, ordering, colors, and existing layouts remain in `PREVIEW_SPECS` and
`CHINESE_PREVIEW_SPECS` in `scripts/generate_app_store_previews.py`.
