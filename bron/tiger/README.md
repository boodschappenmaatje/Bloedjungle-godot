# Tiger I (Meshy-model van Dennis, rijdbaar gemaakt)

`assets/tank.glb` (de eigen tank uit de garage) is nu de **Tiger I** die Dennis in de Meshy-app maakte
(prompt in de bestandsnaam: *Tiger I German WWII heavy tank, realistic, weathered olive-green and sand camouflage paint, matte steel, worn tracks with individual links, road wheels, cylindrical turret…*).
De oude, procedurele tank blijft als vergelijking in de viewer (`assets/vq2_baseline/tank_v1.glb`, `bron/tank/`).

## Bron

| | |
| --- | --- |
| Bestand | `Tiger I … _Meshy_AI_2026-10-29_148bc2.glb` in Dennis' Google Drive, 129,6 MB, 4.134.818 driehoeken, 2,2 miljoen hoekpunten, 1 materiaal (4K-albedo, metallic-ruwheid, normal) |
| Deelpagina | https://www.meshy.ai/s/p7Ph2A (alleen plaatjes; het GLB zit achter inloggen) |
| Niet in de repo | te groot voor GitHub; zet het bestand lokaal en geef het pad door aan stap 1 |
| Licentie | Meshy betaald abonnement: de uitvoer is van Dennis |

## Opnieuw bouwen (Blender 5.2 via `pip install bpy numpy`, ongeveer 6 minuten op 4 kernen)

    CACHE=/tmp/tiger_cache
    python3 stap1_delen.py   <bron.glb> $CACHE      # op ware grootte, voorkant naar +Y, voxel-remesh, delen indelen
    python3 stap2_laag.py    $CACHE                 # lage delen: romp, toren, kanon, 20 wielen, 2 rupsbanden, UV's
    python3 stap3_bakken.py  $CACHE 2048 4096       # albedo, normal, ruwheid/metallic bakken (Cycles CPU)
    python3 stap4_export.py  $CACHE uit 2048        # draaipunten, clips, uit/tiger.blend en uit/tiger.glb
    cp uit/tiger.glb ../../assets/tank.glb

`tiger_delen.py` bevat de indeling (wielassen, torenlager, kanonsteunen, baan van de rups); pas daar aan als het bronmodel verandert.

## Wat er gebeurt

1. **Op maat**: bronmodel 1,905 lang → 8,45 m met kanon (ware Tiger I), voorkant naar +Y (wordt −Z in Godot). Het onderstel wordt naar het midden geschoven en op de grond gezet.
2. **Delen**: de Meshy-mesh is één stuk met losse schilfers. Decimeren van de losse delen gaf scherven, dus eerst een voxel-remesh (3 cm) van het hele model: één gesloten schil. Die wordt per vlak ingedeeld in romp, toren, kanon, wielen en rupsen; snijvlakken (torenlager, wielen) worden dichtgemaakt.
3. **Lage versie** (≈ 27.400 driehoeken): romp (9.000) en toren (7.000) gedecimeerd uit de gesloten schil; het kanon is een schoon omwentelingslichaam (14 zijden) op de licht omhoogwijzende as van het bronkanon, recht gezet; 20 wielen (16 zijden, 448 driehoeken, profiel uit het bronmodel); twee rupsbanden als strook (u = afstand langs de baan).
4. **Textuur bakken** van de 4,1 miljoen driehoeken naar één atlas (2048²: albedo, tangent-normal, ORM) voor alles behalve de rupsen, en één strook 4096 × 512 voor de rupsband (links gebakken, beide kanten gebruiken hem). Geverfde delen worden mat-dielectrisch, alleen donker staal blijft metaal.
5. **Draaipunten en clips** (zie hieronder).

## Knopen en clips (contract met `scripts/tank.gd`)

`Tank` > `Body` > [`RompMesh`, `RupsL`, `RupsR`, `WielL_w1..w8`, `WielL_aandrijf`, `WielL_spanwiel` (en R), `Toren` > [`TorenMesh`, `Loop` > [`LoopMesh`, `Monding`]]]

* `Toren` draait om Y op het torenlager, `Loop` kantelt om X op de kanonsteunen; **het spel stuurt beide zelf** (de clips raken ze niet aan).
* `Monding` zit op de kanonsmond (3,7 m voor de loopas): granaten en vuurflits komen daar vandaan.
* Clips (30 beelden/s): `Stationair` (romp trilt), `Rijden` en `Achteruit` (alle wielen draaien één omwenteling per lus bij 3,12 m/s, romp deint), `Draaien` (links en rechts tegengesteld, 2,2 m/s rupssnelheid), `Schieten` (`LoopMesh` schiet 0,55 m terug, romp wipt na).
* **Rupsbanden lopen via Godot**: `tank.gd` geeft `RupsL` en `RupsR` elk een eigen materiaalkopie en schuift `uv1_offset.x` met `snelheid per kant × dt / 13,27 m`. In een bocht lopen de banden dus verschillend. De viewer doet hetzelfde met de textuur-offset.

## Cijfers

| | oude tank | Tiger |
| --- | ---: | ---: |
| Driehoeken | 7.544 | 27.391 |
| Meshes / draaiende wielen | 1 + 80 rupsschakels | 25 meshes, 20 wielen, 2 rupsbanden |
| Materialen | 6 | 2 (Tiger, Tiger_rups) |
| Texturen | geen (alleen kleur en een 256-camo) | 2048² albedo/normal/ORM + 4096 × 512 rups ×3 |
| `tank.glb` | 0,3 MB | 3,9 MB |
| Maat (b × l × h) | 3,0 × 6,5 × 2,6 m | 3,9 × 6,6 (8,4 met kanon) × 3,15 m |

Niet gemeten: FPS op iPhone, Safari/Xogot, VRAM. Wel getest: Godot-import (4.7.2), `tests/tiger_test.gd`, `tests/tank_pantser_test.gd`, `tests/tank_mik_test.gd`, `tests/boom_val_tank_test.gd`, viewer `tools/blender-vq2-viewer/test-tank.mjs`. USDZ-preview: `previews/usdz/tiger/v1/tiger_iPhone.usdz` (Apple `usdchecker` NIET uitgevoerd: alleen op macOS).
