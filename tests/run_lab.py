#!/usr/bin/env python3
"""Run text-only Godot movement scenarios and optional full-match simulations."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import threading
from concurrent.futures import ThreadPoolExecutor
from uuid import uuid4
from match_scenarios import load as load_scenarios, swapped
from match_report import summarize, html_report


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


def run_script(engine: str, script: str, arguments: list[str], real_time: bool = False, visible: bool = False, label: str = "") -> dict:
    command = [
        engine, *([] if visible else ["--headless"]), "--path", str(ROOT),
        "--log-file", str(ARTIFACTS / f"game_lab_{uuid4().hex}.log"),
    ]
    if real_time and not visible:
        command.extend(["--fixed-fps", "60", "--disable-render-loop"])
    command.extend(["--script", script, "--", *arguments])
    lines: list[str] = []
    marker = "LAB_MATCH_REPORT " if real_time else "LAB_REPORT "
    process = subprocess.Popen(command, cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, bufsize=1)
    def collect() -> None:
        assert process.stdout is not None
        for line in process.stdout:
            if line.startswith("LAB_MATCH_PROGRESS "):
                progress = json.loads(line.removeprefix("LAB_MATCH_PROGRESS "))
                print(f"{label or 'match'} seed {progress['seed']}: {progress['seconds']}s, King HP {progress['king_health']}, armies {progress['army']}", flush=True)
            else:
                lines.append(line)
    reader = threading.Thread(target=collect, daemon=True)
    reader.start()
    try:
        process.wait(timeout=None if visible else 300)
    except subprocess.TimeoutExpired as error:
        process.kill()
        process.wait()
        raise SystemExit(f"{script} exceeded five wall-clock minutes") from error
    reader.join()
    reports = [line.removeprefix(marker) for line in lines if line.startswith(marker)]
    if process.returncode or len(reports) != 1 or any("SCRIPT ERROR:" in line or line.startswith("ERROR:") or ("WARNING:" in line and ("leaked" in line or "still in use" in line)) for line in lines):
        print("".join(lines)[-8000:], end="", file=sys.stderr)
        raise SystemExit(f"{script} failed (exit {process.returncode}; {len(reports)} reports).")
    report = json.loads(reports[0])
    if report.get("failures", 0) or report.get("outcome") == "technical_failure":
        raise SystemExit(f"{script} reported failure: {report.get('error', report.get('failures'))}")
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", help="Path to the Godot executable")
    parser.add_argument("--suite", choices=["movement", "matches", "all"], default="movement")
    parser.add_argument("--seeds", default="42", help="Comma-separated match seeds")
    parser.add_argument("--output", default="tests/artifacts/game_lab_report.json", help="JSON report path")
    parser.add_argument("--scenarios", help="Version 1 scenario JSON file")
    parser.add_argument("--html", help="Self-contained HTML report path")
    parser.add_argument("--limit-seconds", type=float, default=1800.0, help="Simulated match time limit")
    parser.add_argument("--jobs", type=int, default=1, help="Concurrent Godot matches (default: 1)")
    parser.add_argument("--watch", metavar="SCENARIO", help="Show one named scenario in a Godot window using the first seed")
    parser.add_argument("--sample-seconds", type=int, choices=(1, 5), default=1)
    parser.add_argument("--no-html", action="store_true", help="Skip embedding large experiment captures into HTML")
    parser.add_argument("--resume", action="store_true", help="Reuse completed runs from an identical source/config checkpoint")
    args = parser.parse_args()
    if not 0 < args.limit_seconds <= 1800:
        parser.error("--limit-seconds must be between 0 and 1800")
    if not 1 <= args.jobs <= 16:
        parser.error("--jobs must be between 1 and 16")
    if args.watch and args.suite == "movement":
        parser.error("--watch requires --suite matches or all")
    ARTIFACTS.mkdir(parents=True, exist_ok=True)
    engine = engine_path(args.godot)
    digest = hashlib.sha256()
    for directory in ("scripts", "resources", "scenes", "localization"):
        for path in sorted((ROOT / directory).rglob("*")):
            if path.is_file() and path.suffix in (".gd", ".tres", ".tscn"):
                digest.update(str(path.relative_to(ROOT)).encode())
                digest.update(path.read_bytes())
    digest.update((ROOT / "tests/engine_match_lab.gd").read_bytes())
    digest.update((ROOT / "project.godot").read_bytes())
    engine_version = subprocess.check_output([engine, "--version"], text=True).strip()
    output: dict = {"version": 1, "engine": engine, "engine_version": engine_version, "source_digest": digest.hexdigest(), "suite": args.suite, "seeds": args.seeds, "limit_seconds": args.limit_seconds, "sample_seconds": args.sample_seconds}
    destination = Path(args.output)
    if not destination.is_absolute():
        destination = ROOT / destination
    destination.parent.mkdir(parents=True, exist_ok=True)
    previous = None
    if args.resume and destination.exists():
        previous = json.loads(destination.read_text())
        for key in ("source_digest", "engine_version", "seeds", "limit_seconds", "sample_seconds"):
            if previous.get(key) != output[key]:
                parser.error(f"Cannot resume: {key} changed")
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
        if not seeds:
            parser.error("--seeds must contain at least one seed")
        scenarios = load_scenarios(Path(args.scenarios)) if args.scenarios else {"baseline": {}}
        if "baseline" not in scenarios:
            scenarios = {"baseline": {}, **scenarios}
        specs = []
        if args.watch and args.watch not in scenarios:
            parser.error(f"unknown watch scenario: {args.watch}")
        for name, config in scenarios.items():
            assignments = [("normal", config, 1)]
            if config.get("teams"):
                assignments.append(("swapped", swapped(config), 2))
            for assignment, effective, candidate_team in assignments:
                for seed in seeds:
                    specs.append((name, assignment, effective, candidate_team, seed))
        if args.watch:
            specs = [spec for spec in specs if spec[0] == args.watch and spec[1] == "normal" and spec[4] == seeds[0]][:1]
        if previous:
            remaining = []
            for spec in specs:
                name, assignment, config, candidate_team, seed = spec
                existing = next((r for r in previous.get("matches", []) if r.get("scenario") == name and r.get("assignment") == assignment and r.get("seed") == seed and r.get("outcome") in ("win", "timeout") and r.get("effective_config", {}).get("requested") == config), None)
                if existing:
                    matches.append(existing)
                else:
                    remaining.append(spec)
            specs = remaining
        def run_match(spec):
            name, assignment, effective, candidate_team, seed = spec
            try:
                report = run_script(engine, "tests/engine_match_lab.gd", [str(seed), json.dumps(effective, separators=(",", ":")), str(args.limit_seconds), str(args.sample_seconds), *(["--watch"] if args.watch else [])], True, visible=bool(args.watch), label=f"{name} {assignment}")
            except SystemExit as error:
                report = {"seed": seed, "outcome": "technical_failure", "error": str(error), "effective_config": effective}
            report.update(scenario=name, assignment=assignment, candidate_team=candidate_team)
            return report
        with ThreadPoolExecutor(max_workers=args.jobs) as pool:
            for report in pool.map(run_match, specs):
                matches.append(report)
                output["matches"] = matches
                output["summary"] = summarize(matches)
                destination.write_text(json.dumps(output, separators=(",", ":")) + "\n")
                print(f"{report['scenario']} {report['assignment']} seed {report['seed']}: {report.get('outcome')} winner {report.get('winning_team_id', '-')}", flush=True)
        output["matches"] = matches
        output["summary"] = summarize(matches)
        output["label"] = "Diagnostic evidence; not an automatic balance verdict"
    destination = Path(args.output)
    if not destination.is_absolute():
        destination = ROOT / destination
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(output, separators=(",", ":")) + "\n")
    print(f"report: {destination}")
    if args.suite in {"matches", "all"} and not args.no_html:
        html_path = Path(args.html) if args.html else destination.with_suffix(".html")
        if not html_path.is_absolute():
            html_path = ROOT / html_path
        html_path.parent.mkdir(parents=True, exist_ok=True)
        html_path.write_text(html_report({"version": 1, "runs": matches, "summary": output["summary"]}))
        print(f"replay: {html_path}")
    if output.get("movement", {}).get("failures", 0) or any(r.get("outcome") == "technical_failure" for r in output.get("matches", [])):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
