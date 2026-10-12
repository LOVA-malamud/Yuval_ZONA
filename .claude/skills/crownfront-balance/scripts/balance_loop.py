#!/usr/bin/env python3
"""Run the configured scenario set through the match lab, judge it against
targets, and compare with the previous run of the same scenarios.

Everything tunable lives in the loop config (default tests/balance_loop.json).
This wrapper adds no gameplay knowledge: it shells out to tests/run_lab.py and
reads the summary that run_lab already computes.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
WATCHED = ("scripts", "resources", "scenes", "localization")


def load_config(path: Path, args) -> dict:
    config = json.loads(path.read_text())
    if config.get("version") != 1:
        sys.exit(f"{path}: expected version 1")
    if args.scenarios:
        config["scenarios"] = args.scenarios
    if args.seeds:
        config["seeds"] = [int(s) for s in args.seeds.split(",")]
    elif args.quick:
        config["seeds"] = config.get("quick_seeds", config["seeds"][:2])
    if args.jobs:
        config["jobs"] = args.jobs
    if args.limit_seconds:
        config["limit_seconds"] = args.limit_seconds
    return config


def source_signature(config_path: Path, config: dict) -> tuple:
    """Cheap change detector for --follow (mtime + size of gameplay sources)."""
    watched = [config_path, ROOT / config["scenarios"], ROOT / "project.godot"]
    for directory in WATCHED:
        watched += [p for p in (ROOT / directory).rglob("*") if p.is_file()]
    return tuple(sorted((str(p), p.stat().st_mtime_ns, p.stat().st_size) for p in watched if p.exists()))


def run_lab(config: dict, output: Path, godot: str | None) -> int:
    command = [sys.executable, "tests/run_lab.py", "--suite", "matches",
               "--seeds", ",".join(map(str, config["seeds"])), "--jobs", str(config["jobs"]),
               "--scenarios", config["scenarios"], "--limit-seconds", str(config["limit_seconds"]),
               "--sample-seconds", str(config["sample_seconds"]), "--no-html", "--output", str(output)]
    if godot:
        command += ["--godot", godot]
    return subprocess.call(command, cwd=ROOT)


def judge(summary: dict, targets: dict, limit: float) -> list[str]:
    """Return the list of missed targets for one scenario summary."""
    misses = []
    if limit < targets.get("duration_seconds", (0, 0))[1]:
        return ["not judged: simulated limit is shorter than the target duration band"]
    runs = summary["runs"]
    valid = runs - summary["technical_failures"]
    if summary["technical_failures"] > targets.get("max_technical_failures", 0):
        misses.append(f"{summary['technical_failures']} technical failure(s)")
    if not valid:
        return misses + ["no valid runs"]
    low, high = targets.get("duration_seconds", (0, float("inf")))
    if summary["median_duration"] is not None and not low <= summary["median_duration"] <= high:
        misses.append(f"median duration {summary['median_duration']:.0f}s outside {low}-{high}s")
    if summary["timeouts"] / valid > targets.get("max_timeout_rate", 1):
        misses.append(f"timeouts {summary['timeouts']}/{valid}")
    if summary["stalls"] / valid > targets.get("max_stall_rate", 1):
        misses.append(f"stalls (no King damage) {summary['stalls']}/{valid}")
    if "win_rate" in targets and valid >= targets.get("min_runs_for_win_rate", 8):
        low, high = targets["win_rate"]
        if not low <= summary["win_rate"] <= high:
            misses.append(f"win rate {summary['win_rate']:.2f} outside {low}-{high}")
    return misses


def ability_stats(matches: list, name: str) -> dict | None:
    """Per-match ability measurements for one scenario, from each run's `metrics` block."""
    runs = [m["metrics"] for m in matches if m["scenario"] == name and m.get("outcome") in ("win", "timeout") and "metrics" in m]
    if not runs:
        return None
    def med(values):
        values = sorted(values)
        return values[len(values) // 2] if values else None
    uses = {a: med([r.get("ability_uses", {}).get(a, 0) for r in runs]) for a in ("dash", "guard", "heavy", "feint")}
    heavy = sum(r.get("ability_uses", {}).get("heavy", 0) for r in runs)
    hits = sum(r.get("heavy_hits", 0) for r in runs)
    unguarded = sum(r.get("heavy_unguarded", r.get("heavy_hits", 0)) for r in runs)
    encounters = sum(len(r.get("commander_encounter_durations", [])) for r in runs)
    durations = [d for r in runs for d in r.get("commander_encounter_durations", [])]
    return {"uses_per_match": uses,
            "heavy_hit_rate": hits / heavy if heavy else None,
            "heavy_unguarded_rate": unguarded / heavy if heavy else None,
            "stuns_per_match": med([r.get("event_counts", {}).get("stun", 0) for r in runs]),
            "encounter_seconds": med(durations),
            "escape_rate": sum(r.get("commander_escapes", 0) for r in runs) / encounters if encounters else None,
            "healing_interruptions": med([r.get("healing_interruptions", 0) for r in runs])}


def judge_abilities(stats: dict | None, targets: dict) -> list[str]:
    """Only enforce what the config sets: ranges are the user's balance decisions, not defaults."""
    if not stats:
        return []
    misses = []
    for ability, minimum in targets.get("min_uses_per_match", {}).items():
        if (stats["uses_per_match"].get(ability) or 0) < minimum:
            misses.append(f"{ability} used {stats['uses_per_match'].get(ability)}x/match (min {minimum})")
    for key in ("heavy_hit_rate", "heavy_unguarded_rate", "escape_rate", "encounter_seconds", "stuns_per_match"):
        if key in targets and stats[key] is not None and not targets[key][0] <= stats[key] <= targets[key][1]:
            misses.append(f"{key} {stats[key]:.2f} outside {targets[key][0]}-{targets[key][1]}")
    return misses


def fmt(value, scale=1, digits=0):
    return "-" if value is None else f"{value * scale:.{digits}f}"


def config_fingerprint(matches: list, name: str) -> str:
    requested = [m.get("effective_config", {}).get("requested", {}) for m in matches if m["scenario"] == name]
    return hashlib.sha256(json.dumps(requested[:1], sort_keys=True).encode()).hexdigest()[:12]


def git(*args) -> str:
    return subprocess.run(["git", *args], cwd=ROOT, text=True, capture_output=True).stdout.strip()


def iteration(args, config_path: Path) -> int:
    config = load_config(config_path, args)
    stamp = time.strftime("%Y%m%d-%H%M%S")
    output = ROOT / "tests/artifacts/balance" / f"{stamp}.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    count = len(json.loads((ROOT / config["scenarios"]).read_text()).get("scenarios", {}))
    print(f"balance loop: {len(config['seeds'])} seed(s) x {count}+ scenario(s) from {config['scenarios']}, limit {config['limit_seconds']:.0f}s", flush=True)
    code = run_lab(config, output, args.godot)
    if not output.exists():
        return code or 1
    report = json.loads(output.read_text())
    history_path = ROOT / config["history"]
    history = [json.loads(line) for line in history_path.read_text().splitlines()] if history_path.exists() else []
    entry = {"time": stamp, "commit": git("rev-parse", "--short", "HEAD"), "dirty": bool(git("status", "--porcelain")),
             "source_digest": report["source_digest"], "seeds": config["seeds"], "limit_seconds": config["limit_seconds"], "report": str(output.relative_to(ROOT)), "scenarios": {}}
    print(f"\n{'scenario':34} {'runs':>4} {'win%':>5} {'med s':>6} {'t/o':>3} {'stall':>5}  verdict / change vs previous")
    all_met = True
    for name, summary in report["summary"].items():
        misses = judge(summary, config["targets"], config["limit_seconds"])
        fingerprint = config_fingerprint(report["matches"], name)
        previous = next((h["scenarios"][name] for h in reversed(history)
                         if name in h["scenarios"] and h["seeds"] == config["seeds"] and h.get("limit_seconds") == config["limit_seconds"] and h["scenarios"][name]["config"] == fingerprint), None)
        change = ""
        if previous and previous["source_digest"] != report["source_digest"] and summary["median_duration"] is not None and previous["median_duration"] is not None:
            change = f" | duration {summary['median_duration'] - previous['median_duration']:+.0f}s"
            if summary["win_rate"] is not None and previous["win_rate"] is not None:
                change += f", win rate {summary['win_rate'] - previous['win_rate']:+.2f}"
        elif previous:
            change = " | identical source as previous run"
        base = report["summary"].get("baseline")
        if name != "baseline" and base and summary["median_duration"] is not None and base["median_duration"] is not None:
            change += f" | vs baseline: duration {summary['median_duration'] - base['median_duration']:+.0f}s"
            if summary["win_rate"] is not None and base["win_rate"] is not None:
                change += f", win rate {summary['win_rate'] - base['win_rate']:+.2f}"
        abilities = ability_stats(report["matches"], name)
        ability_misses = judge_abilities(abilities, config.get("ability_targets", {}))
        if ability_misses and not misses:
            misses = ability_misses
        elif ability_misses:
            misses = misses + ability_misses
        all_met &= not misses
        win = "-" if summary["win_rate"] is None else f"{summary['win_rate'] * 100:.0f}"
        median = "-" if summary["median_duration"] is None else f"{summary['median_duration']:.0f}"
        print(f"{name[:34]:34} {summary['runs']:>4} {win:>5} {median:>6} {summary['timeouts']:>3} {summary['stalls']:>5}  "
              f"{'OK' if not misses else ('' if misses[0].startswith('not judged') else 'MISS: ') + '; '.join(misses)}{change}")
        entry["scenarios"][name] = {"config": fingerprint, "source_digest": report["source_digest"], "win_rate": summary["win_rate"],
                                    "median_duration": summary["median_duration"], "timeouts": summary["timeouts"],
                                    "stalls": summary["stalls"], "misses": misses, "abilities": abilities}
    print(f"\n{'abilities (per match, median)':34} {'dash':>5} {'guard':>5} {'heavy':>5} {'feint':>5} {'hit%':>5} {'unguard%':>8} {'stuns':>5} {'enc s':>5} {'esc%':>5} {'heal int':>8}")
    for name, data in entry["scenarios"].items():
        a = data["abilities"]
        if a:
            u = a["uses_per_match"]
            print(f"{name[:34]:34} {fmt(u['dash']):>5} {fmt(u['guard']):>5} {fmt(u['heavy']):>5} {fmt(u['feint']):>5} {fmt(a['heavy_hit_rate'], 100):>5} "
                  f"{fmt(a['heavy_unguarded_rate'], 100):>8} {fmt(a['stuns_per_match']):>5} {fmt(a['encounter_seconds'], 1, 1):>5} "
                  f"{fmt(a['escape_rate'], 100):>5} {fmt(a['healing_interruptions']):>8}")
    with history_path.open("a") as handle:
        handle.write(json.dumps(entry) + "\n")
    print(f"\n{'all targets met' if all_met else 'some targets missed'} (diagnostic evidence, not a verdict; "
          f"few seeds are noisy). report: {output.relative_to(ROOT)}  history: {config['history']}")
    return code


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", default="tests/balance_loop.json", help="Loop config JSON, relative to the repo root")
    parser.add_argument("--scenarios", help="Override the scenario file from the config")
    parser.add_argument("--seeds", help="Override seeds, comma-separated")
    parser.add_argument("--jobs", type=int, help="Override concurrent matches")
    parser.add_argument("--limit-seconds", type=float, help="Override the simulated time limit (shorter is faster but turns long matches into timeouts)")
    parser.add_argument("--quick", action="store_true", help="Use the config's quick_seeds for a faster, noisier pass")
    parser.add_argument("--godot", help="Path to the Godot executable")
    parser.add_argument("--follow", action="store_true", help="Re-run whenever gameplay sources or scenarios change")
    parser.add_argument("--interval", type=int, default=20, help="Seconds between --follow checks")
    args = parser.parse_args()
    config_path = ROOT / args.config
    code = iteration(args, config_path)
    while args.follow:
        signature = source_signature(config_path, load_config(config_path, args))
        print(f"\nwatching for changes every {args.interval}s (Ctrl-C to stop)...", flush=True)
        while source_signature(config_path, load_config(config_path, args)) == signature:
            time.sleep(args.interval)
        time.sleep(3)  # let a multi-file save settle
        code = iteration(args, config_path)
    return code


if __name__ == "__main__":
    raise SystemExit(main())
