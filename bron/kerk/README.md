# Oude kerk met toren (stad achter de brug)

`assets/kerk.glb` komt uit `maak_kerk.py` (`pip install bpy`): verweerd kerkje met een schip van 9,5 x 14 m onder een
zadeldak van oude pannen (mos, zwarte aanslag, ontbrekende pannen) en een vierkante klokkentoren van 5 x 5 m aan de
voorkant. Vergeelde witkalk met schimmelstrepen, scheuren en kale plekken (natuursteen), steunberen, spitsboogramen met
kapot glas-in-lood, roosvenster, uurwerk, kantelen en pinakels. Binnen: banken (sommige omgevallen), altaar, preekstoel,
doopvont, zandzakken; in de toren het uurwerk, de klok in de klokkenstoel en bovenop een uitkijkpost met vlag.

Toren: vloeren 0,3 / 3,9 / 7,5 / 11,1. Drie steile houten trappen (A en C langs de westmuur, B langs de oostmuur) brengen
je tot op het torendak; C is een ladder door het luik. Torendeur aan +Z in Godot (Blender -Y).

Alles kan kapot: muurstukken `M0*..M3*` (toren), `P0` (boog naar het schip), `S0*` (schip) met `_heel`/`_kapot`,
`Vloer1..3` heel en ingezakt, `Dak_heel`/`Dak_kapot`. Toren en schip storten elk apart in: `RuineToren` en `RuineSchip`
(in groep `Ruine`, verborgen tot het instort). Sloopregels staan in `Woonhuis._spec_kerk()` (scripts/woonhuis.gd).

    python3 maak_kerk.py uit/                                         # kerk.glb + kerk.blend
    python3 render.py uit/kerk.blend $PWD/uit/schuin.png "-22,-30,18" 35 --doel=0,0,5     # ook --sloop --ruine --toren=2
    python3 maak_viewer.py ../winkel/winkel-viewer.html uit/kerk.glb uit/kerk-viewer.html  # 3D-viewer met sloop
