# Asset Design Specification: Generals-verhoudingen voor de basis

Status: **ONTWERP, wacht op goedkeuring.** Er is nog niets gebouwd of gewijzigd in de game.
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

## Maten (meter, doel)
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
