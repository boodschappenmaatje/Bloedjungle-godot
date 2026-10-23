# Straatmeubilair (stad achter de brug)

`assets/straatmeubilair.glb` komt uit `maak_straatmeubilair.py` (`pip install bpy`): 13 straatdingen met eigen texturen
(hout, bast, blad, geschilderd staal, jute, beton, verkeersbord; allemaal klein, 128-256 px). Samen 2120 driehoeken.

Objecten (één mesh per ding, voorkant = +Z in Godot): `Lantaarn` (gietijzer met lampkap; materiaal `LampGlas` is emissief),
`Bankje`, `Bushokje` (met glas, reclamepaneel en haltebord), `Prullenbak`, `Hek`, `Zandzakken`, `Puin`, `Boom`, `Struik` en nieuw:
`Container` (vuilcontainer), `Bord` (verboden in te rijden), `Stoplicht`.

`assets/brandkraan.glb` (zelfde script, eigen export) is de brandkraan met animatie: `Romp`, `Dop` (knalt eraf), `Straal` (waterkolom met bogen
tot 3 m hoog, draait rond) en 24 `Druppel`-objecten. Clips: `Spuit` (3 s: dop vliegt omhoog, tuimelt en stuitert, de straal groeit, druppels komen
op gang) gevolgd door `Spuiten-loop` (1,5 s lus). Spel: `scripts/brandkraan.gd` (kogels, ontploffing of voertuig in groep `voertuigen`),
mist, druppels en plas als deeltjes. `scripts/lantaarn.gd`: lamp, licht en gloed bij avond en nacht.

`Stad._prop()` pakt de mesh bij naam (`Stad.PROP_PARTS`; lantaarn en brandkraan hebben eigen scripts) en zet er een botsvorm omheen (`Stad.PROP_BOXES`: bankje, bushokje,
zandzakken, puin, boom, container, prullenbak; de brandkraan heeft een eigen botsvorm). Auto's staan er nog als blokken in code: dat is de volgende stap.

    python3 maak_straatmeubilair.py uit/
    python3 render.py uit/straatmeubilair.blend $PWD/uit/a.png "9,-9,3.5" "9,0,1.1" 40
    python3 render_brandkraan.py uit/straatmeubilair.blend $PWD/uit/h.png 30 "37,-6,1.4" "33,0,1.5" 40   # beeldje 30 van de uitbarsting
python3 maak_viewer.py uit/straatmeubilair.glb uit/brandkraan.glb uit/straatmeubilair-viewer.html

Na een nieuwe glb: kopieer naar `assets/`, importeer, en maak de knoppen opnieuw:
`xvfb-run -a godot --rendering-driver opengl3 --path . -s tools/stad_icons.gd -- straat`.
