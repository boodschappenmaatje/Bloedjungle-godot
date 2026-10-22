# Woonhuis (stad achter de brug)

`assets/woonhuis.glb` komt uit `maak_woonhuis.py` (`pip install bpy`): koloniaal stadshuis van 2 verdiepingen (8 x 7 m) met
okergele pleister, pannendak, groene luiken, balkon, binnenkant (trap, deuren, meubels) en een tuin achter (tot 10 m).
Voordeur aan de +Z-kant in Godot (Blender -Y).

Alles kan kapot. Elk muurstuk is een knooppunt met twee kinderen `<naam>_heel` en `<naam>_kapot`:
`M0V0..M0V3`, `M0A*`, `M0W*`, `M0O*` (begane grond voor/achter/west/oost), `M1*` (verdieping), `P0`/`P1` (binnenmuren),
`T_*` (tuinmuur). Verder `Vloer1_heel`/`Vloer1_kapot` (ingezakt), `Dak_heel`/`Dak_kapot` (gat) en sjablonen in `Puin`
(`PuinGroot`, `PuinKlein`, `Brok0..3`). Groepen: `Begane`, `Verdieping`, `Dak`, `Tuin`. Deuren `DeurVoor`, `DeurAchter`,
`DeurBinnen0`, `DeurBinnen1`: het knooppunt is het scharnier.

Maten: vloer beneden 0,3, verdieping 3,2, muren tot 6,0. Trap langs de westmuur (x -3,75..-2,75), van Blender-y -1,8 tot 2,25.
In het spel: `scripts/woonhuis.gd` (+ `house_body.gd`).

    python3 maak_woonhuis.py uit/
    python3 render.py uit/woonhuis.blend $PWD/uit/schuin.png "-14,-19,13" 32            # ook --geendak, --open, --sloop, --kapot
