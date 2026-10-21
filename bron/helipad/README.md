# Helikopterplatform (Blender-bron)

`assets/helipad.glb` komt uit `maak_helipad.py` (`pip install bpy`). Betonplaat met een schacht van 9 x 9 m, twee stalen luiken op
hydraulische zuigers, een lift met H-markering, schachtverlichting, zwaailampen, windzak, lichtmast en bedieningskast.

    python3 maak_helipad.py uit/ ../apache/apache_anim.blend      # helipad.glb, helipad.blend, helipad_show.glb (met Apache erop)
    python3 render.py uit/helipad_show.blend uit.png 6.5 "-14,-17,9" 35 1

Hiërarchie: `Helipad` > `Romp` (stilstaand), `LuikL`/`LuikR`, `Zuiger*Basis/Stang`, `Lift`, `ZwaaiA/ZwaaiB`, lampen.
Clips: `Open`, `Dicht` (4,5 s: luiken 0-1,9 s, lift 1,4-4,4 s), `Show-loop` (viewer). In het spel draait de code de zwaailampen.
