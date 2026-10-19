# AH-64 Apache (Blender-bron)

`assets/apache.glb` wordt gemaakt door `maak_apache.py` (Blender 5.2, ook zonder scherm via `pip install bpy`):

    python3 maak_apache.py uit/      # maakt apache.glb, apache.blend en apache_olijf.png
    python3 render.py uit/apache.blend $PWD/preview.png 9,16,4.5 38

`apache.blend` kun je ook in Blender openen en met de hand aanpassen of realistische textures geven.

Onderdelen: `Apache` > `RompMesh`, `Rotor` (hoofdrotor, draait om de hoogte-as), `Staartrotor` (draait om de X-as).
Voorkant is -Z in Godot. Ongeveer 4.200 driehoeken, 1 meter = 1 eenheid, rotor 14,6 m doorsnee.
Staat nog niet in het spel.

## Animaties

`animeer_apache.py` voegt clips toe (maakt `apache_anim.blend` en een nieuwe `apache.glb`):

| Clip | Wat | Lus |
|---|---|---|
| `Grond` | stationair draaiende rotor op de grond | ja |
| `Opstijgen` | rotor op toeren, opstijgen naar 3 m | nee |
| `Zweven` | hangen met lichte deining | ja |
| `Vliegen` | neus omlaag, vooruit vliegen | ja |
| `Bocht` | in de bocht hangen | ja |

Hiërarchie: `Apache` > `Body` > (`RompMesh`, `Rotor`, `Staartrotor`). De clips bewegen alleen `Body` en de rotors,
zodat het spel zelf `Apache` door de wereld kan sturen. Godot zet de lus aan door de `-loop` achter de naam.

`vlucht_film.py` rendert het filmpje (opstijgen van een helipad, langs de camera, wegzwenken):
`python3 vlucht_film.py uit/apache_anim.blend $PWD/film` (Cycles, ongeveer 12 s per beeld op 4 cpu's).
