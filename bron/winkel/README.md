# Winkel met flat (stad achter de brug)

`assets/winkel.glb` komt uit `maak_winkel.py` (`pip install bpy`): toko van drie lagen (9 x 8 m) met mintgroene pleister,
winkelpui met twee etalages, glazen winkeldeur, luifel en uithangbord (KOPI / TOKO / RIJST), daarboven twee flats met
luiken en een balkon, plat dak met borstwering, watertank, airco en antenne. Binnen: toonbank, rekken, koeling, magazijn,
en in de flats bank, bedden, keukentje, zandzakken bij het raam. Voordeur aan de +Z-kant in Godot (Blender -Y).

Bordestrap langs de westmuur: trap A (winkel -> flat 1) loopt naar achter (Blender-y -1,4 -> 2,6), trap B (flat 1 -> flat 2)
ernaast terug naar voor (2,6 -> -1,4). Vloeren: 0,3 / 3,8 / 6,8, muren tot 9,6, dakvloer tot 9,9.

Alles kan kapot, net als het woonhuis: muurstukken `M0*`, `M1*`, `M2*` (laag 0..2) en `P0..P2` met `_heel`/`_kapot`,
`Vloer1`/`Vloer2` heel en ingezakt, `Dak_heel`/`Dak_kapot`. Nieuw: `Ruine` (`RuineMesh`) is het hele gebouw ingestort,
verborgen tot het instort. Groepen: `Begane`, `Verdieping`, `Verdieping2`, `Dak`, `Puin`, `Ruine`.
In het spel: `scripts/woonhuis.gd` (soort "winkel" in `_spec`). Vijf muurstukken van flat 1 weg: flat 2 en het dak
zakken in. Vijf muurstukken van de winkel weg: alles stort in.

    python3 maak_winkel.py uit/
    python3 render.py uit/winkel.blend $PWD/uit/schuin.png "-15,-22,14" 35     # ook --geendak, --flat1, --open, --sloop, --ruine
