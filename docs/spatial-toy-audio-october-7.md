# Spatial toy sounds, October 7

Tire marks now use a rounded, softly modulated rubber squeal instead of the broad hiss. Its mixer level is -44 dB, 14 dB below the previous setting. The existing mark-driven, smoothly released loop remains in place.

Perimeter assembly uses three original wooden tok/clack samples, including a quiet rebound. Houses have three rising swoop samples. A sorted, cached cue schedule follows the same grow and impact timing as both CPU toys and baked vertex animation. Material batches are deduplicated by toy position, tiny sprouts and fading birds remain silent, and jumping through an intro does not release a backlog of impacts. Each frame prioritizes the nearest cue of each material, with cooldowns and the existing twelve-voice limit.

Town Foley now uses pooled AudioStreamPlayer3D voices with Stream playback. Their actual world positions provide stereo panning and distance attenuation. An explicit AudioListener3D follows the truck during gameplay and the camera's view of the mat during intros. This avoids listening from the orthographic camera hundreds of metres away, where all the scene sounds would become inaudible. Continuous refill, steam and tire sounds also use spatial voices; phone and dialogue retain their interface audio.

Validation:

- `tests/spatial_audio_test.gd` captures actual post-pan stereo PCM from the native mixer: left/right toy positions favor the corresponding channel by more than 2:1, while a toy 60 m away produces less than 15% of the nearby energy.
- `tests/intro_audio_test.gd` checks both mat schedules, one cue per toy across material batches, and listener placement. The simulated tours trigger 30 wooden landings and 7 growth cues in Maple Bay, and 16 wooden landings and 2 growth cues on the Motorway.
- The tire, town feedback, mission reactions, mat travel and Compatibility toy arrival regressions pass.
- The actual Maple Bay browser intro plays 32 wooden landings, 19 plastic landings and 7 growth cues. Captured PCM has peak 0.0788 and maximum adjacent-sample step 0.00714; 1,439 of 1,443 observed frames finish within 18 ms, with the other four below 25 ms, at 1280×800 on Apple M5. `tools/check_intro_audio_web.js` and `tools/check_motorway_audio_web.js` exercise the real browser mix and cue cadence.

The actual Motorway browser intro plays 18 wooden landings, 12 plastic landings and 2 growth cues. Peak PCM is 0.0425 and the largest adjacent-sample step is 0.0080. Of 1,560 observed frames, 1,550 finish within 18 ms, nine between 18 and 25 ms, and one between 35 and 50 ms. Final FPS is 60; both browser flows report no console errors.
