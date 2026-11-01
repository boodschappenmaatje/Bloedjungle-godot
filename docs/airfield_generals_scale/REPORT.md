# Vliegveld in Generals-verhoudingen: rapport

Branch `claude/airfield-generals-scale-spec`. Niet gemerged, geen OTA. Native iPhone-prestaties en -touchgedrag: **NIET GETEST**.
Specificatie en onderbouwing: [ASSET_DESIGN_SPEC.md](ASSET_DESIGN_SPEC.md).

## Wat is gedaan
- De hele vliegveldscène is uniform met factor **0,6** verkleind (`AirfieldHQ23.SCALE`). Hangar, toren, platform, taxibaan en baan zijn **dezelfde modellen, texturen en animaties**; ze zijn niet opnieuw gemodelleerd. Kleiner betekent dus een hogere pixeldichtheid per meter.
- De baan heeft drie in plaats van vijf dekplaten (45 m ontwerp, 27 m in de wereld).
- Het toestel (straaljager) is van schaal 0,62 naar 0,55 gegaan: ~8,1 × 5,2 m, iets langer dan de tank (7,9 m) en veel groter dan de jeep.
- Wereldmaten (plaatsing, voetafdruk, camerakadrering, bouwoppervlak) rekenen met `SCALE`. Binnen de scène blijven alle maten gelijk, zodat deuren, animaties, botsing en lichten niet verschuiven.
- Vliegtuigcode: schaal-onafhankelijke parkeerpositie, hoogte van het asfalt (0,22 × 0,6), hangarpasvorm en een echte draai op de plaats binnen de hangar (anders zwaait de neus tegen de deurstijl).
- Kazerne, garage, helipad, voertuigen, soldaten en hun uitgangen zijn niet aangeraakt.

## Maten (gemeten in Godot)
Hangar 13,5 × 12,6 m (opening 9 × 3,5), baan 27 × 10,8, platform 10,8 × 8,4, toren 4,8 × 4,8; het hele vliegveld past in 36,9 × 33,0 m (was 75 × 53). Voor/na met identieke camera: [voor](captures/voor/) en [na](captures/na/). Schema: [basis_oud_vs_nieuw.png](basis_oud_vs_nieuw.png).

## Eisen van de gebruiker
| Eis | Resultaat |
|---|---|
| Animaties blijven bestaan | Hangardeuren (alle 3 LODs, tween plus botsing), torendeur (botsing draait mee open), windzak-lus en de jager-clip `Vliegen` werken (tests hieronder). Geen enkele clip is aangepast. |
| Zelfde ontwerp, hoge pixeldichtheid | Zelfde GLB's en texturen, uniform geschaald. Geen nieuwe bronbestanden, dus geen wijziging aan `.blend`/`.usdz`/viewer. |
| Alles blijft werken | Zie de testtabel. |

## Tests (headless Godot 4.7.2, Linux)
| Test | Uitkomst |
|---|---|
| `airfield_hq_23_contract_test` | PASS (verwachtingen over baan 45 m, oppervlak 981,8 m² en schaal 0,6 bijgewerkt) |
| `vliegtuig_test` | 0 fouten (opstijgen, vliegen, landen, taxiën, terug in de hangar, crash-tests) |
| `airfield_hq_23_hangar_gameplay_test` | 0 fouten (muren, deuren, dak, op de geschaalde scène) |
| `airfield_scale_test` (nieuw) | 0 fouten: wereldmaten, opening laat jager door, speler loopt door de open deur (ook 2,3 m naast het midden), trapbreedte, torendeur, windzak, 3 dekplaten |
| `bouw_test`, `generator_test`, `heli_test`, `schade_test`, `truck_test`, `wachtpost_test`, `ai_test`, `raket_test`, `vq2_test` | geen fouten |
| `airfield_hq_22_import_test` | **faalt, maar ook zonder mijn wijzigingen** (`The compact left-door GLB action must play in Godot`, headless) |

Opnames in het echte spel (`tests/airfield_scale_capture.gd`, Mesa llvmpipe, OpenGL-compatibiliteit): modellen, texturen en hangar-interieur met het toestel zijn intact. Dit is geen prestatiemeting.

## Open punten
1. **Binnen de basismuren plaatsen kan nog niet.** Het spel weigert elke vliegveldlocatie binnen 60 m van het midden ("Vijandelijke spawnzone", `Data.SPAWN_R = 58`), dus ook binnen de basis (56 × 56 m). Het verkleinde vliegveld (37 × 33 m) past er qua afmeting wel, maar dan moet die regel veranderen en worden vijanden de gebouwen aanvallen. Beslissing van de gebruiker nodig.
2. Het vliegveld is omvattend 37 × 33 m, groter dan de eerste inschatting van 24 × 21 m, omdat het ontwerp (taxibocht) dezelfde samenstelling houdt.
3. De baan van 27 m is korter dan een echte baan; het vliegen is arcade en de test (opstijgen, landen) slaagt.
4. Torentrap: de botsvormen zijn verbreed zodat de speler (0,9 m) past, maar klimmen is niet getest (was ook al niet geaccepteerd in 2.3).
5. Native iPhone-test (framerate, aanraking, camera): NIET GETEST.
