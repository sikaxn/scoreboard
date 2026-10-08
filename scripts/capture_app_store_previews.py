#!/usr/bin/env python3
"""Capture Debug simulator previews through Device Hub's devicectl CLI."""
from __future__ import annotations
import argparse
import base64
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import time
from PIL import Image, ImageStat

BUNDLE = "IronMaple.smartScoreboard"
SCREENS = (("01-control-board", "main"), ("02-display-modes", "display"),
           ("03-game-setup", "game"), ("04-integrations", "integration"),
           ("05-remote-display", "remote-display"), ("06-rosters", "players"),
           ("08-merged-view", "merged"))


def device_command(*args: str) -> dict:
    with tempfile.TemporaryDirectory(prefix="scoreboard-devicectl-") as directory:
        output = Path(directory) / "result.json"
        result = subprocess.run(["xcrun", "devicectl", "--timeout", "60", "--json-output", str(output), *args],
                                capture_output=True, text=True)
        payload = json.loads(output.read_text()) if output.exists() else {}
        if result.returncode or payload.get("info", {}).get("outcome") != "success":
            raise RuntimeError(result.stderr or result.stdout or str(payload))
        return payload["result"]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", default="1.6")
    parser.add_argument("--device", required=True, help="Booted simulator name or UDID from devicectl list devices.")
    parser.add_argument("--platform", required=True, choices=("iPhone", "iPhoneDuo", "iPad"))
    parser.add_argument("--app", type=Path, required=True, help="Debug iphonesimulator .app built from current branch.")
    parser.add_argument("--fixture", type=Path, help="Demo state JSON; defaults to AppStorePreviews/fixtures/demo.json.")
    parser.add_argument("--language", choices=("all", "English", "Chinese"), default="all")
    parser.add_argument("--screen", choices=("all", *(s[1] for s in SCREENS)), default="all")
    parser.add_argument("--display", help="Display unique ID; default is the active primary display.")
    parser.add_argument("--duo-state", choices=("folded", "unfolded"), default="folded")
    parser.add_argument("--wait-for-display", type=float, default=300,
                        help="Seconds to wait for the requested Duo display to become active in Device Hub.")
    parser.add_argument("--settle-seconds", type=float, default=12)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    details = device_command("device", "info", "details", "--device", args.device)
    # Physical devices must never receive demo state or have their apps replaced.
    hardware = details.get("hardwareProperties", details.get("properties", {}).get("hardware", {}))
    if hardware.get("reality") != "simulated":
        raise RuntimeError("Capture requires a simulated device; refusing a physical device.")
    displays = device_command("device", "info", "displays", "--device", args.device)
    if args.platform == "iPhoneDuo":
        expected = [1398, 2034] if args.duo_state == "folded" else [2007, 2853]
        deadline = time.monotonic() + args.wait_for_display
        announced = False
        while True:
            display = next((d for d in displays["displays"] if sorted(d["nativeSize"]) == expected
                            and d.get("active")), None)
            if display:
                args.display = display["uniqueId"]
                break
            if time.monotonic() >= deadline:
                raise RuntimeError(f"Duo {args.duo_state} display is inactive. Change its pose in Device Hub.")
            if not announced:
                print(f"Waiting for iPhone Duo to be {args.duo_state} in Device Hub…", flush=True)
                announced = True
            time.sleep(5)
            displays = device_command("device", "info", "displays", "--device", args.device)
    device_command("device", "install", "app", "--device", args.device, str(args.app.resolve()))
    device_command("device", "simulate", "statusBar", "preset", "--device", args.device, "screenshot")
    fixture = json.loads((args.fixture or root / "AppStorePreviews/fixtures/demo.json").read_text())
    languages = ("English", "Chinese") if args.language == "all" else (args.language,)
    prefix = {"iPhone": "iphone", "iPhoneDuo": "iphone-duo", "iPad": "ipad"}[args.platform]
    for language in languages:
        folder = root / "images" / args.version / language / args.platform
        if args.platform == "iPhoneDuo" and args.duo_state == "unfolded":
            folder /= "Unfolded"
        folder.mkdir(parents=True, exist_ok=True)
        manifest_path = folder / "capture.json"
        manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {"captures": {}}
        manifest.update(device=args.device, platform=args.platform, version=args.version,
                        language=language, displays=displays, tool="devicectl",
                        duo_state=args.duo_state if args.platform == "iPhoneDuo" else None,
                        commit=subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip(),
                        working_tree_modified=bool(subprocess.check_output(["git", "status", "--porcelain"], cwd=root)),
                        fixture_sha256=hashlib.sha256(json.dumps(fixture, sort_keys=True).encode()).hexdigest())
        for suffix, screen in SCREENS:
            if screen == "merged" and args.platform == "iPhone":
                continue
            if args.screen != "all" and args.screen != screen:
                continue
            state = dict(fixture)
            state.update(theme="classic" if screen in ("main", "display", "merged") else "night",
                         selectedSport="basketball" if screen == "players" else "simple",
                         sport="basketball" if screen == "players" else "simple",
                         isPlayerTrackingEnabled=screen == "players", isRemoteDisplayHostEnabled=False,
                         areTipsEnabled=False, showGettingStartedOnStartup=False,
                         didAutoShowGettingStarted=True, didCompleteSetup=True)
            environment = json.dumps({"SCOREBOARD_PREVIEW_SCREEN": screen,
                "SCOREBOARD_PREVIEW_STATE": base64.b64encode(json.dumps(state).encode()).decode()})
            locale = ("en", "en_US") if language == "English" else ("zh-Hans", "zh_CN")
            orientations = ("portrait", "landscapeLeft") if args.platform == "iPhone" else (
                "landscapeLeft",) if args.platform == "iPad" else ("portrait",)
            for orientation in orientations:
                device_command("device", "orientation", "set", "--device", args.device, orientation)
                launch = ["device", "process", "launch", "--device", args.device, "--terminate-existing",
                          "--environment-variables", environment]
                # Launch on the active main display. Simulator launch --display
                # requests require private app entitlements; capture can select it.
                for attempt in range(3):
                    try:
                        device_command(*launch, BUNDLE, "--", "-AppleLanguages", f"({locale[0]})", "-AppleLocale", locale[1])
                        break
                    except RuntimeError as error:
                        if "10004" not in str(error) or attempt == 2:
                            raise
                        time.sleep(2)
                time.sleep(args.settle_seconds)
                ending = ("-portrait" if orientation == "portrait" else "-landscape") if args.platform == "iPhone" else ""
                output = folder / f"{prefix}-{suffix}{ending}.png"
                pending = output.with_name(f".{output.stem}.capturing.png")
                capture = ["device", "capture", "screenshot", "--device", args.device, "--destination", str(pending)]
                if args.display:
                    capture.extend(["--display-unique-id", args.display])
                for attempt in range(6):
                    device_command(*capture)
                    with Image.open(pending) as image:
                        image.verify()
                    with Image.open(pending) as image:
                        center = image.convert("RGB").crop((image.width // 5, image.height // 3,
                            image.width * 4 // 5, image.height * 2 // 3))
                        ready = max(ImageStat.Stat(center).stddev) >= 5
                        if args.platform == "iPhoneDuo":
                            ready = ready and sorted(image.size) == expected
                    if ready:
                        pending.replace(output)
                        break
                    if attempt == 5:
                        pending.unlink(missing_ok=True)
                        raise RuntimeError(f"Blank or wrong-display screenshot: {output}")
                    time.sleep(4)
                manifest["captures"][output.name] = {"screen": screen, "orientation": orientation,
                    "size": Image.open(output).size, "theme": state["theme"],
                    "captured_at": datetime.now(timezone.utc).isoformat()}
                manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
                print(output.relative_to(root), flush=True)
    device_command("device", "simulate", "statusBar", "clear", "--device", args.device)

if __name__ == "__main__":
    main()
