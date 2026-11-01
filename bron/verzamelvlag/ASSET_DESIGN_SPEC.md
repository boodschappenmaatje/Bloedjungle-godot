# Asset Design Specification: Verzamelvlag (Rally Flag)

Status: **VOORSTEL, wacht op expliciete goedkeuring van Dennis** (zie docs/ASSET_QUALITY_STANDARD.md, "Nieuwe modellen: ontwerp vóór productie"). Plan: docs/GENERALS_PLAN.md, stap 2b.

## Keuzes van Dennis (2026-11-01)
1B groter (paal 3 m, doek 1,1 × 0,7 m) · 2A olijfgroen doek, gouden rand, ster in het midden · 3A houten paal in een stapel zandzakken · 4A doek wappert zacht (goedkope animatie) · 5A zachte gouden ring op de grond · 6A klein gouden lampje bovenaan de paal (alleen gloed, geen echt licht) · hoge kwaliteit, zo realistisch mogelijk, kwaliteitsniveau van bunker en hangaar.

## Rol in de game
Visuele markering van het verzamelpunt van een kazerne. Vervangt `Buildings._make_flag()` (scripts/buildings.gd). Contract blijft gelijk: node-naam `Verzamelvlag`, positie = `b.rally` op de grond, zichtbaarheid via `_flag_visible()` (alleen bij stand "vlag" of in het bouwscherm), geen collision, geen interactie.

## Onderdelen
| Onderdeel | Beschrijving |
|---|---|
| Paal | Gedraaid houten paal 3,0 m, Ø 0,08 m aan de voet naar Ø 0,055 m boven, lichte slijtage en kopse nerf. Messing ring onder de punt. |
| Punt | Messing speerpunt of knop (~0,12 m) boven de lamp-ring. |
| Doek | 1,1 × 0,7 m, aan de paal bevestigd met drie touwlussen. Olijfgroen canvas, geweven normal map, gouden rand 0,04 m (gestikte zoom), ster in het midden (geborduurd, licht verheven). Hangt vanaf ca. 2,55 m. Dubbelzijdig. |
| Lamp | Klein amberkleurig glazen lampje (Ø 0,10 m) in een messing kooi, bovenaan. Emissief materiaal "Lamp_Emissive"; Godot zet de gloed alleen bij Avond/Nacht (geen echte lichtbron). |
| Voet | Stapel van ca. 14 zandzakken in twee lagen (Ø ca. 1,2 m, hoogte 0,45 m) met gedeukte, ongelijke vormen, canvas met lichte vlekken; de paal staat er middenin. |
| Grondring | Niet in de GLB. Godot-mesh/shader: dunne gouden ring Ø 3,0 m, zachte puls, hergebruikt per vlag. |

## Animatie
- Blender-clip `Wapperen-loop`: 2,0 s, naadloze lus, golf van paal naar de vrije rand via een skinned keten van 6 botten op het doek. Alleen deze ene clip (keuze 4A).
- Godot-gestuurd: lamp-gloed (aan/uit en lichte puls), grondring-puls, zichtbaarheid.
- Geen nepclips: de viewer toont de echte clip met een zichtbare knop.

## Pivots, assen en namen
Oorsprong = midden van de voet op de grond. Godot: Y omhoog, doek wijst naar +X. Hiërarchie: `Verzamelvlag > Voet, Paal, Punt, Lamp, Doek (skinned, armature "Doek_Rig")`. Clip op de AnimationPlayer: `Wapperen-loop`.

## Materialen en textuur
Hergebruik van de goedgekeurde VQ2-families in `assets/textures/vq2/` (geen nieuwe downloads): `canvas` (zandzakken), `olive` (doek, getint), `timber` (paal), `steel` (messing, getint), plus een kleine eigen emissiemap voor de lamp. Bron en provenance staan in assets/textures/vq2/provenance.json. Dit sluit aan bij de bunker, de kazerne en de wachttoren.

## Kwaliteit en budgetten (richtwaarden, worden gemeten en gerapporteerd)
| | HQ-bronmodel | Godot-gameversie |
|---|---|---|
| Triangles | ca. 20.000 tot 30.000 gepland, geleverd 16.690 | maximaal ca. 6.000 (LOD0), ca. 1.500 (LOD1 voor de uitgezoomde tactische stand); geleverd 3.230 en 1.414 |
| Texturen | 2K per PBR-set | 1K atlas (cloth + hout + messing), zandzakken 1K; vaak 512 px per onderdeel is genoeg, wordt gemeten |
| Materialen | per onderdeel | 3 tot 4 |
| Skin | 6 botten, één mesh | idem |
Zo blijft de vlag een klein, goedkoop prop. Het kwaliteitsniveau van bunker (37.752 triangles in de bron, 2048 px PBR) en hangaar geldt voor het bronmodel; de game-versie wordt geoptimaliseerd voor de iPhone.

## Oplevering
`.blend` (bewerkbaar), reproduceerbaar Blender-Python-script `maak_verzamelvlag.py`, geoptimaliseerde `.glb` (met LOD1), `.usdz`-preview voor iPhone Bestanden/Quick Look (met PBR en, waar betrouwbaar, de animatie), viewer-invoer in `tools/blender-vq2-viewer/` met echte clipknop, Godot-test (laden, namen, clip speelt, geen collision, gameplaycontract van `_make_flag()`), voor/na-opnames met identieke camera en belichting, en een rapport met triangles, materialen en texturen. Alles in een Draft PR.

## Productieketen en beperkingen
De lokale iMac-pipeline (Bloedjungle 3D Production Pipeline 1.0) is vanuit deze cloudomgeving niet bereikbaar. Het model wordt gemaakt met headless Blender (`bpy`) in deze omgeving. Er wordt geen lokale iMac-render geclaimd en geen iPhone-FPS: de native iPhone-test blijft **NIET GETEST** tot Dennis het zelf test.

## Acceptatie
1. Vlag is herkenbaar vanaf de gamecamera en uitgezoomd. 2. Doek wappert zichtbaar en loopt naadloos. 3. Lamp gloeit alleen 's nachts. 4. Gameplaycontract van de oude vlag blijft werken. 5. Triangle/texture/materiaal-rapport binnen de budgetten of gemotiveerd. 6. Dennis keurt het resultaat in de viewer en in de native app goed vóór merge.

## Geleverd (2026-11-01, Draft PR)

- HQ-bron 16.690 triangles, spelversie 3.230, LOD1 1.414; 5 materialen (doek, lamp, messing, hout, zandzak); spel 1024 px, LOD1 512 px (HQ-doek 2048 px).
- Eerlijke noot: de gedeelde VQ2-brontexturen (hout, staal, canvas) zijn native 1024 px en niet echt op te schalen; alleen het gegenereerde doek (weefsel, zoom, ster) is op 2048 px gemaakt.
- Totale hoogte ca. 3,3 m (paal 3 m plus lamp en speerpunt), doek 1,1 x 0,7 m.
- Clip `Wapperen-loop` (60 frames, 30 fps, skelet Doek_Rig); Godot hernoemt hem naar `Wapperen` en laat hem herhalen.
- Gouden grondring (Ø 3 m, pulserend) en de lampgloed (alleen Avond/Nacht) zijn Godot-kant (`scripts/rally_flag.gd`).
- Op de iPhone en in Quick Look NIET GETEST; de USDZ is niet gevalideerd (geen Apple-tools in de sandbox).
