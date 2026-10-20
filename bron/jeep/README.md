# Jeep met schutter (Blender-bron)

`assets/jeep.glb` wordt gemaakt door `maak_jeep.py` (Blender 5.2, ook zonder scherm via `pip install bpy`):

    python3 maak_jeep.py uit/      # maakt jeep.glb, jeep.blend en jeep_olijf.png

Willys-achtige legerjeep met een .50 MG op een paal, een staande schutter en een bestuurder. Ongeveer 5.300 driehoeken.
Voorkant is -Z in Godot, 1 meter = 1 eenheid. Staat nog niet in het spel.

## Onderdelen

`Jeep` > `Body` > `RompMesh`, `Bestuurder`, `StuurLV`/`StuurRV` (sturen, draait om de hoogte-as) > `WielLV`/`WielRV`,
`WielLA`, `WielRA`, lampen `KoplampL/R` (spot) en `AchterlichtL/RLamp` (punt), en
`Geschut` (draait om de hoogte-as) > `MG` (terugslag) > `Monding` > `Vlam`, plus `Schutter` > `Bovenlijf`.
De schutter staat in `Geschut` en draait dus mee als het spel het geschut richt.

Lampen: materialen `Koplamp` en `Achterlicht` gloeien (emissie); de lichtbronnen zitten in de glb
(export in RAW-modus, dus de waarden zijn direct Godot-lichtsterktes). Remlicht = emissie van `Achterlicht` hoger zetten.

## Animaties

| Clip | Wat | Lus |
|---|---|---|
| `Stationair` | motor draait, alles trilt licht | ja |
| `Rijden` | 8 m/s: wielen rollen, vering deint | ja |
| `Achteruit` | 3 m/s achteruit | ja |
| `Bocht` | voorwielen 26 graden ingestuurd, carrosserie helt over | ja |
| `Remmen` | neus duikt, wielen stoppen | nee |
| `Vuren` | MG vuurt 8 schoten per seconde: terugslag, mondingsvlam, hulzen, schutter schokt mee | ja |
| `Rondkijken` | schutter draait het geschut 70 graden links en rechts | ja |
