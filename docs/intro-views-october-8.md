# Camera-timed toy assembly — October 8

The first visits to Maple Bay and Motorway Race Club now schedule nearby toys around the camera tour's closest approach, with seeded staggering inside each view. Toys outside the close-up route still arrive throughout the tour. The perimeter retains its travelling cascade.

Schedules are resolved and cached behind the browser loading screen. Fixed scenery stores the same delay and duration as whole animated toys in its cinematic mesh's UV lane; the shader no longer duplicates the arrival rules. These temporary meshes preserve all exported LOD thresholds and index buffers and restore the original meshes at handover. Sound cues use those same schedules.

Featured timings use the incoming tour clock, excluding the Motorway's two-second departure:

| Location | Assembly window |
| --- | --- |
| Biscuit by the first cottage | 5.05–5.95 s, as one complete dropping toy |
| Southwest Maple grove | 9.8–12.1 s |
| Motorway personal-best display | 3.6–5.1 s |
| Northern Snack Shack | 10.0–11.6 s |
| Western benches and spectators | 16.4–18.6 s |

The Motorway ribbon, bridge, shoulders, supports and rails finish rising at about 3.1 s, before any gate lands. The driving surface and safety collision geometry retain their existing profiles.

The west audience platform now sits at (-52, 0, 15), north of the bend and facing south. The camera tour frames its assembly and then the broadcast camera at (-39, 0, 14). The broadcast head has its own small render batch; its operator holds the controls and turns with its pan. Tracking requires an active lap and a truck within 38 metres. The head holds its last angle during free driving or when the racer is elsewhere.

## Verification

- `intro_view_schedule_test.gd`: complete dog arrival, every southwest tree, shared CPU/shader schedules, preserved LODs, road-before-gates, display and food-stand deadlines, spectator clearance/orientation, and active/idle broadcast tracking.
- Existing toy-arrival, Motorway crowd/walking, landscape/portrait camera-clearance, intro-audio, mission-reaction, bridge-contact and mat-travel checks pass.
- `tools/check_intro_views_web.js` captures both tours, verifies Start gating, handover controls and starting/continuing a lap beside the relocated spectators. Browser results are recorded in `docs/performance/intro-views-october-8.json`.
- The final browser pass without screenshots sampled 60 FPS at all eight featured views and after handover. Of 2,535 measured frame intervals, 2,385 were at most 18 ms, 146 were 18–25 ms and four were 25–35 ms; none exceeded 35 ms. Both tours completed without console errors.
- Both printed mats and changed scenery batches were regenerated and the Web export rebuilt for localhost:8064.
