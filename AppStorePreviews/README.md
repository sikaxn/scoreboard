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
