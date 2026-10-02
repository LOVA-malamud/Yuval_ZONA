#!/usr/bin/env python3
"""Apply the agreed pacing selection rule to completed paired comparisons."""
import argparse
import json
from pathlib import Path
from statistics import median


def select(runs):
    groups = {}
    for run in runs:
        groups.setdefault(run["scenario"], []).append(run)
    if any(run["outcome"] == "technical_failure" for run in runs):
        raise ValueError("Technical failures cannot be used for balance selection")
    expected = set(range(42, 62))
    for name, items in groups.items():
        if {r["seed"] for r in items} != expected or len(items) != 20:
            raise ValueError(f"{name}: require exactly seeds 42–61")
    if "baseline" not in groups or len(groups) != 8:
        raise ValueError("Require baseline plus seven factorial pacing candidates")
    summaries = []
    baseline_timeouts = sum(r["outcome"] == "timeout" for r in groups["baseline"])
    for name, items in groups.items():
        duration = median(r["duration"] for r in items)
        timeouts = sum(r["outcome"] == "timeout" for r in items)
        requested = items[0]["effective_config"]["requested"]
        rules = requested.get("shared", {}).get("rules", {})
        health = requested.get("shared", {}).get("balance", {}).get("tower_health", 480)
        changes = int(rules.get("rally_wait_seconds", 6) != 6) + int(rules.get("army_speed_multiplier", 1) != 1) + int(health != 480)
        summaries.append(dict(scenario=name, median_seconds=duration, timeouts=timeouts, changes=changes,
                              config=requested, meets_target=720 <= duration <= 1080 and timeouts <= 2))
    eligible = [s for s in summaries if s["meets_target"]]
    if eligible:
        chosen = min(eligible, key=lambda s: (s["changes"], abs(s["median_seconds"] - 900), s["scenario"]))
    else:
        chosen = min((s for s in summaries if s["timeouts"] <= baseline_timeouts),
                     key=lambda s: (max(720 - s["median_seconds"], s["median_seconds"] - 1080, 0), s["changes"], abs(s["median_seconds"] - 900), s["scenario"]))
    return dict(selected=chosen, candidates=summaries, target_met=chosen["meets_target"])


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = select(json.loads(args.report.read_text())["matches"])
    payload = json.dumps(result, indent=2) + "\n"
    if args.output:
        args.output.write_text(payload)
    print(payload)
