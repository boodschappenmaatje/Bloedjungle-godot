# Meshy commando V2

Player-only upgrade of Dennis's `assets/meshy_jungle_commando.glb`. The face, Tiger Stripe clothing, olive plate carrier, gloves and boots are retained. `build.py` adds a high-cut olive shell, retention straps, single-ear headset, boom mic, rear radio and antenna. The equipment is skinned to the existing head or Spine2 bone. The original 28-bone hierarchy is unchanged, and the original Walking, Running and RunFast GLB clips remain in the export; the game installs its separate 75-clip libraries.

Run `blender -b -t 4 --python bron/meshy_commando/build.py` from this repository. The script writes `meshy_commando_aaa.blend` here and `assets/meshy_commando_aaa.glb`. It reuses the project's existing olive nylon, dark webbing and parkerized steel PBR maps at `bron/soldaat_vq2/jungle_commando/`, which are packed into the source and embedded in the GLB. No new third-party textures were downloaded. The editable source includes the imported original character and the added geometry; the script is the repeatable construction record.

| Version | Triangles | Bones | Materials | Textures | GLB |
| --- | ---: | ---: | ---: | ---: | ---: |
| Source player | 60,669 | 28 | 1 | 3 | 15 MB |
| Commando V2 | 62,706 | 28 | 6 | 12 | 15 MB |

The [before/after browser capture](../../previews/meshy_commando/viewer_before_after.png) uses the existing VQ2 viewer with the same camera and lights. The [USDZ preview](../../previews/usdz/meshy_commando/v1/meshy_commando_aaa.usdz) was exported with Blender 4.5.0; its archive contains one USD layer and 12 texture files. Apple `usdchecker --arkit` and physical iPhone Quick Look were unavailable here, so the preview is **not yet device validated**. The browser's three locomotion clips are real GLB clips; Godot's weapon IK, state transitions and other action clips must be judged in the game.

Godot 4.7.2 imports the new GLB. `SoldierModel` selects it for `soldaat = meshy` and falls back to the original Meshy GLB if the new one is absent. Allies and enemies keep their existing models. Native iPhone performance: **NIET GETEST**.
