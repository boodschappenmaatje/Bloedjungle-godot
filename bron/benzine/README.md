# Benzinestation (stad achter de brug)

`assets/benzine.glb` komt uit `maak_benzine.py` (`pip install bpy`): klein tankstation uit de jaren veertig. Een roomwit
winkeltje (7 x 5,2 m, plat dak met naambord TOKO BENSIN) met etalages en een rode glazen deur, ervoor een luifel van
9,6 x 5,1 m op vier betonnen kolommen met een rode rand (BENSIN / OLIE), twee pompeilanden met elk twee ouderwetse
pompen (glazen bol, wijzerplaat, slang in de houder), een prijsbord op een paal, olievaten, banden, een compressor en
jerrycans. Binnen: toonbank met kassa, sigarettenrek, rekken met oliekannen en blikken, koeling, plafondventilator; achter
de binnenmuur een opslag met werkbank, kisten en vaten. Voorkant (luifel) aan +Z in Godot (Blender -Y).

Alles kan kapot: muurstukken `M0*` en `P0` (binnenmuur) en kolommen `K0..K3` met `_heel`/`_kapot`, `Dak_heel`/`Dak_kapot`.
Het winkeltje en de luifel storten elk apart in: `RuineWinkel` en `RuineLuifel` (groep `Ruine`). De pompen `XPomp0..3` en
olievaten `XVat0..2` hebben een uitgebrande versie (`_kapot`); in het spel ontploffen ze (`scripts/pomp.gd`), met een
kettingreactie naar de andere pompen, de vaten, de kolommen en de muren. Sloopregels staan in `Woonhuis._spec_benzine()`.

    python3 maak_benzine.py uit/                                         # benzine.glb + benzine.blend
    python3 render.py uit/benzine.blend $PWD/uit/schuin.png "-13,-19,11" 35     # ook --open --sloop --kapot --ruine
    python3 maak_viewer.py ../winkel/winkel-viewer.html uit/benzine.glb uit/benzine-viewer.html  # 3D-viewer met sloop

De winkel-viewer staat in de projectbestanden (`modellen/winkel/winkel-viewer.html`).
