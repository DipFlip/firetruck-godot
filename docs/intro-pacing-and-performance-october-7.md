# Intro pacing and performance, October 7

The Maple Bay fly-in starts at 1.575 seconds, half a second before the 2.075-second rollout ends. The incoming Motorway mat also begins its fly-in half a second before it settles. Camera interpolation continues from the moving rollout view, avoiding a cut at the join.

Maple reaches the first cottage at about 4.11 seconds and starts moving away at 6.25: about 2.14 seconds close up, compared with 4.27 previously. Its house, trees and neighbour have shorter arrival spans and finish before that departure. The perimeter sweep and cascade follow earlier; the rest of the tour and handwriting continue through the original 24-second intro.

## Performance changes

- Pending CPU toys retain their existing hidden transform instead of being rewritten every frame. MultiMesh world-to-local transforms are cached once per batch.
- Opaque scenery batches stay hidden until their first toy arrives, stop receiving animation updates once settled, and regain tight culling bounds then. The vertex shader skips tumble calculations for pending and finished toys.
- Arrival materials and batch schedules are reused across warmup and live introductions. The loading screen now renders actual tour views, shadows, rolled/flat meshes and print fades before Start becomes active.
- A flat, closed, rounded carpet mesh replaces the dense curled sheet once rollout finishes: 208 triangles instead of 52,640. The rolled mesh, felt thickness, corners and printed-toy transition remain intact.

## Validation

`room_and_train_test.gd`, `toy_arrival_test.gd` with the Compatibility renderer, and `intro_camera_test.gd` pass. Camera clearance is checked across both complete tours and the return trip in landscape and portrait. Browser screenshots confirm the first house/tree/person sequence, perimeter cascade, food court and audience. Both complete tours run without console errors, and warmup leaves the intro clock at zero until Start.

The isolated `tools/benchmark_intro.gd` CPU benchmark, using 720 advancing assembly updates per town, measured warmed Maple toy-update averages of **2.30 → 1.23 ms/frame (47% less)**; Motorway measured **0.226 → 0.109 ms/frame (52% less)**. These are headless CPU measurements, excluding GPU time.

The private 1280×800 browser runs remained around 30 fps, with no sampled frames above 50 ms before or after. They confirm reduced work and correct sequencing, but do not demonstrate a higher browser frame rate or elimination of stutters on all devices. Browser metric totals include the tail of warmup; concurrent native validation also limits comparisons of those totals. Detailed measurements are in `performance/intro-pacing-october-7.json`.

The subsequent [60 fps pass](browser-60fps-october-7.md) identified those 30 fps samples as background-window throttling. Foreground testing showed 120 fps before the new scheduling changes; the earlier samples should not be interpreted as a foreground rendering limit.

Reproduce the browser flow with `tools/check_intro_pacing_web.js` and the frame sampling with `tools/benchmark_intro_web.js`. The refreshed web export is served at `http://localhost:8064/`.
