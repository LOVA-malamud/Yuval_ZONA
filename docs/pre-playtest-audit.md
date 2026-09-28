# Pre-playtest audit

Baseline: verified strategic overhaul, preserved as commit `8ca89f7` and `/private/tmp/crownfront-before-final-polish.tar.gz`. Work branch: `feat/pre-playtest-final-polish`.

The lead reviewed the composition root, scene hierarchy, controllers, economy, navigation, combat/worker state machines, structures, procedural drawing, HUD, localization, resources, tests, README and previous verification report before changing runtime code. Subagents independently reviewed performance, settings/audio, and Russian/onboarding. Baseline project/localization validation and all 90 smoke assertions passed; real 1280×720 Russian battle capture was retained for comparison. MCP preflight was ready with no diagnostics.

## Findings and bounded response

- Preserve the controller → commander body → team boundary, all prices/stat resources, AI strategy and route semantics. No balance retuning is justified by this audit.
- Healthy-unit health bars, duplicate human labels and large ground labels obscure crowded combat. Improve presentation first; existing separation already passes the 60-unit test.
- There is no audio system. Add original cached procedural cues, a fixed voice pool, event cooldowns, distance mixing and priority for important events.
- Language-only settings need validated, atomic shared persistence and useful master/SFX/display/guidance controls. Fresh English must remain unconditional.
- The opening controls/welcome text does not teach the King objective, shared economy, route semantics or respawns. Add optional, dismissible guidance and a short help panel.
- HUD rebuilds immutable card text/tooltip strings at 10 Hz and formats resource hints every frame. Separate changing status from purchase state; invalidate shop content on relevant changes.
- Geometry line queries repeatedly construct obstacle corners for distant rectangles. Measure and prove a conservative rejection optimization before accepting it.
- Combat actors redraw all procedural silhouettes at physics frequency; measure visibility/throttling opportunities without altering simulation.
- Minimap already clusters armies and refreshes at 5 Hz. Retain this architecture and add team shapes and clearer major markers.
- Russian resource terminology and generic recruitment notices need editorial corrections, preserving keys/placeholders.
- No export presets/templates or actual packaged-build evidence exists. Add reproducible macOS packaging with tests/editor tooling excluded, then test a real release binary with isolated settings.
- Runtime MCP autoload currently registers even outside editor-connected play. Distribution must remove the addon/autoload entirely, while development integration remains available.

All changes require integration review, regression, real viewport captures, representative performance measurements and honest platform limitations. Source tests are not evidence of an exported build working.
