---
name: crownfront-run
description: Open and run the CROWNFRONT Godot game - play it windowed, open the sprite/animation preview, or watch one AI-vs-AI match with full graphics. Use whenever the user wants to launch, start, open, play, see, screenshot or preview the game, even if they only say "let me see it" or "does it start".
---

# Run CROWNFRONT

The repo root is the Godot project (`project.godot`). If a command below errors on an unknown flag, read `--help` of that script and use what it shows; `python3 tests/check_skills.py` reports which skill lines have gone stale.

## Pick the mode

| Goal | Command |
|---|---|
| Play the game | `python3 tools/run_game.py` |
| Look at character animations (actions, 8 facings, both teams) | no-Godot option: open `assets/pixel_art/preview.html` in a browser; native looping preview: `python3 tools/run_game.py --preview` |
| Watch one AI match with real graphics (a whole game, not just sprites) | `python3 tests/run_lab.py --suite matches --watch baseline --seeds 42` (run_lab is otherwise text-only; `--watch` is the windowed exception) |
| Web (HTML) replay of AI matches | use the `crownfront-simulate` skill |

Use `tools/run_game.py` instead of plain `godot --path .` because it re-imports assets first (a few silent seconds before the window appears, also in `--preview`). Skipping that can leave a stale atlas cache after artwork changes.

## Before launching

1. `which godot` (or pass `--godot /path`). Compare `godot --version` with the `version:` field in `.github/workflows/verify.yml` (also in the README "Run from source" section). A mismatch is worth mentioning but is not necessarily fatal.
2. These modes need a display (`echo $WAYLAND_DISPLAY $DISPLAY`). With none, say so and offer headless alternatives (`crownfront-verify`, `crownfront-simulate`) instead of launching a window that cannot show.
3. Launch with `run_in_background` so the session is not blocked while the window is open, and tell the user how to close it (Escape pauses, close the window to quit).

## Controls to relay

Read the Controls table in `README.md` and quote it; do not recite from memory since keys have changed between versions.

## If it will not start

- Script errors on launch: run `python3 tests/verify.py --suite fast --fixture runtime_smoke` for a clean diagnosis in an isolated copy.
- Odd or missing sprites: re-run through `tools/run_game.py` to refresh imports.
- Preferences (language, difficulty) persist in the user profile and can explain surprising behavior; tests avoid this by using isolated XDG dirs.
