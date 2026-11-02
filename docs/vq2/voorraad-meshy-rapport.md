# Voorraadtruck uit Dennis' Meshy-model, gladder rijden en donkerder depot (v182) — rapport

Aanleiding: Dennis' feedback op v179 (2 november 2026): de truck is niet zo mooi als tank en jeep, het depot geeft te veel licht en de truck neemt bochten te houterig.
Dennis maakte zelf een nieuwe vrachtwagen in Meshy (Google Drive-map "Vrachtauto depo", `Vrachtauto depo.glb` en `.fbx`) en vroeg om dezelfde animaties op dat model,
met een controle dat de textures niet te zwaar zijn (minimaal 40.000 driehoeken voor de hoge-kwaliteitsversie).

Standaard: [ASSET_QUALITY_STANDARD.md](../ASSET_QUALITY_STANDARD.md). Productie: Blender 5.2.3 (`pip install bpy`, headless, Cycles CPU) in de cloudsandbox; **niet** via de
Bloedjungle 3D Production Pipeline 1.0 op de iMac (geen toegang in deze sessie). Bron, stappen en reproduceerbare code: [bron/voorraad_meshy/](../../bron/voorraad_meshy/README.md).

## 1. Wat er is opgeleverd

| Onderdeel | Bestand(en) |
|---|---|
| Truck LOD0 / LOD1 / wrak (Godot-GLB) | `assets/voorraadtruck.glb`, `voorraadtruck_lod1.glb`, `voorraadtruck_wrak.glb` |
| Bewerkbare Blender-bronnen | `bron/voorraad_meshy/uit/voorraadtruck_meshy.blend`, `_lod1.blend`, `_wrak.blend` |
| Reproduceerbare code | `bron/voorraad_meshy/stap1_delen.py` … `stap6_usdz.py`, `delen.py`, `kijk.py` |
| iPhone-preview | `bron/voorraad_meshy/uit/Voorraadtruck.usdz` (met clip `Laden`), `Voorraadtruck_wrak.usdz` |
| Vergelijking oud/nieuw | `assets/vq2_baseline/voorraadtruck_v1.glb`, `voorraadtruck_wrak_v1.glb` (de procedurele truck van v179) in de bestaande viewer `tools/blender-vq2-viewer/` |
| Gameplay | `scripts/voorraad_truck.gd`, `scripts/voorraad.gd`, nieuw `scripts/voorraad_baan.gd` (vloeiend rijden) |
| Depot minder fel | `bron/voorraad/vc.py` (donkerder kleuren), opnieuw gebakken `assets/voorraaddepot.glb` en `_lod1.glb` |

De Meshy-bron zelf (117,9 MB, 3,7 miljoen driehoeken) staat **niet** in de repo (te groot voor GitHub). Het pad gaat als argument naar stap 1.

## 2. Gemeten

Uit de echte GLB's (Godot-import en Blender), niet geschat:

| | v179 (procedureel) | Meshy-truck (v182) |
|---|---:|---:|
| Bron (Dennis' Meshy-model) | — | **3.729.764 driehoeken**, 1 mesh, 4K-albedo/ORM/normal |
| Spel LOD0 | 16.603 | **52.147** driehoeken |
| LOD1 (vanaf 70 m) | 2.608 | **3.198** |
| Wrak | 16.492 | **52.111** |
| Materialen LOD0 | 6 | 3 (`VR_Meshy_truck`, `VR_Staal`, `VR_Kist`) |
| Texturen LOD0 | 2K albedo/ORM/normal + stencil | 2K albedo/ORM/normal (2048²) + kistje 512×256 |
| Texturen LOD1 | 1K | 1K albedo/ORM/normal |
| GLB-grootte LOD0 / LOD1 / wrak | 6,0 / — / 6,0 MB | 5,87 / 1,17 / 4,58 MB |
| Clips | `Laden`, `Lossen` 4,5 s | `Laden`, `Lossen` **6,0 s** (30 beelden/s, echte NLA-clips, begin = eind) |
| Maat (breed × lang × hoog) | 2,6 × 6,4 × 3,5 m | 2,14 × 6,67 × 3,36 m |

Dennis' eis "minimaal 40.000 driehoeken" geldt voor het hoge-kwaliteitsmodel: de spelversie heeft **52.147** (de bron 3,7 miljoen). Dat is ruim boven 40.000 en past op de spelcamera
omdat de truck van boven en op afstand gezien wordt. Textuur: één 2K-atlas (drie kaarten) voor de hele truck; het geschatte texturengeheugen is ongeveer 17 MB na ASTC-compressie.
Dat getal is **een schatting**, geen meting. De rekenlast van drie trucks tegelijk (ruim 150.000 driehoeken, alleen binnen 70 m van de camera, daarachter LOD1) is op de iPhone **NIET GETEST**.

## 3. Hoe het model is gemaakt

1. **Op maat en gesloten schil**: de Meshy-mesh bestaat uit losse schilfers (3,7 miljoen driehoeken). Een voxel-remesh van 2 cm geeft één gesloten schil (733.000 driehoeken); schaal ×3,5 = 6,66 m, een 6×6-kraanwagen.
2. **Delen**: romp, kolom, giek, uitschuifgiek, grijper, drie klauwarmen, lading (kisten en zakken in de bak) en zes wielen worden uit de schil gesneden, dichtgemaakt en op budget gedecimeerd (romp 27.000, kolom 3.600, giek 3.600, uitschuifgiek 3.200, grijper 1.500, klauw 3 × 1.100, lading 5.000).
3. **Wielen**: schoon gegenereerde omwentelingslichamen (24 zijden, profiel uit het bronwiel) zodat Godot ze kan laten draaien.
4. **Textuur bakken** (Cycles CPU, ca. 93 s): alle 3,7 miljoen driehoeken naar één 2K-atlas met albedo, tangent-normal en ORM. Geverfde delen zijn mat, alleen donker staal is metaal.
5. **Rig en clips**: kolom, giek, uitschuifgiek, ketting, grijper en drie klauwen als echte kinderknopen; clips `Laden` en `Lossen` met zachte versnelling. Reikwijdte gemeten: grijper **4,90 m voor het midden van de truck**.
6. **LOD1** uit een gesloten voxel-schil van 8 cm (3.198 driehoeken) met eigen 1K-bake; **wrak** in een ingestorte kraanpose, scheef, verkoold albedo en ruwere ORM.

## 4. Animaties

* **`Laden`** (6,0 s): de kolom zwenkt ongeveer 182° zodat de giek over de cabine naar voren wijst, de uitschuifgiek schuift 2,5 m uit, de ketting zakt, de drie klauwen openen en sluiten om de kist (de kist wordt zichtbaar in de klauwen, beeld 90 = `LOAD_TAKE`), de grijper hijst op, de giek zwenkt terug en de lading verschijnt in de bak.
* **`Lossen`** (6,0 s): omgekeerd; de kist hangt in de klauwen, wordt op de laadplaat gezet (beeld 126 = `UNLOAD_DROP`) en de lading in de bak verdwijnt.
* De wielen (`Wiel_*`), het sturen van de voorwielen, stof, geluid en de gouden ruit van de stapel zijn **Godot-gestuurd**, niet in een clip. De viewer toont daarom alleen de twee echte clips; de wielen worden in Godot getest.

## 5. Gameplay-wijzigingen

* **Gladder rijden** (Dennis: "te houterig"): nieuw `scripts/voorraad_baan.gd`. De route krijgt afgeronde hoeken (cirkelbogen), de snelheid volgt de kromming, de voorwielen sturen mee met de bocht. Waar een bocht te scherp is rijdt hij in drie keer. Getest in `tests/voorraad_baan_test.gd`.
* **Stof**: zachte stofwolk bij optrekken en remmen in plaats van hard stof.
* **Nieuwe stoppunten** door het kleinere bereik van de Meshy-kraan (4,90 m in plaats van 6,64 m): `Voorraad.STOP_BEFORE` 9,44 → **7,70 m**, `Voorraad.DOCK_OFFSET` 4,39 → **3,65 m**, `REACH_UNLOAD` 4,90 m, `LOAD_T`/`UNLOAD_T` 6 s. De eerste rit duurt daardoor 49,5 in plaats van 46 s (de test bewaakt dat een cyclus binnen 83 s blijft).
* Het wiel-draaien volgt de stand van het wielknooppunt, zodat ook het gespiegelde (Meshy-)model de goede kant op rolt.
* **Depot minder fel**: oorzaak was de bakwinst (2,4) uit de hoofdkwartier-pijplijn: geel liep tot felle neon (rood en groen afgekapt op 1) en het laadplatform van beton was bijna wit. In `bron/voorraad/vc.py` is het geel (`YELLOW` 0,62/0,45/0,04 → 0,22/0,135/0,008), de gevaarband-textuur (0,70/0,50/0,04 → 0,52/0,36/0,03) en het beton van het platform (0,80/0,78/0,72 → 0,60/0,58/0,53) donkerder gemaakt; `assets/voorraaddepot.glb` en `_lod1.glb` zijn opnieuw gebakken. Aantal driehoeken ongewijzigd (zie `voorraad_modellen_test`).

## 6. Afwijkingen en bijzonderheden

1. **Drie klauwen** (zoals Dennis' model), niet vier of twee; de grijper bewerkt alleen de drie echte klauwarmen.
2. **Geen aparte midden-gieksectie**: het bronmodel heeft één giek met uitschuifdeel. Een `Telescoop`-buis (binnenste, staalkleurige buis) vult de opening die bij het uitschuiven ontstaat.
3. **Ketting en kist zijn nieuw gemaakt** (de Meshy-bron heeft geen aparte ketting of kist): ketting schaalt mee met het zakken, kist `Kist_vast` met eigen kleine textuur (olijfgroen met gele banden, zoals de Intendance-stijl).
4. **LOD1 toont de lading** altijd (de lading is niet apart te animeren op 3.198 driehoeken); LOD1 wordt pas vanaf 70 m gebruikt.
5. De sandbox heeft geen EGL voor Workbench; controlebeelden zijn Cycles CPU (`bron/voorraad_meshy/kijk.py`) en Godot-software-rendering (llvmpipe).
6. De USDZ-bestanden bevatten PBR-materialen (albedo, ORM, normal) en de clip `Laden`. Of die animatie in Quick Look afspeelt is **niet gecontroleerd** (geen iPhone of macOS in deze sessie). De GLB blijft de bron voor animatie.
7. Oude texturen (`voorraadtruck_vr_truck_*`, stencil) zijn uit `assets/` verwijderd en leven voort in `assets/vq2_baseline/voorraadtruck_v1*` voor de vergelijking.

## 7. Tests

Uitgevoerd in de cloudsandbox met Godot 4.6.3 (headless; beelden met xvfb + opengl3):

* `tests/voorraad_modellen_test.gd` (bijgewerkt voor het nieuwe model): **fouten=0**. Namen, clips (lengte, kanalen, onderdelen bewegen echt), driehoeksbudgetten, materialen, LOD1, wrak.
* `tests/voorraad_test.gd` (contract, rit, lading, wrak, stoppunten): **fouten=0** met de echte modellen.
* `tests/voorraad_baan_test.gd` (nieuw, vloeiend rijden: bogen, kromming-snelheid, wielhoek, drie-puntskeer): **groen** (zie §8).
* `tools/blender-vq2-viewer/test-voorraad.mjs`: **ok**; de vier modellen laden uit de echte GLB, de clips spelen en de onderdelen (Kolom, Giek, GiekUit, Grijper, Klauw_LV, Lading) bewegen; zie `docs/vq2/results/voorraad-viewer-test.json`.
* Regressie: zie §8.

## 8. Regressie

90 bestaande tests (alle tests uit de lijst van stap 4b plus `voorraad_baan_test`, `voorraad_modellen_test`, `garage_meshy_test`, `garage_hoogte_test`, `garage_truck_uit_test`), uitgevoerd na het samenvoegen met main (v181) en na de versie-ophoging naar v182, Godot 4.6.3 headless:

* **82 groen** (`fouten=0`/exit 0).
* **`magazijn_dak_test`** gaf in de batch één fout (`fouten=1`) en bij herhaling `fouten=0`: een tijdsgevoelige test, geen vaste fout.
* **Rood, maar identiek op een schone `origin/main` (2e18f65, v181)**, dus niet van deze wijziging: `besturing_test`, `wiel_richten_test` (3 fouten), `grass_3d_test` (palm- en rotsposities), `soldaat_markering_test` (de speler heeft nog een ring) en `animatie_test` (loopt na 400 s tegen de tijdgrens).
* **`kwaliteit_regel_test`** (resolutieregel) faalt ook op main (bij stap 4b op 4e2bc0a geverifieerd); `meshy_player_gameplay_video` is een video-opname, geen test, en eindigt met exit 1 zonder GPU.
* Ook zonder fouten: `voorraad_baan_test` (nieuw), `voorraad_modellen_test`, `voorraad_test`, `garage_*`, `hoofdkwartier_test`, `hq_*`, `bouw_test`, `truck_test`, `poort_test` en de overige bouw-, stad-, schade- en explosietests.

De volledige uitvoer per test staat niet in de repo (sandbox-logs); de tests zijn opnieuw uit te voeren met `godot --headless --path . --script tests/<naam>.gd --fixed-fps 60`.

## 9. Voor/na met de echte spelcamera

`tests/voorraad_foto.gd` met dezelfde camera, belichting (dag) en standen: **voor** = v179 (`docs/vq2/renders/voorraad4b/na_*.jpg`), **na** = deze branch. Beelden in `docs/vq2/renders/voorraad-meshy/`:

* `voor_*.jpg` (v179) en `na_*.jpg` (nu): depot dicht, truck lost, truck laadt, wrak. Alleen `na_*` hebben ook `lossen_20/65`, `laden_20/44/52` en de drie stapelstanden (`na_stapel_*`).
  De clips zijn nu 6,0 s in plaats van 4,5 s: de tijdstippen van `voor` (v179: 3,1 s, 4,6 s, 2,6 s) en `na` (3,5 s, 4,7 s, 3,4 s) zijn dus niet exact dezelfde fase van de beweging, maar wel dezelfde camera, dezelfde belichting en dezelfde standen.
* Wat je ziet: het depot is niet meer neon (geel en platform donkerder), de truck is een olijfgroene kraanwagen met de kraan over de cabine, de kist hangt in de drie klauwen en wordt op de laadplaat gezet (de portaalkraan pakt hem daarna op en de punten komen erbij), bij het laden pakt de grijper de kist van de stapel, en het wrak ligt scheef met de giek op de grond.
* Viewer-opnames: `docs/vq2/renders/voorraadtruck-viewer-*.png`, `voorraaddepot-viewer-*.png`, `voorraadtruck_wrak-viewer-*.png`.

De opnames komen van software-rendering (llvmpipe) en zeggen niets over snelheid.

## 9b. Niet gedaan / niet gemeten

* **iPhone/native FPS: NIET GETEST.** Geen native-appmeting, geen Safari, geen Xogot. Driehoek- en texturenaantallen zijn uit de bestanden gemeten, de prestatie niet.
* **Bochten op de iPhone**: het gladder rijden is getest in tests en op beeld, niet met een echte vinger op de native app.
* **USDZ-animatie in Quick Look**: NIET GETEST.
* **Depot 's nachts**: lampen zijn emissieve materialen van de GLB; alleen overdag vergeleken.
* Niet via de Bloedjungle 3D Production Pipeline 1.0 op de iMac.
* Niet gemerged en geen OTA. Draft PR; Dennis geeft apart toestemming.
