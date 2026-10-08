# Browser frame pacing, October 7

The web build now schedules rendered frames around a 60 fps target and leaves the browser free between them. The earlier 30 fps intro measurements came from a background Chromium window. Bringing the private test browser to the foreground showed 120 fps before these changes, so this pass improves pacing and spare capacity rather than claiming a doubled rendering rate.

## Changes

- `web/render_budget.js` aligns draws to whole browser refreshes: 60 fps on 60/120/240 Hz displays, 90 on 90 Hz and 72 on 144 Hz. Refresh changes, timestamp jitter, canceled callbacks, exceptions and returning from the background are covered by the scheduling test. An engine FPS cap was rejected because the local single-threaded web build spent its spare time waiting inside WASM; browser scheduling releases that time instead.
- The same helper caches only the game's WebGL `SCISSOR_TEST` boolean, tracking `enable`/`disable` and context restoration. Every other query remains native. Instrumenting the old foreground renderer found 240 scissor queries spending 309.7 ms over two seconds, versus 0.3 ms for its 240 framebuffer-binding queries. This was a substantial avoidable main-thread cost.
- Repeat town visits retain existing actor and prop poses and reveal them with camera and shadow rendering masks. They no longer reconstruct and update thousands of assembly transforms. Room furniture stays visible, and hidden toys cast no lingering shadows. First visits retain the full toy assembly sequence; fixed MultiMesh assembly records are reused from loading warmup.
- `BrowserFrameBudget` watches actual foreground callback intervals. Sustained overload lowers only the 3D resolution in bounded steps, with a minimum scale of 0.75, a cooldown between changes and gradual recovery after twelve seconds of stable frames. Loading, paused play and unfocused/background windows are excluded. HUD text, portraits and meters retain full resolution. Godot exposes this separately through [Viewport.scaling_3d_scale](https://docs.godotengine.org/en/stable/classes/class_viewport.html#class-viewport-property-scaling-3d-scale).

## Validation

Foreground Chromium, Apple M5, Compatibility/WebGL 2, 1280×800 CSS viewport with the existing approximately two-million-pixel backing-buffer limit. Native captures and Godot test processes were stopped during browser sampling. Start remains gated after warmup; both full introductions, ordinary driving, pool/barbecue spraying, Motorway driving and a repeat return trip are exercised.

| Scene | FPS monitor | Intervals ≤18 ms | Main-thread busy | 3D scale |
|---|---:|---:|---:|---:|
| maple intro | 60 | 99.7% | 25.8% | 1.00 |
| station | 60 | 100.0% | 23.4% | 1.00 |
| maple driving | 60 | 100.0% | 22.6% | 1.00 |
| pool spray | 60 | 97.4% | 30.0% | 1.00 |
| barbecue spray | 60 | 100.0% | 27.0% | 1.00 |
| motorway intro | 60 | 99.6% | 16.2% | 1.00 |
| race driving | 60 | 100.0% | 17.8% | 1.00 |
| return swap | 60 | 98.8% | 14.7% | 1.00 |

Across these phases, **99.6%** of 4,472 measured callback intervals were at most 18 ms. One was between 25 and 35 ms; the cumulative maximum was **27.6 ms**. No console errors occurred, and the adaptive resolution remained at 1.0 throughout. The return trip no longer reproduced the earlier 52 ms assembly hitch.

Measurements are recorded in `performance/browser-60fps-october-7.json`. Frame intervals come from `Time.get_ticks_usec()` between real rendering callbacks rather than Godot's smoothed gameplay delta. Histogram counts are differences between telemetry samples; engine FPS and CPU monitor readings update less frequently. A phase's maximum callback interval is cumulative through that point, not an independently reset maximum. Cold downloads/loading are excluded.

The browser results describe this hardware and foreground browser. Operating-system scheduling can still miss an individual refresh; they are not a guarantee for every device or background tab.

The WebGL state and refresh scheduler test, adaptive-resolution test, resource/pooling test, train/room test, both-town travel/state test, real Compatibility toy-arrival test, and landscape/portrait intro camera-clearance test pass. The travel tests also check camera/shadow mask restoration and preservation of moved props on repeat visits.

Reproduce using the Playwright CLI's `run-code --filename tools/benchmark_browser_60.js` in a headed session with the local web server running. The benchmark explicitly brings its own browser page to the foreground, waits for warmup and collects console errors. The latest web build is served at `http://localhost:8064/`.
