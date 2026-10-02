"""Self-contained diagnostic report for paired matches."""
from __future__ import annotations
import json
from pathlib import Path
from statistics import median


def summarize(runs):
    result = {}
    def is_baseline(run):
        return run.get("scenario", "") == "baseline" or run.get("scenario", "").startswith("baseline_")
    def pair_key(run):
        difficulty = run.get("effective_config", {}).get("rules", {}).get("difficulty", "standard")
        return run.get("seed"), difficulty
    baselines = {pair_key(r): r for r in runs if is_baseline(r) and r.get("outcome") in ("win", "timeout")}
    for name in sorted({r["scenario"] for r in runs}):
        items = [r for r in runs if r["scenario"] == name]
        valid = [r for r in items if r.get("outcome") in ("win", "timeout")]
        wins = sum(r.get("winning_team_id") == r.get("candidate_team") for r in valid if r["outcome"] == "win")
        money_delta = [r["timeline"][-1]["teams"][0]["money"] - r["timeline"][0]["teams"][0]["money"] for r in valid if r.get("timeline")]
        pairs = [(r, baselines[pair_key(r)]) for r in valid if not is_baseline(r) and pair_key(r) in baselines]
        finished = [r["duration"] for r in valid if r["outcome"] == "win"]
        rework_metrics = [r["metrics"] for r in valid if "metrics" in r]
        result[name] = {"runs": len(items), "technical_failures": len(items)-len(valid), "wins": wins, "win_rate": wins/len(valid) if valid else None, "timeouts": sum(r["outcome"] == "timeout" for r in valid), "stalls": sum(r.get("first_king_damage", -1) < 0 for r in valid), "median_duration": median(r["duration"] for r in valid) if valid else None, "median_first_king_damage": median(r["first_king_damage"] for r in valid if r.get("first_king_damage", -1) >= 0) if any(r.get("first_king_damage", -1) >= 0 for r in valid) else None, "median_team1_money_delta": median(money_delta) if money_delta else None, "paired_runs": len(pairs), "median_paired_duration_delta": median(r["duration"]-b["duration"] for r,b in pairs) if pairs else None, "paired_win_delta": sum((r.get("winning_team_id") == r.get("candidate_team", 1)) - (b.get("winning_team_id") == r.get("candidate_team", 1)) for r,b in pairs) if pairs else None}
        heavy_attempts = sum(m.get("ability_uses", {}).get("heavy", 0) for m in rework_metrics)
        unguarded_hits = sum(m.get("heavy_unguarded", m.get("heavy_hits", 0)) for m in rework_metrics)
        result[name].update({"heavy_attempts": heavy_attempts, "heavy_unguarded_hits": unguarded_hits,
                             "heavy_unguarded_rate": unguarded_hits / heavy_attempts if heavy_attempts else None,"median_completed_duration": median(finished) if finished else None,
                             "completed_in_target": sum(600 <= duration <= 900 for duration in finished),
                             "completed_matches": len(finished),
                             "median_heavy_hits": median(m.get("heavy_hits", 0) for m in rework_metrics) if rework_metrics else None,
                             "median_wood_remaining": median(m.get("wood_remaining", 0) for m in rework_metrics) if rework_metrics else None})
    return result


def html_report(report):
    payload = json.dumps(report, separators=(",", ":")).replace("<", "\\u003c")
    return Path(__file__).with_name("replay.html").read_text().replace("__REPLAY_PAYLOAD__", payload)
