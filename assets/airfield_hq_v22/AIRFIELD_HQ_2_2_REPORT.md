# Bloedjungle Airfield HQ 2.2 — reviewrapport

Status: **Draft, visuele acceptatie nog niet behaald.** De nieuwe Blender-geometrie, PBR-export en Godot-integratietest zijn geleverd. De renders komen nog niet overtuigend overeen met de vier fotorealistische conceptbeelden. Airfield HQ 2.0 en 2.1 blijven intact; de productie-scene en OTA zijn niet gewijzigd.

## Opgeleverd

- Bewerkbaar Blender 4.5.15-bronbestand: `high_quality/Bloedjungle_Airfield_HQ_2_2_Source.blend`. De drie mobiele LOD-bronnen staan in `game_optimized/`; de game-GLB's en hun texturen in `runtime/`.
- Nieuwe hangar van 44 × 40 m met echt geprofileerd dak, staalspanten, schuifdeuren, werkplaatsobjecten en ramen; toren met beglaasde observatieruimte, buitentrap, radio-interieur, bewegende deur en windzak; 900 × 38 m baan, betonnen opstelplaats en gebogen taxibaan. Bron bevat 1.807 meshobjecten, vóór batching en export.
- Godot-scene `scenes/airfield_hq_22_showcase.tscn` met afzonderlijke vluchtintegratie, eenvoudige botsingsvormen en bereikgebaseerde LOD's. Bestaande hangardeurclips blijven behouden; torendeur en windzak hebben eigen clips.
- `tools/blender-vq2-viewer/` biedt keuze tussen 2.1/2.2, LOD en animaties. De webbundel bouwt lokaal en HTML/JS/LOD0-GLB gaven HTTP 200 in een lokale serveertest; daadwerkelijke WebGL-weergave en Safari op een echte iPhone zijn niet getest.
- Tien Blender Cycles-renders in `previews/airfield_hq/v22_review/`, waaronder dezelfde eerste vier camera's als 2.1, vier naast-elkaar-vergelijkings-PNG's (`compare_*.png`) en een HTML-vergelijking. De P-47-maatbox in render 10 is alleen een annotatie en zit niet in het model.
- `previews/usdz/airfield_hq/2.2/Bloedjungle_Airfield_HQ_2_2_iPhone.usdz` is met Apple's `usdchecker --arkit` en `usdzip` op macOS gevalideerd. Quick Look op een iPhone is niet getest.

## Meetbare assetgegevens

| Niveau | Driehoeken totaal | Meshnodes | glTF-primitives | Materialen | GLB | Bovengrens ongecomprimeerde RGBA8-texturen inclusief mipmaps |
|---|---:|---:|---:|---:|---:|---:|
| LOD0 | 166.968 | 34 | 97 | 19 | 51,9 MB | 224 MiB |
| LOD1 | 61.445 | 21 | 81 | 12 | 11,0 MB | 48 MiB |
| LOD2 | 27.096 | 21 | 81 | 12 | 4,5 MB | 12 MiB |

De glTF-primitives zijn een **draw-surface-proxy**, geen gemeten GPU-drawcalls. De textuurwaarde is een ongecomprimeerde rekenkundige bovengrens; daadwerkelijke GPU-compressie en resident geheugen zijn niet gemeten. LOD0 gebruikt 2K Base Color/normal/ARM voor de hoofdmaterialen en 1K voor secundaire oppervlakken; LOD1 gebruikt 1K, LOD2 512 px. Zes hoofdmaterialen exporteren AO uit de rode ARM-kanaal; roughness en metallic komen uit groen/blauw. De beelden komen uit de reeds aanwezige Poly Haven CC0- en ambientCG CC0-bronnen in de repository. De GLB-audit staat in `GLB_AUDIT.json`.

## Godot 4.7.2-controle

Headless import en `tests/airfield_hq_22_import_test.gd`: **PASS**. Controle omvat 34 meshinstanties, 97 surfaces met UV en materiaal, vijf lichtbronnen, vijf geïmporteerde animaties en 13 collision-shapes. De test speelt beide schuifdeuren, waarschuwingslicht, torendeur en vervormende windzak af, en controleert de beweging van deurcollisions. LOD1/LOD2 en P-47-markers/routes importeren eveneens. Dit bewijst de asset- en scene-integratie, geen FPS of visuele kwaliteit in de echte spelwereld.

LOD-grenzen staan op 95/155 m, afgeleid van de huidige vaste camera (40° FOV, 170 m far plane). De 900 m baan is ruimtelijk in negen stukken verdeeld, omdat Godot visibility ranges per object-oorsprong beoordelen. Deze grenzen zijn nog niet met camerabewegingen en framerate op een echte iPhone getuned.

## P-47-voorbereiding

De ontbrekende echte Meshy P-47 is niet vervangen door een nepmodel. De scene bevat `P47_Hangar_Spawn`, `P47_Apron_Parking`, `P47_Taxi_Start`, `P47_Runway_Hold`, `P47_Runway_Start`, `P47_Landing_Approach`, `P47_Landing_Touchdown` en Curve3D-routes voor taxi, start en landing. De vrije deuropening is 39,4 × 13,0 m; taxibaan 18,4 m breed. Tegen de opgegeven P-47-maat van 12,44 m spanwijdte en 4,45 m hoogte blijven 13,48 m per zijde in de deur en 2,98 m per zijde op de taxibaan vrij. Een daadwerkelijke bewegingstest met het echte vliegtuig, propeller, landingsgestel en definitieve vlieganimaties wacht op het Meshy-bronmodel.

De 900 m baan biedt in een **alleen voor gameplay aangenomen** profiel (2 m/s² tot 50 m/s) 625 m grondrol en 275 m restlengte. Dit is geen historisch geverifieerde P-47D-startprestatie of fysicasimulatie.

## Openstaande acceptatiepunten

1. De hangar heeft een geloofwaardiger dak en draagconstructie dan 2.1, maar mist nog de variatie in plaatvervorming, roest, schade en afwerking van referentie 1.
2. Het interieur bevat onderhoudsobjecten, maar oogt zonder het echte P-47-model en extra microdetails nog te leeg ten opzichte van referentie 2.
3. De toren heeft echte ramen en toegang, maar de massa en gevel blijven te hoekig en repetitief ten opzichte van referentie 3.
4. De baan/taxibaan vormen nu één functioneel terrein, maar het gras, de boomlijn, bermen en verwering halen de fotorealistische sfeer van referentie 4 niet.
5. Werkelijke iPhone GPU-drawcalls, GPU-geheugen, frametimes en FPS: **niet gemeten**. Geen claim van 60 FPS. Native Quick Look en Safari-viewer zijn eveneens niet op een iPhone getest.

**Conclusie:** de technische 2.2-reviewversie is reproduceerbaar en Godot importeert haar met werkende animaties. De fotorealistische visuele acceptatie en native iPhone-validatie blijven open. Draft PR #164 mag daarom niet worden gemerged en er mag geen OTA-versie worden gepubliceerd.
