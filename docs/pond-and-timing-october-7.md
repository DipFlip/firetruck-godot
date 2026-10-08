# Pond, bridge and intro timing — October 7

Maple Bay's 3.8-second flight into the mat now takes 2.53 seconds, and Motorway's takes 1.09 seconds. The first cottage starts earlier; perimeter drops retain their timing beside the camera sweep. Smaller details use a fourth arrival mode that scales them up at their planted position. Buildings rise, while bushes, people and larger toys retain their tumble.

The departure zoom takes 0.5625 seconds, 25% longer, with zero initial velocity and acceleration. First-visit gathering takes 1.3 seconds, 30% longer. Repeat trips take 4.2 seconds, with both gathering and unfolding phases 50% longer and eased at either end. Arrival welcome popups are removed. The thick mesh and its stitched orange binding share 4.5-metre rounded corners.

Rowan smoothly faces the nearby truck and keeps watching it during conversation. Boarding blends from his current gaze and raises his hop to clear the cabin's header.

The Motorway infield pond is 26 by 20 metres and 2.4 metres deep, with a level bottom and continuous slopes to a flat rim. Ground and wood-floor openings reveal the actual bowl. The collision surface and truck's smooth support sampler share its height/gradient function. Shore stones have irregular spacing and two open approaches. Ducks swim over the larger water area. Three tents and a picnic table form the northwest campsite.

Bridge rails and the underside use one combined static contact mesh, leaving the smooth driving sampler and lower crossing intact.

## Verification

- Room/train checks passed, including earlier camera framing, original seating/arm pose, print fade, state preservation and slower repeat swaps.
- Toy arrival checks passed with the Compatibility renderer: all closed-mat faces point outward, all corner vertices lie on the rounded outline, baked geometry contains sprout data, over 500 tiny garden parts grow without sky offsets, and the border cascade remains staggered.
- Pond/bridge physics checks passed: Rowan gaze, no hidden slab filling the basin, natural driving into/out of the pond, solid underside and a rail stopping the truck before it leaves the bridge. Lowest truck centre was about −1.57 metres.
- Complete 46.63-second driven lap passed. Flat-road chassis step stayed below 0.5 mm; maximum surface-height error was under 7 mm. Suspension stayed grounded through both approaches; the underpass, charged jump and bridge landing passed.
- Scene details and travel/mission preservation checks passed.
- Camera bounds checks passed through both full introductions and the slower return, in landscape and portrait. Minimum conservative clearance was over 0.41 metres.
- Native captures verified the rounded mat, faster framing, campsite, pond, boarding and slower swap. A coplanar patch outside the pond was removed during visual review.
- Chromium localhost check passed: Start gating, both faster flights, normal pond driving, return and revisit timing, and no game/browser console errors. Pond drive samples remained at 60 fps on this machine; the lowest truck centre was −1.30 metres on its curved route. This is a local smoke check, not a cross-device benchmark.

Browser evidence: `docs/performance/pond-and-timing-october-7.json`. Captures and test logs are in ignored `output/playwright/pond-*` files. Rebuilt web release: `builds/web/index.html`, served at `http://localhost:8064/`.
