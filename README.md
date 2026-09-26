# Curva de Sintra

Open `project.godot` in Godot 4.7.2 and press F5. Choose **Begin journey**, or **Play with friends** for LAN play. The cabin and forest are generated at runtime; inspect the Remote scene tree during play.

## Journey

Reach the lit São Pedro refuge before the dashboard clock reaches **00:00**. Journeys start with 15 minutes. The correct route takes approximately 12 minutes 17 seconds in the automated driving check; wrong turns use the remaining time. Solo menus pause the clock. Multiplayer menus do not pause the shared journey.

## Controls

| Role | Controls |
| --- | --- |
| Everyone | Mouse to look; hold right mouse for focus zoom; hold left mouse to point. The hand follows the direction of view. Escape opens the pause menu. |
| Driver | W/S accelerate and reverse; A/D steer; Space brakes; L toggles headlights; hold H to honk. Hands follow the rotating wheel. All three mirrors show live views. |
| Navigator | M raises/lowers the map; its car marker updates as you travel. Lower the map, aim at the physical radio, and click. Left knob: power; scroll over it: volume. Right knob: station. Bottom buttons: volume −/+, presets 1/2/3. R or controller X also activates the targeted radio control. |
| Rear passenger | C raises/lowers the camcorder. You look through its viewfinder while others see you holding it. |
| Solo | 1/2/3 change seats; also available in the pause menu. |
| Voice | Enable the microphone in Settings → Audio. Hold V for push-to-talk, or choose voice activity. |

Holding equipment suppresses pointing. Look limits keep held equipment within the cabin. Zoom is local; head direction, equipment, gestures, car motion, radio and outcomes replicate to other players.

## Settings

Display, Graphics, Audio, Controls and Accessibility pages include resolution/window mode, timed display confirmation, frame limits, shadows, draw distance, FOV, exposure, grain/scanlines, audio buses/devices, microphone gain/gate, key rebinding, look inversion, controller sensitivity, camera sway, text size, contrast and interaction prompts.

## Multiplayer

The build uses direct-IP ENet on UDP 28470. One player chooses a seat and hosts. Two others choose different seats and join using the host's reachable address. The host owns movement, radio authorization, the deadline and outcomes. Late arrivals inherit the clock and completed outcome. A disconnected driver's car stops; leaving as host ends the session.

Voice uses opt-in microphone capture and host-relayed 16 kHz PCM. Public room codes, hosting and production voice compression/echo cancellation are future work. Included tests exercise loopback connections and synthetic voice packets, not three physical microphones.

## Art and ambience

Menus use cream typography, dark translucent panels and muted brass accents. Road strips join continuously at bends; junctions exclude roadside clutter. Sparse mossy stones, ferns and grasses replace continuous boundary rocks. Headlights remain readable against darker fog and forest lighting. Original synthesized owl, fox and branch cues occasionally play from distant positions.

The final clearing contains a refuge with pitched roof, chimney, shutters, lit windows, covered porch, steps, bench and low walls. At the deadline, the engine and radio fall silent and the ghost appears ahead of the car.

Character meshes remain procedural stand-ins. Possession, walking and combat are not implemented. Included art and synthesized audio are original. Radio folders accept user-supplied audio; no commercial recordings were downloaded.

## Source and validation

- `scripts/game.gd`: driving, inputs, authority, clock, gestures and outcomes.
- `scripts/cabin.gd`: car, passengers, hands, equipment, radio targets and mirrors.
- `scripts/forest.gd`: roads, junctions, vegetation and refuge.
- `scripts/interface.gd`, `scripts/settings.gd`: menus and preferences.
- `scripts/radio.gd`, `scripts/voice.gd`: radio and voice.
- `assets/region.json`: road network; `tools/build_region.py`: region/map generator.
- `tools/build_wildlife.py`: original sound generator; requires NumPy only when rebuilding.

Run `-- --qa=smoke`, `-- --qa=night`, or `-- --qa=route` for automated checks. `-- --qa=screenshots` captures rendered views to `SINTRA_QA_OUTPUT`. Coordinated host/client modes test remote driving, radio, synthetic voice relay, pointing, the deadline and late joining after failure.

Validated on Windows in Godot 4.7.2 with the Compatibility renderer; core checks also passed in Godot 4.5.1. Internet connectivity and spoken audio quality still need a playtest across separate machines.

Headlights and horn are driver-only, replicated by the host, and available for key rebinding. The horn stops on release, pause/menu, focus loss, driver disconnect or journey end. New journeys restore headlights. Horn volume follows Engine; wind drone and shared positional footsteps/creaks follow Ambience. Environmental cues are interspersed with quiet intervals and grow subtly tenser near the deadline or with headlights off.
