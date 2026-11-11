# Apache Showcase — Meshy concept asset

Meshy task trail:
- Preview: `text-to-3d` task `01a18972-a4b4-75fd-8060-a8e55d0bc7b9`
- Textured refine: `text-to-3d` task `01a18973-919f-702f-a17c-2285523add49`
- Planner estimate: 30 credits total (20 preview + 10 refine); actual task credit totals were not returned in the REST task responses.

Files:
- `apache_showcase_meshy.glb`: original Meshy textured master.
- `Apache_Showcase_Source.blend`: editable Blender source imported from the master.
- `Apache_Showcase_Mobile.glb`: decimated standalone mobile trial export (50k body polygons) with separate main/tail rotor pivots and five animation clips.
- `meshy/preview.png`: Meshy render preview.
- `build_showcase.py`: repeatable Blender import, rotor assembly, animation, source and mobile export procedure.

The Meshy master is a single merged mesh. `build_showcase.py` adds separate rotor assemblies and creates five Blender/GLB clips: `Grond`, `Opstijgen`, `Zweven`, `Vliegen`, and `Bocht`. The animation clip tracks rotate the main and tail rotors; body motion is local to the clips. This is a standalone visual trial and does not replace `assets/apache.glb` or alter gameplay. The isolated Godot scene is `tests/apache_showcase_trial.tscn`.

The generated master is photorealistically textured in the Meshy preview. The USDZ/iPhone Quick Look export is not included because the available Blender 4.3 runtime has no USD exporter enabled. The GLB can be downloaded/opened in 3D apps that support glTF, but iPhone Files Quick Look requires USDZ.

The isolated Godot trial scene autoplays `Grond`; keys 1–5 select `Grond`, `Opstijgen`, `Zweven`, `Vliegen`, and `Bocht`.

- `Apache_Showcase_iPhone.usdz`: static USDZ package for iPhone Files / Quick Look. It preserves the textured model and rotor geometry; the animated clips remain in the GLB.
- `build_usdz.py`: creates and validates the USDZ package from the mobile GLB (requires Python packages `usd-core` and `pygltflib`).
