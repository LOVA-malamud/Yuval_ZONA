#!/usr/bin/env python3
"""Refresh Godot's local asset imports, then run the game or animation preview."""
import argparse
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default=shutil.which('godot'))
    parser.add_argument('--preview', action='store_true')
    args = parser.parse_args()
    if not args.godot:
        parser.error('Godot unavailable; provide --godot /path/to/Godot')
    common = [args.godot, '--path', str(ROOT)]
    print('Refreshing local asset imports…', flush=True)
    subprocess.run([*common, '--headless', '--editor', '--import', '--quit'], check=True)
    command = [*common, '--script', 'tests/pixel_art_preview.gd'] if args.preview else common
    return subprocess.call(command)


if __name__ == '__main__':
    raise SystemExit(main())
