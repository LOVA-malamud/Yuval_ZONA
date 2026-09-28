#!/usr/bin/env python3
"""Export only production source. Development project/autoloads stay untouched."""
import argparse
import copy
import hashlib
import re
import shutil
import subprocess
import tempfile
import zipfile
from contextlib import nullcontext
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def finalize_archive(output):
    """Use a clean Finder-facing app name; keep signed contents byte-identical."""
    notices = output.parent / "GODOT-LICENSES.txt"
    if not notices.is_file():
        raise ValueError("Generate GODOT-LICENSES.txt with tests/export_licenses.gd before finalizing")
    temporary = output.with_suffix(".normalizing")
    try:
        with zipfile.ZipFile(output) as source:
            app_roots = {name.split("/", 1)[0] for name in source.namelist() if ".app/" in name}
            if len(app_roots) != 1:
                raise ValueError("Expected exactly one application bundle in export")
            old_root = app_roots.pop()
            with zipfile.ZipFile(temporary, "w") as target:
                for original in source.infolist():
                    if original.filename in ("GODOT-LICENSES.txt", "CROWNFRONT-ASSETS.txt"):
                        continue
                    info = copy.copy(original)
                    if info.filename == old_root or info.filename.startswith(old_root + "/"):
                        info.filename = "Crownfront.app" + info.filename[len(old_root):]
                    with source.open(original) as incoming, target.open(info, "w") as outgoing:
                        shutil.copyfileobj(incoming, outgoing)
                target.write(notices, "GODOT-LICENSES.txt", compress_type=zipfile.ZIP_DEFLATED)
                target.writestr("CROWNFRONT-ASSETS.txt", "Crownfront visuals and sound effects are original procedural work created for this project.\nNo third-party art, music or sound asset packs are included.\nGodot Engine and its bundled components are covered by GODOT-LICENSES.txt.\n", compress_type=zipfile.ZIP_DEFLATED)
        temporary.replace(output)
    finally:
        if temporary.exists():
            temporary.unlink()
    digest = hashlib.sha256(output.read_bytes()).hexdigest()
    output.with_suffix(".sha256").write_text(f"{digest}  {output.name}\n")
    print(f"Release archive SHA-256: {digest}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", default="godot")
    parser.add_argument("--template", type=Path, help="Official 4.6.2 macos.zip; otherwise use installed templates")
    parser.add_argument("--output", type=Path, default=ROOT / "builds/Crownfront.zip")
    parser.add_argument("--stage-only", type=Path, help="Prepare a new source directory without launching Godot; useful for separately approved engine commands")
    parser.add_argument("--finalize-only", action="store_true", help="Normalize a previously exported ZIP bundle name and write its SHA-256, without launching Godot")
    args = parser.parse_args()
    if args.template and not args.template.is_file():
        parser.error("The macOS template does not exist")
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    if args.finalize_only:
        finalize_archive(output)
        return
    # Each export gets its own throwaway workspace, preventing stale imports or
    # accidental inclusion of tests, MCP, secrets, archives or previous builds.
    if args.stage_only and args.stage_only.exists():
        parser.error("--stage-only must name a new directory")
    context = nullcontext(args.stage_only) if args.stage_only else tempfile.TemporaryDirectory(prefix="crownfront-export-")
    with context as directory:
        stage = Path(directory)
        stage.mkdir(parents=True, exist_ok=True)
        for name in ("assets", "localization", "resources", "scenes", "scripts"):
            shutil.copytree(ROOT / name, stage / name)
        config = (ROOT / "project.godot").read_text()
        config = re.sub(r'^McpRuntimeAutoload=.*\n', '', config, flags=re.M)
        config = re.sub(r'\[editor_plugins\]\s*enabled=.*?\n', '', config)
        # Universal macOS templates require both desktop and Apple Silicon
        # texture import support, even when current artwork is procedural.
        config = config.replace('[rendering]\n', '[rendering]\ntextures/vram_compression/import_etc2_astc=true\n')
        (stage / "project.godot").write_text(config)
        preset = (ROOT / "export_presets.cfg").read_text()
        if args.template:
            template = str(args.template.resolve()).replace('\\', '\\\\').replace('"', '\\"')
            preset = preset.replace('custom_template/release=""', f'custom_template/release="{template}"')
            preset = preset.replace('custom_template/debug=""', f'custom_template/debug="{template}"')
        (stage / "export_presets.cfg").write_text(preset)
        assert 'addons/' not in config and 'McpRuntime' not in config
        if args.stage_only:
            print(f"Production source staged at {stage.resolve()}; import and export with the configured Godot engine")
            return
        subprocess.run([args.engine, "--headless", "--path", str(stage), "--import",
                        "--log-file", str(output.parent / "export-import.log")], check=True)
        subprocess.run([args.engine, "--headless", "--path", str(stage), "--script",
                        str(ROOT / "tests/export_licenses.gd"), "--", str(output.parent / "GODOT-LICENSES.txt")], check=True)
        subprocess.run([args.engine, "--headless", "--path", str(stage), "--export-release", "macOS", str(output),
                        "--log-file", str(output.parent / "export-release.log")], check=True)
    if not output.is_file():
        raise RuntimeError("Godot did not create the requested export")
    finalize_archive(output)
    print(f"Exported {output} ({output.stat().st_size:,} bytes); no test/editor/MCP source included")


if __name__ == "__main__":
    main()
