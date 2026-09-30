---
name: match-simulation
description: Extend and run the Godot full-match scenario lab, including new tuning fields, measurements, paired comparisons, and replay data.
---

# Match simulation

Run `tests/run_lab.py --suite matches --seeds 42,43,44 --scenarios path/to/scenarios.json`. Reports are diagnostic evidence; use more paired seeds for balance conclusions.

Scenario files have `version: 1`, `scenarios` keyed by name, and optional `sweeps` keyed by name. A sweep has `base`, a dotted `path`, and `values`. Each scenario has `shared` and optional `teams` keyed `1` and `2`. Empty config means production defaults. Asymmetric cases run both assignments. Preserve the version and exact effective config in artifacts. Reject unknown fields; introduce a new version or explicit migration when changing meanings.

To expose a gameplay value, locate its read. Add it to `tests/match_scenarios.py`, then apply it in `GameManager._apply_simulation_config` or `_team_config` before `_ready` creates entities. Duplicate mutable `.tres` resources. Verify an empty scenario still uses production defaults.

To measure a value, add it to `tests/engine_match_lab.gd` snapshots, final report, or timestamped events, then show it in `tests/match_report.py` as needed. Keep map captures at fixed intervals. Check events and final state against the match result.

Compare baseline and candidates using the same seeds. Validate JSON and HTML artifacts, including timeouts and technical failures. Keep simulation at fixed 60 Hz. A realistic new-stat walkthrough is `worker_health`: add its default to `GameTeam.base_stats`, read it in `Worker._ready`, validate it under `base_stats`, then compare an ordinary and extreme value in paired runs.

For live inspection, `tests/run_lab.py` streams simulated time, King HP, and army counts every 30 simulated seconds. Add `--jobs 2` to run two headless matches concurrently. Use `--watch SCENARIO --seeds 42` to open one AI match in a Godot window; use headless paired runs for comparable measurements, then open the generated HTML file to scrub its strategic replay.
