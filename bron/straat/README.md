# Straatset (stad achter de brug)

`assets/straat.glb` komt uit `maak_straat.py` (`pip install bpy`): de wegdelen van de stadseditor als modellen met texturen.
Elk wegdeel is 6 x 6 m (`Stad.CELL`), het plein 12 x 12 m. Asfalt op 0,03 m, stoep met betonnen stoeprand op 0,12 m.

Delen: `Recht` (stippellijn, putdeksel, kolken), `Bocht` (ronde stoeprand binnen 1 m / buiten 5 m, gebogen stippellijn),
`TStuk`, `Kruis` (vier ronde stoephoeken), `Steeg` (2 m kinderkopjes), `Zebra` (zebrapad), `Stoep` (vol tegels), `Plein`
(keien, stenen rand en cirkel) en `Fontein` (los, het spel zet er een botsvorm omheen). Samen 862 driehoeken.

Texturen (zelf gemaakt met numpy, klein voor de iPhone): asfalt 512 px per 12 m, stoeptegels en keien 256 px met normal map,
natuursteen, wegverf, putdeksel en kolkrooster. Asfalt, Stoep, Keien en Steen krijgen in het spel wereld-UV
(`Stad.WORLD_UV`): `Stad.rebuild_roads()` voegt alle wegdelen samen tot één mesh met één vlak per materiaal en rekent de UV van
de bovenvlakken uit de wereldpositie, zodat de texturen naadloos doorlopen over gedraaide en gespiegelde delen.

    python3 maak_straat.py uit/                                           # straat.glb + straat.blend
    python3 render.py uit/straat.blend $PWD/uit/overzicht.png "12,-26,22" "12,-4,0" 32
    python3 maak_viewer.py uit/straat.glb uit/straat-viewer.html

Na een nieuwe straat.glb: kopieer naar `assets/`, importeer (`godot --headless --path . --import`) en maak de knoppen
opnieuw: `xvfb-run -a godot --rendering-driver opengl3 --path . -s tools/stad_icons.gd -- weg`.
