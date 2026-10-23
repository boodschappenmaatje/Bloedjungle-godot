# Hotel (stad achter de brug)

`assets/hotel.glb` komt uit `maak_hotel.py` (`pip install bpy`): hotel van vier lagen (10 x 9 m) met okergele pleister en groene
luiken. Lobby (hoog, tegelvloer) met balie, sleutelbord, zithoek, een bar met krukken en flessenrek, keukentje en opslag achterin;
daarboven drie verdiepingen met elk vier kamers (bed, nachtkastjes, kast, tafeltje), verbonden door vier deuren. Boven de entree
een balkon, voor de lobby een rood-wit gestreepte luifel met BAR / HOTEL / KAMERS, op het plat dak een dakreclame HOTEL, watertank
en antenne. Voorkant (entree) aan +Z in Godot (Blender -Y).

Bordestrap langs de westmuur: A (lobby -> 1) en C (2 -> 3) lopen naar achter, B (1 -> 2) ernaast terug naar voor. Vloeren 0,3 / 3,8 /
6,8 / 9,8, muren tot 12,6, dakvloer tot 12,9.

Alles kan kapot: muurstukken `M0*..M3*` (laag 0..3), kamerwanden `P0`, `P1a..P3c`, met `_heel`/`_kapot`; `Vloer1..3` heel en
ingezakt, `Dak_heel`/`Dak_kapot`, `Ruine` (`RuineMesh`) is het hele gebouw ingestort. Groepen: `Begane`, `Verdieping`,
`Verdieping2`, `Verdieping3`, `Dak`, `Puin`, `Ruine`. Sloopregels in `Woonhuis._spec_hotel()`: vijf muren van een verdieping weg =
alles erboven en het dak zakt in; zes muren van de lobby weg = het hele hotel stort in.

    python3 maak_hotel.py uit/                                          # hotel.glb + hotel.blend
    python3 render.py uit/hotel.blend $PWD/uit/schuin.png "-17,-24,16" 35   # ook --kamers --open --kapot --sloop --ruine
    python3 maak_viewer.py ../winkel/winkel-viewer.html uit/hotel.glb uit/hotel-viewer.html

De winkel-viewer staat in de projectbestanden (`modellen/winkel/winkel-viewer.html`).
