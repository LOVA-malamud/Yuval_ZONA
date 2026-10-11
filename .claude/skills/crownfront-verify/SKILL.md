---
name: crownfront-verify
description: Run and interpret the CROWNFRONT headless regression tests (tests/verify.py suites and single fixtures) and report evidence. Use whenever the user asks to test, verify, check, run the suite or CI locally, find out if a change broke something, or diagnose a failing fixture, even if they just say "run the tests".
---

# Verify CROWNFRONT

`tests/verify.py` copies the project to a temp dir with isolated preferences, runs static checks, imports assets, then runs Godot fixtures headless. It never touches the user's settings.

## Choose a suite

Get the real options from `python3 tests/verify.py --help` (the `--suite` choices) and the contributor guide (`docs/contributor-guide.md`, "Verification and experiments"). In outline:

- `fast`: what CI runs (`.github/workflows/verify.yml`). Default choice after any code change.
- `full`: fast plus complete seeded matches and replay validation. Slow; use before sign-off on gameplay changes.
- `desktop` / `touch` / `native` / `render`: need a display. Only run if a display exists.
- `--fixture NAME`: one fixture, for diagnosis. It still runs the static checks (`project`, `localization`, the whole Python unittest discovery) and the asset import first. the summary labels it `fast`; report it as "single fixture NAME". A single passing fixture does NOT mean the suite passes; say that when reporting. "Combat" has several fixtures (for example `combat_rework_regression`, `tactical_regression`, `facing_scouting_regression`); pick by what changed or run all that match.
- Other `--suite` values (`baseline`, `paired`, `tuning`) are long match-based runs for pacing work; use `crownfront-balance` instead. Use `--godot PATH` if `godot` is not on PATH.

The fixture list is `REGRESSIONS` in `tests/verify.py`; list it live with `python3 -c "import sys; sys.path.insert(0,'tests'); import verify; print(*verify.REGRESSIONS, sep='\n')"` when the user asks what is covered.

## Run

Run in the background for `full` (minutes). Fast takes a few minutes. Output ends with PASS/FAIL per check and writes logs to `tests/artifacts/verification/` (`tests/artifacts/verification/summary.json`, one `.log` per check).

## Interpret failures

1. Read the first `FAIL` line, then `tests/artifacts/verification/<name>.log`. The failure printed is the tail; the cause is usually earlier.
2. Fixture fails with `SCRIPT ERROR`: real bug in game or test script. Quote file and line.
3. Fails on "leaked"/"still in use": a resource or node was not freed; look at what the fixture creates.
4. Static checks (`project`, `localization`, `python`): fix those first; they are cheap and the Godot steps depend on `import` passing.
5. Re-run just that fixture with `--fixture` after a fix, then the whole suite once.

## Report

State: suite, commit (`git rev-parse --short HEAD`), whether tracked files are modified and whether new untracked files exist (`git status --short`), engine version, pass/fail counts and any failing names. The contributor guide asks for exactly this as verification evidence. Keep static, headless-engine, rendered and physical-device results separate; this skill only produces the first two (and rendered if a display exists).
