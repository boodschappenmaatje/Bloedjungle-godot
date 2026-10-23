# Legervrachtwagen (Blender-bron)

`assets/vrachtwagen.glb` wordt gemaakt door `maak_vrachtwagen.py` (Blender 5.2, ook zonder scherm via `pip install bpy`):

    python3 maak_vrachtwagen.py uit/      # maakt vrachtwagen.glb, vrachtwagen.blend en vrachtwagen_olijf.png
    python3 render.py vrachtwagen.blend uit/schuin.png 9,10,6 35 [--open] [--dicht]

Zware zeswieler (6x6) in M35-stijl: lier, beschermrooster, zandzakken op de spatborden, dak met ringaffuit en .50,
uitlaatpijp achter de cabine, dubbele achterwielen, laadbak met twee banken voor 10 soldaten, spanten en een zeil
dat op- en afrolt. Ongeveer 12.000 driehoeken. Voorkant is -Z in Godot, 1 meter = 1 eenheid; het spel schaalt het model met 1,1
(zodat de soldaten van SOLDIER_SCALE 1,2 op de banken passen). In het spel: `scenes/vrachtwagen.tscn` + `scripts/vrachtwagen.gd`.

## Onderdelen

`Vrachtwagen` > `Body` > `RompMesh`, `StuurLV`/`StuurRV` (sturen) > `WielLV`/`WielRV`, `WielLM`, `WielRM`, `WielLA`, `WielRA`,
`Klep` (laadklep, scharniert om X) > `KlepMesh`, `Trap` (klapt uit),
`Zeil` > `ZeilDak` (schaal Y = hoe ver het dak is uitgerold), `RolDak`, `ZeilL`/`ZeilR` (schaal Z), `RolL`/`RolR`,
`Zit0`..`Zit9` (oorsprong van een zittende soldaat: 0,44 m onder de laadvloer), `Instap`, `Uitlaat` (bovenkant uitlaat),
lampen `KoplampL/R` (spot) en `AchterlichtL/RLamp` (punt). Materialen `Koplamp` en `Achterlicht` gloeien.

## Animaties

| Clip | Wat |
|---|---|
| `Open` | klep valt naar beneden en veert na, dan klapt het trapje uit tot vlak boven de grond (1,2 s) |
| `Dicht` | trapje klapt in, klep omhoog (1 s) |
| `ZeilDicht` | zijflappen zakken, dan rolt het dak naar achteren uit (1,8 s) |
| `ZeilOpen` | andersom |

Elke clip keyt klep, trapje én zeil; het spel haalt de sporen eruit die niet bij de clip horen en speelt het zeil op een
tweede AnimationPlayer, zodat klep en zeil tegelijk kunnen bewegen. Wielen, sturen, vering en rook doet de code.
