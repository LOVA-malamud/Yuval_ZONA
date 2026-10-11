---
name: crownfront-balance
description: Continuous balance testing for CROWNFRONT using fast headless simulations driven by a JSON config - run many seeds across scenario variants, judge them against target ranges (match length, timeouts, stalls, win rate), and compare to the previous run after each tuning change. Use whenever the user wants to tune or balance the game, test a stat change, check pacing, sweep a value, or keep re-testing as they edit.
---

# Balance loop

Wraps `tests/run_lab.py` (the real game scripts, 60 Hz, headless, accelerated) with targets and a run history so each tuning change gets an immediate, comparable answer.

## The configuration (edit these, not the script)

- `tests/balance_loop.json` (tracked in git, so commit it with the skills): scenario file, seeds, quick seeds, jobs, simulated time limit, sample interval, targets, history path. Targets are ranges for median duration, max timeout rate, max stall rate (a stall = nobody damaged a King), win-rate band, and technical failures. Ask the user before changing targets: the duration band should agree with the pacing goal in `docs/contributor-guide.md`.
- `ability_targets` in the same config: `min_uses_per_match` (an ability never used is untested or dead) is set; optional ranges `heavy_hit_rate`, `heavy_unguarded_rate`, `escape_rate`, `encounter_seconds`, `stuns_per_match` are enforced only when you add them. They are balance decisions, so ask the user for the numbers rather than inventing them.
- Scenario files in `tests/scenarios/*.json`: version 1, `scenarios` and optional `sweeps` (`base`, dotted `path`, `values`). What may be tuned is exactly what `tests/match_scenarios.py` accepts (unknown fields are rejected), so read its field sets to see what is tunable today. Asymmetric `teams` scenarios automatically run both team assignments.

## Loop

1. Make the scenario for the idea (copy a file in `tests/scenarios/`, or add a `sweeps` entry for a range of one value). Validate quickly: `python3 -c "import sys; sys.path.insert(0,'tests'); from pathlib import Path; import match_scenarios as m; print(len(m.load(Path('tests/scenarios/<scenario>.json'))))"`.
2. Run: `python3 .claude/skills/crownfront-balance/scripts/balance_loop.py --scenarios tests/scenarios/<scenario>.json`. `--quick` uses fewer seeds for a faster, noisier pass; `--seeds`, `--jobs`, `--limit-seconds` override the config (a short limit is a smoke test only: long matches become timeouts). Check `--help` for the current flags.
3. Read the table: each scenario shows OK or the missed targets, plus two comparisons: `vs baseline` (same run, same seeds; the head-to-head answer) and change versus the previous run of the same scenario and seeds when the game source differs (`identical source` means no gameplay file changed, so nothing to compare). With a limit shorter than the target band the verdict says `not judged`; that is a smoke run. History is `tests/artifacts/balance_history.jsonl` (ignored by git).
4. A second table prints per-match ability measurements for every scenario (dash/guard/heavy uses, heavy hit and unguarded rates, stuns, commander encounter length and escape rate, healing interruptions), read from each run's `metrics`. To test an ability change, sweep its `shared.balance.*` field (for example `heavy_damage`) and compare these columns across the sweep rows, alongside the pacing table.
5. Change the game or scenario, re-run. For hands-off iteration, `--follow` re-runs whenever scripts/resources/scenes/scenario files change. Run it in the background and read its output as it arrives.
6. To view a surprising match, re-run that one scenario and seed through `crownfront-simulate` (the loop skips HTML to stay fast), then open the replay it produces.

## Judging results

- Timing: matches are about 12x faster than real time per core; wall time is roughly (seeds x scenarios x 2 min) divided by `--jobs`. A 4-seed, 3-scenario pass is several minutes. The long suite `verify.py --suite tuning` takes hours and is for final selection, not iteration.
- Compare candidates on identical seeds. Four seeds can show a gross problem (everything timing out) but cannot support a fine claim; widen seeds before concluding, and say how many were used.
- Stalls and timeouts depend on the simulated limit: only trust them at the configured full limit.
- Technical failures are bugs, not balance data.
- Output is diagnostic evidence. Human feel and difficulty still need playtests.

## Keep in sync

If target semantics or summary fields change in `tests/run_lab.py` or `tests/match_report.py`, update `scripts/balance_loop.py` (it reads the `summary` block) and run `python3 tests/check_skills.py`.
