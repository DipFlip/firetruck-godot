# Browser audio ticks, October 7

The hose was the only continuously faded sound using the browser's default Sample playback. Godot 4.7's [sample volume setter](https://github.com/godotengine/godot/blob/4.7/platform/web/js/libs/library_godot_audio.js) writes Web Audio gain values immediately. A frame-delayed start or stop can therefore make a large jump between adjacent audio samples. The remaining music, engine, speech and Foley already used Stream playback. The hose now uses that same mixer, which interpolates volume changes.

Two other abrupt stops were removed. The last 65 ms dialogue syllable finishes its existing soft release when a conversation closes. Answered phone notes fade below audibility before stopping. Existing cooldowns and the twelve-player sound pool remain in place.

The browser's preferred output latency is increased from 50 to 100 ms. On this 48 kHz browser, Godot rounds those settings to buffers of 2,048 and 4,096 frames: **42.7 → 85.3 ms** of queued audio. This gives the single-threaded mixer extra room for a brief rendering delay; the tradeoff is about **43 ms more audio latency**. Native output latency is unchanged. See [Godot's output-latency setting](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html#class-projectsettings-property-audio-driver-output-latency) and [web driver buffer calculation](https://github.com/godotengine/godot/blob/4.7/platform/web/audio_driver_web.cpp).

## Validation

`tools/check_audio_web.js` captures PCM from the game's actual Web Audio outputs in a private foreground Chromium window at 1280×800, Apple M5. A silent capture branch inspects the mix without adding another audible copy. It exercises phone/station sound, spraying by the pool, spraying by the barbecue, and repeated deliberate 75 ms main-thread stalls. Natural water depletion exercises the hose release during the stressed phase.

The saved previous web pack and updated pack use the same capture procedure. Results are in `performance/browser-audio-october-7.json`. Peak levels stay well below digital clipping in these flows; simultaneous loudness did not explain the observed waveform spike. Adjacent-sample jumps are measured directly, rather than assuming that a good graphics FPS reading implies healthy audio. This check does not prove the absence of every possible click or attribute the user's unspecified tick to a single cause.

The largest adjacent-sample jump during the stressed hose release fell from **0.02619 to 0.00592** (about **77% smaller**), while peak mix levels remained similar. The updated capture contains no fully silent output blocks. All three normal phases report **60 fps**; deliberately blocking the rendering thread lowers both builds to 53 fps in the stressed phase. This is a controlled audio stress test, not a claim of 60 fps while JavaScript is forcibly stalled.

`town_feedback_test.gd` passes both headless and with the real Compatibility renderer, including the existing sound-bank continuity, contact/cooldown, sustained hiss and ringing tests. New checks cover the final syllable's natural release, the ringing fade and consistent hose playback. Two old camera assertions were updated to the already shortened cottage/perimeter tour's current times. `water_feedback_test.gd` also passes, including pause, refill fade and full-tank release. The exported browser reports no console errors.

Reproduce with Playwright CLI `run-code --filename tools/check_audio_web.js` in a fresh headed session. An optional initial `audio-baseline` query uses `output/playwright/audio-baseline.pck`, extracted from the previous validated upload archive. The normal run checks the current `http://localhost:8064/` build. No microphone or system-audio recording is used.
