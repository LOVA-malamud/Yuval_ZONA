# Performance polish verification

Measured on 28 September 2026 with the official Godot 4.6.2 macOS editor executable, Compatibility renderer, OpenGL 4.1, AMD Radeon Pro 5300M, macOS 26.5.2. These are development-engine measurements on this Mac, not a minimum-spec guarantee or measurements of Windows/Linux exports. Other Godot test, editor and export jobs were held during samples. VSync and the frame cap were disabled by the test only.

## Preserved behavior and accepted changes

- `RouteMap.clear_line()` rejects obstacle rectangles outside the segment's bounding box before allocating corner arrays and running the original exact segment-edge tests. Strict comparisons preserve touching-edge behavior. No path costs, obstacle geometry, movement speeds, targeting priorities or route semantics changed.
- `CombatEntity.tick()` retains Godot's cached draw commands for idle static infantry. Movement transforms remain live. Workers, commander capes and active hit/attack feedback redraw while visible. Offscreen actors still run the entire simulation; entering the viewport invalidates their art, including health and expired flashes. An offscreen shooter's trace remains eligible if its bounds enter the view. Attack, damage, upgrades and translation changes explicitly redraw.
- The original 3,800 decorative grass strokes use one immutable triangle mesh, generated once with the same seed, positions, colors and widths. The battlefield art direction and navigation remain unchanged.
- HUD shop text is invalidated by actual shop state changes, not reformatted every frame. Minimap updates remain at 5 Hz with army clustering. Effects expire and have a bounded ordinary-effect budget. Audio uses a fixed voice pool and cue cooldowns.

No texture atlas, simulation throttling, hidden benchmark runtime switches, reduced actor limits, balance changes, or obstacle-based crowd system were added.

## Matched rendered capacity test

`tests/performance_probe.gd` stages 80 combat units, 20 workers, nine towers, four commanders and two Kings (115 actors), three concurrent mixed-role battles, active AI, workers, effects, HUD and minimap. A fixed seed (67231) and increased **fixture-only** health sustain the load. Combat damage totals and simulated time are saved to prove the game is running. This is a deliberate sustained capacity stress test, not a match-balance experiment.

The before copy was extracted afresh from `/private/tmp/crownfront-before-final-polish.tar.gz` (preserved baseline commit `8ca89f7`). The after copy contains the integrated polish. Both use the exact same test script, distinct application names/settings stores and disabled MCP editor/autoload tooling. Each run warms up for three seconds and measures fifteen wall-clock seconds. The viewport screenshot dimensions are asserted.

| Resolution | Before FPS | After FPS | Before mean frame | After mean frame | Before p95 | After p95 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1280 × 720 | 5.34 | 41.78 | 187.25 ms | 23.93 ms | 195.16 ms | 35.44 ms |
| 1280 × 800 | 5.31 | 39.22 | 188.35 ms | 25.50 ms | 199.69 ms | 37.84 ms |
| 1920 × 1080 | 5.20 | 39.91 | 192.45 ms | 25.06 ms | 208.26 ms | 38.91 ms |

The accepted comparison is about 7.4–7.8× faster. Rendered-object count fell from roughly 9,824 to 2,523. Draw calls did **not** fall: around 923 before versus 988 after, because the final game also adds explicit team emblems and feedback. The improvement primarily removes repeated procedural geometry generation and command traversal, rather than changing combat.

The baseline advances only 13.3–13.7 simulated seconds during the three-second warmup plus fifteen-second sample: very slow rendering exceeds the physics catch-up limit. The final build advances about 18.02 seconds and deals more damage because it actually simulates the full period. Samples are matched by wall-clock workload and fixture, not identical frame-by-frame combat states. FPS comes from measured frame intervals. Godot's process/physics monitor values are separately recorded and must not be summed as disjoint timings.

At 1080p one frame reached 118.43 ms. The sustained capacity test therefore does not demonstrate a locked 60 FPS. Typical human play and target hardware still need subjective assessment; this Mac's stress case is approximately 40 FPS with occasional spikes.

Accepted machine-readable reports and actual viewport captures are `tests/artifacts/performance_matched_before_*` and `performance_matched_after_*`. Earlier `performance_baseline_*`, `optimized`, `visible`, `hidden`, `mesh`, `batched` and `current` files are diagnostic or superseded. In particular, the earliest headless report had zero samples, and the earlier fixture placed all ranged units in the central visible battle. The isolated directory used during earlier experiments was also modified in place. Those numbers are **not** evidence for the final comparison. The reported 141 FPS earlier in the investigation came from that nonrepresentative all-ranged center fixture and must not be used as the final result.

## Sixty-second capacity soak and memory

The same 720p fixture measured **37.99 FPS** over 2,280 frames, mean 26.32 ms, p95 40.66 ms, maximum 112.54 ms. After the warmup plus sixty measured seconds it had simulated 62.99 seconds, dealt 103,600 damage and retained all 115 actors. Sixty once-per-second samples contained **274–283 nodes and 3–12 live effects**, with no growing population of expired effects.

Those in-run samples measured **101.427–101.808 MiB** of Godot static memory. The probe intentionally retains all timing arrays and sixty snapshot dictionaries for percentile reporting (15,960 numeric sample values in the soak). This accounts for small stepwise growth; these numbers are not a formal allocator/leak trace. Final values after viewport readback, PNG encoding and array sorting are not treated as a gameplay leak measurement. The bounded node count is stronger evidence that transient effects are being retired. The dedicated polish regression separately verifies 500 requested effects are capped at 48 ordinary effects and that expiry restores the budget.

## CPU simulation and navigation correctness

Headless measurements manually step exactly 900 measured simulation ticks at 1/60 second, after 180 warmup ticks. This isolates script work without claiming rendered FPS. Both preserved and polished versions advanced exactly 18 simulated seconds and dealt exactly **29,004 damage** with all 115 actors retained.

| Script group | Before mean | After mean | Before p95 | After p95 |
| --- | ---: | ---: | ---: | ---: |
| World/economy/pads | 0.167 ms | 0.170 ms | 0.206 ms | 0.221 ms |
| AI/commanders | 0.104 ms | 0.105 ms | 0.105 ms | 0.125 ms |
| Units/workers/towers | 5.252 ms | 5.208 ms | 9.508 ms | 9.230 ms |
| HUD/effects | 0.174 ms | 0.223 ms | 0.432 ms | 0.354 ms |
| Total | **5.697 ms** | **5.705 ms** | **9.969 ms** | **9.761 ms** |

There is **no meaningful overall CPU simulation speedup** in this pair; the rendering gain is the important result, and the extra feedback has a small CPU cost. The isolated navigation microbenchmark did improve: 15,500 random, near-obstacle, exact-edge, corner and zero-length cases matched the old algorithm exactly, with 168.035 ms before versus 47.816 ms after on this run. This microbenchmark improvement is not a whole-game speedup claim.

The probe asserts the 115-actor population and nonzero sustained combat. Its manually stepped headless mode releases the test scene, allows two native physics frames, stops/frees the audio pool and drains the mixer before shutdown; otherwise a pending audio-player start can outlive the artificial test loop. This teardown is outside measurement. One verbose and two subsequent ordinary verification runs exited without orphaned playback warnings (see `performance_teardown_*` logs). Rendered samples exited cleanly.

`tests/polish_regression.gd` also verifies rendered idle art reuse, damage/flash expiry invalidation, offscreen-to-visible refresh, and incoming offscreen traces. No actor was hidden or removed from simulation to obtain the accepted measurements.

## Reproduction

Create isolated project copies (unique `config/name`, or a custom user directory), remove the MCP autoload/editor plugin from those test copies, copy in the same current probe, import with the same Godot executable, then run one process at a time:

```sh
Godot --path /path/to/isolated-copy --script tests/performance_probe.gd -- rendered 1280x720 matched_after
Godot --path /path/to/isolated-copy --script tests/performance_probe.gd -- rendered 1280x800 matched_after
Godot --path /path/to/isolated-copy --script tests/performance_probe.gd -- rendered 1920x1080 matched_after
Godot --path /path/to/isolated-copy --script tests/performance_probe.gd -- rendered 1280x720 matched_soak 60
Godot --headless --path /path/to/isolated-copy --script tests/performance_probe.gd -- headless 1280x720 matched_after
Godot --headless --path /path/to/isolated-copy --script tests/navigation_parity.gd
```

The probe writes only under its copy's `tests/artifacts`. Increased health/resources belong solely to the test fixture. Real developer settings were neither removed nor reset. Export excludes the complete `tests/` directory.
