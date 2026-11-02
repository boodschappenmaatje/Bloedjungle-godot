# Garage — Meshy-motorpool van Dennis (vervangt de oude golfplaat-garage)

`assets/garage.glb` is sinds v178 de **Wartime Motor Pool Garage** die Dennis in Meshy maakte (uiterlijk door hem goedgekeurd).
De oude garage blijft als vergelijking in de viewer: `assets/vq2_baseline/garage_v1.glb` (bron `bron/garage/`).

## Bron

| | |
| --- | --- |
| Bestand | `Wartime Motor Pool Garage_Meshy_AI_2026-11-02_caa4bb.glb` in Dennis' Google Drive, 119 MB, 3.706.042 driehoeken, 1 materiaal (2K albedo, metallic-ruwheid, normal), geen animaties, binnen hol |
| Niet in de repo | te groot voor GitHub; zet het bestand lokaal en geef het pad door aan stap 1 |
| Licentie | Meshy betaald abonnement: de uitvoer is van Dennis |

## Opnieuw bouwen (Blender 5.2 via `pip install bpy numpy`, ongeveer 3 minuten op 4 kernen)

    CACHE=/tmp/garage_cache
    python3 stap1_laag.py    <bron.glb> $CACHE 6.5 36000   # schaal 6,5 = keuze B, voxel-remesh 3,5 cm, vereenvoudigen
    python3 stap1b_hoogte.py $CACHE $CACHE2 1.8            # hogere poort (truck past): wand 1,8 m hoger; daarna stap 2 en 3 op $CACHE2
    python3 stap2_bakken.py  $CACHE 2048 8                # poort uitsnijden, deuren + binnenbak, UV, 2K bakken
    python3 stap3_export.py  $CACHE uit                   # scharnieren, lampen, LOD1, clips, uit/garage.blend + uit/garage.glb
    cp uit/garage.glb ../../assets/garage.glb

`maten.json` in de cache bevat de gemeten poort (x, z en de voorkant y); de code in `scripts/buildings.gd` gebruikt dezelfde getallen.

## Wat er gebeurt

1. **Op maat (keuze B, 2 nov 2026):** schaal 6,5 → terrein 8,8 × 12,6 m, nok 4,9 m (ventilatiekap 5,5 m), poort 4,2 × 2,3 m. **Stap 1b (2 nov 2026, op Dennis' verzoek):** de legertruck is 3,9 m hoog, dus het model wordt in Z uitgerekt: wand tussen 1,0 m en de poortbovenkant 1,8 m hoger, alles erboven (latei, bord, dak, lampen) schuift 1,8 m omhoog. Poort nu 4,2 × 4,4 m, nok 6,7 m en ventilatiekap 7,3 m; alleen de twee uitlaatpijpen van de truck (5,7 m) steken nog door de latei. Voorkant naar −Y in Blender (+Z in Godot), midden van het terrein in de oorsprong, onderkant op de grond.
2. **Gesloten schil:** voxel-remesh (3,5 cm) van het hele model, daarna vereenvoudigd tot ±35.500 driehoeken (zelfde aanpak als de Tiger-tank: decimeren van de losse Meshy-schilfers geeft scherven).
3. **Poort:** elk vlak met een hoekpunt in de poortopening gaat weg (de onderste 10 cm blijft als drempel). Twee nieuwe deuren (`DeurL`, `DeurR`) op de plek van de oude deurplaat; ze worden gebakken van de bron, dus ze zien er hetzelfde uit. De achterkant krijgt dezelfde planken (gespiegeld).
4. **Binnen:** `Binnen` is een donkere bak met de vlakken naar binnen (vloer, wanden, plafond onder het dak), alleen zichtbaar door de open poort.
5. **Bakken:** Smart-UV-atlas voor romp + deuren, 2048² albedo, tangent-normal en ORM (Cycles CPU). Meshy zette hout en golfplaat half-metallic; alleen donker kleurloos staal blijft metaal. Materialen enkelzijdig (Meshy had alles dubbelzijdig).
6. **LOD1:** `Romp_LOD1` (5.000 driehoeken, dezelfde atlas). Godot toont vanaf 45 m LOD1 (`visibility_range`).

## Knopen en clips (contract met `scripts/buildings.gd`)

`Romp`, `Romp_LOD1`, `Binnen`, `DeurL`, `DeurR` (scharnier op de buitenste voorrand), lampen `DeurLampL/M/R` (spots boven de poort) en `BinnenLamp`.

* Clips (30 beelden/s): `Open` (2 s, deuren draaien 88° naar buiten), `Dicht` (2 s, terug; rustpose = dicht), `Show-loop` (6 s, voor viewer en USDZ). Het spel speelt Open/Dicht in 1 s (`DOOR_T`).
* De lampen branden alleen bij Avond/Nacht; het spel geeft ze een kort bereik (spot 9 m, binnen 6 m) en geen schaduw.
* De oude garage had een zwaailicht en een takel; die zitten niet in dit model. De code slaat ze over als ze ontbreken.
* Botsvormen staan in `Buildings.GARAGE_KASTEN`: hal-wanden, voorgevel naast de poort, latei, drie luifels met spullen, zandzakken links voor en kabelhaspel rechts voor (niet door meubels lopen). De poort is `Poortkast` en gaat uit als de poort open is. Het voorplein is vrij.

## Cijfers

| | oude garage | Meshy-bron | motorpool (spel) |
| --- | ---: | ---: | ---: |
| Driehoeken | 13.712 | 3.706.042 | 46.237 dichtbij (romp 46.189 + deuren + binnenbak), 5.647 LOD1 |
| Meshes | 29 | 1 | 4 (+ LOD1) |
| Materialen | 20 | 1 | 2 (`Garage` met texturen, `Garage_binnen` effen) |
| Texturen | 2 × 512 | 3 × 2K | 3 × 2K (albedo, normal, ORM) |
| `garage.glb` | 1,2 MB | 119 MB | 6,2 MB |
| Terrein (b × d) | 5,15 × 5,7 m | – | 8,8 × 12,6 m |

Niet gemeten: FPS op iPhone, Safari/Xogot, VRAM. USDZ-preview: `previews/usdz/garage/v2/garage_iPhone.usdz` (Apple `usdchecker` NIET uitgevoerd: alleen op macOS; Quick Look op iPhone NIET getest).
