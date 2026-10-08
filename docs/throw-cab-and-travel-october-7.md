# Carpet throw, phone and train cab — 7 October 2026

The opening rollout now takes 2.075 seconds, half the previous 4.15-second motion. Its easing starts with a quick throw and slows as the held south edge settles. The camera begins approaching the town sooner, while handwritten titles retain their delayed start.

City travel uses two independent thick mats. The old sheet gathers flat, then rises and moves away as the new roll arrives, lands and unfolds. The flash overlay is removed. Floor grain and its distance shading use coordinates relative to each room, preserving the same pattern across the world swap. Later visits still take 2.8 seconds, including the continuous zoom back to the truck.

The flat printed layer fades from 19 to 22.5 seconds into each full intro instead of being lowered through the live scene. The transparent shader variant is warmed under the loading screen. The camera also approaches its gameplay distance gradually, with the shadow range following its subject. Travel clears old impact shake and conversation panning, uses the same truck height before and after handover, and keeps the miniature focus band stable. The short return completes its framing before the camera descends past Maple Bay's airborne birds.

The phone uses a 256-pixel SVG handset with mipmaps, linear filtering and antialiased rings. Its badge oscillates and tilts in bursts while the phone rings, then stops shaking when the dispatcher speaks.

Northline now requires 1.4 seconds of assisted forward contact with backwards hose recoil, four times the previous 0.35-second threshold. The cab has an open, deeper footwell instead of a solid block, a higher hinged roof and interior controls. Rowan lands inside, faces the locomotive's front and leans toward the side window, with one arm outside and the other reaching toward the controls. His pose stays relative to the engine when it turns around.

The Motorway feeder road and lane marks stop inside the carpet's orange binding. The binding has filtered yarn, mottled nap and a stitched seam that remain attached as the sheet bends. Both printed mats have been regenerated from the actual scene.

## Validation

- The full town-additions suite passes real off-centre contact/recoil and verifies the longer shove, boarding, powered motion and return route.
- Room/train checks pass the faster rollout, SVG resolution, fixed room composition and floor origin, gradual print fade, smooth truck handover, entrance limits, preserved toy state and the forward-facing conductor with one hand outside the window.
- Mat-travel, town-feedback and scene-detail suites pass mission/prop preservation, lap records, camera continuity, title timing, road/bridge geometry and controls.
- Dense camera sampling passes both full tours and short return in landscape and portrait. The regression intersects oriented geometry bounds with the visible near-plane rectangle to avoid false intersections from wide flat roads and rotated walls. It detected and helped resolve a real bird-wing intersection during the return zoom.
- Compatibility-renderer captures inspect both sides of the room swap, print fade, carpet throw, ringing badge, roof opening and finished cab pose. Chromium/WebGL checks the full intro, ringing badge, first Motorway tour, responsive controls, short return and revisit. The return takes 3.297 seconds including command and telemetry delay. Browser/game console errors: none. [Browser report](performance/throw-cab-and-travel-october-7.json).

The Web export and upload ZIP are refreshed on localhost port 8064. No commit or remote deployment was made.
