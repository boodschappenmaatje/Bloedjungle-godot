# Tank (Blender-bron)

`assets/tank.glb` wordt gemaakt door `maak_tank.py` (Blender 5.2, ook zonder scherm via `pip install bpy`):

    python3 maak_tank.py uit/      # maakt tank.glb, tank.blend en tank_camo.png
    python3 render.py uit/tank.blend $PWD/preview.png 9,10,7 45

`tank.blend` kun je ook gewoon in Blender openen en met de hand aanpassen of andere textures geven.
Daarna exporteren als glTF (.glb) naar `assets/tank.glb`.

Onderdelen: `Tank` > `Body` > (`RompMesh`, losse wielen, 40 rupsschakels per kant, `Uitlaat`, `Toren`) (koepel, draait om de hoogte-as) > `Loop` (kanon, kantelt) > `Monding` (punt voor flits en kogels).
Voorkant is -Z in Godot. Ongeveer 7.500 driehoeken, 1 meter = 1 eenheid.

## Animaties

| Clip | Wat | Lus |
|---|---|---|
| `Stationair` | motor draait, romp trilt licht | ja |
| `Rijden` | vooruit 3,12 m/s: wielen draaien, schakels lopen rond, romp deint | ja |
| `Achteruit` | achteruit 1,8 m/s | ja |
| `Draaien` | op de plek draaien: linker rups achteruit, rechter vooruit | ja |
| `Schieten` | kanon slaat 0,55 m terug, romp wipt na op de vering | nee |

De clips bewegen alleen `Body`, wielen, schakels en `LoopMesh`; het spel stuurt `Tank`, `Toren` en `Loop`.
Speel `Rijden` met `speed_scale = snelheid / 3.12` zodat de rups niet slipt.
