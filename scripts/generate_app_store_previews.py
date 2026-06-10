#!/usr/bin/env python3
"""Generate App Store preview screenshots from the project images folder.

Requirements:
    python3 -m pip install -r AppStorePreviews/requirements.txt

Run from the repository root:
    python3 scripts/generate_app_store_previews.py

The default output is AppStorePreviews/1.1/English and
AppStorePreviews/1.1/Chinese. Edit PREVIEW_SPECS below for English, or
CHINESE_PREVIEW_SPECS for Chinese, to make small copy, color, ordering, or
source screenshot changes.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont, ImageOps


DEFAULT_VERSION = "1.1"
BRAND_LABEL = "Smart Scoreboard"
BRAND_LABELS = {
    "English": "Smart Scoreboard",
    "Chinese": "Smart Scoreboard",
}
SUPPORTED_LANGUAGES = tuple(BRAND_LABELS)

# Highest accepted screenshot sizes used here:
# iPhone from the requested App Store size list, iPad 13", Mac, and Apple TV.
PLATFORM_SIZES = {
    "iPhone": (1284, 2778),
    "iPad": (2752, 2064),
    "Mac": (2880, 1800),
    "AppleTV": (3840, 2160),
}

WHITE = (249, 250, 255)
MUTED = (196, 205, 222)
BLUE = (62, 133, 255)
CYAN = (37, 184, 235)
ORANGE = (255, 126, 27)
GREEN = (92, 196, 96)
RED = (238, 76, 66)
PURPLE = (144, 104, 255)
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
}

CHINESE_FONT_PATHS = {
    "heavy": [
        "/System/Library/Fonts/STHeiti Medium.ttc",
        "/System/Library/Fonts/Hiragino Sans GB.ttc",
        "/System/Library/Fonts/Supplemental/Arial Unicode.ttf",
    ],
    "bold": [
        "/System/Library/Fonts/STHeiti Medium.ttc",
        "/System/Library/Fonts/Hiragino Sans GB.ttc",
        "/System/Library/Fonts/Supplemental/Arial Unicode.ttf",
    ],
    "semi": [
        "/System/Library/Fonts/STHeiti Medium.ttc",
        "/System/Library/Fonts/Hiragino Sans GB.ttc",
        "/System/Library/Fonts/Supplemental/Arial Unicode.ttf",
    ],
}


@dataclass(frozen=True)
class TextProfile:
    headline_size: int
    subhead_size: int
    label_size: int
    margin_x: int
    margin_y: int
    max_text_width: int
    image_top: int
    image_margin_x: int
    image_margin_bottom: int
    image_radius: int
    shadow_blur: int
    shadow_alpha: int
    mode: str = "framed"


@dataclass(frozen=True)
class PreviewSpec:
    platform: str
    source: str
    output: str
    headline: str
    subhead: str
    left_accent: tuple[int, int, int]
    right_accent: tuple[int, int, int]
    trim_dark_border: bool = False
    mode: str | None = None
    secondary_source: str | None = None


PROFILES = {
    "iPad": TextProfile(
        headline_size=108,
        subhead_size=45,
        label_size=30,
        margin_x=124,
        margin_y=100,
        max_text_width=2150,
        image_top=520,
        image_margin_x=185,
        image_margin_bottom=100,
        image_radius=52,
        shadow_blur=68,
        shadow_alpha=185,
    ),
    "Mac": TextProfile(
        headline_size=94,
        subhead_size=44,
        label_size=30,
        margin_x=138,
        margin_y=92,
        max_text_width=2300,
        image_top=465,
        image_margin_x=290,
        image_margin_bottom=84,
        image_radius=42,
        shadow_blur=72,
        shadow_alpha=190,
    ),
    "iPhone": TextProfile(
        headline_size=66,
        subhead_size=31,
        label_size=23,
        margin_x=70,
        margin_y=74,
        max_text_width=1088,
        image_top=565,
        image_margin_x=120,
        image_margin_bottom=95,
        image_radius=64,
        shadow_blur=48,
        shadow_alpha=165,
    ),
    "AppleTV": TextProfile(
        headline_size=126,
        subhead_size=58,
        label_size=38,
        margin_x=160,
        margin_y=122,
        max_text_width=2920,
        image_top=610,
        image_margin_x=360,
        image_margin_bottom=120,
        image_radius=54,
        shadow_blur=82,
        shadow_alpha=190,
    ),
}


PREVIEW_SPECS = [
    # iPad 13" landscape, 2752 x 2064.
    PreviewSpec(
        "iPad",
        "iPad/IMG_1844.PNG",
        "ipad-01-control-board.png",
        "Run the full game from iPad",
        "Scores, clocks, shots, periods, and player controls stay ready.",
        ORANGE,
        BLUE,
    ),
    PreviewSpec(
        "iPad",
        "iPad/IMG_1845.PNG",
        "ipad-02-display-modes.png",
        "Choose what the crowd sees",
        "Switch between scoreboard, black screen, team view, player view, event logo, and backgrounds.",
        GREEN,
        ORANGE,
    ),
    PreviewSpec(
        "iPad",
        "iPad/IMG_1846.PNG",
        "ipad-03-game-setup.png",
        "Set up sports and teams fast",
        "Presets, event names, teams, and timers are ready before kickoff.",
        BLUE,
        GREEN,
    ),
    PreviewSpec(
        "iPad",
        "iPad/IMG_1847.PNG",
        "ipad-04-integrations.png",
        "Connect displays and production tools",
        "Remote Display, Web API, and Bitfocus Companion fit into one workflow.",
        BLUE,
        PURPLE,
    ),
    PreviewSpec(
        "iPad",
        "iPad/IMG_1848.PNG",
        "ipad-05-remote-display.png",
        "Pair a nearby remote display",
        "Send the live scoreboard to Apple TV, iPhone, iPad, or Mac.",
        ORANGE,
        RED,
    ),
    PreviewSpec(
        "iPad",
        "iPad/IMG_1849.PNG",
        "ipad-06-rosters.png",
        "Import rosters and track players",
        "Use CSV import/export with active lineups, player fouls, and substitutions.",
        RED,
        CYAN,
    ),
    PreviewSpec(
        "iPad",
        "Common_ext_screen.PNG",
        "ipad-07-common-external-scoreboard.png",
        "Show a clean external scoreboard",
        "Use a shared public display from iPad, Mac, or iPhone when the room needs it.",
        ORANGE,
        CYAN,
    ),
    # iPhone portrait, 1284 x 2778. Most combine portrait and landscape.
    PreviewSpec(
        "iPhone",
        "iPhone/IMG_0921.PNG",
        "iphone-01-control-board.png",
        "iPhone control in both orientations",
        "Use portrait for quick checks or landscape for a wider game board.",
        ORANGE,
        BLUE,
        secondary_source="iPhone/IMG_0922.PNG",
    ),
    PreviewSpec(
        "iPhone",
        "iPhone/IMG_0926.PNG",
        "iphone-02-display-modes.png",
        "Switch display modes from iPhone",
        "Preview the public board and choose what spectators see.",
        GREEN,
        ORANGE,
        secondary_source="iPhone/IMG_0927.PNG",
    ),
    PreviewSpec(
        "iPhone",
        "iPhone/IMG_0928.PNG",
        "iphone-03-game-setup.png",
        "Set up games on any iPhone",
        "Pick a sport preset, name the event, and start quickly.",
        BLUE,
        GREEN,
        secondary_source="iPhone/IMG_0929.PNG",
    ),
    PreviewSpec(
        "iPhone",
        "iPhone/IMG_0930.PNG",
        "iphone-04-integrations.png",
        "Connect Remote Display and APIs",
        "Pair displays, serve web overlays, and trigger production tools.",
        BLUE,
        PURPLE,
        secondary_source="iPhone/IMG_0931.PNG",
    ),
    PreviewSpec(
        "iPhone",
        "iPhone/IMG_0932.PNG",
        "iphone-05-remote-display.png",
        "Turn iPhone into a remote display",
        "Pair it with another Scoreboard device for live scoreboard sync.",
        ORANGE,
        RED,
        secondary_source="iPhone/IMG_0934.PNG",
    ),
    PreviewSpec(
        "iPhone",
        "iPhone/IMG_0935.PNG",
        "iphone-06-rosters.png",
        "Roster tools fit on iPhone",
        "Manage roster size, active lineup, player fouls, and CSV tools.",
        RED,
        CYAN,
        secondary_source="iPhone/IMG_0936.PNG",
    ),
    PreviewSpec(
        "iPhone",
        "Common_ext_screen.PNG",
        "iphone-07-common-external-scoreboard.png",
        "Share a clean external scoreboard",
        "Run controls from iPhone while a shared public board stays visible.",
        ORANGE,
        CYAN,
        mode="iphone_external",
        secondary_source="iPhone/IMG_0921.PNG",
    ),
    # Mac, 2880 x 1800.
    PreviewSpec(
        "Mac",
        "Mac/*2.10.53*.png",
        "mac-01-control-board.png",
        "Operate every part of the game",
        "Score, clock, shot clock, period, possession, and players stay in one workspace.",
        RED,
        BLUE,
        trim_dark_border=True,
    ),
    PreviewSpec(
        "Mac",
        "Mac/*2.11.00*.png",
        "mac-02-display-modes.png",
        "Preview display modes on Mac",
        "Control what the public screen shows before the room sees it.",
        GREEN,
        ORANGE,
        trim_dark_border=True,
    ),
    PreviewSpec(
        "Mac",
        "Mac/*2.11.04*.png",
        "mac-03-game-setup.png",
        "Configure teams, sports, and events",
        "Start from presets or tune the rules before opening the board.",
        BLUE,
        GREEN,
        trim_dark_border=True,
    ),
    PreviewSpec(
        "Mac",
        "Mac/*2.11.13*.png",
        "mac-04-public-scoreboard.png",
        "Show a polished public scoreboard",
        "Present the clean board while controls stay on the operator device.",
        ORANGE,
        CYAN,
        trim_dark_border=True,
    ),
    PreviewSpec(
        "Mac",
        "Mac/*2.11.30*.png",
        "mac-05-integrations.png",
        "Connect Web API and Companion",
        "Feed overlays, OBS, automation, and production commands from live game state.",
        BLUE,
        PURPLE,
        trim_dark_border=True,
    ),
    PreviewSpec(
        "Mac",
        "Mac/*2.11.36*.png",
        "mac-06-remote-display.png",
        "Pair remote displays nearby",
        "Apple TV, iPhone, iPad, and Mac can all become synced display devices.",
        ORANGE,
        RED,
        trim_dark_border=True,
    ),
    PreviewSpec(
        "Mac",
        "Mac/*2.11.55*.png",
        "mac-07-rosters.png",
        "Manage rosters from the desktop",
        "CSV import/export and player tracking are built into the operator tools.",
        RED,
        CYAN,
        trim_dark_border=True,
    ),
    PreviewSpec(
        "Mac",
        "Common_ext_screen.PNG",
        "mac-08-common-external-scoreboard.png",
        "Share a common external display",
        "Use the same public scoreboard view across iPad, iPhone, and Mac workflows.",
        ORANGE,
        CYAN,
    ),
    # Apple TV, 3840 x 2160. Do not use Common_ext_screen.PNG for Apple TV.
    PreviewSpec(
        "AppleTV",
        "AppleTV/*02.26.47.png",
        "appletv-01-pairing.png",
        "Apple TV remote display pairing",
        "Pair once, then show the live scoreboard from a nearby Scoreboard device.",
        ORANGE,
        RED,
    ),
    PreviewSpec(
        "AppleTV",
        "AppleTV/*02.27.24.png",
        "appletv-02-live-scoreboard.png",
        "Display-only scoreboard for Apple TV",
        "Spectators see the board while controls stay on your paired device.",
        BLUE,
        ORANGE,
    ),
]


CHINESE_PREVIEW_SPECS = [
    # iPad 13" landscape, 2752 x 2064.
    PreviewSpec(
        "iPad",
        "iPad/*10.42.25*.png",
        "ipad-01-control-board.png",
        "用 iPad 掌控整场比赛",
        "比分、计时、进攻时间、节次和球员控制都在一个界面。",
        ORANGE,
        BLUE,
    ),
    PreviewSpec(
        "iPad",
        "iPad/IMG_1860.PNG",
        "ipad-02-display-modes.png",
        "决定观众看到什么",
        "快速切换记分牌、黑屏、队伍视图、球员视图、活动标志和背景。",
        GREEN,
        ORANGE,
    ),
    PreviewSpec(
        "iPad",
        "iPad/IMG_1852.PNG",
        "ipad-03-game-setup.png",
        "快速设置运动和队伍",
        "从预设开始，设置赛事、队伍和计时器。",
        BLUE,
        GREEN,
    ),
    PreviewSpec(
        "iPad",
        "iPad/IMG_1853.PNG",
        "ipad-04-integrations.png",
        "连接显示器和制作工具",
        "远程显示、Web API 和 Bitfocus Companion 集成在一个流程中。",
        BLUE,
        PURPLE,
    ),
    PreviewSpec(
        "iPad",
        "iPad/IMG_1855.PNG",
        "ipad-05-remote-display.png",
        "配对附近的远程显示",
        "将实时记分牌发送到 Apple TV、iPhone、iPad 或 Mac。",
        ORANGE,
        RED,
    ),
    PreviewSpec(
        "iPad",
        "iPad/IMG_1856.PNG",
        "ipad-06-rosters.png",
        "导入名单并跟踪球员",
        "支持 CSV 导入导出、上场名单、球员犯规和换人。",
        RED,
        CYAN,
    ),
    PreviewSpec(
        "iPad",
        "Common_ext_screen.png",
        "ipad-07-common-external-scoreboard.png",
        "共享清晰的外接记分牌",
        "从 iPhone、iPad 或 Mac 控制，公共屏幕保持可见。",
        ORANGE,
        CYAN,
    ),
    # iPhone portrait, 1284 x 2778. Most combine portrait and landscape.
    PreviewSpec(
        "iPhone",
        "iPhone/IMG_0958.PNG",
        "iphone-01-control-board.png",
        "iPhone 横竖屏都能控制",
        "竖屏快速查看，横屏获得更宽的比赛面板。",
        ORANGE,
        BLUE,
        secondary_source="iPhone/IMG_0959.PNG",
    ),
    PreviewSpec(
        "iPhone",
        "iPhone/IMG_0960.PNG",
        "iphone-02-display-modes.png",
        "用 iPhone 切换显示模式",
        "预览公共记分牌，并选择观众看到的内容。",
        GREEN,
        ORANGE,
        secondary_source="iPhone/IMG_0961.PNG",
    ),
    PreviewSpec(
        "iPhone",
        "iPhone/IMG_0962.PNG",
        "iphone-03-game-setup.png",
        "在 iPhone 上设置比赛",
        "选择运动预设、命名赛事，然后快速开始。",
        BLUE,
        GREEN,
        secondary_source="iPhone/IMG_0963.PNG",
    ),
    PreviewSpec(
        "iPhone",
        "iPhone/IMG_0964.PNG",
        "iphone-04-integrations.png",
        "连接远程显示和 API",
        "配对显示设备，提供网页叠加层，并触发制作工具。",
        BLUE,
        PURPLE,
        secondary_source="iPhone/IMG_0965.PNG",
    ),
    PreviewSpec(
        "iPhone",
        "iPhone/IMG_0966.PNG",
        "iphone-05-remote-display.png",
        "把 iPhone 变成远程显示",
        "与另一台 Scoreboard 设备配对，实时同步记分牌。",
        ORANGE,
        RED,
        secondary_source="iPhone/IMG_0968.PNG",
    ),
    PreviewSpec(
        "iPhone",
        "iPhone/IMG_0969.PNG",
        "iphone-06-rosters.png",
        "球员名单工具适配 iPhone",
        "管理名单人数、上场阵容、球员犯规和 CSV 工具。",
        RED,
        CYAN,
        secondary_source="iPhone/IMG_0970.PNG",
    ),
    PreviewSpec(
        "iPhone",
        "Common_ext_screen.png",
        "iphone-07-common-external-scoreboard.png",
        "共享清晰的外接记分牌",
        "用 iPhone 操作，公共记分牌保持显示。",
        ORANGE,
        CYAN,
        mode="iphone_external",
        secondary_source="iPhone/IMG_0958.PNG",
    ),
    # Mac, 2880 x 1800.
    PreviewSpec(
        "Mac",
        "Mac/*10.36.49*.png",
        "mac-01-control-board.png",
        "在 Mac 上掌控整场比赛",
        "比分、时钟、进攻时间、节次和球员控制都在同一工作区。",
        RED,
        BLUE,
        trim_dark_border=True,
    ),
    PreviewSpec(
        "Mac",
        "Mac/*10.37.06*.png",
        "mac-02-display-modes.png",
        "在 Mac 上预览显示模式",
        "先决定公共屏幕内容，再把画面给观众。",
        GREEN,
        ORANGE,
        trim_dark_border=True,
    ),
    PreviewSpec(
        "Mac",
        "Mac/*10.38.21*.png",
        "mac-03-game-setup.png",
        "配置队伍、运动和赛事",
        "从预设开始，也可以在打开记分牌前调整规则。",
        BLUE,
        GREEN,
        trim_dark_border=True,
    ),
    PreviewSpec(
        "Mac",
        "Mac/*10.38.39*.png",
        "mac-04-public-scoreboard.png",
        "展示精致的公共记分牌",
        "观众看到清晰画面，控制保留在操作设备上。",
        ORANGE,
        CYAN,
        trim_dark_border=True,
    ),
    PreviewSpec(
        "Mac",
        "Mac/*10.38.57*.png",
        "mac-05-integrations.png",
        "连接 Web API 和 Companion",
        "将实时比赛状态送到叠加层、OBS、自动化和制作命令。",
        BLUE,
        PURPLE,
        trim_dark_border=True,
    ),
    PreviewSpec(
        "Mac",
        "Mac/*10.39.10*.png",
        "mac-06-remote-display.png",
        "配对附近的远程显示",
        "Apple TV、iPhone、iPad 和 Mac 都能成为同步显示设备。",
        ORANGE,
        RED,
        trim_dark_border=True,
    ),
    PreviewSpec(
        "Mac",
        "Mac/*10.39.26*.png",
        "mac-07-rosters.png",
        "在桌面管理球员名单",
        "CSV 导入导出和球员跟踪都内置在操作工具中。",
        RED,
        CYAN,
        trim_dark_border=True,
    ),
    PreviewSpec(
        "Mac",
        "Common_ext_screen.png",
        "mac-08-common-external-scoreboard.png",
        "共享通用外接显示",
        "iPad、iPhone 和 Mac 工作流程使用同一个公共记分牌视图。",
        ORANGE,
        CYAN,
    ),
    # Apple TV, 3840 x 2160. Do not use Common_ext_screen.png for Apple TV.
    PreviewSpec(
        "AppleTV",
        "AppleTV/*10.47.13*.png",
        "appletv-01-pairing.png",
        "Apple TV 远程显示配对",
        "配对一次，即可显示附近 Scoreboard 设备的实时记分牌。",
        ORANGE,
        RED,
    ),
    PreviewSpec(
        "AppleTV",
        "AppleTV/*10.47.23*.png",
        "appletv-02-live-scoreboard.png",
        "Apple TV 专用显示记分牌",
        "观众看到记分牌，控制保留在已配对设备上。",
        BLUE,
        ORANGE,
    ),
]

PREVIEW_SPECS_BY_LANGUAGE = {
    "English": PREVIEW_SPECS,
    "Chinese": CHINESE_PREVIEW_SPECS,
}


def load_font(
    kind: str,
    size: int,
    language: str = "English",
) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = []
    if language == "Chinese":
        candidates.extend(CHINESE_FONT_PATHS[kind])
    candidates.extend(FONT_PATHS[kind])
    for path in candidates:
        if Path(path).exists():
            return ImageFont.truetype(path, size=size)
    return ImageFont.load_default(size=size)


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
    """Remove captured desktop padding without cropping dark app UI panels."""
    gray = ImageOps.grayscale(image)
    mask = gray.point(lambda value: 255 if value > threshold else 0)
    bbox = mask.getbbox()
    if bbox is None:
        return image

    left, top, right, bottom = bbox
    if left == 0 and top == 0 and right == image.width and bottom == image.height:
        return image

    return image.crop(
        (
            max(0, left - padding),
            max(0, top - padding),
            min(image.width, right + padding),
            min(image.height, bottom + padding),
        )
    )


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
    if " " not in text:
        lines: list[str] = []
        line = ""
        for char in text:
            candidate = f"{line}{char}"
            if text_size(draw, candidate, font)[0] <= max_width or not line:
                line = candidate
            else:
                lines.append(line)
                line = char
        if line:
            lines.append(line)
        return lines

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
    alpha_boost: float = 1.0,
) -> None:
    width, height = base.size
    wash = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(wash)
    for y in range(height):
        t = y / max(height - 1, 1)
        left_alpha = round((78 * (1 - t) + 30) * alpha_boost)
        right_alpha = round((34 * (1 - t) + 78) * alpha_boost)
        draw.line([(0, y), (width // 2, y)], fill=(*left_accent, min(180, left_alpha)))
        draw.line([(width // 2, y), (width, y)], fill=(*right_accent, min(180, right_alpha)))
    base.alpha_composite(wash)


def make_canvas(
    screenshot: Image.Image,
    size: tuple[int, int],
    left_accent: tuple[int, int, int],
    right_accent: tuple[int, int, int],
) -> Image.Image:
    background = cover_resize(screenshot, size).filter(ImageFilter.GaussianBlur(42))
    background = ImageEnhance.Contrast(background).enhance(0.82)
    base = background.convert("RGBA")
    base.alpha_composite(Image.new("RGBA", size, (3, 5, 10, 184)))
    add_color_wash(base, left_accent, right_accent)
    return base


def draw_text_block(
    draw: ImageDraw.ImageDraw,
    profile: TextProfile,
    headline: str,
    subhead: str,
    accent: tuple[int, int, int],
    brand_label: str = BRAND_LABEL,
    language: str = "English",
) -> int:
    x = profile.margin_x
    y = profile.margin_y
    label_font = load_font("semi", profile.label_size, language)
    headline_font = load_font("heavy", profile.headline_size, language)
    subhead_font = load_font("bold", profile.subhead_size, language)

    label_text = brand_label.upper()
    label_height = round(profile.label_size * 1.95)
    label_width = text_size(draw, label_text, label_font)[0] + round(profile.label_size * 1.9)
    draw.rounded_rectangle(
        [x, y, x + label_width, y + label_height],
        radius=label_height // 2,
        fill=(20, 26, 38, 210),
        outline=(*accent, 170),
        width=max(2, profile.label_size // 12),
    )
    draw.text(
        (x + round(profile.label_size * 0.95), y + round(profile.label_size * 0.45)),
        label_text,
        font=label_font,
        fill=(*accent, 255),
    )
    y += label_height + round(profile.headline_size * 0.32)

    for line in wrap_text(draw, headline, headline_font, profile.max_text_width)[:2]:
        draw.text(
            (x + 5, y + 6),
            line,
            font=headline_font,
            fill=(0, 0, 0, 160),
        )
        draw.text((x, y), line, font=headline_font, fill=WHITE)
        y += round(profile.headline_size * 1.08)

    y += round(profile.headline_size * 0.13)
    underline_width = round(profile.headline_size * 1.75)
    underline_height = max(8, round(profile.headline_size * 0.12))
    draw.rounded_rectangle(
        [x, y, x + underline_width, y + underline_height],
        radius=underline_height // 2,
        fill=(*accent, 255),
    )
    y += underline_height + round(profile.headline_size * 0.22)

    for line in wrap_text(draw, subhead, subhead_font, profile.max_text_width)[:2]:
        draw.text((x, y), line, font=subhead_font, fill=MUTED)
        y += round(profile.subhead_size * 1.2)

    return y


def add_fullbleed_scrim(
    base: Image.Image,
    left_accent: tuple[int, int, int],
    right_accent: tuple[int, int, int],
) -> None:
    width, height = base.size
    scrim = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(scrim)
    for x in range(width):
        t = x / max(width - 1, 1)
        alpha = round(185 * (1 - min(1, t * 1.45)))
        draw.line([(x, 0), (x, height)], fill=(0, 0, 0, max(20, alpha)))
    for y in range(height):
        t = y / max(height - 1, 1)
        alpha = round(130 * (1 - t))
        draw.line([(0, y), (width, y)], fill=(0, 0, 0, max(0, alpha)))
    base.alpha_composite(scrim)
    add_color_wash(base, left_accent, right_accent, alpha_boost=0.45)


def resolve_source(root: Path, version: str, language: str, source: str) -> Path:
    source_root = root / "images" / version / language
    matches = sorted(source_root.glob(source))
    if matches:
        return matches[0]

    exact = source_root / source
    if exact.exists():
        return exact

    raise FileNotFoundError(f"No source image matching {source!r} under {source_root}")


def platform_output_dir(output_root: Path, platform: str) -> Path:
    names = {
        "iPhone": "iPhone",
        "iPad": "iPad",
        "Mac": "Mac",
        "AppleTV": "AppleTV",
    }
    return output_root / names[platform]


def render_iphone_combined(
    root: Path,
    version: str,
    output_root: Path,
    spec: PreviewSpec,
    language: str,
) -> Path:
    if spec.secondary_source is None:
        raise ValueError(f"{spec.output} needs a secondary landscape iPhone source")

    size = PLATFORM_SIZES["iPhone"]
    profile = PROFILES["iPhone"]
    portrait = Image.open(resolve_source(root, version, language, spec.source)).convert("RGB")
    landscape = Image.open(resolve_source(root, version, language, spec.secondary_source)).convert("RGB")

    base = make_canvas(portrait, size, spec.left_accent, spec.right_accent)
    draw = ImageDraw.Draw(base)
    text_bottom = draw_text_block(
        draw,
        profile,
        spec.headline,
        spec.subhead,
        spec.left_accent,
        BRAND_LABELS[language],
        language,
    )

    landscape_top = max(profile.image_top, text_bottom + 58)
    landscape_frame = fit_resize(landscape, (1080, 520))
    landscape_x = (size[0] - landscape_frame.width) // 2
    paste_shadowed(
        base,
        landscape_frame,
        (landscape_x, landscape_top),
        radius=42,
        shadow_blur=44,
        shadow_alpha=155,
    )

    portrait_top = landscape_top + landscape_frame.height + 82
    max_portrait_height = size[1] - portrait_top - profile.image_margin_bottom
    portrait_frame = fit_resize(portrait, (690, max_portrait_height))
    portrait_x = (size[0] - portrait_frame.width) // 2
    paste_shadowed(
        base,
        portrait_frame,
        (portrait_x, portrait_top),
        radius=64,
        shadow_blur=48,
        shadow_alpha=165,
    )

    output = platform_output_dir(output_root, spec.platform) / spec.output
    output.parent.mkdir(parents=True, exist_ok=True)
    base.convert("RGB").save(output, "PNG")
    return output


def render_iphone_external(
    root: Path,
    version: str,
    output_root: Path,
    spec: PreviewSpec,
    language: str,
) -> Path:
    if spec.secondary_source is None:
        raise ValueError(f"{spec.output} needs an iPhone control source")

    size = PLATFORM_SIZES["iPhone"]
    profile = PROFILES["iPhone"]
    external = Image.open(resolve_source(root, version, language, spec.source)).convert("RGB")
    phone = Image.open(resolve_source(root, version, language, spec.secondary_source)).convert("RGB")

    base = make_canvas(external, size, spec.left_accent, spec.right_accent)
    draw = ImageDraw.Draw(base)
    text_bottom = draw_text_block(
        draw,
        profile,
        spec.headline,
        spec.subhead,
        spec.left_accent,
        BRAND_LABELS[language],
        language,
    )

    external_top = max(profile.image_top, text_bottom + 58)
    external_frame = fit_resize(external, (1080, 620))
    external_x = (size[0] - external_frame.width) // 2
    paste_shadowed(
        base,
        external_frame,
        (external_x, external_top),
        radius=42,
        shadow_blur=44,
        shadow_alpha=155,
    )

    phone_top = external_top + external_frame.height + 88
    phone_frame = fit_resize(phone, (610, size[1] - phone_top - profile.image_margin_bottom))
    phone_x = (size[0] - phone_frame.width) // 2
    paste_shadowed(
        base,
        phone_frame,
        (phone_x, phone_top),
        radius=64,
        shadow_blur=48,
        shadow_alpha=165,
    )

    output = platform_output_dir(output_root, spec.platform) / spec.output
    output.parent.mkdir(parents=True, exist_ok=True)
    base.convert("RGB").save(output, "PNG")
    return output


def render_preview(
    root: Path,
    version: str,
    output_root: Path,
    spec: PreviewSpec,
    language: str,
) -> Path:
    if spec.platform == "iPhone" and spec.mode == "iphone_external":
        return render_iphone_external(root, version, output_root, spec, language)

    if spec.platform == "iPhone" and spec.secondary_source is not None:
        return render_iphone_combined(root, version, output_root, spec, language)

    size = PLATFORM_SIZES[spec.platform]
    profile = PROFILES[spec.platform]
    mode = spec.mode or profile.mode

    screenshot = Image.open(resolve_source(root, version, language, spec.source)).convert("RGB")
    if spec.trim_dark_border:
        screenshot = trim_dark_border(screenshot)

    if mode == "fullbleed":
        base = cover_resize(screenshot, size).convert("RGBA")
        add_fullbleed_scrim(base, spec.left_accent, spec.right_accent)
        draw = ImageDraw.Draw(base)
        draw_text_block(
            draw,
            profile,
            spec.headline,
            spec.subhead,
            spec.left_accent,
            BRAND_LABELS[language],
            language,
        )
    elif mode == "split":
        base = make_canvas(screenshot, size, spec.left_accent, spec.right_accent)
        draw = ImageDraw.Draw(base)
        draw_text_block(
            draw,
            profile,
            spec.headline,
            spec.subhead,
            spec.left_accent,
            BRAND_LABELS[language],
            language,
        )

        left_panel_width = profile.margin_x + profile.max_text_width + 70
        max_width = size[0] - left_panel_width - profile.image_margin_x
        max_height = size[1] - profile.image_margin_bottom * 2
        foreground = fit_resize(screenshot, (max_width, max_height))
        x = left_panel_width + (max_width - foreground.width) // 2
        y = (size[1] - foreground.height) // 2
        paste_shadowed(
            base,
            foreground,
            (x, y),
            radius=profile.image_radius,
            shadow_blur=profile.shadow_blur,
            shadow_alpha=profile.shadow_alpha,
        )
    else:
        base = make_canvas(screenshot, size, spec.left_accent, spec.right_accent)
        draw = ImageDraw.Draw(base)
        text_bottom = draw_text_block(
            draw,
            profile,
            spec.headline,
            spec.subhead,
            spec.left_accent,
            BRAND_LABELS[language],
            language,
        )
        image_top = max(profile.image_top, text_bottom + round(profile.headline_size * 0.35))
        max_width = size[0] - profile.image_margin_x * 2
        max_height = size[1] - image_top - profile.image_margin_bottom
        foreground = fit_resize(screenshot, (max_width, max_height))
        x = (size[0] - foreground.width) // 2
        paste_shadowed(
            base,
            foreground,
            (x, image_top),
            radius=profile.image_radius,
            shadow_blur=profile.shadow_blur,
            shadow_alpha=profile.shadow_alpha,
        )

    output_dir = platform_output_dir(output_root, spec.platform)
    output = output_dir / spec.output
    output.parent.mkdir(parents=True, exist_ok=True)
    base.convert("RGB").save(output, "PNG")
    return output


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path.cwd(), help="Repository root.")
    parser.add_argument("--version", default=DEFAULT_VERSION, help="Image version under images/.")
    parser.add_argument("--out", type=Path, default=Path("AppStorePreviews"), help="Output directory.")
    parser.add_argument(
        "--language",
        "--locale",
        default="all",
        choices=("all", *SUPPORTED_LANGUAGES),
        help="Preview language to generate. Defaults to all.",
    )
    args = parser.parse_args()

    root = args.root.resolve()
    output_base = args.out if args.out.is_absolute() else root / args.out
    generated: list[Path] = []
    languages = SUPPORTED_LANGUAGES if args.language == "all" else (args.language,)

    for language in languages:
        output_root = output_base / args.version / language
        for spec in PREVIEW_SPECS_BY_LANGUAGE[language]:
            generated.append(render_preview(root, args.version, output_root, spec, language))

    for path in generated:
        size = Image.open(path).size
        print(f"{path.relative_to(root)} {size[0]}x{size[1]}")


if __name__ == "__main__":
    main()
