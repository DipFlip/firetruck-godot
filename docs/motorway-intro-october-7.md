# Motorway Race Club introduction — 7 October 2026

Laps now allow one full road width (13 m) of grass beyond either asphalt edge. The centreline cancellation limit is therefore 19.5 m. Going farther resets the lap and immediately hides its timer without a cancellation message. The race-arrival instruction toast is removed, and travel clears any pending toast before the intro starts. Ordered gates and saved personal records remain unchanged.

The playroom has matching north and west star-papered walls and skirting. Incoming mats lift from the south edge as if held while shaking out a sheet. The lift tapers to zero where the unwound sheet meets the spiral. Outgoing mats use a separate gathering mode, keeping the remaining unrolled fabric flat on the floor. Both directions retain the continuous, thick carpet mesh.

Both handwritten names begin at four seconds into their incoming intro, two seconds later than previously. They finish at 19 seconds and hold before fading during the truck handover. The race name is now **Motorway Race Club**, including Kit's welcome dialogue.

The first race tour sweeps through START early, turns toward the food court and watches its building and small toys assemble. It then follows the track over the bridge to the western audience. Bench pieces arrive before the falling spectators, while the raised camera focus keeps them in frame. The tour finally heads toward the north entrance where the truck arrives. Other toy arrivals stay scattered throughout the mat. Subsequent visits retain the short 2.8-second carpet swap.

## Validation

- Mat-travel checks pass the grass allowance, immediate timer removal, absence of cancellation messages, ordered lap completion, saved records and town-state preservation.
- Room/train checks pass both walls, separate incoming/outgoing mat modes, both delayed titles, the club name, no race-arrival instructions, short swaps and preserved toy positions.
- Town-feedback checks pass continuous camera curves, intro timing, complete-title hold and smooth control handover.
- The full town-additions suite passes the updated title delay, intro/skip controls, puddle interaction, real train pushing and recoil, conductor boarding and the train's powered return.
- The camera regression samples both full tours and short return in landscape and portrait. No visible geometry bounds intersect the near plane; minimum conservative clearance is 25.6 units with the new west wall.
- Native Compatibility-renderer and Chromium/WebGL screenshots inspect the held mat, flat gathering motion, start gate, food court, falling audience and complete handwriting. Browser QA also starts a lap, drives 12 m beyond the asphalt edge, exceeds the 13 m allowance, starts another attempt and returns to Maple Bay. The return takes 3.128 seconds including command/telemetry delay. Browser/game console errors: none. [Browser report](performance/motorway-intro-october-7.json).

The Web export and upload ZIP are refreshed for localhost port 8064. No Git commit or remote deployment was made.
