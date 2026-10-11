---
name: crownfront-add-test
description: Add or update a CROWNFRONT regression test or scenario after a gameplay change (new unit, ability, tower, map, economy rule, UI element) by copying the nearest existing fixture and registering it. Use whenever the user changes game content or systems and asks for tests, coverage, or "make sure this stays working", or when a change touches code that no fixture covers.
---

# Add coverage for a change

Fixtures are headless Godot scripts `tests/*_regression.gd` (plus labs like `game_lab.gd`) registered in `REGRESSIONS` in `tests/verify.py`. Python unit tests are `tests/test_*.py` and run automatically via unittest discovery. The architecture notes in `docs/contributor-guide.md` explain the session/command model fixtures rely on; skim its "Commands and events" and "Resources" sections first.

## Steps

1. Identify what changed (`git diff --stat`, or ask) and name the system (towers, abilities, economy, HUD, localization, scenarios, replay).
2. Find the nearest fixture by system, not by keyword: grep for the identifier of an existing sibling. For a new tower, search for an existing tower id; for a new unit, an existing unit id. Example: `grep -rln "long_range" --include=*.gd --include=*.py --include=*.tres .` Also list candidates with `ls tests/*_regression.gd tests/*_lab.gd`.
3. **Ripple search.** Whatever the new thing is, its siblings are probably hardcoded in places a test or validator will trip over: tuple/set literals of ids and field names (`tests/match_scenarios.py`, `tests/validate_replay.py`, `tests/engine_match_lab.gd`), count assertions in HUD fixtures (`size() == 3`-style), AI choosers, and localization. The grep from step 2 lists them all; go through every hit and decide whether it needs the new id. Check dynamically built localization keys too (`grep -rn '"[A-Z_]*_" +' scripts`), since `tests/validate_localization.py` only sees literal keys, so a missing one shows up as a raw key at runtime with no failure.
4. **Extend or add.** For a new variant of an existing system, extend the existing fixture (add the id to its definitions and a branch for the new behavior) rather than creating a near-duplicate file. Create a new `tests/<name>_regression.gd` only for a genuinely new system; then register the name (no `.gd`) in `REGRESSIONS` in `tests/verify.py` and keep Godot's generated `.uid` file with it.
5. Match the fixture's own style (read it first): they typically use a local `check(cond, msg)` helper, a `failures` counter and a final summary print that `verify.py` treats as pass/fail. Some call game objects directly (`tower.attack(...)`); others drive `MatchCommand` and `session.step()`. Use whichever the nearest fixture uses and prefer the command path for anything player-visible, so tests survive internal refactors. Assert behavior (state after N steps, results), not implementation details.
6. Scenario-tunable values: fields are validated in `tests/match_scenarios.py` (unknown fields fail by design; read how it treats zero and integers) and have matching unit tests in `tests/test_match_scenarios.py`.
7. Prove the check can fail: temporarily revert the fix or flip an assertion, run the single fixture (`python3 tests/verify.py --fixture NAME`, see `crownfront-verify`), see it fail, restore, see it pass. Then run `python3 tests/verify.py --suite fast`.
8. Update docs the change affects: `README.md` (feature list, controls), `docs/player-guide.md`, and the verification docs if a result is recorded. Add localization keys to both English and Russian.

## Keep skills in sync

If you added, renamed or removed a script, flag or fixture that any `.claude/skills/crownfront-*/SKILL.md` mentions, update that skill in the same change, then run `python3 tests/check_skills.py`.
