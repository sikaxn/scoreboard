# App Store Previews

Generated preview PNGs live in localized folders:

- `AppStorePreviews/1.1/English/iPhone` at `1284 x 2778`
- `AppStorePreviews/1.1/Chinese/iPhone` at `1284 x 2778`
  - Each iPhone preview combines matching portrait and landscape screenshots on one portrait canvas.
- `AppStorePreviews/1.1/English/iPad` and `AppStorePreviews/1.1/Chinese/iPad` at `2752 x 2064`
- `AppStorePreviews/1.1/English/Mac` and `AppStorePreviews/1.1/Chinese/Mac` at `2880 x 1800`
- `AppStorePreviews/1.1/English/AppleTV` and `AppStorePreviews/1.1/Chinese/AppleTV` at `3840 x 2160`

The generator uses:

- `images/1.1/English/iPhone/*.PNG`
- `images/1.1/English/iPad/*.PNG`
- `images/1.1/English/Mac/*.png`
- `images/1.1/English/AppleTV/*.png`
- `images/1.1/English/Common_ext_screen.PNG` for non-Apple-TV external display previews
- `images/1.1/Chinese/iPhone/*.PNG`
- `images/1.1/Chinese/iPad/*.PNG`
- `images/1.1/Chinese/Mac/*.png`
- `images/1.1/Chinese/AppleTV/*.png`
- `images/1.1/Chinese/Common_ext_screen.png` for non-Apple-TV external display previews
- Local system fonts, with Arial fallback
- Pillow

Regenerate after minor copy or layout edits:

```bash
python3 -m pip install -r AppStorePreviews/requirements.txt
python3 scripts/generate_app_store_previews.py
```

Generate one language only:

```bash
python3 scripts/generate_app_store_previews.py --language English
python3 scripts/generate_app_store_previews.py --language Chinese
```

For small edits, change the text, source ordering, colors, or output names in
`PREVIEW_SPECS` or `CHINESE_PREVIEW_SPECS` inside
`scripts/generate_app_store_previews.py`.

## Future Screenshot Capture Prompt

Use this prompt when capturing a new source screenshot set:

```text
I need you to capture new source screenshots for App Store preview generation for Smart Scoreboard.

Do not redesign preview images. Do not change app code or the preview generator script. Run the app, capture clean source screenshots, copy them into the existing screenshot source folder structure, then run the existing preview generator.

Before starting:
- If the screenshot version folder is unclear, ask me which version to use, for example `1.1`, `1.2`, etc.
- Use the folder structure:
  - `images/<version>/English/`
  - `images/<version>/Chinese/`
- Use English and Simplified Chinese app/localization screenshots.
- For Chinese, run the app/simulator in Simplified Chinese if needed.
- Use realistic demo data:
  - Team Home: ISA
  - Home score: 67
  - Guest: AISG
  - Guest score: 6
  - Event Name: Super Playoff
  - Filename in Library: DEMO
  - Mode: Simple
  - Timer: 10:00
  - Control board screenshot theme: Default
  - Settings screenshots theme: Night
- When roster screenshots are needed, switch sport to Basketball only for the roster settings screenshots.
- If needed, go to Settings > About and factory default the app.
- Do not use simulator external-display screenshots for `Common_ext_screen`.
- Instead, use the clean Apple TV live scoreboard screenshot as the shared `Common_ext_screen` source for iPhone, iPad, and Mac preview generation.
- Do not use `Common_ext_screen` for Apple TV previews.

Target platforms:
- macOS: run the Mac app target directly. macOS does not use Simulator.
- iPadOS: use an iPad simulator.
- iOS: use an iPhone simulator.
- Apple TV: use an Apple TV simulator.
- For Apple TV live scoreboard, pair an iOS/iPadOS operator simulator with the Apple TV simulator if needed.

Screenshots needed for each language:

iPadOS, save to `images/<version>/<Language>/iPad/`
Capture landscape screenshots for:
1. Main live control board
2. Display modes / public display controls
3. Game setup / sport and team setup
4. Integrations screen showing Remote Display, Web API, and Bitfocus Companion
5. Remote Display pairing screen
6. Players / roster settings screen

iOS, save to `images/<version>/<Language>/iPhone/`
Capture both portrait and landscape for:
1. Main live control board
2. Display modes / public display controls
3. Game setup / sport and team setup
4. Integrations screen
5. Remote Display pairing screen
6. Players / roster settings screen

Shared external scoreboard:
- Capture or reuse the clean Apple TV live scoreboard screenshot.
- Save/copy it as `images/<version>/<Language>/Common_ext_screen.png` or `.PNG`.
- This should be the clean public scoreboard / display-only view, not operator controls.
- Use this for iPhone/iPad/Mac preview generation.
- Do not use this common external screenshot for Apple TV.

macOS, save to `images/<version>/<Language>/Mac/`
Capture screenshots for:
1. Main live control board
2. Display modes / public display controls
3. Game setup / sport and team setup
4. Clean public scoreboard window/view
5. Integrations screen showing Remote Display, Web API, and Bitfocus Companion
6. Remote Display pairing screen
7. Players / roster settings screen

Apple TV, save to `images/<version>/<Language>/AppleTV/`
Capture screenshots for:
1. Remote Display pairing screen
2. Live display-only scoreboard

File naming examples:
- iPad: `ipad-01-control-board.png`, `ipad-02-display-modes.png`
- iPhone: `iphone-01-control-board-portrait.png`, `iphone-01-control-board-landscape.png`
- Mac: `mac-01-control-board.png`
- Apple TV: `appletv-01-pairing.png`, `appletv-02-live-scoreboard.png`

After capturing:
1. Copy the new clear filenames to any legacy filenames expected by the existing preview generator.
2. Run `python3 scripts/generate_app_store_previews.py`.
3. If `images/demo_obs.png` exists, the preview generator should add it to the generated integration preview image for iPhone, iPad, and Mac in each language.
   - Use it only on the related integration preview images, not Apple TV.
   - Trim a small border from the OBS screenshot before placing it.
   - Crop nonessential lower OBS controls when useful, so the scoreboard output area can be shown larger.
   - Keep enough OBS chrome/controls visible to make the image read as an integration/output example.
   - Present it as a separate, clearly labeled output/integration example, not as Smart Scoreboard app UI.
   - Use labels such as `OUTPUT EXAMPLE` / `OBS output from Web API` in English and `输出示例` / `OBS / Web API 输出` in Simplified Chinese.
   - For the iPhone integration preview, show both portrait and landscape app screenshots plus the OBS output example. Keep the portrait screenshot primary and make the landscape screenshot smaller.
4. Verify generated output dimensions:
   - iPhone: `1284 x 2778`
   - iPad: `2752 x 2064`
   - Mac: `2880 x 1800`
   - Apple TV: `3840 x 2160`
5. Report:
   - Final source files created
   - Final generated preview files created
   - Any screenshots that could not be captured
   - Any issues encountered and exactly how you worked around them
   - Whether any existing source files were reused, especially `Common_ext_screen`
   - Confirm whether code/scripts were changed or not

Important:
- Keep screenshots clean and uncropped.
- Avoid blank/default empty states unless the screenshot is specifically the pairing screen.
- Avoid random desktop clutter.
- Do not change my code.
```
