# Asset Design Specification: Generals-verhoudingen voor de basis

Status: **ONTWERP, wacht op goedkeuring. De maten hieronder zijn voorlopig en worden herzien op basis van de echte Generals-data (zie de sectie 'Echte Generals-maten').** Er is nog niets gebouwd of gewijzigd in de game.
Aanleiding: referentieplaatje uit Command & Conquer Generals. Het huidige vliegveld (footprint 75 × 53 m, baan 75 m) is groter dan de basis (56 × 56 m) en veel groter dan kazerne en garage.

Vergelijking op schaal: [basis_oud_vs_nieuw.png](basis_oud_vs_nieuw.png) (bron: `.svg`). De plaatsing daarin is schematisch.

## Gekozen door de gebruiker
- Compact Generals-vliegveld.
- Helipad kleiner (12,8 → ~9 m) en garage groter (~6,4 → ~8 m).
- Betonplaten onder elk gebouw.
- Rook en kleine details op de gebouwen (pas na de maten).
- Vliegtuig kleiner (schaal 0,62 → ~0,40).
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

## Maten (meter, doel) - VOORLOPIG, wordt herzien
| Onderdeel | Nu | Doel | Opmerking |
|---|---|---|---|
| Kazerne | ~5,8 × 4,2 (collider 4,4 × 3,2) | ongewijzigd | referentie (B ≈ 6 m) |
| Garage | ~6,4 × 5,7 | ~8 × 7,1 (×1,25) | meeschalen van mesh, deur, collider en `GS`/`FRONT`/`DOOR_U` |
| Helipad | 12,8 × 12,8 | ~9 × 9 | luiken en lift meeschalen |
| Hangar | 22,5 × 21 | ~11 × 10 | opening past bij vliegtuig ~0,40 |
| Platform | 18 × 14 | ~11 × 8 | |
| Baan | 75 × 18 | ~30 × 7 | arcade-vliegen, geen echte startlengte nodig |
| Toren | 8 × 8 (+ trap 4 × 8) | ~3 × 3 | trapcollision opnieuw |
| Vliegveld totaal | 75 × 53 (~3975 m²) | ~30 × 26 (~780 m²) | ~25% van de basis |
| Vliegtuig | schaal 0,62 (~10 m) | schaal ~0,40 (~6,5 m) | `MODEL_SCALE` in `vliegtuig.gd` |

Bronnen in de code: `scripts/airfield_hq_23.gd` (constanten), `scripts/buildings.gd` (`DEFS`, `GS`, `GSH`), `scripts/vliegtuig.gd`, `Data.COMPOUND = 28`.

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
