# Curva de Sintra

Open `project.godot` in Godot 4.7.2 and press F5. Choose **Play**. The cabin and forest are generated at runtime.

## Journey

Reach the lit São Pedro refuge before the dashboard clock reaches **00:00**. Journeys start with 15 minutes. Several routes take roughly 12–14 minutes in automated driving checks; wrong turns use the remaining time. Menus pause the journey.

## Controls

| Role | Controls |
| --- | --- |
| Everyone | Mouse to look; hold right mouse to focus; hold left mouse to point. Escape pauses. **1** driver, **2** navigator, **3** rear camera operator. |
| Driver | W/S or up/down accelerate, brake and reverse; A/D or left/right steer. Hold left mouse on the wheel centre to honk. Click the button on the wheel’s left spoke for headlights. Hands follow the wheel; all three mirrors show live views. |
| Navigator | Click the folded map on the dashboard to unfold it; click again to fold it away. Put it away to use the radio: click the left knob for power, drag it right or scroll up to increase volume; click the right knob for station. Bottom buttons provide volume −/+, and presets 1/2/3. |
| Front seats | Click the front roof lamp for warm on/off lighting. Instruments remain softly lit. |
| Camera operator | Click the camcorder on the seat to your right to pick it up. Click while filming to put it back. Click the rear roof lamp for warm on/off lighting. |

Driving and seat-switching bindings can be changed in Settings. All cabin controls and equipment use physical mouse interactions. Controller triggers drive, left stick steers, right stick looks and Start pauses.

Holding equipment suppresses pointing. Look limits keep held equipment within the cabin. Changing seats preserves the previous occupant's map or camcorder pose so it can be viewed from another seat.

## Settings

Display, Graphics, Audio, Controls and Accessibility pages include resolution/window mode with immediate preview and timed confirmation, frame limits, shadows, draw distance, FOV, exposure, grain/scanlines, volume/output device, key rebinding, look inversion, camera sway, text size, contrast and interaction prompts.

## Art and ambience

Roads share a single triangulated surface with rounded junctions. Dead-end turnoffs sit away from the main intersections. Slim, dark galvanized-metal post-and-rail barriers follow the outside road boundary, with full-car collision checks and a quiet, rate-limited impact sound. Sparse mossy stones, ferns and grasses line the roads. Fog, clearings, varied trees, distant fires punctuate the forest. Original synthesized wildlife, footsteps and creaks alternate with quiet intervals. Headlights remain readable against the dark woods.

The destination clearing contains a refuge with pitched roof, chimney, shutters, lit windows, covered porch, steps, bench and low walls. At the deadline, the engine and radio fall silent and the ghost appears ahead of the car.

Headlights and horn are driver-only. The horn stops on release, seat change, pause, focus loss or journey end. New journeys restore headlights and instrument lighting, with the roof lamps off. Horn volume follows Engine; environmental sounds follow Ambience.

The hanging wooden shield carries the supplied IST symbol. Other included art and synthesized audio are original. Radio folders accept user-supplied audio; no commercial recordings were downloaded. Character meshes are procedural. Possession, walking and combat are not implemented.

## Source and validation

- `scripts/game.gd`: driving, inputs, clock, gestures and outcomes.
- `scripts/cabin.gd`: car, passengers, hands, equipment, radio targets and mirrors.
- `scripts/cabin_lights.gd`: warm roof lamps, instrument lighting and their controls.
- `scripts/cabin_interactions.gd`: horn pad, wheel-mounted headlight button, stowed equipment and physical click targets.
- `scripts/forest.gd`, `scripts/woodland.gd`: roads, vegetation, ambience and refuge.
- `scripts/guardrails.gd`: batched roadside barriers and collision checks.
- `scripts/pendant.gd`, `assets/ist_wood.svg`: wooden IST pendant.
- `scripts/interface.gd`, `scripts/settings.gd`: menus and preferences.
- `scripts/radio.gd`: radio playback and dial animation.
- `assets/region.json`, `assets/road_geometry.json`, `tools/build_region.py`: shared road geometry and paper map; rebuilding requires Pillow and Shapely 2.1.
- `tools/build_impact.py`: barrier impact audio generator.
- `tools/build_tuning.py`: short radio tuning sound, using Python's standard library.
- `tools/build_wildlife.py`, `tools/build_radio.py`: original audio generators; require NumPy when rebuilding.

Run `-- --qa=barriers`, `-- --qa=roles`, `-- --qa=smoke`, `-- --qa=night`, `-- --qa=effects`, or `-- --qa=routes` for automated checks. `-- --qa=roles_screenshots` captures the cabin controls, lamps and menus to `SINTRA_QA_OUTPUT`.

Validated on Windows in Godot 4.7.2 with the Compatibility renderer.

Display mode and resolution changes preview immediately; Keep changes saves them, while Revert or the 12-second timeout restores the last confirmed display. In fullscreen and borderless modes, resolution sets 3D render detail while menus stay at native screen clarity. Windowed mode changes the window dimensions. Use a separate game window when testing display modes in the Godot editor.

Driving uses progressive acceleration and steering, reduced steering lock at speed and a quicker return to centre. Opposite driving input brakes before reversing. The compact rounded instrument cluster has live speed and RPM needles, a resettable journey trip counter and a headlamp telltale. Its markings are subdued and its faces stay dark when cabin lights change. Controller options are hidden from Settings.
