---
name: crownfront-simulate
description: Run accelerated headless AI-vs-AI CROWNFRONT matches and open the self-contained HTML web replay (battlefield timelapse with scrubbing, events, speed control). Use whenever the user wants to see how a game went, watch a simulation or replay, run matches with specific seeds or scenario JSON, or compare scenarios once, even if they say "simulate a game".
---

# Simulate and replay

Matches run the real scene tree at a fixed 60 Hz, headless, with a scripted AI in the human slot. They are far faster than real time (a 1800s match took about 2.5 wall minutes on one core), so use `--jobs` for several. They measure system behavior, not how it feels to a human; say so when presenting results.

For repeated tuning with pass/fail targets use `crownfront-balance`. For extending the lab itself (new tunable fields, new measurements) read `.agents/skills/match-simulation/SKILL.md`.

## Steps

1. Confirm flags live: `python3 tests/run_lab.py --help`.
2. Run, writing to a named file so earlier results are not overwritten:
   `python3 tests/run_lab.py --suite matches --seeds 42,43 --jobs 2 --output tests/artifacts/<name>.json`
   Add `--scenarios <file>` for variants (files in `tests/scenarios/`), `--sample-seconds 5 --no-html` for large batches, `--resume` to continue an interrupted identical run, `--limit-seconds` to cap simulated time (a capped run always ends as a timeout), `--html <path>` to place the replay elsewhere. `--suite` defaults to `movement`, so always pass `--suite matches`.
3. The HTML replay is written next to the JSON (`<name>.html`). Open it: `xdg-open tests/artifacts/<name>.html` (it is a local file, no server needed). Describe what to click: pick a match, Play (16x default), drag the slider, click gold event markers, hover units.
4. Summarize from the JSON `summary` block: per scenario win rate, median duration, timeouts, stalls, technical failures. The `stalls` count is runs where nobody ever damaged a King (per-run `first_king_damage` is -1; the summary's `median_first_king_damage` is null when every run stalled). At the normal 1800s limit a stall usually signals a pacing problem rather than a close game; call it out. With a short `--limit-seconds` it only means the cap came first, so treat duration and stalls as smoke-test output, not evidence. Paired fields (`paired_runs`, `paired_win_delta`) stay empty unless the scenario file has variants next to a `baseline`.
5. Optional checks: `python3 tests/validate_replay.py <json>`; `node tests/check_replay_browser.mjs <html>` (needs Node and Chromium).

## Honest reporting

- One seed is an anecdote. Say how many seeds back any claim.
- Technical failures are never balance results; report and investigate them.
- Watching with real graphics (single match) is `crownfront-run`.
