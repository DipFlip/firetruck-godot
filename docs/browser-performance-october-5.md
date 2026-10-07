# Browser performance review — 5 October 2026

The earlier optimization session is documented in [performance.md](performance.md) and landed in `25c1161`. The working tree was clean when this review began, at `479db10`. Scenery batching, active water instancing, off-screen cosmetic culling, pooled rewards and a two-million-pixel browser buffer limit were already present. The later toy-room pass added a screen-space tilt-shift shader and room dust.

## Reproduced pool-water stall

The previous warm-up visited the pool but kept its water hidden at zero fill. Therefore, the actual transparent `basin_water.gdshader` never reached the GPU before play. Godot's [Compatibility renderer guidance](https://docs.godotengine.org/en/4.6/tutorials/performance/pipeline_compilations.html) requires showing the material for a rendered frame; preloading its resource is insufficient.

Measured Chromium/WebGL 2 on an Apple M5, 390 × 844 portrait viewport, Godot 4.7.2, without CPU throttling. Compared an export of `479db10` with this working tree. Both builds used the same opt-in pose/fill QA probes. Each page was newly loaded, allowed to warm up, then placed beside the empty pool. Three one-second requestAnimationFrame samples toggled water from zero to 4% fill. No scene transitions or racing ran during these samples.

| Pool water appearance | Previous maximum frame interval | Updated maximum frame interval |
| --- | ---: | ---: |
| First appearance | 641.4 ms | 10.2 ms |
| Second appearance | 10.0 ms | 10.3 ms |
| Third appearance | 10.4 ms | 10.3 ms |

Median intervals stayed about 8.3 ms in all samples. This is evidence that the first-use hitch was removed on this machine, rather than a claim about phone FPS or all browser drivers. Raw results are in [before](performance/pool-first-use-before.json) and [after](performance/pool-first-use-after.json).

The loading pass now draws a visible proxy with the pool's real mesh, scale, shadow setting and transparent shader. It uses a separate material at half depth, preserving the actual empty pool and mission progress. It also warms the live instanced water batch, the printed mat and the new race scenery. `warmup_pool` telemetry is set after rendered warm-up frames.

## Changes and remaining costs

| Path | Finding and action |
| --- | --- |
| First pool water draw | Confirmed first-use shader stall; the visible loading proxy fixes it. |
| Refill hose | Previously cast 17 ground rays per rendered update, even while parked. Ground heights now refresh at 10 Hz while still, with immediate refresh when a sample moves more than 20 cm. The curve, pulse and flow keep updating smoothly. Water-feedback tests cover connection, terrain clearance, departure and pause. |
| Fire discovery | A world ray query was constructed before rejecting a distant or fast truck. Those checks now happen first. |
| Tilt shift | The fullscreen effect used five texture samples even inside the sharp band. The sharp band now uses one sample; the blurred edges retain the same look. A screen copy and edge blur remain GPU costs, especially at larger backing-buffer resolutions. |
| Water simulation | Each active droplet still casts a segment ray and runs receiver checks at physics frequency. Five gameplay drops are emitted per spray tick, plus sparse cosmetic drops. This is a likely CPU hotspot during sustained spraying. The existing batch reduces rendering submissions but does not reduce these collision queries. Consolidating stream collision requires further profiling and trajectory/occlusion regression checks. |
| Player tire contact | Four tires each sample five points in the visible-paving layer. This preserves curb and ramp behaviour but costs up to 20 ground queries per pose update. A future stationary-contact cache is a candidate; this pass preserves the existing tire behaviour. |
| Scenery and shadows | The mature town still submits hundreds of draws in portrait views. Many shaders and interactive toy parts cannot use the existing fixed-geometry merge. Material/draw batching and shadow caster reduction remain the next GPU investigation. |
| Two mats | The inactive mat is hidden and its simulation disabled. Town rigid bodies are frozen and restored with their velocities on return. The race scene is built once and warmed during loading, avoiding new mesh construction and shader compilation during travel. Both scenes stay in memory to preserve town missions and props. |

The general 4× CPU-throttled sample saturated the browser main thread while spraying. This pass does **not** establish an overall frame-rate improvement: different gameplay state, active train movement and background regression work make those broader samples unsuitable for a clean before/after claim. The repeatable pool first-use comparison above is the measured result.

## Repeatable checks

Build with `tools/build_web.sh`, serve `builds/web/` over HTTP and open `?qa=travel&touch` in the Playwright CLI. The explicit `qa=travel` flag enables local pose/fill probes; normal play and plain `?qa` retain read-only telemetry. Run `tools/check_pool_web.js` through `playwright-cli run-code` on a newly loaded page. `tools/check_travel_web.js` checks both travel directions, start-line driving and ordered lap completion. Its checkpoint poses are test probes, not an authentic race-time benchmark.

`tests/mat_travel_test.gd` checks the warm-up proxy, skippable assembly, train-opened exit, preserved town progress/props, race bounds/recovery, swept and ordered checkpoint crossings, shortcuts, pause timing, record saving, hose jobs and the return route. `tools/benchmark.gd` now explicitly finishes the intro before taking samples, avoiding measurements of the opening camera instead of the requested location.

## Validation

Fourteen suites passed across the review: mat travel, performance/resource reuse, water feedback, water motion, wooden boundaries, town/train additions, touch, dialogue dock, visibility guards, motion clarity, traffic aim, ladder, braking and car-wash assistance. The updated town-additions suite uses the new ten-second opening tour and confirms actual contact plus backwards hose recoil still starts Northline.

The existing dispatch suite still has one strict half-second camera assertion outside its 0.45–0.55 blend range. A focused run reproduced the failure on `479db10` (blend 0.557 at clock 0.538 s) as well as the updated build (0.567 at 0.545 s). Other dispatch assertions passed; this pre-existing frame-count/timing sensitivity is not treated as a new gameplay regression.

The real Compatibility renderer compiled the mat shader and produced intro/travel/track captures. The Chromium export passed both travel directions, actual start-line driving and checkpoint/record flow. Portrait and desktop views were inspected. Exported files are available in `builds/web/`; no remote deployment or Git commit was made by this task.
