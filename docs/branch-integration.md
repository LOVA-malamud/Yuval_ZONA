# Branch integration — October 3, 2026

Remote references were refreshed from origin before reviewing all local and remote branches. Branch tips below are the inventory before integration; source branches are retained.

| Branch/reference | Tip | Changes and disposition |
| --- | --- | --- |
| `main`, `origin/main` | `51c99dc` | Pre-playtest polish baseline; receives the complete integration. |
| `dardal_improvements`, `origin/dardal_improvements` | `707a51a` | Mobile movement, headless lab, configurable full-match simulations, offline timelapse viewer and architecture plan. Already an ancestor of both overhaul histories; included once. |
| Local `feat/command-and-coordination-overhaul` | `8c28682` | Commander overhaul plus two local validation/frame-rate commits. Preserved in merge ancestry. |
| `origin/feat/command-and-coordination-overhaul` | `078b942` | Five additional commits from common ancestor `7179af9`: metadata, combat/finite wood/towers, mobile HUD, lab/replay support and Android preparation. Merged with local fixes. |

`origin/HEAD` aliases `origin/main`; it is not a separate development branch. Two pre-existing documentation edits were preserved in a dedicated commit before the divergent merge. No source branches were deleted or rebased.

## Merge decisions

- Keep newer combat abilities, finite timber, tower choices, AI lane deployment and compact mobile drawers together with persistent orders, Rally, Regroup, tutorial and difficulty support.
- Retain match-owned actor caching and living-actor Rally counting, plus the 30/60 FPS death/projectile trace that covers the original frame-rate bug.
- Preserve catalog/map/rules resource validation and extension fixtures; restore match-rule validation removed by the independently developed remote history.
- Combine mobile ability refresh with visibility-gated command-panel refresh; refresh Orders when opening it and retain mutually exclusive compact drawers.
- Retain the expanded rework fixtures and local difficulty regression in the fast suite.
- Combine performance runner modes, exact-size rendering and idle checks with preserved baseline-directory support. Add missing projectile updates only for baselines without a shared session, avoiding duplicate simulation.
- Use finite-resource translations in both languages. Update player/contributor guidance for the actual merged feature set, replay version 4 and the Godot 4.7.2 CI target. Preserve earlier platform and measurement evidence as historical.

## Validation and remaining work

Combined source passes project/resource validation (104 Godot files, 125 resource paths), localization validation (250 bilingual keys), all 13 Python tests and whitespace checks. Python tools compile and documentation links resolve locally.

The initial pre-merge local fast run passed its three static checks but failed import on a sandbox TCP socket restriction. The fetched docs record a prior request to avoid launching Godot; no further engine checks were run after discovering it. Therefore combined-source engine parsing/runtime, render/input checks, pacing/performance comparisons and physical mobile acceptance remain pending. Older local full/desktop reports do not verify this integration. Android packaging is prepared; no rework APK is established as built.

This integration updates local `main`. Remote publication is separate from the local merge; no force push or branch deletion is required.
