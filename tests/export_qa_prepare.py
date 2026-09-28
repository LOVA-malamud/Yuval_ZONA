#!/usr/bin/env python3
"""Inspect production PCK and prepare a separate, externally instrumented app copy."""
import argparse
import hashlib
import json
import shutil
import struct
import time
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def pack_paths(data):
    magic, version, major, minor, patch, flags = struct.unpack_from("<6I", data)
    if magic != 0x43504447 or version not in (2, 3) or flags & 1:
        raise ValueError("Expected an unencrypted Godot 4 PCK")
    cursor = struct.unpack_from("<Q", data, 32)[0] if version == 3 else 96
    count = struct.unpack_from("<I", data, cursor)[0]
    cursor += 4
    paths = []
    for _ in range(count):
        length = struct.unpack_from("<I", data, cursor)[0]
        cursor += 4
        paths.append(data[cursor:cursor + length].rstrip(b"\0").decode())
        cursor += length + 36
    return paths


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("destination", type=Path)
    parser.add_argument("--instrument", action="store_true")
    args = parser.parse_args()
    if args.destination.exists():
        parser.error("destination must be a new directory")
    destination = args.destination.resolve()
    destination.mkdir(parents=True)
    with zipfile.ZipFile(args.archive) as archive:
        names = archive.namelist()
        if any(Path(n).is_absolute() or ".." in Path(n).parts for n in names):
            raise ValueError("Unsafe archive path")
        pack_name, = [name for name in names if name.endswith(".pck")]
        pack = archive.read(pack_name)
        paths = pack_paths(pack)
        forbidden = [p for p in paths if any(p.removeprefix("res://").startswith(x) for x in ("tests/", "addons/", "docs/", "builds/"))]
        if forbidden:
            raise ValueError(f"Development resources in release: {forbidden}")
        if not any("localization/en" in p for p in paths) or not any("localization/ru" in p for p in paths):
            raise ValueError("Missing packaged translation resources")
        archive.extractall(destination)
        for info in archive.infolist():
            if info.external_attr >> 16:
                (destination / info.filename).chmod((info.external_attr >> 16) & 0o777)
    app, = destination.glob("*.app")
    renamed = destination / "Crownfront.app"
    if app != renamed:
        app.rename(renamed)
    app = renamed
    exe, = (app / "Contents/MacOS").iterdir()
    if args.instrument:
        diagnostic = destination / "export_qa.gd"
        shutil.copyfile(ROOT / "tests/export_qa.gd", diagnostic)
        override = '[application]\nconfig/name="Crownfront Export QA ' + str(time.time_ns()) + '"\n\n[autoload]\nExportQA="*' + str(diagnostic) + '"\n'
        (exe.parent / "override.cfg").write_text(override)
    report = {"archive": str(args.archive.resolve()), "pck_sha256": hashlib.sha256(pack).hexdigest(), "pck_bytes": len(pack), "resource_count": len(paths), "paths": paths, "executable": str(exe), "external_instrumentation": args.instrument}
    (destination / "manifest.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({k: v for k, v in report.items() if k != "paths"}, indent=2))


if __name__ == "__main__":
    main()
