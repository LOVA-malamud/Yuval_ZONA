#!/usr/bin/env python3
"""Verify a staged source copy without touching the developer's preferences."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time
import io
import hashlib
import threading
import tarfile

ROOT = Path(__file__).resolve().parents[1]
REGRESSIONS = (
    "runtime_smoke", "tactical_regression", "route_travel", "navigation_parity",
    "localization_regression", "settings_audio_regression", "onboarding_regression",
    "polish_regression", "game_lab", "step_parity", "definition_regression", "difficulty_regression",
    "combat_rework_regression", "economy_towers_regression", "deployment_policy_regression",
    "hud_rework_regression", "economy_pacing_lab",
)


def diagnostics(log: str, fixture: str) -> list[str]:
    """Allow only the intentional malformed ConfigFile fixture diagnostic."""
    lines = log.splitlines()
    errors = []
    for index, line in enumerate(lines):
        if re.search(r"(?:SCRIPT ERROR:|ERROR:|WARNING:.*(?:leaked|still in use))", line):
            context = "\n".join(lines[index:index + 5])
            expected = fixture == "settings_audio_regression" and (
                "ConfigFile parse error" in line and "polish_settings_test.cfg" in context
            )
            if not expected:
                errors.append(line)
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--suite", choices=("fast", "full", "baseline", "desktop", "touch", "native", "render", "paired", "tuning"), default="fast")
    parser.add_argument("--match-jobs", type=int, choices=range(1, 17), default=2)
    parser.add_argument("--godot", default=shutil.which("godot"))
    parser.add_argument("--output", type=Path, default=ROOT / "tests/artifacts/verification")
    parser.add_argument("--fixture", help="Run one named regression for diagnosis")
    parser.add_argument("--verbose", action="store_true")
    parser.add_argument("--source-ref", help="Stage an exact Git revision for historical baselines")
    args = parser.parse_args()
    if not args.godot:
        parser.error("Godot unavailable; supply --godot")
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    checks = []
    engine = subprocess.check_output([args.godot, "--version"], text=True).strip()
    commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    with tempfile.TemporaryDirectory(prefix="crownfront-verify-") as temporary:
        stage = Path(temporary) / "project"
        if args.source_ref:
            archive = subprocess.check_output(["git", "archive", args.source_ref], cwd=ROOT)
            stage.mkdir()
            with tarfile.open(fileobj=io.BytesIO(archive)) as bundle:
                bundle.extractall(stage, filter="data")
            commit = subprocess.check_output(["git", "rev-parse", args.source_ref], cwd=ROOT, text=True).strip()
        else:
            shutil.copytree(ROOT, stage, ignore=shutil.ignore_patterns(
                ".git", ".godot", ".aws", ".codex", "artifacts", "builds", "__pycache__"))
        (stage / "tests/artifacts").mkdir(exist_ok=True)
        digest = hashlib.sha256()
        for directory in ("scripts", "resources", "scenes", "localization"):
            for path in sorted((stage / directory).rglob("*")):
                if path.is_file() and path.suffix in (".gd", ".tres", ".tscn"):
                    digest.update(str(path.relative_to(stage)).encode())
                    digest.update(path.read_bytes())
        digest.update((stage / "project.godot").read_bytes())
        env = os.environ.copy()
        for name in ("XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"):
            env[name] = str(Path(temporary) / name.lower())

        def run(name, command, timeout=300):
            if args.verbose and command[0] == args.godot:
                command = [*command, "--verbose"]
            start = time.monotonic()
            lines = []
            process = subprocess.Popen(command, cwd=stage, env=env, text=True,
                                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            def collect():
                for line in process.stdout:
                    lines.append(line)
                    # A script abort can leave an empty Godot window running.
                    # Fail immediately rather than waiting for the wall timeout.
                    # The settings fixture deliberately emits a ConfigFile error.
                    if name != "settings_audio_regression" and ("SCRIPT ERROR:" in line or line.startswith("ERROR:")):
                        process.terminate()
            reader = threading.Thread(target=collect, daemon=True)
            reader.start()
            try:
                code = process.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
                lines.append("\nVerification wall-clock timeout\n")
                code = 124
            reader.join()
            log = "".join(lines)
            (output / f"{name}.log").write_text(log)
            errors = diagnostics(log, name)
            passed = code == 0 and not errors
            checks.append(dict(name=name, command=command, passed=passed, exit_code=code,
                               diagnostics=errors, seconds=round(time.monotonic() - start, 3)))
            print(f"{'PASS' if passed else 'FAIL'} {name}", flush=True)
            if not passed:
                print(log[-3000:], flush=True)
            return passed

        run("project", ["python3", "tests/validate_project.py"])
        run("localization", ["python3", "tests/validate_localization.py"])
        run("python", ["python3", "-m", "unittest", "discover", "-s", "tests", "-p", "test_*.py"])
        imported = run("import", [args.godot, "--headless", "--path", str(stage), "--editor", "--import", "--quit"])
        if imported:
            if args.suite != "baseline":
                for fixture in ((args.fixture,) if args.fixture else REGRESSIONS):
                    run(fixture, [args.godot, "--headless", "--path", str(stage), "--script", f"tests/{fixture}.gd"])
                for fixture in ("coordination_regression", "session_regression"):
                    if not args.fixture and (stage / f"tests/{fixture}.gd").exists():
                        run(fixture, [args.godot, "--headless", "--path", str(stage), "--script", f"tests/{fixture}.gd"])
            if args.suite in ("baseline", "full"):
                run("matches", ["python3", "tests/run_lab.py", "--suite", "matches", "--seeds", "42,43,44",
                                "--jobs", "2", "--godot", args.godot, "--output", "tests/artifacts/matches.json"], 1200)
                if (stage / "tests/artifacts/matches.json").exists():
                    run("replay", ["python3", "tests/validate_replay.py", "tests/artifacts/matches.json"])
            if args.suite == "tuning" and all(check["passed"] for check in checks):
                run("pacing_matches", ["python3", "tests/run_lab.py", "--suite", "matches", "--seeds", ",".join(map(str, range(42, 62))),
                                       "--jobs", str(args.match_jobs), "--godot", args.godot, "--scenarios", "tests/scenarios/pacing.json",
                                       "--sample-seconds", "5", "--no-html", "--output", "tests/artifacts/pacing.json"], 18000)
                if (stage / "tests/artifacts/pacing.json").exists():
                    run("pacing_replay", ["python3", "tests/validate_replay.py", "tests/artifacts/pacing.json"])
                    run("pacing_selection", ["python3", "tests/select_pacing.py", "tests/artifacts/pacing.json", "--output", "tests/artifacts/pacing_selection.json"])
            if args.suite == "paired" and all(check["passed"] for check in checks):
                run("paired_matches", ["python3", "tests/run_lab.py", "--suite", "matches", "--seeds", "42,43",
                                       "--jobs", "1", "--godot", args.godot, "--scenarios", "tests/scenarios/assignment_smoke.json",
                                       "--limit-seconds", "120", "--output", "tests/artifacts/paired.json"], 1200)
                if (stage / "tests/artifacts/paired.json").exists():
                    run("paired_replay", ["python3", "tests/validate_replay.py", "tests/artifacts/paired.json"])
            if args.suite == "desktop":
                run("render_parity", [args.godot, "--path", str(stage), "--script", "tests/render_parity.gd"])
                for dimensions in ("1280x720", "1280x800", "1920x1080", "1600x720", "1280x960"):
                    for locale in ("en", "ru"):
                        for scenario in ("battle", "commands", "rally", "tutorial", "victory", "settings"):
                            run(f"visual_{scenario}_{locale}_{dimensions}", [args.godot, "--path", str(stage), "--script", "tests/visual_review.gd", "--", scenario, dimensions, locale], 45)
                run("live_input", [args.godot, "--path", str(stage), "tests/live_playtest.tscn", "--", "finish"])
                for locale in ("en", "ru"):
                    run(f"visual_cutout_{locale}", [args.godot, "--path", str(stage), "--script", "tests/visual_review.gd", "--", "cutout", "1600x720", locale], 45)
            if args.suite == "touch":
                for locale in ("en", "ru"):
                    for scenario in ("battle", "commands", "tutorial", "victory", "settings", "cutout"):
                        run(f"touch_{scenario}_{locale}", [args.godot, "--path", str(stage), "--script", "tests/visual_review.gd", "--", scenario, "1600x720", locale], 45)
                run("live_input", [args.godot, "--path", str(stage), "tests/live_playtest.tscn", "--", "finish"])
            if args.suite == "native":
                run("live_input", [args.godot, "--path", str(stage), "tests/live_playtest.tscn", "--", "finish", "display"])
            if args.suite == "render":
                run("render_parity", [args.godot, "--path", str(stage), "--script", "tests/render_parity.gd"])
        shutil.copytree(stage / "tests/artifacts", output / "artifacts", dirs_exist_ok=True)
    summary = dict(suite=args.suite, commit=commit, engine=engine, checks=checks,
                   source_digest=digest.hexdigest(),
                   passed=all(check["passed"] for check in checks), artifacts=str(output / "artifacts"))
    (output / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    return 0 if summary["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
