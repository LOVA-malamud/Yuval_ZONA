# Approved pixel art and action animation plan

Branch: `feat/pixel-art-action-overhaul`, based on `aca1f34`.

The user chose crisp medieval art, characters plus effects, eight directions, and unchanged combat timing. Implementation and verification are recorded in [the delivery report](pixel-art-overhaul-verification.md).

## Character and effect scope

Create original Azure/Ember art for human and AI commanders, infantry, archers, siege-hammer tanks and straw-hat workers. Use steel/gold/warm skin colors, dark outlines, clear boots, consistent handedness, stable foot anchors and nearest texture filtering.

Animate actual movement and idle; commander light/heavy strikes, guard and guarded-hit recoil, dash, exposed recovery, healing, stun and respawn; troop strikes and arrow release; worker chopping, carried logs, loaded retreat and deposits. Add restrained pixel slashes, shield sparks, arrow projectiles, dash trails, wood chips, healing/stun cues, shadows and half-second death remnants. Use matching static recruitment portraits.

Workers continue to retreat and ordinary troops have no guard ability. Terrain, buildings, HUD art redesign, new abilities and combat rebalance are separate work. Preserve the existing result-screen crown burst.

## Timing and integration

- Animation reads gameplay. Damage, projectile release, movement, economy and protection never depend on animation callbacks.
- Commander preparation follows existing timers. Troops show impact/release immediately, then follow-through; archer preparation uses existing cooldown time without delaying shots.
- Separate legs and upper-body actions so moving attacks, guard walking and ranged retreat remain accurate. Use displacement rather than input intention for walking.
- Preserve idle facing, stabilize diagonal boundaries and retain continuous gameplay aim. Committed ability facing overrides walking direction.
- Freeze character/action animation with the session. Reset on respawn, refresh offscreen poses on re-entry, and retain culling and the shared effect budget. Death remnants cannot be targeted or keep actors alive.
- Retain team emblems, role silhouettes, health bars, the human marker and actionable telegraphs. Keep camera movement smooth and existing zoom controls.

## Delivery and acceptance

1. Show original commander/worker samples, contact sheets and a looping native preview before integrating production art.
2. Connect human and AI commander action poses, including misses, guarded hits, interruption, healing and respawn.
3. Connect troop and worker artwork, effects and portraits.
4. Review crowded fights, both teams, desktop/mobile sizes and zoom extremes; investigate rendered p95 regressions above 10%.

Acceptance requires distinct poses for existing actions, no stuck animation after interruptions, no walking while blocked/waiting, truthful carrying/chopping feedback, unchanged simulation outcomes, passing fast/parity checks, and recorded visual/performance evidence. Physical phone acceptance remains a device playtest rather than a desktop simulation claim.
