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

Display, Graphics, Audio, Controls and Accessibility pages include resolution/window mode, timed display confirmation, frame limits, shadows, draw distance, FOV, exposure, grain/scanlines, volume/output device, key rebinding, look inversion, controller sensitivity, camera sway, text size, contrast and interaction prompts.

## Art and ambience

Road strips join continuously at bends; junctions exclude roadside clutter. Sparse mossy stones, ferns and grasses line the roads. Fog, clearings, varied trees, distant fires and figures punctuate the forest. Original synthesized wildlife, footsteps and creaks alternate with quiet intervals. Headlights remain readable against the dark woods.

The destination clearing contains a refuge with pitched roof, chimney, shutters, lit windows, covered porch, steps, bench and low walls. At the deadline, the engine and radio fall silent and the ghost appears ahead of the car.

Headlights and horn are driver-only. The horn stops on release, seat change, pause, focus loss or journey end. New journeys restore headlights and instrument lighting, with the roof lamps off. Horn volume follows Engine; environmental sounds follow Ambience.

Included art and synthesized audio are original. Radio folders accept user-supplied audio; no commercial recordings were downloaded. Character meshes are procedural. Possession, walking and combat are not implemented.

## Source and validation

- `scripts/game.gd`: driving, inputs, clock, gestures and outcomes.
- `scripts/cabin.gd`: car, passengers, hands, equipment, radio targets and mirrors.
- `scripts/cabin_lights.gd`: warm roof lamps, instrument lighting and their controls.
- `scripts/cabin_interactions.gd`: horn pad, wheel-mounted headlight button, stowed equipment and physical click targets.
- `scripts/forest.gd`, `scripts/woodland.gd`: roads, vegetation, ambience and refuge.
- `scripts/interface.gd`, `scripts/settings.gd`: menus and preferences.
- `scripts/radio.gd`: radio playback and dial animation.
- `assets/region.json`, `tools/build_region.py`: road layout and map generator.
- `tools/build_tuning.py`: short radio tuning sound, using Python's standard library.
- `tools/build_wildlife.py`, `tools/build_radio.py`: original audio generators; require NumPy when rebuilding.

Run `-- --qa=roles`, `-- --qa=smoke`, `-- --qa=night`, `-- --qa=effects`, or `-- --qa=routes` for automated checks. `-- --qa=roles_screenshots` captures the cabin controls, lamps and menus to `SINTRA_QA_OUTPUT`.

Validated on Windows in Godot 4.7.2 with the Compatibility renderer.
