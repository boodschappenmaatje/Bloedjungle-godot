# Garage / motorpool (Blender-bron)

`assets/garage.glb` komt uit `maak_garage.py` (`pip install bpy`): legerhangar van golfplaat met rolpoort, camonet, zandzakken,
antenne, olievaten, banden, takel, werkbank en een bord MOTORPOOL. Deur aan de +Z-kant in Godot (Blender -Y).
Terrein 7,8 x 8,6 m (het gebouw zelf 6,4 breed, rechts een erf met vaten en banden).

Onderdelen: `Romp` (stilstaand), `Deur` (rolpoort, clips `Open` en `Dicht`), `Zwaai/ZwaaiKap` (waarschuwingslicht, draait de code),
`Kraan/Arm/Haak` (takel, zwaait de code), lampen `DeurLampL/R`, `ZwaaiLicht`, `BinnenLamp`. Clip `Show-loop` is voor de 3D-viewer.

    python3 maak_garage.py uit/
    python3 render.py uit/garage.blend $PWD/g.png "-4,-13,5.5" 38
