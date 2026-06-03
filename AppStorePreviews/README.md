# App Store Previews

Generated preview PNGs live in:

- `AppStorePreviews/iPad` at `2732 x 2048`
- `AppStorePreviews/Mac` at `2880 x 1800`

The generator uses:

- `images/iPad/*.PNG`
- `images/mac/*.png`
- Local system fonts, with Arial fallback
- Pillow

Regenerate after minor copy or layout edits:

```bash
python3 -m pip install -r AppStorePreviews/requirements.txt
python3 scripts/generate_app_store_previews.py
```

For small edits, change the text, source ordering, colors, or output names in
`IPAD_SPECS` and `MAC_SPECS` inside `scripts/generate_app_store_previews.py`.
