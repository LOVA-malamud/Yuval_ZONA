# Strategic overhaul audit

Branch: feat/2v2-strategic-overhaul. Initial project files were untracked in an unborn repository; the existing implementation is also preserved in /private/tmp/crownfront-before-overhaul.tar.gz for this session.

Baseline: Godot 4.6.2 MCP editor/scene inspection and play succeeded, runtime snapshot reported zero script/runtime errors. Existing headless runtime smoke test passed all assertions. MCP game screenshot returned the editor surface rather than the game; use a viewport capture test for reliable visual review.

Keep: composition root command boundary; GameTeam wallet/stats/signals; CombatEntity damage/ownership; resource unit/upgrade definitions; worker state machine; King objective; UI pause/restart.

Limitations: 2400x1200 open rectangle; no collision/navigation; all units pursue the King directly; one commander; bot only purchases; O(n²) separation scans; fixed sidebar; coarse shape art; stale README claimed engine unavailable.

Implementation order:
1. Four persistent commanders with replaceable controller children and independent spawn/respawn. Keep shared wallets and King-only victory.
2. 4600x2600 arena: three winding roads, connector clearings, solid terrain islands, finite safe groves and renewable forward groves. Shared grid A* for obstacle detours, explicit lane waypoints for strategic army advance; same collision geometry for human movement and targeting line of sight.
3. Pads outside road centers; validated nearby construction/upgrade, damageable towers and rebuild cooldown.
4. Per-commander tactical/production cadence, reserve budget for ally, sensed base defense and staggered aggression/economy priorities.
5. Procedural terrain/characters/effects; compact container HUD, minimap, route selection, context construction.
6. Deterministic real-script regression, every-route travel/stuck checks, accelerated full matches, viewport screenshots at three resolutions; MCP reruns/logs.

Scope: one Guard Tower, no networking or second tower. Navigation terrain is static; pads never obstruct roads. Balance constants remain editable. AI perception is local plus shared friendly base warnings, without hidden resource bonuses.
