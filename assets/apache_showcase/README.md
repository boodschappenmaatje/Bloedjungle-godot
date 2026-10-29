# Apache Showcase — Meshy concept asset

Meshy task trail:
- Preview: `text-to-3d` task `01a18972-a4b4-75fd-8060-a8e55d0bc7b9`
- Textured refine: `text-to-3d` task `01a18973-919f-702f-a17c-2285523add49`
- Planner estimate: 30 credits total (20 preview + 10 refine); actual task credit totals were not returned in the REST task responses.

Files:
- `apache_showcase_meshy.glb`: original Meshy textured master.
- `Apache_Showcase_Source.blend`: editable Blender source imported from the master.
- `Apache_Showcase_Mobile.glb`: decimated standalone mobile trial export (target about 50k polygons).
- `meshy/preview.png`: Meshy render preview.
- `build_showcase.py`: repeatable Blender import/source/mobile export procedure.

The Meshy model is a single merged mesh with no animation tracks. It is a standalone visual trial and does not replace `assets/apache.glb` or alter gameplay. The isolated Godot scene is `tests/apache_showcase_trial.tscn`.

The generated master is photorealistically textured in the Meshy preview. The USDZ/iPhone Quick Look export is not included because the available Blender 4.3 runtime has no USD exporter enabled. The GLB can be downloaded/opened in 3D apps that support glTF, but iPhone Files Quick Look requires USDZ.
