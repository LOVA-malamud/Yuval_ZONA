#!/usr/bin/env python3
"""Probe one archetype pairing against several stat variants.

Variants are `shared` config blocks (plus optional "$a"/"$b" strategy overrides) (see tests/balance/*.json) layered on an optional
base file. Prints how often archetype A beats archetype B per variant, so one edge of
the counter wheel can be tuned in minutes instead of running the whole matrix.
Example: tests/pair_probe.py rush boom --variants tests/balance/variants_rush.json
"""
import argparse
import json
import subprocess
import sys
from copy import deepcopy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def merge(base, extra):
    result = deepcopy(base)
    for key, value in extra.items():
        if isinstance(value, dict) and isinstance(result.get(key), dict):
            result[key] = merge(result[key], value)
        else:
            result[key] = deepcopy(value)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("a")
    parser.add_argument("b")
    parser.add_argument("--variants", required=True, help="JSON object: variant name -> shared block")
    parser.add_argument("--base", help="JSON shared block applied under every variant")
    parser.add_argument("--strategies", default=str(ROOT / "tests/strategies.json"))
    parser.add_argument("--a-strategy", help="JSON overrides merged into archetype A's preset")
    parser.add_argument("--seeds", default="42,43,44,45")
    parser.add_argument("--jobs", type=int, default=3)
    parser.add_argument("--limit-seconds", type=int, default=600)
    parser.add_argument("--output", default=str(ROOT / "tests/artifacts/probe.json"))
    args = parser.parse_args()
    doc = json.loads(Path(args.strategies).read_text())
    base = json.loads(Path(args.base).read_text()) if args.base else {}
    variants = json.loads(Path(args.variants).read_text())
    strat_a = merge(doc["archetypes"][args.a], json.loads(args.a_strategy) if args.a_strategy else {})
    scenarios = {}
    for name, variant in variants.items():
        # "$a" / "$b" entries override the two archetype presets for this variant only.
        shared = {k: v for k, v in variant.items() if not k.startswith("$")}
        scenarios[name] = {"shared": merge(base, shared), "teams": {"1": {"strategy": merge(strat_a, variant.get("$a", {}))}, "2": {"strategy": merge(doc["archetypes"][args.b], variant.get("$b", {}))}}}
    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    scenario_file = out.with_suffix(".scenarios.json")
    scenario_file.write_text(json.dumps({"version": 1, "scenarios": scenarios}))
    cmd = [sys.executable, str(ROOT / "tests/run_lab.py"), "--suite", "matches", "--scenarios", str(scenario_file), "--seeds", args.seeds,
           "--jobs", str(args.jobs), "--limit-seconds", str(args.limit_seconds), "--no-html", "--output", str(out)]
    if subprocess.run(cmd, cwd=ROOT, stdout=subprocess.DEVNULL).returncode != 0:
        sys.exit("run_lab.py failed")
    report = json.loads(out.read_text())
    print(f"\n{args.a} (row) vs {args.b}, {args.limit_seconds}s limit; wins/losses/timeouts for {args.a}")
    for name in variants:
        rows = [m for m in report["matches"] if m["scenario"] == name]
        wins = sum(1 for m in rows if m["winning_team_id"] == m["candidate_team"])
        losses = sum(1 for m in rows if m["winning_team_id"] not in (0, m["candidate_team"]))
        times = sorted(m["duration"] for m in rows if m["winning_team_id"] == m["candidate_team"])
        print(f"  {name:28} {wins}/{losses}/{len(rows) - wins - losses}   median win {times[len(times) // 2] / 60:.1f} min" if times else f"  {name:28} {wins}/{losses}/{len(rows) - wins - losses}")


if __name__ == "__main__":
    main()
