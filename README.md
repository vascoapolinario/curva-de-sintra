# Curva de Sintra — in-car prototype

A three-player first-person horror prototype for **Godot 4.7**, using the Compatibility renderer. All meshes, textures, map artwork and ambience in this prototype are original; no asset downloads or add-ons are needed.

## Play

Open `project.godot` in Godot and press **F5**. The entry scene is `scenes/main.tscn`.

Choose **Drive alone** to test immediately. You can switch between the three seats with **1 / 2 / 3** in this mode. The car coasts to a stop when you leave the driver's seat. Escape pauses solo driving and opens settings.

| Seat | Controls |
|---|---|
| Driver | **W / S** accelerate, brake and reverse; **A / D** steer; **Space** brake. Arrow keys also work. |
| Front-right navigator | **M** raises/lowers a folded physical map. The PNG is on a 3D surface and matches the playable road layout. |
| Rear camera operator | **C** raises/lowers the camcorder, narrows the field of view and enables the green low-light recording effect. A roadside apparition is visible only through the camcorder. |
| Everyone | **Mouse** looks around; **Escape** menu / mouse release; **F11** fullscreen. |
| Voice | Enable the microphone in the menu, then **hold V** to transmit. Microphone capture is off by default. |

The paper map identifies the start, the two junctions, both dead ends and the São Pedro shelter. It is a fictional local route diagram, not a tourist map. Reach the illuminated shelter to win. The map contains the route notes: first junction right, second junction left. Dead ends require reversing or turning around.

## Three-player session

1. Give each player the same project folder. Each runs it with Godot F5.
2. One player chooses a seat and clicks **Host a car**. The host can take any of the three seats.
3. The other two players choose different seats, enter the host computer's local IP address and click **Join a car**.
4. Enable each microphone in the menu and hold **V** to talk. Headphones avoid acoustic feedback.

This prototype uses **LAN / direct IP**, on **UDP port 28470**. The host must be reachable; the operating system may ask the user to allow Godot on their network. Internet play requires appropriate routing/port forwarding or a shared virtual LAN. There is no public lobby, relay or automatic NAT traversal.

Only the assigned driver can move the car; changing seats with 1/2/3 is disabled in multiplayer. Menus do not pause the shared world. Releasing input, opening the driver's menu, or losing driver updates stops acceleration. If the driver disconnects, the car stops and that seat becomes available. If the host leaves, the session ends cleanly. There is no host migration.

Voice uses 16 kHz mono PCM in 20 ms packets, relayed by the host on a separate ENet channel. This is a lightweight LAN prototype, not a production voice service: no Opus compression, echo cancellation, recording, encryption or relay service. Windows microphone access and the default input device must be working. A microphone can be disabled again at any time in the menu.

## Aesthetic and scope

- Dark textured cabin with an old dashboard, cassette radio, cloth seats, hanging rosary and live rear-view mirror.
- Warm headlights, fog, dense low-poly pines, road reflectors and engine/forest ambience.
- Pixelation, restrained film grain, scanlines, desaturation and vignette. Exposure and mouse sensitivity are adjustable in the menu.
- Two meaningful junctions, two blocked dead ends and a reachable destination.
- Three seated character stand-ins, synchronized head look and tool state.

**Possession is intentionally not implemented** in this first in-car prototype. There is no walking, combat, inventory, matchmaking or video-file recording. The camcorder is a visual viewing tool. The driving uses a kinematic bicycle model with a road-edge boundary and blocked dead ends, rather than a full suspension/damage simulation. Character models are simple stand-ins that can later be replaced with rigged art.

## Edit the prototype

The main scene builds the cabin and forest at runtime. The editor scene tree is therefore intentionally small; use the **Remote** scene tree during play to inspect the generated objects.

| File | Purpose |
|---|---|
| `scripts/game.gd` | Menus, input, driving, host-authoritative networking, seat allocation, win condition. Exports top speed, acceleration and mouse sensitivity on the main node. |
| `scripts/forest.gd` | Deterministic forest, route splines, junction signs, blockers, shelter and apparition. Edit `ROUTES` for the layout. |
| `scripts/cabin.gd` | Interior geometry, seat positions, characters, tools, mirror and animation. `EYES` sets the three camera positions. |
| `scripts/voice.gd` | Opt-in microphone capture, push-to-talk, packet validation and playback. |
| `scripts/geometry.gd` | Shared beveled mesh and material helpers. |
| `shaders/analog.gdshader` | Pixel size, film grain, vignette, exposure and camcorder color. |
| `assets/sintra_map.png` | Replaceable map image. Update it if the roads change. |
| `tools/make_assets.py` | Rebuilds original procedural textures, map and ambience. Optional; requires Python + Pillow and uses Windows Georgia for the map. Not needed to play. |

Suggested next production step: replace the seated stand-ins with a rigged car interior and characters, then build the possession loop on the existing host-authoritative seat ownership.

## Validation

Tested in Godot **4.7.2** on Windows, with the OpenGL Compatibility renderer.

- Imported and ran the project; checked rendered images from all three seats.
- Automated driving/braking, raised map, camcorder reveal and destination checks.
- Drove the complete correct route with a test controller through the same movement function used in normal play.
- Ran three separate local processes: host driving and client driving; verified unique seats, vehicle replication, passenger input rejection, synthetic voice packet relay and synchronized arrival.

Spoken audio quality with three physical microphones and connectivity across separate computers still need a teammate playtest. Automated checks use synthetic audio and loopback networking, and do not activate the microphone.

The optional development checks use `-- --qa=smoke`, `-- --qa=route`, or `-- --qa=screenshots`. Screenshot capture uses the `SINTRA_QA_OUTPUT` environment variable if set, otherwise the project's Godot user-data directory. The `host`, `host_remote`, `join0`, `join1`, and `join2` QA modes are coordinated integration checks and are not game modes.

Godot API references: [High-level multiplayer](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html), [AudioEffectCapture](https://docs.godotengine.org/en/stable/classes/class_audioeffectcapture.html), [AudioStreamGenerator](https://docs.godotengine.org/en/stable/classes/class_audiostreamgenerator.html).
