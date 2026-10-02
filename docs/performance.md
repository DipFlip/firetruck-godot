# Performance comparison — 2 October 2026

Compared the previous main commit `0dba30b` with the optimized build on the development Apple M5 Mac. Median frame time fell by **9–22%** across six native samples. The portrait web sample submitted **39% fewer draw calls while spraying**, and used **12–13% less main-thread CPU time** per second under 4× CPU throttling.

Native measurement used Godot 4.7.2, the Compatibility renderer, a 1280 × 800 window and disabled VSync. Each location warmed for 1.5 seconds before a three-second sample. Timings come from monotonic time between actual rendered frames, not the headless renderer. Station, cat and train samples held the truck still; barbecue and pool samples continuously sprayed. The driving sample enabled physics and used the same camera-relative input in both versions. Each version ran separately, with other automated game windows and test workers closed. Draw counts include the renderer's shadow passes. Results vary with hardware and running traffic; these are measured local improvements rather than promised phone frame rates.

| Scene | Median frame ms, before → after | 95th percentile ms, before → after | Median draw calls, before → after |
| --- | --- | --- | --- |
| station | 4.30 → 3.89 | 5.33 → 4.70 | 1570 → 1344 |
| cat | 4.19 → 3.61 | 5.16 → 4.36 | 1568 → 1246 |
| barbecue | 5.31 → 4.14 | 6.61 → 5.67 | 1852 → 1273 |
| pool | 3.95 → 3.28 | 5.23 → 4.43 | 1150 → 774 |
| train | 2.79 → 2.56 | 3.71 → 3.47 | 585 → 496 |
| driving | 4.28 → 3.91 | 5.39 → 5.08 | 1209 → 932 |

The browser comparison used Chromium/WebGL on the same Mac, a 390 × 844 portrait viewport and CDP 4× CPU throttling. Both runs began at the station, dismissed dispatch, sampled idle for five seconds, then sampled five seconds of spraying with Shift held to keep the position fixed. Main-thread load is Chrome's `TaskDuration` divided by elapsed time; it includes scripting and browser rendering work. CPU throttling does not emulate a phone GPU. The median browser frame interval stayed 16.7 ms, so the useful comparison is workload/headroom rather than a claimed FPS increase.

| Web sample | Median draw calls, before → after | Main-thread load, before → after |
| --- | --- | --- |
| idle | 1061 → 809 | 59.6% → 51.6% |
| spray | 1274 → 782 | 92.6% → 81.6% |

The exported game confirmed `scenery_cached: true` and 243 merged fixed-scene sources. Raw samples are in `performance/before.json`, `performance/after.json` and `performance/web.json`.

The changes preserve scenery density, screen resolution, water hitboxes and vehicle behaviour:

- Flower beds now use 16-metre spatial batches instead of town-wide MultiMeshes, allowing off-screen beds to be culled independently.
- Fixed buildings and decorations combine compatible palette materials into vertex colours, in local batches. Lower-detail mesh levels are regenerated. Normal transforms preserve the lighting of thin, nonuniformly scaled paving.
- Each tree's palette surfaces are combined internally; all 51 trees retain independent rigid bodies, wind, stumps and respawn behaviour.
- All water drops and small splashes share one visible MultiMesh batch. The 600 pooled simulation slots retain individual colour, collision, aim assistance and lifetime behaviour; only active slots render. Small drops use fewer sphere segments.
- Off-screen foliage, NPC cosmetics, bird poses, butterflies, fountain drops and traffic wheel animation/ground rays skip visual work. Traffic routes, bird movement, missions and collisions continue.
- Anchored props use cached collision transforms and a cheap distance check before detailed sweeps. Car-water hit checks reject distant cars before inverse transforms. Mission labels refresh on job completion instead of every pellet.

The compressed scenery resources add about 8.6 MB to the asset pack. This trades download/storage size for fewer draws and avoids generating meshes/LODs during browser startup. Existing shader warmup still runs behind the loading screen. `tools/build_web.sh` regenerates the caches on every export, including GitHub Actions and Vercel. After changing models or the native town layout, regenerate them with:

```sh
Godot --headless --path . --script tools/bake_scenery.gd
```

To repeat the native comparison, run each checkout with the same benchmark script:

```sh
Godot --path . --rendering-method gl_compatibility --disable-vsync --audio-driver Dummy \
  --script tools/benchmark.gd -- --output=/tmp/firedriver-benchmark.json
```

For the web comparison, start a Playwright CLI session on the exported game with `?qa&touch`, resize to 390 × 844, start the game and skip the intro. Run `tools/benchmark_web.js` through the CLI's `run-code` command. It restores CPU throttling and releases the held keys afterwards.

Seventeen current regression suites passed, covering performance/resource reuse, water trajectories and feedback, car washing, traffic recovery/aiming, interactive scenery, bird behaviour, visibility guards, conversations, HUD/touch controls, ladder rescue, train/town additions, braking, dialogue presentation and 120 Hz interpolation. Desktop and portrait exports were inspected visually, and a browser drive crossed multiple parts of town.

The older `neighbourhood_test.gd` still has two obsolete dialogue assertions (closing at a short driving distance and finishing in exactly two presses). Both fail unchanged on the baseline and optimized build; current conversation behaviour is covered by the passing `conversations_life_test.gd` and `dialogue_dock_test.gd`.
