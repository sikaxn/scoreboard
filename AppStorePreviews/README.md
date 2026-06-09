# App Store Previews

Generated preview PNGs live in:

- `AppStorePreviews/1.1/iPhone` at `1320 x 2868`
  - Each iPhone preview combines matching portrait and landscape screenshots on one portrait canvas.
- `AppStorePreviews/1.1/iPad` at `2752 x 2064`
- `AppStorePreviews/1.1/Mac` at `2880 x 1800`
- `AppStorePreviews/1.1/AppleTV` at `3840 x 2160`

The generator uses:

- `images/1.1/iPhone/*.PNG`
- `images/1.1/iPad/*.PNG`
- `images/1.1/Mac/*.png`
- `images/1.1/AppleTV/*.png`
- `images/1.1/Common_ext_screen.PNG` for non-Apple-TV external display previews
- Local system fonts, with Arial fallback
- Pillow

Regenerate after minor copy or layout edits:

```bash
python3 -m pip install -r AppStorePreviews/requirements.txt
python3 scripts/generate_app_store_previews.py
```

For small edits, change the text, source ordering, colors, or output names in
`PREVIEW_SPECS` inside `scripts/generate_app_store_previews.py`.
