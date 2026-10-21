# Stalen schuifpoort (Blender-bron)

`assets/poort.glb` komt uit `maak_poort.py` (`pip install bpy`). Buitenkant is +Y in Blender (-Z in Godot), de poort hangt 0,55 m vóór de muur en schuift 6,8 m (2 x G) naar +X langs de buitenkant. Animatie `Paneel` (2,5 s) laat paneel en wielen schuiven; terugspelen = sluiten. De game (`scripts/gates.gd`) zoekt de stand op met `seek`.

    python3 maak_poort.py uit/
    python3 render.py uit/poort.blend uit/
    python3 viewer_glb.py uit/poort.blend uit/poort_viewer.glb   # met muur, alleen voor het 3D-voorbeeld
