#!/usr/bin/env python3
"""Capture final real viewports sequentially; fail on engine errors or bad bounds."""
import argparse
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", default="godot")
    parser.add_argument("--quick", action="store_true", help="Inspect the smallest Russian layout first")
    parser.add_argument("--start-case", type=int, default=1, help="Resume at a one-based case after an interrupted capture")
    args = parser.parse_args()
    dimensions = ["1280x720"] if args.quick else ["1280x720", "1280x800", "1920x1080"]
    languages = ["ru"] if args.quick else ["en", "ru"]
    scenarios = ["battle", "king", "economy", "pads", "settings", "victory", "guidance", "help"]
    cases = [(scene, size, language) for size in dimensions for language in languages for scene in scenarios]
    if not args.quick:
        cases += [(scene, "1280x720", language) for language in languages
                  for scene in ["danger", "defeat", "respawn", "pad_states"]]
    for index, (scene, size, language) in enumerate(cases, start=1):
        if index < args.start_case:
            continue
        log = ROOT / "tests/artifacts" / f"matrix_{scene}_{language}_{size}.log"
        result = subprocess.run([args.engine, "--path", str(ROOT), "--log-file", str(log),
                                 "--script", "tests/visual_review.gd", "--", scene, size, language],
                                capture_output=True, text=True, timeout=35)
        combined = result.stdout + result.stderr
        if result.returncode or "LAYOUT problems=0" not in combined or "ERROR:" in combined:
            print(combined, flush=True)
            raise RuntimeError(f"Capture failed: {scene} {size} {language}")
        print(f"[{index}/{len(cases)}] PASS {scene} {size} {language}", flush=True)
    print(f"CAPTURE MATRIX COMPLETE {len(cases)} real viewports; inspect PNGs individually.")


if __name__ == "__main__":
    main()
