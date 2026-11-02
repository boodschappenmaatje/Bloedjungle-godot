# Voorraad stap 4b: depot, truck, wrak en stapel (stijl Intendance) — rapport

Generals-plan stap 4b (docs/GENERALS_PLAN.md, onderdeel A1). Ontwerp: [bron/voorraad/ASSET_DESIGN_SPEC.md](../../bron/voorraad/ASSET_DESIGN_SPEC.md) (door Dennis gekozen stijl **Intendance**: geel-zwarte gevaarbanden, witte stencilletters, olijfkisten met gele band, gele chevron).
Productie: Blender 5.2.3 (`pip install bpy`, headless, Cycles CPU) op de cloudsandbox; **niet** op de gekoppelde iMac (geen toegang in deze sessie), dus niet via Bloedjungle 3D Production Pipeline 1.0. Standaard: [ASSET_QUALITY_STANDARD.md](../ASSET_QUALITY_STANDARD.md).

## 1. Wat er is opgeleverd

| Model | Spel-GLB | LOD1 | HQ-bron (.blend) | USDZ | Clips (echte glTF) |
|---|---|---|---|---|---|
| Voorraaddepot | `assets/voorraaddepot.glb` | `voorraaddepot_lod1.glb` | `bron/voorraad/uit/Voorraaddepot_HQ.blend` | `uit/Voorraaddepot.usdz` | `Poort` (2,0 s), `Kraan-lossen` (4,5 s) |
| Voorraadtruck | `assets/voorraadtruck.glb` | `voorraadtruck_lod1.glb` | `uit/Voorraadtruck_HQ.blend` | `uit/Voorraadtruck.usdz` | `Laden` (4,5 s), `Lossen` (4,5 s), 13 kanalen elk |
| Wrak | `assets/voorraadtruck_wrak.glb` | — | `uit/Voorraadtruck_wrak_HQ.blend` | `uit/Voorraadtruck_wrak.usdz` | geen (statisch) |
| Voorraadstapel | `assets/voorraadstapel.glb` (drie standen in één bestand) | — | `uit/Voorraadstapel_HQ.blend` | `uit/Voorraadstapel.usdz` | geen (statisch) |

Reproduceerbaar: `python3 bron/voorraad/maak_<model>.py hq|game|lod1` (zie [bron/voorraad/README.md](../../bron/voorraad/README.md)). De spel-`.blend`'s (`uit/voorraad*.blend`) zijn de gebakken tussenstap voor de export.

## 2. Gemeten (uit de echte GLB's; Godot-import en Blender)

| Model | HQ-bron | Spel LOD0 | LOD1 | Materialen (spel) | Texturen (spel) | GLB |
|---|---:|---:|---:|---:|---|---:|
| Depot | 141.644 driehoeken | **33.278** (budget ≤ 45.000) | 4.184 (≈ 6.000) | 5 (1 gebakken + stencil + 3 lampen) | 2K albedo/ORM/normal (2048²) + stencil 2048×1024 | 7,2 MB |
| Truck | 52.938 | **16.603** (richt ca. 16.000, +4 %) | 2.608 (≈ 2.500) | 6 (1 gebakken + glas + stencil + 3 lampen) | 2K albedo/ORM/normal + stencil | 6,0 MB |
| Wrak | 48.916 | 16.492 | — | 1 | 2K albedo/ORM/normal | 6,0 MB |
| Stapel (3 standen) | 82.008 totaal | **vol 4.276 / half 2.643 / leeg 2.078** (≈ 5.000 per stand; Godot toont er één) | — | 3 (gebakken + stencil + camonet) | 2K albedo/ORM/normal + stencil + camonet 1024 | 6,9 MB |

LOD1-texturen zijn 1024². De HQ-bronnen zijn ruim boven de 40.000 driehoeken en gebruiken live procedurele materialen (afgebakt voor de spelversie). Spelversies hebben één gebakken atlas per model, geen losse kleine meshes (snoeien van onzichtbare vlakken is gedaan: depot 6.188 → 3.504 vlakken).

Visibility range: LOD0 tot 80 m (depot, `VoorraadDepotModel.LOD_SWITCH`) of 70 m (truck), LOD1 daarna. Geheugen: per model drie 2048²-texturen (jpg-bronnen, op iOS ETC2/ASTC-gecomprimeerd door Godot-import).

## 3. Animaties

* **Truck** (`Laden`, `Lossen`, 4,5 s): kraankolom zwenkt, telescoopgiek schuift uit en helt, ketting/lier laat de grijper zakken, de klauwen sluiten en openen, de kist (`Lading`/`Kist_vast`) verschijnt in de klauwen en gaat de bak in (of op de laadplaat). Begin- en eindpose zijn gelijk (loopt naadloos door). De wielen (`Wiel_*`) zijn losse nodes: de code draait ze met de snelheid mee.
* **Depot**: `Poort` = rolpoort rolt op (schaal op de balk), `Kraan-lossen` = portaalkraan (brug > loopkat > ketting/haak) pakt de kist van de laadplaat en stapelt hem op het opslagpallet.
* Controle: `tests/voorraad_modellen_test.gd` laat de clips echt afspelen en kijkt of de onderdelen bewegen (zie §5); de viewer-test doet hetzelfde in de browser.
* De wielrotatie, de stofwolk, geluid, de gouden stapelruit en de teller zijn Godot-gestuurd (niet in een clip).

## 4. Afwijkingen van de spec (en waarom)

1. **Eén stapel-GLB** met drie groepen (`Stapel_vol`, `Stapel_half`, `Stapel_leeg`) in plaats van drie bestanden; Godot toont er één. Dit scheelt drie texturensets.
2. **Clips 4,5 s** in plaats van 3,0 s (laden) en 2,2 s (lossen): de kraan heeft een geloofwaardige reikwijdte en snelheid nodig. De code gebruikt dezelfde lengtes (`LOAD_T`/`UNLOAD_T`), dus de ritcyclus is iets langer; de test `voorraad_test` bewaakt dat een cyclus binnen 83 s blijft.
3. **Truck 16.603 driehoeken** is 4 % boven het richtgetal van 16.000 (budget in de test: ≤ 17.000).
4. **Truck stopt verder van de stapel.** Omdat de grijper 6,64 m voor de truck pakt (Laden) en 5,64 m voor de truck neerzet (Lossen): `STOP_BEFORE` 4,5 → **9,44 m** (grijper op de afhaalkist, 2,8 m voor de stapel), `DOCK_OFFSET` **4,39 m** voor het depot, nieuw `PRE_DOCK` 9 m (de truck komt recht op het depot af). Gemeten met een Blender-probe op de echte clips.
5. **Afhaalkist**: elke stapelstand heeft een losse kist op een klein pallet aan de voorkant (+Z), die de grijper pakt; verdwijnt als de truck hem heeft (`pickup_taken`).
6. **Depot-voetafdruk 9 × 6,5 m** (was 8 × 6): het portaal en de laadplaat passen anders niet. Botsblok = voetafdruk.
7. De USDZ's zijn met PBR-materialen en texturen geëxporteerd (pakketstructuur gecontroleerd: `.usdc` + albedo/ORM/normal + stencil). Of de clips van truck en depot in de USDZ meespelen is **niet gecontroleerd**; de GLB is de bron voor animatie.

## 5. Tests

Uitgevoerd in de cloudsandbox (Godot 4.6.3, headless, en xvfb + opengl3 voor beelden):

* `tests/voorraad_modellen_test.gd` (nieuw): **fouten=0**. Namen, clips (lengte, kanalen, onderdelen bewegen), driehoeksbudgetten, materialen, LOD1, afhaalkist per stand.
* `tests/voorraad_test.gd` (4a-contract, uitgebreid met de afhaalkisten): **fouten=0** met de echte modellen: botsblok, route, wrak en verloren lading, poortopening alleen voor rijdende trucks, volledige rit, kopen (maximaal 3), stapel leegmaken en nieuwe stapel verder weg, tweede depot, depotpaneel.
* `tools/blender-vq2-viewer/test-voorraad.mjs` (nieuw): **ok** — alle vier de modellen laden uit de echte GLB, clips spelen en de onderdelen bewegen (zie `docs/vq2/results/voorraad-viewer-test.json`), 360°-draaien, gamecamera.
* Regressie (30 bestaande tests rond bouwen, HK, garage, benzine, hotel, magazijn, stad, HUD, radio, sloop, schade, explosie, granaat, enzovoort): **allemaal groen**, op één na: `kwaliteit_regel_test` (2 fouten, de resolutieregel) faalt **identiek op main** (4e2bc0a) en is niet van deze wijziging. Bekende bestaande rode tests op main (animatie, besturing, wiel_richten, tactical_hybrid_4, combat_visuals, soldaat_pose, wapen_clips, airfield-contract, meshy-speler, `*_foto`) zijn niet gewijzigd en niet opnieuw beoordeeld.

## 6. Voor/na met de echte spelcamera

`tests/voorraad_foto.gd` maakt opnames met dezelfde camera, belichting (dag) en standen in beide versies: **voor** = 4a-blokken (main 4e2bc0a), **na** = deze branch. Beelden in `docs/vq2/renders/voorraad4b/` (`voor_*.jpg`, `na_*.jpg`):

* depot dicht; truck lost (1,5 s / 3,1 s / 4,6 s); truck laadt bij de stapel; stapel vol, half, leeg; wrak.
* Viewer-opnames per model (iso, gamecamera, clip-moment): `docs/vq2/renders/voorraad*-viewer-*.png`.

Opmerking: de opnames komen van software-rendering (llvmpipe) en zeggen niets over snelheid.

## 7. Niet gedaan / niet gemeten

* **iPhone/native FPS: NIET GETEST.** Geen echte native-appmeting, geen Safari, geen Xogot. De driehoek- en texturenaantallen zijn uit de bestanden gemeten, de prestatie is niet gemeten.
* Geen USDZ-controle op een echte iPhone of in macOS Quick Look (alleen pakketstructuur en bevat-texturen gecontroleerd).
* Niet via de Bloedjungle 3D Production Pipeline 1.0 op de iMac (geen toegang in deze sessie).
* Niet gemerged, geen OTA. Draft PR; Dennis geeft apart toestemming.

## 8. Bekende bijzonderheden

* De bake duurt 5 tot 30 min per model (Cycles CPU); de GLB's zijn daarom gecommit en worden niet bij elke build opnieuw gegenereerd.
* Godot hernoemt dubbele Blender-namen (`Afhaal`, `Afhaal.001` → `Afhaal_001`); `scripts/voorraad_stapel.gd` zoekt daarom op naamvorm (getest in `voorraad_test`).
* Het voor/na-script crasht soms bij het opstarten in xvfb (`std::system_error`, thread-aanmaak in de sandbox); opnieuw starten helpt.
