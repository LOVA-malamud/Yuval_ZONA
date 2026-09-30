#!/usr/bin/env python3
"""Run text-only Godot movement scenarios and optional full-match simulations."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "tests" / "artifacts"


def engine_path(explicit: str | None) -> str:
    if explicit:
        selected = Path(explicit).expanduser()
        if not selected.is_file():
            raise SystemExit(f"Godot executable not found: {selected}")
        return str(selected)
    candidates = [
        os.environ.get("GODOT_BIN"),
        shutil.which("godot"),
        shutil.which("godot4"),
        str(Path.home() / "Downloads/Godot_mono.app/Contents/MacOS/Godot"),
    ]
    for candidate in candidates:
        if candidate and Path(candidate).is_file():
            return candidate
    raise SystemExit("Godot not found. Pass --godot /path/to/Godot or set GODOT_BIN.")


def run_script(engine: str, script: str, arguments: list[str], real_time: bool = False) -> dict:
    command = [
        engine, "--headless", "--path", str(ROOT),
        "--log-file", str(ARTIFACTS / "game_lab_godot.log"),
    ]
    if real_time:
        command.extend(["--fixed-fps", "60", "--disable-render-loop"])
    command.extend(["--script", script, "--", *arguments])
    try:
        result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, timeout=300)
    except subprocess.TimeoutExpired as error:
        raise SystemExit(f"{script} exceeded five wall-clock minutes") from error
    marker = "LAB_MATCH_REPORT " if real_time else "LAB_REPORT "
    reports = [line.removeprefix(marker) for line in result.stdout.splitlines() if line.startswith(marker)]
    if result.returncode or len(reports) != 1 or "SCRIPT ERROR:" in result.stdout:
        print(result.stdout, end="", file=sys.stderr)
        print(result.stderr, end="", file=sys.stderr)
        raise SystemExit(f"{script} failed (exit {result.returncode}; {len(reports)} reports).")
    return json.loads(reports[0])


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", help="Path to the Godot executable")
    parser.add_argument("--suite", choices=["movement", "matches", "all"], default="movement")
    parser.add_argument("--seeds", default="42", help="Comma-separated match seeds")
    parser.add_argument("--output", default="tests/artifacts/game_lab_report.json", help="JSON report path")
    args = parser.parse_args()
    ARTIFACTS.mkdir(parents=True, exist_ok=True)
    engine = engine_path(args.godot)
    output: dict = {"engine": engine, "suite": args.suite}
    if args.suite in {"movement", "all"}:
        movement = run_script(engine, "tests/game_lab.gd", [])
        output["movement"] = movement
        print(f"movement: {movement['checks']} checks, {movement['failures']} failures; {movement['metrics']}")
    if args.suite in {"matches", "all"}:
        matches = []
        try:
            seeds = [int(item) for item in args.seeds.split(",")]
        except ValueError:
            parser.error("--seeds must be comma-separated integers")
        for seed in seeds:
            report = run_script(engine, "tests/engine_match_lab.gd", [str(seed)], True)
            matches.append(report)
            print(f"seed {seed}: {report['duration']:.1f}s, winner {report['winning_team_id']}, first King damage {report['first_king_damage']:.1f}s, failures {report['failures']}")
        output["matches"] = matches
    destination = Path(args.output)
    if not destination.is_absolute():
        destination = ROOT / destination
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(output, indent=2) + "\n")
    print(f"report: {destination}")


if __name__ == "__main__":
    main()
