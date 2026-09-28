# Localization and onboarding polish

The pre-playtest pass retains every existing translation key, gameplay ID and formatting placeholder. The native Godot English/Russian catalogs now contain **170 matching keys**, including settings, contextual opening hints and an optional six-topic guide.

## Editorial changes

- Russian uses **древесина** consistently for the resource; prices use **древесины**. Worker capacity/gathering units use **ед.** / **ед./с**, avoiding malformed numeric phrases such as “12.0 дерево”.
- Recruitment feedback works for workers as well as combatants. King danger wording covers melee attacks as well as projectiles. Rebuild countdowns explain when construction becomes available.
- Pause text states the win/loss objective explicitly: commanders return; Kings do not. English income/error copy consistently uses “gold”.
- Existing unit/team names remain recognizable, including **Тяжёлый**, **Лазурь**, **Угли** and **Страж**. Upgrade and status labels were shortened or clarified without changing their meaning.
- New Russian help copy was reviewed for natural phrasing, concise controls, consistent terminology and line wrapping. This was an agent editorial review; a native-speaking human playtest remains useful for tone preferences.

## Onboarding

Gameplay starts immediately. A compact opening card introduces the King objective, movement/attack, recruitment/routes, workers/shared resources and minimap. Contextual tips explain nearby pads, upgrade tabs and commander respawn. The HUD ends opening guidance after 100 match seconds; **Hide tips** persists a disabled preference. Settings and the guide can enable it again.

**How to play** opens a paused, optional reference guide with six topics: commander controls, recruitment/routes/roles, resources/workers, build pads/towers, shared upgrades and minimap. Every topic includes a short practical suggestion. Escape closes the guide while leaving the match paused. The guide and any selected topic update immediately when the language changes.

`scripts/ui/help_panel.gd` owns only the guide UI. HUD owns pause/context selection; `GameSettings` owns persistence. There is no tutorial match, scripted gameplay reward, controller override or separate gameplay state machine.

## Verification

| Check | Result |
| --- | --- |
| Static localization validation | 170 matching keys; placeholder and referenced-key checks pass |
| Existing localization regression | 14 checks pass, including all used Cyrillic glyphs, fresh English default and live language switching |
| Onboarding regression | 24 checks pass, including real mouse clicks for opening/dismissing, Escape, contextual hints, alert priority, persistence and all six bilingual topics |
| Guide rendered matrix | 36 captures: all six topics × English/Russian × 1280×720, 1280×800, 1920×1080 |
| Guide visual inspection | All 36 images inspected individually; no clipped text, overflowing controls or broken Cyrillic glyphs found |

Guide captures include the saved-settings feedback row, checking the tallest practical panel state. Each rendered run passed 35 assertions at capture time (the final additional Hide tips click check makes subsequent rendered runs 36). Tests use `user://onboarding_regression.cfg`; they do not overwrite the developer's preferences. The localization test allows the mixer to release its final result sounds before quitting.

Reproduce with the Godot executable available on your system:

```sh
python3 tests/validate_localization.py
godot --headless --path . --script tests/localization_regression.gd
godot --headless --path . --script tests/onboarding_regression.gd
godot --path . --script tests/onboarding_regression.gd -- capture 1280x720
godot --path . --script tests/onboarding_regression.gd -- capture 1280x800
godot --path . --script tests/onboarding_regression.gd -- capture 1920x1080
```

Images are written to ignored `tests/artifacts/help_topic_<index>_<language>_<resolution>.png`. Test screenshots establish layout correctness; whether the opening tip timing teaches enough without distracting from play requires human feedback.
