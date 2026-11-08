# MCV-bouwwagen uit Dennis' Meshy-modellen (8 november 2026)

Drie modellen van Dennis (Drive, "Iedereen met de link"): `wagen.glb` (97,8 MB, 3.083.686 driehoeken), `module.glb` (39 MB, 1.065.412) en `poot.glb` (16,8 MB, 319.682). Niet in de repo.
Afspraak met Dennis: **A** (de container blijft als commandokern), de wagen **blijft staan**, uitklappen 6 s en opbouwen ongeveer 20 s.

## Resultaat
- `assets/mcv.glb` (+ drie 2K-JPEG-sets): wagen (romp 29.837, schild 3.492, 8 wielen van 1.008), module (container 13.991, twee dakhelften 6.4k, mast 4.4k, schotel 3.0k), vier poten (3.5k + 2.5k). **99.576 driehoeken** samen, 23 meshes, 3 materialen, 9 texturen (2K, poot 1K). GLB 10,4 MB. Geen LOD (nog te doen als de iPhone dit niet haalt; er staat maar één wagen in het spel).
- Knopen: `Mcv > [Romp, Schild, Stuur_A1L/R, Stuur_A2L/R > Wiel_*, Wiel_A3L/R, Wiel_A4L/R, Module > [Kern, Dak_L, Dak_R, Mast, Schotel], Poot_ML/MR/AL/AR > [PootBoven, PootOnder]]`. Voorkant is -Z (Godot).
- Echte GLB-clip **Uitklappen** (6,0 s, 30 beelden/s): schild 32° omhoog, vier poten schuiven schuin naar buiten, dakpanelen schuiven 0,8 m uit, mast rijst 0,9 m, schotel kantelt 35°. De wielen en het sturen (voorste vier) doet Godot (`scripts/mcv_model.gd`).
- Bron en reproduceerbare keten: `bron/mcv_meshy/` (stap1 voxel-remesh, stap2 delen, stap3 bakken, stap4 samenbouwen met clip, stap5 USDZ). USDZ-preview: `Bouwwagen_MCV.usdz` (11,5 MB, PBR + clip Uitklappen, niet in Quick Look gecontroleerd).

## Spel
- `McvModel` (nieuw) vervangt het blokmodel: wielen draaien, voorwielen sturen, de wagen wiebelt op snelheid, schild omhoog na het uitklappen.
- Na UITKLAPPEN: het hoofdkwartier staat meteen op de plek (alle spelregels ongewijzigd), de wagen rijdt 9,6 m naar voren (lokaal -Z), blijft daar staan en speelt de clip Uitklappen. De stroken voor de wagen worden vrijgemaakt en de plek telt mee bij de plekcontrole (droog, binnen de kaart); het spookbeeld toont ook de parkeerplek.
- **Opbouw** (`McvOpbouw`): na 3,5 s (de wagen rijdt weg) groeit het hoofdkwartier in 20 s omhoog met steigers (zelfde look als de andere bouwplaatsen), de zandzakkenring komt als laatste. Alleen het zichtbare deel groeit; botsvorm en gezondheid blijven.
- De wagen verlaat de groep `mcv` (testen zien hem als weg) en zit in `mcv_wagen`; bij een nieuw spel wordt hij opgeruimd (`main.gd`).

## Tests
- Nieuw `tests/mcv_wagen_test.gd` (0 fouten): model, wielen/sturen, parkeren, clip, opbouw tot klaar.
- Bestaand: `mcv_test`, `mcv_muur_test`, `mcv_muur_ui_test`, `mcv_poort_test`, `mcv_wacht_test`, `mcv_kaarten_test`, `mcv_toren_test`, `mcv_voorraad_test`, `mcv_draai_test` allemaal 0 fouten.
- Viewer (`tools/blender-vq2-viewer`, asset `mcv`, `test-mcv.mjs`): echte clip, alle 6 bewegende delen bewegen, 360° orbit. Chromium software-WebGL, geen Safari.
- Beelden uit de engine (software-Vulkan, `tests/mcv_wagen_foto.gd`): `docs/vq2/renders/mcv-spel-*.png`.

## Bekend en niet gemeten
- **NIET GETEST:** native iPhone (FPS, touch, camera), Xogot, Quick Look.
- ~100k driehoeken: zwaarder dan de andere voertuigen. Geen LOD, schaduw alleen van romp, container en schild.
- De geparkeerde wagen heeft alleen de voertuiglaag (32): bouwen kan er nog overheen (plek wordt niet geweigerd) en vijanden schieten er niet op.
- De dakpanelen schuiven plat naar buiten en de mast rijst weinig: eerste versie van de animatie, te verfijnen na Dennis' oordeel.
- Het uitgeklapte hoofdkwartier is het bestaande HK-model; de container is een apart commandokern naast het gebouw, niet er een onderdeel van.
