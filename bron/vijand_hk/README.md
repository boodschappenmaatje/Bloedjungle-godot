# Vijandelijk hoofdkwartier — Dennis' Meshy-model "Enemy hk"

`assets/vijand_hk.glb` is sinds v188 het hoofdkwartier van de vijandbasis (Generals-plan stap D2, onderdeel 5a-2). Uiterlijk door Dennis zelf gemaakt en goedgekeurd ("dit mag er gelijk in"); wij zorgen voor de techniek.

## Bron

| | |
| --- | --- |
| Bestand | `Enemy hk.glb` in Dennis' Google Drive-map "Enemy hk" (ook een FBX van 106 MB), 69,8 MB, 2.025.162 driehoeken, 1 mesh, 1 materiaal (basiskleur, metallic-ruwheid, normal als JPEG), geen animaties |
| Niet in de repo | te groot voor GitHub; zet het bestand lokaal en geef het pad door aan stap 1 |
| Licentie | Meshy betaald abonnement: de uitvoer is van Dennis |

## Opnieuw bouwen (Blender 5.2 via `pip install bpy numpy`, ongeveer 2 minuten op 4 kernen)

    CACHE=/tmp/vijand_hk_cache
    python3 stap1_laag.py   <bron.glb> $CACHE 9.0 45000   # 9 m breed (even breed als het oude blok), voxel-remesh 4 cm, vereenvoudigen tot ~45.000
    python3 stap2_bakken.py $CACHE 2048 8                  # UV-atlas, 2K albedo, normal en ORM bakken van de bron (Cycles CPU)
    python3 stap3_export.py $CACHE uit                     # LOD1, wrak, uit/vijand_hk.blend + uit/vijand_hk.glb
    cp uit/vijand_hk.glb ../../assets/vijand_hk.glb

`maten.json` in de cache bevat de gemeten maten (bbox, kern, dakhoogte); `scripts/vijand_hk.gd` gebruikt dezelfde getallen voor het botsblok.

## Wat er gebeurt

1. **Op maat (Dennis: "formaten gelijk houden"):** de bron is genormaliseerd (1,9 m breed); hij wordt 9,0 m breed zoals het blok waarmee stap 5a-1 begon, dus indeling, middenstraat en botsblokken van de basis blijven kloppen. Hoogte 7,26 m (met mast), dak op 4,6 m, grondvlak 9,0 × 8,9 m inclusief steunberen en trap. Voorkant (deur, "HQ") naar −Y in Blender = +Z in Godot = de poort van de basis. Midden van het grondvlak in de oorsprong, onderkant op de grond.
2. **Gesloten schil:** voxel-remesh (4 cm), daarna vereenvoudigd tot **44.891 driehoeken** (Dennis: minimaal 40.000). Zelfde aanpak als de garage en de Tiger-tank.
3. **Bakken:** Smart-UV-atlas, 2048² albedo, tangent-normal en ORM (Cycles CPU, 8 samples). Meshy zet geverfd staal half-metallic: alleen donker, kleurloos staal blijft metaal. Materiaal enkelzijdig.
4. **LOD1:** `Romp_LOD1` (4.864 driehoeken, dezelfde atlas), getoond vanaf 80 m (`visibility_range`).
5. **Wrak:** `Wrak` (6.864 driehoeken, dezelfde atlas): de romp ingestort tot 30% van de hoogte, met deuken. Het spel maakt het zwart en toont het als het hoofdkwartier gesloopt is.

## Knopen (contract met `scripts/vijand_hk.gd`)

`Romp`, `Romp_LOD1`, `Wrak`. Geen clips, geen lampen. Rook en vuur (bij 60% en 30%), de levensbalk, de instorting en het winnen doet de code.

## Wat er bij het verlagen verloren gaat

De dunne delen (prikkeldraad op het dak, de antennemast, de reling) zijn dunner dan de voxels (4 cm) en worden dunne staafjes of verdwijnen; de kleur en de reliëfnaad ervan zitten wel in de texturen. Het silhouet van het gebouw, de deur, de trap, de zandzakken en de belettering ("HQ", "03", gevaarstrepen) blijven goed leesbaar.

## Cijfers

| | bron | spel (dichtbij) | LOD1 | wrak |
| --- | ---: | ---: | ---: | ---: |
| Driehoeken | 2.025.162 | 44.891 | 4.864 | 6.864 |
| Texturen | 3 JPEG | 3 × 2K (albedo, normal, ORM) | dezelfde | dezelfde |
| Bestand | 69,8 MB | `vijand_hk.glb` 7,8 MB (alles samen) | | |

Niet gemeten: FPS op iPhone, VRAM. USDZ-preview en viewer-invoer (tools/blender-vq2-viewer) staan nog open.
