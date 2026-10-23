# Straatmeubilair (stad achter de brug)

`assets/straatmeubilair.glb` komt uit `maak_straatmeubilair.py` (`pip install bpy`): 13 straatdingen met eigen texturen
(hout, bast, blad, geschilderd staal, jute, beton, verkeersbord; allemaal klein, 128-256 px). Samen 2304 driehoeken.

Objecten (één mesh per ding, voorkant = +Z in Godot): `Lantaarn` (gietijzer met lampkap; materiaal `LampGlas` is emissief),
`Bankje`, `Bushokje` (met glas, reclamepaneel en haltebord), `Prullenbak`, `Hek`, `Zandzakken`, `Puin`, `Boom`, `Struik` en nieuw:
`Brandkraan`, `Container` (vuilcontainer), `Bord` (verboden in te rijden), `Stoplicht`.

`Stad._prop()` pakt de mesh bij naam (`Stad.PROP_PARTS`) en zet er een botsvorm omheen (`Stad.PROP_BOXES`: bankje, bushokje,
zandzakken, puin, boom, container, prullenbak, brandkraan). Auto's staan er nog als blokken in code: dat is de volgende stap.

    python3 maak_straatmeubilair.py uit/
    python3 render.py uit/straatmeubilair.blend $PWD/uit/a.png "9,-9,3.5" "9,0,1.1" 40
    python3 maak_viewer.py uit/straatmeubilair.glb uit/straatmeubilair-viewer.html   # sjabloon: ../straat/maak_viewer.py-stijl

Na een nieuwe glb: kopieer naar `assets/`, importeer, en maak de knoppen opnieuw:
`xvfb-run -a godot --rendering-driver opengl3 --path . -s tools/stad_icons.gd -- straat`.
