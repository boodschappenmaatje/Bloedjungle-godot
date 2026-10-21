# Uitrusting voor het mannetje (Blender-bron)

`assets/uitrusting.glb` wordt gemaakt door `maak_uitrusting.py` (Blender 5.2 via `pip install bpy`): `python3 maak_uitrusting.py uit/`.
Delen: `Helm` (DEF-head), `Rugzak` met slaaprol, riemen en borstzakken (DEF-spine003), `Koppel` met pouches, veldfles en holster (DEF-hips),
`LaarsL`/`LaarsR` (DEF-footL/R). Gemodelleerd in de ruimte van `assets/soldaat.glb` in de stilstaande houding (Godot-assen, zie het script);
`SoldierModel._attach_gear` zet ze met de omgekeerde botpose aan de botten. Eén mesh en één materiaal (hoekkleuren) per deel.
