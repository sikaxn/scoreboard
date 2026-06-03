#!/usr/bin/env python3
"""Generate App Store preview screenshots from the project images folder.

Requirements:
    python3 -m pip install pillow

Run from the repository root:
    python3 scripts/generate_app_store_previews.py

Edit IPAD_SPECS and MAC_SPECS below for small copy, color, or ordering changes.
The script uses the existing images/iPad and images/mac screenshots as source
assets and writes final PNGs into AppStorePreviews/.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont, ImageOps


IPAD_SIZE = (2732, 2048)
MAC_SIZE = (2880, 1800)

WHITE = (249, 250, 255)
MUTED = (188, 199, 218)
BLUE = (62, 133, 255)
CYAN = (37, 184, 235)
ORANGE = (255, 126, 27)
GREEN = (92, 196, 96)
RED = (238, 76, 66)
BORDER = (95, 111, 145)

FONT_PATHS = {
    "heavy": [
        "/Library/Fonts/SF-Pro-Rounded-Heavy.otf",
        "/System/Library/Fonts/SFNSRounded.ttf",
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    ],
    "bold": [
        "/Library/Fonts/SF-Pro-Rounded-Bold.otf",
        "/Library/Fonts/SF-Pro-Display-Bold.otf",
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    ],
    "semi": [
        "/Library/Fonts/SF-Pro-Rounded-Semibold.otf",
        "/Library/Fonts/SF-Pro-Display-Semibold.otf",
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    ],
    "regular": [
        "/Library/Fonts/SF-Pro-Rounded-Regular.otf",
        "/Library/Fonts/SF-Pro-Display-Regular.otf",
        "/System/Library/Fonts/Supplemental/Arial.ttf",
    ],
}


@dataclass(frozen=True)
class PreviewSpec:
    source: str
    output: str
    headline: str
    subhead: str
    left_accent: tuple[int, int, int]
    right_accent: tuple[int, int, int]


IPAD_SPECS = [
    PreviewSpec(
        "images/iPad/IMG_1820.PNG",
        "ipad-01-public-scoreboard.png",
        "Show a clean public scoreboard",
        "Keep the presentation visible while you run the game privately.",
        ORANGE,
        CYAN,
    ),
    PreviewSpec(
        "images/iPad/IMG_1821.PNG",
        "ipad-02-control-board.png",
        "Control scores, clocks, and shots",
        "Basketball-ready controls keep every period moving.",
        ORANGE,
        BLUE,
    ),
    PreviewSpec(
        "images/iPad/IMG_1823.PNG",
        "ipad-03-game-setup.png",
        "Pick a sport and start fast",
        "Use presets for basketball, soccer, hockey, chess, debate, and more.",
        BLUE,
        ORANGE,
    ),
    PreviewSpec(
        "images/iPad/IMG_1825.PNG",
        "ipad-04-players-fouls.png",
        "Track players and fouls",
        "Manage rosters, active lineups, and player details from one place.",
        RED,
        GREEN,
    ),
    PreviewSpec(
        "images/iPad/IMG_1827.PNG",
        "ipad-05-game-logs.png",
        "Review every game run",
        "Audit sessions, score changes, and exported event logs stay organized.",
        BLUE,
        RED,
    ),
]

MAC_SPECS = [
    PreviewSpec(
        "mac:12.47.26",
        "mac-01-control-board.png",
        "A Mac control board for every game",
        "Score, clock, shot clock, period, and player tools in one workspace.",
        RED,
        BLUE,
    ),
    PreviewSpec(
        "mac:12.47.29",
        "mac-02-public-scoreboard.png",
        "Open a presentation-ready scoreboard",
        "Give spectators a clean public board while controls stay private.",
        BLUE,
        ORANGE,
    ),
    PreviewSpec(
        "mac:12.47.40",
        "mac-03-setup-tools.png",
        "Set up teams, sports, and timers",
        "Choose presets or customize the rules before the opening whistle.",
        BLUE,
        GREEN,
    ),
]


def load_font(kind: str, size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for path in FONT_PATHS[kind]:
        if Path(path).exists():
            return ImageFont.truetype(path, size=size)
    return ImageFont.load_default(size=size)


FONTS = {
    "headline_ipad": load_font("heavy", 110),
    "headline_mac": load_font("heavy", 94),
    "sub": load_font("bold", 46),
    "label": load_font("semi", 30),
}


def cover_resize(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    width, height = image.size
    target_width, target_height = size
    scale = max(target_width / width, target_height / height)
    resized = image.resize(
        (round(width * scale), round(height * scale)),
        Image.Resampling.LANCZOS,
    )
    left = (resized.width - target_width) // 2
    top = (resized.height - target_height) // 2
    return resized.crop((left, top, left + target_width, top + target_height))


def fit_resize(image: Image.Image, max_size: tuple[int, int]) -> Image.Image:
    scale = min(max_size[0] / image.width, max_size[1] / image.height)
    return image.resize(
        (round(image.width * scale), round(image.height * scale)),
        Image.Resampling.LANCZOS,
    )


def trim_dark_border(image: Image.Image, threshold: int = 18, padding: int = 8) -> Image.Image:
    """Remove captured black desktop padding while preserving dark app UI."""
    gray = ImageOps.grayscale(image)
    mask = gray.point(lambda value: 255 if value > threshold else 0)
    bbox = mask.getbbox()
    if bbox is None:
        return image

    left, top, right, bottom = bbox
    if left == 0 and top == 0 and right == image.width and bottom == image.height:
        return image

    left = max(0, left - padding)
    top = max(0, top - padding)
    right = min(image.width, right + padding)
    bottom = min(image.height, bottom + padding)
    return image.crop((left, top, right, bottom))


def rounded_image(image: Image.Image, radius: int) -> Image.Image:
    image = image.convert("RGBA")
    mask = Image.new("L", image.size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle(
        [0, 0, image.width - 1, image.height - 1],
        radius=radius,
        fill=255,
    )
    result = Image.new("RGBA", image.size, (0, 0, 0, 0))
    result.alpha_composite(image)
    result.putalpha(mask)
    return result


def paste_shadowed(
    base: Image.Image,
    image: Image.Image,
    xy: tuple[int, int],
    *,
    radius: int,
    shadow_blur: int,
    shadow_alpha: int,
) -> None:
    x, y = xy
    image = rounded_image(image, radius)
    padding = shadow_blur * 2

    shadow_mask = Image.new(
        "L",
        (image.width + padding * 2, image.height + padding * 2),
        0,
    )
    shadow_draw = ImageDraw.Draw(shadow_mask)
    shadow_draw.rounded_rectangle(
        [
            padding,
            padding,
            padding + image.width - 1,
            padding + image.height - 1,
        ],
        radius=radius,
        fill=shadow_alpha,
    )
    shadow_mask = shadow_mask.filter(ImageFilter.GaussianBlur(shadow_blur))
    shadow = Image.new("RGBA", shadow_mask.size, (0, 0, 0, 0))
    shadow.putalpha(shadow_mask)
    base.alpha_composite(shadow, (x - padding, y - padding))

    border = Image.new("RGBA", (image.width + 8, image.height + 8), (0, 0, 0, 0))
    border_draw = ImageDraw.Draw(border)
    border_draw.rounded_rectangle(
        [0, 0, border.width - 1, border.height - 1],
        radius=radius + 4,
        outline=(*BORDER, 120),
        width=4,
    )
    base.alpha_composite(border, (x - 4, y - 4))
    base.alpha_composite(image, (x, y))


def text_size(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.ImageFont) -> tuple[int, int]:
    bbox = draw.textbbox((0, 0), text, font=font)
    return bbox[2] - bbox[0], bbox[3] - bbox[1]


def wrap_text(
    draw: ImageDraw.ImageDraw,
    text: str,
    font: ImageFont.ImageFont,
    max_width: int,
) -> list[str]:
    words = text.split()
    lines: list[str] = []
    line = ""
    for word in words:
        candidate = word if not line else f"{line} {word}"
        if text_size(draw, candidate, font)[0] <= max_width or not line:
            line = candidate
        else:
            lines.append(line)
            line = word
    if line:
        lines.append(line)
    return lines


def add_color_wash(
    base: Image.Image,
    left_accent: tuple[int, int, int],
    right_accent: tuple[int, int, int],
) -> None:
    width, height = base.size
    wash = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(wash)
    for y in range(height):
        t = y / max(height - 1, 1)
        left_alpha = round(78 * (1 - t) + 30)
        right_alpha = round(34 * (1 - t) + 78)
        draw.line([(0, y), (width // 2, y)], fill=(*left_accent, left_alpha))
        draw.line([(width // 2, y), (width, y)], fill=(*right_accent, right_alpha))
    base.alpha_composite(wash)


def make_canvas(
    source: Path,
    size: tuple[int, int],
    left_accent: tuple[int, int, int],
    right_accent: tuple[int, int, int],
) -> tuple[Image.Image, Image.Image]:
    screenshot = trim_dark_border(Image.open(source).convert("RGB"))
    background = cover_resize(screenshot, size).filter(ImageFilter.GaussianBlur(42))
    background = ImageEnhance.Contrast(background).enhance(0.82)
    base = background.convert("RGBA")
    base.alpha_composite(Image.new("RGBA", size, (3, 5, 10, 184)))
    add_color_wash(base, left_accent, right_accent)
    return base, screenshot


def draw_text_block(
    draw: ImageDraw.ImageDraw,
    xy: tuple[int, int],
    label: str,
    headline: str,
    subhead: str,
    accent: tuple[int, int, int],
    *,
    max_width: int,
    headline_font: ImageFont.ImageFont,
) -> None:
    x, y = xy
    label_text = label.upper()
    label_width = text_size(draw, label_text, FONTS["label"])[0] + 56
    draw.rounded_rectangle(
        [x, y, x + label_width, y + 58],
        radius=29,
        fill=(20, 26, 38, 210),
        outline=(*accent, 170),
        width=2,
    )
    draw.text((x + 28, y + 15), label_text, font=FONTS["label"], fill=(*accent, 255))
    y += 82

    for line in wrap_text(draw, headline, headline_font, max_width)[:2]:
        draw.text((x + 5, y + 6), line, font=headline_font, fill=(0, 0, 0, 160))
        draw.text((x, y), line, font=headline_font, fill=WHITE)
        y += round(headline_font.size * 1.08)

    y += 16
    draw.rounded_rectangle([x, y, x + 186, y + 14], radius=7, fill=(*accent, 255))
    y += 42

    for line in wrap_text(draw, subhead, FONTS["sub"], max_width)[:2]:
        draw.text((x, y), line, font=FONTS["sub"], fill=MUTED)
        y += round(FONTS["sub"].size * 1.18)


def resolve_source(root: Path, source: str) -> Path:
    if source.startswith("mac:"):
        token = source.split(":", 1)[1]
        matches = sorted((root / "images" / "mac").glob(f"*{token}*.png"))
        if not matches:
            raise FileNotFoundError(f"No Mac screenshot matching {token}")
        return matches[0]
    return root / source


def make_ipad_preview(root: Path, output_dir: Path, spec: PreviewSpec) -> Path:
    base, screenshot = make_canvas(
        resolve_source(root, spec.source),
        IPAD_SIZE,
        spec.left_accent,
        spec.right_accent,
    )
    draw = ImageDraw.Draw(base)
    draw_text_block(
        draw,
        (124, 100),
        "Smart Scoreboard",
        spec.headline,
        spec.subhead,
        spec.left_accent,
        max_width=1960,
        headline_font=FONTS["headline_ipad"],
    )

    is_wide = screenshot.width / screenshot.height > 1.65
    foreground = fit_resize(screenshot, (2420 if is_wide else 2210, 1270 if is_wide else 1450))
    x = (IPAD_SIZE[0] - foreground.width) // 2
    y = 600 if is_wide else 485
    y = min(y, IPAD_SIZE[1] - foreground.height - 95)
    paste_shadowed(base, foreground, (x, y), radius=52, shadow_blur=68, shadow_alpha=185)

    output = output_dir / spec.output
    output.parent.mkdir(parents=True, exist_ok=True)
    base.convert("RGB").save(output, "PNG")
    return output


def make_mac_preview(root: Path, output_dir: Path, spec: PreviewSpec) -> Path:
    base, screenshot = make_canvas(
        resolve_source(root, spec.source),
        MAC_SIZE,
        spec.left_accent,
        spec.right_accent,
    )
    draw = ImageDraw.Draw(base)
    draw_text_block(
        draw,
        (138, 92),
        "Smart Scoreboard",
        spec.headline,
        spec.subhead,
        spec.left_accent,
        max_width=2200,
        headline_font=FONTS["headline_mac"],
    )

    foreground = fit_resize(screenshot, (2380, 1190))
    x = (MAC_SIZE[0] - foreground.width) // 2
    y = min(545, MAC_SIZE[1] - foreground.height - 86)
    paste_shadowed(base, foreground, (x, y), radius=42, shadow_blur=72, shadow_alpha=190)

    output = output_dir / spec.output
    output.parent.mkdir(parents=True, exist_ok=True)
    base.convert("RGB").save(output, "PNG")
    return output


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path.cwd(), help="Repository root.")
    parser.add_argument("--out", type=Path, default=Path("AppStorePreviews"), help="Output directory.")
    args = parser.parse_args()

    root = args.root.resolve()
    output_root = args.out if args.out.is_absolute() else root / args.out
    generated: list[Path] = []

    for spec in IPAD_SPECS:
        generated.append(make_ipad_preview(root, output_root / "iPad", spec))
    for spec in MAC_SPECS:
        generated.append(make_mac_preview(root, output_root / "Mac", spec))

    for path in generated:
        size = Image.open(path).size
        print(f"{path.relative_to(root)} {size[0]}x{size[1]}")


if __name__ == "__main__":
    main()
