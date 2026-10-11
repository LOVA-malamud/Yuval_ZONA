#!/usr/bin/env python3
"""Run every archetype pairing from tests/strategies.json and print a win-rate matrix.

Each pairing runs on both team sides via tests/run_lab.py. Cells are the row
archetype's win rate against the column archetype; "*" marks an intended win from
the wheel and "x" an intended loss, so mismatches are visible at a glance.
"""
import argparse
import itertools
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--strategies", default=str(ROOT / "tests/strategies.json"))
    parser.add_argument("--seeds", default="42,43,44,45")
    parser.add_argument("--jobs", type=int, default=2)
    parser.add_argument("--limit-seconds", type=int, default=1500)
    parser.add_argument("--output", default=str(ROOT / "tests/artifacts/matrix.json"))
    parser.add_argument("--shared", help="JSON file with a `shared` config block (stat overrides) applied to every pairing")
    parser.add_argument("--only", help="Comma-separated archetypes to include")
    parser.add_argument("--resume", action="store_true", help="Reuse finished matches from --output")
    parser.add_argument("--report-only", action="store_true", help="Print the matrix from --output without running")
    args = parser.parse_args()
    doc = json.loads(Path(args.strategies).read_text())
    names = [n for n in doc["archetypes"] if not args.only or n in args.only.split(",")]
    out = Path(args.output)
    scenario_file = out.with_suffix(".scenarios.json")
    if not args.report_only:
        scenarios = {}
        shared = json.loads(Path(args.shared).read_text()) if args.shared else None
        for a, b in itertools.combinations_with_replacement(names, 2):
            scenarios[f"{a}__vs__{b}"] = {"teams": {"1": {"strategy": doc["archetypes"][a]}, "2": {"strategy": doc["archetypes"][b]}}}
            if shared:
                scenarios[f"{a}__vs__{b}"]["shared"] = shared
        out.parent.mkdir(parents=True, exist_ok=True)
        scenario_file.write_text(json.dumps({"version": 1, "scenarios": scenarios}))
        cmd = [sys.executable, str(ROOT / "tests/run_lab.py"), "--suite", "matches", "--scenarios", str(scenario_file), "--seeds", args.seeds,
               "--jobs", str(args.jobs), "--limit-seconds", str(args.limit_seconds), "--no-html", "--output", str(out)]
        if args.resume:
            cmd.append("--resume")
        if subprocess.run(cmd, cwd=ROOT).returncode != 0:
            sys.exit("run_lab.py failed")
    print_matrix(json.loads(out.read_text()), names, doc.get("wheel", {}))


def print_matrix(report, names, wheel):
    cell = {}
    durations = []
    for match in report["matches"]:
        scenario = match["scenario"]
        if "__vs__" not in scenario:
            continue
        a, b = scenario.split("__vs__")
        row = cell.setdefault((a, b), {"a": 0, "b": 0, "draw": 0})
        winner = match.get("winning_team_id", 0)
        # Team 1 holds archetype a in the normal assignment, team 2 when swapped.
        a_team = 1 if match["assignment"] == "normal" else 2
        if winner == 0:
            row["draw"] += 1
        else:
            row["a" if winner == a_team else "b"] += 1
            durations.append(match["duration"])
    width = 14
    print(f"\nWin rate of ROW vs COLUMN (draws = timeouts counted as half); {'*' }= wheel win, x = wheel loss")
    print(" " * width + "".join(f"{n:>{width}}" for n in names) + f"{'overall':>{width}}")
    for a in names:
        line, wins, games = f"{a:<{width}}", 0.0, 0
        for b in names:
            if (a, b) in cell:
                r, mine, theirs = cell[(a, b)], cell[(a, b)]["a"], cell[(a, b)]["b"]
            elif (b, a) in cell:
                r, mine, theirs = cell[(b, a)], cell[(b, a)]["b"], cell[(b, a)]["a"]
            else:
                line += f"{'-':>{width}}"
                continue
            n = r["a"] + r["b"] + r["draw"]
            rate = (mine + 0.5 * r["draw"]) / n if n else float("nan")
            mark = "*" if b in wheel.get(a, []) else "x" if a in wheel.get(b, []) else " "
            line += f"{f'{rate:.0%}{mark} ({r['draw']}d)':>{width}}"
            if a != b:
                wins, games = wins + mine + 0.5 * r["draw"], games + n
        line += f"{(wins / games if games else float('nan')):>{width}.0%}"
        print(line)
    if durations:
        durations.sort()
        print(f"\ndecisive matches: {len(durations)}, median duration {durations[len(durations) // 2] / 60:.1f} min")
    total = sum(sum(r.values()) for r in cell.values())
    timeouts = sum(r["draw"] for r in cell.values())
    print(f"matches: {total}, timeouts: {timeouts}")


if __name__ == "__main__":
    main()
