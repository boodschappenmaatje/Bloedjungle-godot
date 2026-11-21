# VFX Reference Lab — validation evidence

Date: 2026-11-16. Engine: Godot 4.7.2 stable (`ed1daf0bf`). Repository: `Bloedjungle-godot`, branch `feature/vfx-reference-lab-1-0`.

## Validation

| Check | Result |
| --- | --- |
| Godot 4.7.2 project import | **PASS**, editor import exited 0; no VFX lab asset import or script errors |
| VFX lab smoke test | **PASS** — scene/camera, both tracer lanes and target direction, wood/concrete/metal, High/Mobile tiers, bounded pools, and gameplay/settings isolation |
| Lab runtime | **PASS** — scene ran for 180 frames with no VFX GDScript or parse error |
| Existing Colt VFX regression test | **PASS** — `tests/colt_vfx_test.gd` |
| High video | **PASS** — 1280×720, H.264, 75 frames, 30 fps playback timebase, 2.5 seconds |
| Mobile video | **PASS** — 1280×720, H.264, 75 frames, 30 fps playback timebase, 2.5 seconds |
| Native Godot Mobile/Vulkan render | **NOT TESTED** — no Vulkan ICD/device is available in this runner |
| Windows build and physical iPhone | **NOT TESTED** |

The screenshot and H.264 captures are direct exports from Godot Movie Maker using Mesa llvmpipe software OpenGL in a local X server. The 30 fps video timebase is only the encoded playback rate; it is not a measured render rate.

## Render timing

| Lab preset | CPU render average | GPU render average | Render backend |
| --- | ---: | ---: | --- |
| High | 352.07 ms/frame | 353.24 ms/frame | Mesa llvmpipe software OpenGL, GL Compatibility |
| Mobile | 54.70 ms/frame | 170.85 ms/frame | Mesa llvmpipe software OpenGL, GL Compatibility |

The capture ran at 1280×720 with a fixed 30 fps movie timebase. These software-renderer timings are well above the 16.67 ms budget for 60 fps. The Mobile preset lowers the lab's effect quality tier and disables lab glow/shadows, but this is not a phone or hardware-GPU measurement. Do not infer iPhone FPS from these results.

## Known environment limits

- The sandbox blocks writes to `/home/agent/.local/share/godot` and `user://`. Godot therefore logs user-data/logbook errors from the pre-existing Updater/Game autoloads. These errors come from the restricted runner paths; the lab script and smoke assertions pass.
- Godot reports 7 ObjectDB instances leaked at process shutdown in this runner. This appears with the existing project autoloads as well as the lab scene and needs a writable-user-dir run to isolate further.
- The Mobile preset was exercised under llvmpipe GL Compatibility. Godot's actual Mobile renderer uses Vulkan and was unavailable here.

## Captures

- [High preset screenshot](vfx-reference-high.png)
- [High preset animation](vfx-reference-high.mp4)
- [Mobile preset screenshot](vfx-reference-mobile.png)
- [Mobile preset animation](vfx-reference-mobile.mp4)
