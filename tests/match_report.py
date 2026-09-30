"""Self-contained diagnostic report for paired matches."""
from __future__ import annotations
import json
from pathlib import Path
from statistics import median


def summarize(runs):
    result = {}
    baselines = {r.get("seed"): r for r in runs if r.get("scenario") == "baseline" and r.get("outcome") in ("win", "timeout")}
    for name in sorted({r["scenario"] for r in runs}):
        items = [r for r in runs if r["scenario"] == name]
        valid = [r for r in items if r.get("outcome") in ("win", "timeout")]
        wins = sum(r.get("winning_team_id") == r.get("candidate_team") for r in valid if r["outcome"] == "win")
        money_delta = [r["timeline"][-1]["teams"][0]["money"] - r["timeline"][0]["teams"][0]["money"] for r in valid if r.get("timeline")]
        pairs = [(r, baselines[r["seed"]]) for r in valid if r.get("scenario") != "baseline" and r.get("seed") in baselines]
        result[name] = {"runs": len(items), "technical_failures": len(items)-len(valid), "wins": wins, "win_rate": wins/len(valid) if valid else None, "timeouts": sum(r["outcome"] == "timeout" for r in valid), "stalls": sum(r.get("first_king_damage", -1) < 0 for r in valid), "median_duration": median(r["duration"] for r in valid) if valid else None, "median_first_king_damage": median(r["first_king_damage"] for r in valid if r.get("first_king_damage", -1) >= 0) if any(r.get("first_king_damage", -1) >= 0 for r in valid) else None, "median_team1_money_delta": median(money_delta) if money_delta else None, "paired_runs": len(pairs), "median_paired_duration_delta": median(r["duration"]-b["duration"] for r,b in pairs) if pairs else None, "paired_win_delta": sum((r.get("winning_team_id") == r["candidate_team"]) - (b.get("winning_team_id") == r["candidate_team"]) for r,b in pairs) if pairs else None}
    return result


def html_report(report):
    payload = json.dumps(report, separators=(",", ":")).replace("<", "\\u003c")
    return Path(__file__).with_name("replay.html").read_text().replace("__REPLAY_PAYLOAD__", payload)
