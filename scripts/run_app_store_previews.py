#!/usr/bin/env python3
"""Build once, distribute to Device Hub simulators, capture, reuse, and render."""
from __future__ import annotations
import argparse
import json
import os
import re
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import generate_app_store_previews as previews


def stage_capture_project(root: Path, destination: Path) -> Path:
    """Enable commented capture hooks only in an isolated build copy."""
    shutil.copytree(root / 'smartScoreboard', destination)
    count = 0
    for name in ('ContentView.swift', 'ScoreboardStore.swift'):
        source = destination / 'smartScoreboard' / name
        text, enabled = re.subn(
            r'/\* APP_STORE_PREVIEW_CAPTURE_BEGIN\n(.*?)\n[ \t]*APP_STORE_PREVIEW_CAPTURE_END \*/',
            r'\1', source.read_text(), flags=re.DOTALL)
        source.write_text(text)
        count += enabled
    if count != 3:
        raise RuntimeError(f'Expected 3 commented capture hooks; found {count}.')
    return destination / 'smartScoreboard.xcodeproj'


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', type=Path, default=root / 'AppStorePreviews/capture-plan.json')
    parser.add_argument('--app', type=Path, help='Use an already built Debug simulator app instead of rebuilding.')
    parser.add_argument('--build-only', action='store_true', help='Build the isolated capture app and print its path.')
    args = parser.parse_args()
    config = json.loads(args.config.read_text())
    env = dict(os.environ, DEVELOPER_DIR=config['developer_dir'])
    app = args.app
    if app is None:
        derived = Path(tempfile.gettempdir()) / f"scoreboard-previews-{config['version']}-ios"
        with tempfile.TemporaryDirectory(prefix='scoreboard-preview-source-') as directory:
            project = stage_capture_project(root, Path(directory) / 'smartScoreboard')
            subprocess.run(['xcodebuild', '-project', str(project),
                '-scheme', 'smartScoreboard', '-configuration', 'Debug', '-sdk', 'iphonesimulator',
                '-destination', 'generic/platform=iOS Simulator', '-derivedDataPath', str(derived),
                'CODE_SIGNING_ALLOWED=NO', 'ARCHS=arm64', 'build'], env=env, cwd=root, check=True)
        app = derived / 'Build/Products/Debug-iphonesimulator/smartScoreboard.app'
    if args.build_only:
        print(app.resolve())
        return
    for device in config['devices']:
        command = [sys.executable, str(root / 'scripts/capture_app_store_previews.py'),
            '--version', config['version'], '--device', device['name'], '--platform', device['platform'],
            '--app', str(app.resolve()), '--fixture', str(root / config['fixture']),
            '--settle-seconds', str(config['settle_seconds'])]
        if device.get('duo_state'):
            command.extend(['--duo-state', device['duo_state']])
        subprocess.run(command, env=env, cwd=root, check=True)
    records = []
    manifest = root / 'images' / config['version'] / 'reused-assets.json'
    if manifest.exists():
        records = json.loads(manifest.read_text())
    for language, specs in previews.PREVIEW_SPECS_BY_LANGUAGE.items():
        for spec in specs:
            common = 'common-external' in spec.output
            if spec.platform not in config.get('reuse_platforms', []) and not (common and config.get('reuse_common_external')):
                continue
            name = 'Common_ext_screen.png' if common else f'{spec.platform}/{spec.output}'
            destination = root / 'images' / config['version'] / language / name
            if destination.exists():
                continue  # A new capture always wins over a reused asset.
            source = previews.resolve_source(root, config['reuse_version'], language, spec.source)
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, destination)
            records.append({'source': str(source.relative_to(root)), 'destination': str(destination.relative_to(root)),
                'reason': 'Explicit reuse in capture plan; not a new current-branch capture.'})
    manifest.parent.mkdir(parents=True, exist_ok=True)
    manifest.write_text(json.dumps(records, indent=2) + '\n')
    subprocess.run([sys.executable, str(root / 'scripts/generate_app_store_previews.py'),
        '--version', config['version']], cwd=root, env=env, check=True)

if __name__ == '__main__':
    main()
