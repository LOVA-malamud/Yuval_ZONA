# CROWNFRONT

CROWNFRONT is a local 2D action-strategy game built with Godot 4. Two teams fight across three strategic lanes while sharing a King, resources, upgrades, defenses, and reinforcements. You directly control one Azure commander alongside an AI ally against two coordinated Ember commanders. Destroy the opposing King to win.

## Gameplay

- Four independent commanders: human + ally AI versus two enemy AIs
- Three lanes with terrain-aware A* navigation
- Shared Gold and finite Wood economy, exposed late-game gathering, and commander respawns
- Gradual, interruptible base recovery and shared dash, guard, and heavy-strike abilities
- Melee, ranged, and tank roles with distinct battlefield behavior
- Nine build pads with three-level Guard, Splash, and Long-range Towers
- King and Economy upgrade tracks
- Persistent ally orders, visible spending/plans, local Rally and Regroup commands
- Focus targeting, battle alerts, strategic minimap and responsive HUD
- Playable tutorial, match recap and Easy/Standard/Hard AI behavior
- Original eight-direction medieval pixel characters, animated combat and worker actions, and synthesized sound effects
- English and Russian localization with persistent preferences

## Controls

| Input | Action |
| --- | --- |
| `WASD` | Move the human commander |
| Hold `Space` | Attack a nearby enemy |
| `Shift` / `F` / `C` | Dash / guard / heavy strike, aimed toward the mouse |
| `E` near a King or build pad | Open the relevant interaction |
| Mouse wheel | Zoom the battlefield camera |
| `1` / `2` / `3` or route selector | North / Center / South for new recruits |
| Click an enemy | Focus attacks on that visible target |
| `Q` / Rally button | Buff nearby allied troops for 8 seconds |
| `R` / Regroup button | Temporarily gather nearby allied troops |
| Orders button | Set the ally commander’s order and review shared spending |
| Army / King / Economy tabs | Recruit units and buy shared upgrades |
| `Escape` | Pause, close the active panel, or resume |

On a touchscreen, drag from the left side to move. Mobile auto-attack works independently of movement. Drag an ability button to aim and release to activate; drag back into the button to cancel. A quick tap follows your movement facing or a nearby target when stationary. Use Interact near your King to channel recovery or near a build pad to select a tower. Army, King, and Economy controls open in collapsible drawers. Landscape safe areas and a portrait rotate prompt are supported; thumb reach and dense-combat readability still require phone playtests.

Heavy strike commits your facing through a visible 0.6-second wind-up. It deals 48 damage and briefly stuns commanders and troops when their guard fails. Front-facing guard and lateral dash provide counterplay; missing leaves you vulnerable during recovery.

## Character animation preview

Open [the offline sprite preview](assets/pixel_art/preview.html) to inspect actions, eight facings, both teams, and movement independently. Run the native looping preview with:

```sh
python3 tools/run_game.py --preview
```

See the [pixel art implementation and verification](docs/pixel-art-overhaul-verification.md) for timing, source artwork and review evidence.

## Text-only game lab

Run movement, collision, touch-input, and dodge scenarios without opening the editor:

```sh
python3 tests/run_lab.py
```

Run an accelerated full match with the real game scripts:

```sh
python3 tests/run_lab.py --suite all --seeds 42
```

The runner locates Godot automatically when possible. Use `--godot /path/to/Godot` otherwise. It prints key measurements and writes JSON to `tests/artifacts/game_lab_report.json`; use `--output tests/artifacts/experiment.json` to keep a named comparison. Full matches run the actual scene tree at a fixed 60 Hz with a scripted AI commander in the human slot. They measure system behavior, not human play quality.

### Watch simulation timelapses

```sh
python3 tests/run_lab.py --suite matches --seeds 42,43,44 --jobs 2 --output tests/artifacts/simulation_timelapse.json
```

Open `tests/artifacts/simulation_timelapse.html` in a browser. The offline report shows the whole battlefield, distinct unit roles, King health, army composition, workers, resources, and upgrades. Select a match and press **Play**; **16×** is the default speed. Drag the time slider or click a gold event marker to inspect a key moment, and hover units for health and route details. Playback stops at the result. Movement is interpolated between one-second observations; health and economy show sampled values. Older captures support sampled playback with fewer details.

To watch an AI match live with full game graphics instead:

```sh
python3 tests/run_lab.py --suite matches --watch baseline --seeds 42
```

Start **Tutorial** from Pause for a separate guided match; it can be restarted or skipped. **How to Play** includes a coordination reference. See the [player guide](docs/player-guide.md) for tactical commands.

## Languages and settings

The full interface supports **English** and **Русский**. Fresh installations begin in English. Language, Master/SFX volume, fullscreen mode, and onboarding preferences apply immediately and persist between launches. Difficulty persists and applies to the next match; it changes AI behavior while preserving equal starting resources and unit stats.

## Run from source

1. Install **Godot 4.7.2 Standard**.
2. Clone this repository.
3. Import [project.godot](project.godot) in Godot.
4. Press **F5** to run the main project.

To run from a terminal with fresh asset imports:

```sh
python3 tools/run_game.py
```

The launcher imports assets before starting. Direct `godot --path .` execution can retain an older local atlas cache after artwork changes; the character renderer detects mismatched atlas dimensions and recovers from source PNGs during local development. Restart an already-running game after updating artwork.

The project uses GDScript and Godot's Compatibility renderer. It has no external runtime services, accounts, networking, or downloaded asset dependencies.

## Builds and platform status

A universal macOS export was produced with the official Godot 4.6.2 templates and validated on an Intel Mac using the x86_64 slice. The Apple Silicon slice is present but was not run on Apple Silicon hardware. That is historical export evidence; this overhaul uses Godot 4.7.2 and tests native Linux source execution. New platform packages have not been produced. Generated archives are intentionally excluded from source control.

To create a macOS archive with matching export templates:

```sh
python3 tests/build_macos.py --engine /path/to/Godot --template /path/to/macos.zip
```

The packaging script stages production files only, adds Godot and project-asset license notices, and writes the result under the ignored `builds/` directory. Public macOS distribution still requires the publisher's signing and notarization workflow.

## Project status

The integrated `main` includes the command-and-coordination overhaul and the eight-issue gameplay rework: finite wood, gradual base healing, balanced AI deployment, commander abilities, tactical combat, tower choices, and a landscape mobile HUD. Automated checks and simulation evidence are documented in [the rework verification report](docs/rework-verification.md). Human combat and Android device acceptance remain pending; the issues should remain open until their acceptance checks are satisfied.

Run isolated verification without modifying your preferences:

```sh
python3 tests/verify.py --suite fast
python3 tests/verify.py --suite desktop
python3 tests/verify.py --suite full
```

CI runs the fast suite with Godot 4.7.2. Desktop checks require a display; full matches are headless. The [contributor guide](docs/contributor-guide.md) explains the session, commands, resources and scenario lab. See the [documentation index](docs/README.md), [branch integration record](docs/branch-integration.md), and [current rework verification](docs/rework-verification.md). Overhaul verification is historical evidence for the earlier snapshot. The earlier [polish verification](docs/verification.md) and its platform reports remain historical evidence.
