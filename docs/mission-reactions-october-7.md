# Mission feedback, bridge contact, and Motorway arrival — 7 October 2026

Implemented the requested dog washing/jump/goodbye voices, ladder movement, plastic cone impacts, cloth tent impacts, ceramic pot impacts, quieter collision Foley, perimeter wood impacts, selective intro landing sounds, duck quacks, and spectator cheers. The new sounds have three original PCM variants, silent endpoints, and soft envelopes; they use the existing twelve pooled streaming players. All collision sounds receive a 0.85 amplitude multiplier. WAV import defaults preserve PCM, avoiding extra decoding during browser playback.

Barbecue contacts previously called `_update_mission()` for every water droplet. Discovery is now idempotent, and fire HUD text changes only when the displayed percentage or targeting status changes. Steam and splash effects remain pooled and shader warmup still happens before Start.

Mission completion retains the neighbour camera during the thank-you delay. This applies to Maple Bay jobs and the Motorway hose jobs. The proximity talk hint and printed race-arch numbers are removed. Kit starts facing the entrance. The train's connecting rods now follow the wheel crank.

The Motorway's first pieces begin arriving during the fly-in; the start-gate sweep continues immediately into the tour. Food court and audience assembly remain timed to their close views. The firetruck drops onto the mat and its wheels turn as it enters. Small birds fade at their original locations, using alpha materials supported by the browser renderer. Those materials are cached during warmup and replaced by the original opaque materials once the fade finishes. Intro wood/plastic landing cues are selective, camera-local, and rate limited.

The pond refills the tank at 20 units/second while immersed. Moving through it creates pooled splashes; ducks steer away from the truck while staying within the pond. During a race, nearby spectators jump, wave, and cheer with staggered reactions and cooldowns.

Bridge safety uses a separate collision layer, outside the suspension's ground-query mask. Analytic support includes the timber shoulders. Adjacent collision spans no longer contain internal end caps, and rail contact faces cover the truck's full height. A physical upper hull protects the cab from the underside. Moving the orthographic Motorway camera farther along its view axis preserves framing while avoiding foreground room clipping.

## Validation

- Godot tests: mission reactions, actual underside and rail driving contact, pond/bridge traversal, complete race driving, town audio/feedback, toy arrivals with the Compatibility renderer, complete mat round-trip, and intro/southern-edge camera bounds in landscape and portrait.
- Cab collision blocks an approach to the low bridge deck. Rail driving produced at most 1.92 cm of support-height error and 0.337 m/s of upward correction, with no launch.
- Private foreground Chrome at 1280×800, full render scale: actual barbecue spray took the fire from 0 to 100% at 60 FPS, with all 182 sampled render intervals below 18 ms. Completion retained camera blend 1.0.
- A complete browser lap took 46.63 seconds at 60 FPS: 2,828 measured intervals below 18 ms, six between 18 and 25 ms, none above 25 ms. Maximum road support error was 6.56 mm; flat-road frame-to-frame height movement was 0.414 mm.
- Browser pond check: an empty tank gained 69 units in the 3.5-second observation, with splash and quack playback. Spectators generated cheers during the lap. No console errors.
- Screenshots verified early gate assembly, food-court/audience assembly, truck touchdown, and southern-edge framing. Screenshot captures themselves can interrupt frame timing; the complete-lap measurement has no captures during driving.

Raw browser evidence is in `performance/mission-reactions-october-7.json`. The web build and upload ZIP were refreshed, with the existing localhost server serving port 8064. Measurements describe this machine and these scenarios.
