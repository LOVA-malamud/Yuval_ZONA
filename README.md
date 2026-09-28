# CROWNFRONT

CROWNFRONT is a local 2D action-strategy game built with Godot 4. Two teams fight across three strategic lanes while sharing a King, resources, upgrades, defenses, and reinforcements. You directly control one Azure commander alongside an AI ally against two coordinated Ember commanders. Destroy the opposing King to win.

## Gameplay

- Four independent commanders: human + ally AI versus two enemy AIs
- Three lanes with terrain-aware A* navigation
- Shared Gold and Wood economy, workers, gathering, and commander respawns
- Melee, ranged, and tank roles with distinct battlefield behavior
- Nine build pads and three-level Guard Towers
- King and Economy upgrade tracks
- Strategic minimap, responsive HUD, contextual onboarding, and pause/settings UI
- Procedural visuals and original synthesized sound effects
- English and Russian localization with persistent preferences

## Controls

| Input | Action |
| --- | --- |
| `WASD` | Move the human commander |
| Hold `Space` | Attack a nearby enemy |
| `E` near a King or build pad | Open the relevant interaction |
| Mouse wheel | Zoom the battlefield camera |
| Route selector | Choose North, Center, or South for new recruits |
| Army / King / Economy tabs | Recruit units and buy shared upgrades |
| `Escape` | Pause, close the active panel, or resume |

The optional in-game **How to Play** guide explains the objective, unit roles, routes, workers, towers, upgrades, and minimap.

## Languages and settings

The full interface supports **English** and **Русский**. Fresh installations begin in English. Language, Master/SFX volume, fullscreen mode, and onboarding preferences apply immediately and persist between launches.

## Run from source

1. Install **Godot 4.6.2 Standard**.
2. Clone this repository.
3. Import [project.godot](project.godot) in Godot.
4. Press **F5** to run the main project.

The project uses GDScript and Godot's Compatibility renderer. It has no external runtime services, accounts, networking, or downloaded asset dependencies.

## Builds and platform status

A universal macOS export was produced with the official Godot 4.6.2 templates and validated on an Intel Mac using the x86_64 slice. The Apple Silicon slice is present but was not run on Apple Silicon hardware. Windows and Linux builds have not been tested. Generated archives are intentionally excluded from source control.

To create a macOS archive with matching export templates:

```sh
python3 tests/build_macos.py --engine /path/to/Godot --template /path/to/macos.zip
```

The packaging script stages production files only, adds Godot and project-asset license notices, and writes the result under the ignored `builds/` directory. Public macOS distribution still requires the publisher's signing and notarization workflow.

## Project status

This repository contains the completed **pre-playtest final polish** milestone. The current feature set, automated regressions, performance stress scenarios, bilingual layouts, complete simulated matches, and a native macOS export were verified before publication. Competitive balance, subjective audio feel, onboarding clarity, and dense-combat readability now require real human playtesting.

Detailed evidence and limitations are recorded in [docs/verification.md](docs/verification.md). Supporting reports cover [performance](docs/performance-polish.md), [localization and onboarding](docs/localization-polish.md), [regression review](docs/regression-polish.md), and [macOS packaging](docs/export-polish.md).
