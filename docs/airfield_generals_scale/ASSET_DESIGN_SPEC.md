# Asset Design Specification: Generals-verhoudingen voor de basis

Status: **UITGEVOERD op deze branch (Draft, niet gemerged, geen OTA).** Zie [REPORT.md](REPORT.md) voor resultaten en open punten.
Aanleiding: referentieplaatje uit Command & Conquer Generals. Het huidige vliegveld (footprint 75 × 53 m, baan 75 m) is groter dan de basis (56 × 56 m) en veel groter dan kazerne en garage.

Vergelijking op schaal: [basis_oud_vs_nieuw.png](basis_oud_vs_nieuw.png) (bron: `.svg`). De plaatsing daarin is schematisch.

## Gekozen door de gebruiker
- Compact Generals-vliegveld, optie 2 (~24 × 21 m).
- Helipad blijft ongewijzigd (12,8 m). Garage groter: vervalt na de Generals-data.
- Betonplaten onder elk gebouw.
- Rook en kleine details op de gebouwen (pas na de maten).
- Vliegtuig kleiner (schaal 0,62 → ~0,55, niet kleiner dan de tank).
- Voertuigen controleren ten opzichte van de nieuwe maten.
- Eerst vergelijkingsbeeld (dit document).

Niet gekozen: baan door de poort naar buiten, vaste paden, vaste bouwzones, één schaalregel voor alles. Kazerne blijft ongewijzigd.

## Echte Generals-maten (opgezocht)
Bron: de INI-bestanden van de communitypatch [TheSuperHackers/GeneralsGamePatch2](https://github.com/TheSuperHackers/GeneralsGamePatch2/tree/main/Generals/Data/INI/Object/Faction/America), map `Building/` en `Unit/`. Dit is de collisiebox (`Geometry`) van elk object in spel-eenheden. De radii zijn halve maten, hieronder zijn ze verdubbeld tot volledige maat (lengte × breedte). De box is niet precies de zichtbare ondergrond, en dit is de patchversie, niet de originele 1.04-bestanden.

| Object (USA) | Maat (eenheden) | Hoogte | Oppervlak t.o.v. kazerne | Lengte t.o.v. kazerne |
|---|---|---|---|---|
| Barracks (kazerne) | 110 × 90 | 20 | 1,00× | 1,00× |
| War Factory (garage) | 106 × 120 | 40 | 1,28× | 1,09× (diepte) |
| **Airfield (vliegveld)** | **224 × 148** | 25 | **3,35×** | **2,04×** |
| Command Center | 120 × 140 | 49 | 1,70× | 1,27× |
| Supply Center | 88 × 90 | 24 | 0,80× | 0,82× |
| Strategy Center | 124 × 88 | 24 | 1,10× | 1,13× |
| Power Plant | 44 × 60 | 46 | 0,27× | 0,55× |
| Ranger (soldaat) | doorsnede 14 | 13 | - | 0,13× |
| Humvee | 28 × 14 | 11,5 | - | 0,25× |
| Crusader-tank | 30 × 20 | 10 | - | 0,27× |
| Raptor (straaljager) | 28 × 14 | 5 | - | 0,25× |
| Comanche | 40 × 6 | 25 | - | 0,36× |

Niet opgezocht: de helipad uit je plaatje en de Chinese en GLA-gebouwen.

### Wat dit betekent voor Bloedjungle
- **Het vliegveld is in Generals 2× zo lang en 3,35× zo groot als een kazerne**, niet 13×. Het is dus ook niet zo klein als mijn eerste schatting.
- **Garage:** de War Factory is maar 1,28× zo groot als een kazerne. De huidige garage (~6,4 × 5,7 m, ongeveer 1,5× de kazerne) klopt al. De keuze 'garage groter naar ~8 m' wordt door de data **niet** ondersteund en valt weg.
- **Strikt op kazerne-schaal** (kazerne 5,8 m = 110 eenheden, 1 eenheid ≈ 0,053 m): vliegveld ≈ **11,8 × 7,8 m**, ongeveer 82 m² (nu ~3975 m²).
- **Eenheden:** in Generals zijn voertuigen en jagers ~¼ van een kazerne, en een soldaat ~1/8. Bij jou is een soldaat ~1/3 van de kazerne en een straaljager (schaal 0,62) ~1,7× de kazerne. Strikt volgen kan dus niet: een jager van 1,5 m is onspeelbaar. De gebouwen onderling volgen Generals, de eenheden blijven speelbaar.

## Maten (meter), uitgevoerd: uniforme schaal 0,6 van de bestaande vliegveldscène
De hele scène (hangar, toren, platform, taxibaan, baan) is uniform met `AirfieldHQ23.SCALE = 0,6` verkleind, dus dezelfde modellen, texturen,
animaties en botsing. Alleen de baan is korter (3 in plaats van 5 dekplaten). De eerdere voorlopige maten (24 × 21 m) bleken niet haalbaar:
een jager die niet kleiner is dan de tank (8,1 m) past pas in een hangar met schaal ≥ ~0,6. Gemeten in Godot (`tests/airfield_scale_test.gd`):

| Onderdeel | Voor | Na (wereld) |
|---|---|---|
| Hangarschil | 22,5 × 21 | 13,5 × 12,6 m |
| Hangaropening | 15 × 5,9 | 9 × 3,5 m |
| Baan | 75 × 18 | 27 × 10,8 m (3 dekplaten) |
| Platform | 18 × 14 | 10,8 × 8,4 m |
| Taxibaan | 18 breed | 10,8 breed |
| Toren | 8 × 8 | 4,8 × 4,8 m |
| Hele vliegveld (omvattend) | 75 × 53 (~3975 m²) | 36,9 × 33,0 m (voorzichtig oppervlak 982 m², was 3267 m²) |
| Jager | schaal 0,62 | schaal 0,55: ~8,1 × 5,2 m (iets langer dan de tank, 7,9 m) |
| Kazerne, garage, helipad, voertuigen | - | ongewijzigd |

## Voertuigen en soldaten
- **Soldaten:** komen uit de kazerne naar een punt 2,5 m voor de deur. Kazerne blijft gelijk, dus geen wijziging. Rond de deur komt een vrije zone van minstens 3 m, die de plaatsing bewaakt.
- **Garage en voertuigen:** een voertuig rijdt van binnen (0,5 m van het midden) kaarsrecht de deur uit, tot 6 tot 9,5 m ervoor, en gaat dan opzij (`_spawn_vehicle`, `_free_run`). Ruwe afmetingen: jeep 1,7 × 3,8, tank 3,9 × 7,9, truck 3,0 × 8,1 m. Tank en truck zijn dus langer dan de garage diep is (~6,2 m). Dat kan nu al; testen in Godot.
- Uitrijroute van de garage (tot ~10 m vrij voor de deur) en de zone voor de kazerne mogen niet door het vliegveld of de helipad worden afgesloten. Het vliegveld wordt daarom aan een kant van de basis geplaatst, niet tussen kazerne, garage en poorten.

## Besluiten
- Vliegveld optie 2 (~24 × 21 m), jager ~0,55 (niet kleiner dan de tank), helipad en garage ongewijzigd.
- Voertuigen blijven zoals ze zijn; in Godot testen of tank en truck netjes door de garagedeur rijden en corrigeer alleen waar nodig.

## Open punten / aannames
- De Generals-verhoudingen zijn geschat op basis van het plaatje, niet nagemeten in de originele bestanden.
- 30 m baan is niet gecontroleerd met de vliegmechaniek (opstijgen/landen). Dit moet in Godot worden getest.
- Hangar-deuranimatie, torentrap en collision moeten na het schalen opnieuw worden gecontroleerd.
- Betonplaten en rook/details vragen nieuwe Blender-assets (PBR, `.blend`, `.glb`, `.usdz`, viewer-opname). Dit volgt pas na goedkeuring van de maten.
- Voertuigen (jeep, tank, truck) worden naast de nieuwe maten gelegd; alleen corrigeren waar het niet klopt.

## Voorgestelde stappen na goedkeuring
1. Maten doorvoeren (constanten, schalen) en regressietests laten draaien.
2. Compacte hangar/toren/platform/baan opnieuw opbouwen (Blender-script, LOD's, viewer).
3. Garage en helipad schalen; plaatsing in de basis controleren.
4. Betonplaten en details.
5. Voor/na-opnames met dezelfde camera.

Alles op een aparte branch met Draft PR. **Niet mergen en geen OTA zonder aparte toestemming.** Native iPhone-prestaties: NIET GETEST.
