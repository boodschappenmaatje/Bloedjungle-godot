# Voorraadtruck uit Dennis' Meshy-model

`assets/voorraadtruck.glb` (met `voorraadtruck_lod1.glb` en `voorraadtruck_wrak.glb`) is nu de kraanwagen die Dennis in Meshy maakte
(Google Drive-map "Vrachtauto depo", bestanden `Vrachtauto depo.glb` en `.fbx`). De vorige procedurele truck (`bron/voorraad/maak_truck.py`) blijft
als vergelijking in de viewer (`assets/vq2_baseline/voorraadtruck_v1.glb`, `voorraadtruck_wrak_v1.glb`).

## Bron

| | |
| --- | --- |
| Bestand | `Vrachtauto depo.glb`, 117,9 MB, **3.729.764 driehoeken**, 1 mesh, 1 materiaal (drie 4K-texturen: albedo, metallic-ruwheid, normal), maat 1,903 × 0,536 × 1,03 (bron-eenheden) |
| Niet in de repo | te groot voor GitHub; zet het bestand lokaal en geef het pad door aan stap 1 |
| Vorm | één samengesmolten mesh: cabine, bak met kisten en zakken, kraan met giek en 3-klauws grijper, steunpoot, zes wielen (voorwiel enkel, twee achterassen dubbel) |

## Opnieuw bouwen (Blender 5.2 via `pip install bpy numpy`; ongeveer 5 minuten op 4 kernen, zonder GPU)

    CACHE=/tmp/meshy_truck_cache ; UIT=/tmp/meshy_truck_uit
    python3 stap1_delen.py   "Vrachtauto depo.glb" $CACHE 0.02   # voxel-remesh 2 cm (gesloten schil) + indeling van de vlakken
    python3 stap2_laag.py    $CACHE                              # delen dichtmaken, decimeren, wielen schoon genereren, UV's
    python3 stap3_bakken.py  "Vrachtauto depo.glb" $CACHE 2048   # albedo, normal, ruwheid/metallic bakken van de 3,7 miljoen driehoeken
    python3 stap4_export.py  $CACHE $UIT 2048                    # draaipunten, clips Laden en Lossen, uit/voorraadtruck_meshy.blend en .glb
    python3 stap5_lod_wrak.py $CACHE $UIT                        # LOD1 (3.198 driehoeken, 1K) en wrak
    python3 stap6_usdz.py    $UIT                                # USDZ-previews voor iPhone Bestanden/Quick Look
    cp $UIT/voorraadtruck_meshy.glb ../../assets/voorraadtruck.glb   # idem _lod1 en _wrak

`delen.py` bevat de indeling (waar de kolom, giek, uitschuifgiek, grijper, klauwen, lading en wielen zitten) en de schaal; pas daar aan als het
bronmodel verandert. `kijk.py` rendert een `.blend` of `.glb` met Cycles (CPU) vanuit vaste standpunten of in een clip-beeld (controle).

## Wat er gebeurt

1. **Op maat**: de bron is 1,903 lang; ×3,5 = 6,66 m (een 6×6-kraanwagen; band 0,49 m straal). Grond op z = 0, voorkant naar +Z in Godot.
2. **Gesloten schil**: de Meshy-mesh bestaat uit losse schilfers. Een voxel-remesh (2 cm) levert één gesloten schil (733.000 driehoeken) waarop gedecimeerd kan worden.
3. **Delen** (`delen.indelen`): romp (cabine, chassis, bak), kolom (zwenkbasis + cilinder), giek, uitschuifgiek, grijper (naaf), drie klauwarmen,
   lading (kisten en zakken boven de bakvloer) en zes wielen. Snijvlakken worden dichtgemaakt (`holes_fill`).
4. **Lage versie** (52.381 driehoeken): romp 27.000, kolom 3.600, giek 3.600, uitschuifgiek 3.200, grijper 1.500, drie klauwen 3×1.100, lading 5.000
   en zes wielen (omwentelingslichamen, 24 zijden, 864 driehoeken) met het profiel uit het bronwiel.
5. **Textuur bakken** (Cycles CPU, 93 s) van de 3,7 miljoen driehoeken naar één atlas 2048² (albedo, tangent-normal, ORM). Geverfde delen mat-dielectrisch,
   alleen donker staal metaal.
6. **Draaipunten en clips** (`stap4_export.py`), zie hieronder.
7. **LOD1**: gesloten voxel-schil van 8 cm, gedecimeerd tot 3.198 driehoeken, eigen 1K-textuur van de bron gebakken. **Wrak**: dezelfde delen in een
   ingestorte kraanpose (giek half gezakt, uitgeschoven, klauwen op de grond), scheef, albedo verkoold en ruwheid omhoog.

## Knopen en clips (contract met `scripts/voorraad_truck.gd`)

`Voorraadtruck` > [`Romp`, `Wiel_FL`…`Wiel_RR` (zes), `Lading`, `Kolom` > [`KolomMesh`, `Giek` > [`GiekMesh`, `Telescoop`, `GiekUit` >
[`GiekUitMesh`, `Kettingpunt` > [`Ketting`, `Grijper` > [`GrijperMesh`, `Kist_vast`, `Klauw_LV`, `Klauw_LA`, `Klauw_RV`]]]]]]

* **Kolom** zwenkt om de verticale as (de giek draait over de cabine naar voren), **Giek** helt om het scharnier, **GiekUit** schuift 2,5 m uit langs de
  gieklijn terwijl de **Telescoop** (binnenste buis, staal) de opening vult, **Ketting** schaalt mee met het zakken van de **Grijper** (altijd verticaal),
  de drie **Klauw**-armen draaien om een eigen scharnier op de naaf. **Kist_vast** (olijfgroene kist met gele banden, eigen kleine textuur) verschijnt in de
  klauwen, **Lading** (de kisten en zakken uit het model) verschijnt in de bak.
* Clips (30 beelden/s, **6,0 s**, beginpose = eindpose): `Laden` (kist van de stapel, beeld 90 = 0,5 = `LOAD_TAKE`; Lading verschijnt in de bak) en
  `Lossen` (Lading weg, kist op de laadplaat, beeld 126 = 0,7 = `UNLOAD_DROP`).
* **De wielen draait Godot** (snelheid / straal 0,49 m), de voorwielen sturen om de verticale as; `scripts/voorraad_truck.gd` bepaalt de draairichting uit de stand van het wielknooppunt.
* **Reikwijdte** (gemeten in `stap4_export.py`, `uit/voorraadtruck_maten.json`): de grijper komt **4,90 m voor het midden van de truck** (zwenkhoek 182°,
  giek 8° omhoog, 2,5 m uitgeschoven, de as van de klauwen ligt dan op de lengteas). Daarom `Voorraad.STOP_BEFORE` 9,44 → **7,70 m** en
  `Voorraad.DOCK_OFFSET` 4,39 → **3,65 m**, `REACH_UNLOAD` 4,90 m, `LOAD_T`/`UNLOAD_T` 6 s.

## Cijfers

| | vorige truck | Meshy-truck |
| --- | ---: | ---: |
| Driehoeken LOD0 / LOD1 / wrak | 16.603 / 2.608 / 16.492 | **52.147** / 3.198 / 52.111 (gemeten in Godot) |
| Materialen LOD0 | 6 | 3 (VR_Meshy_truck, VR_Staal, VR_Kist) |
| Texturen LOD0 | 2K albedo/ORM/normal + stencil | 2K albedo/ORM/normal + kistje 512×256 |
| Clips | Laden/Lossen 4,5 s | Laden/Lossen 6,0 s |
| Maat (breed × lang × hoog) | 2,6 × 6,4 × 3,5 m | 2,14 × 6,67 × 3,36 m (romp met wielen 2,25 m hoog; gemeten aan de .blend in rustpose) |

Niet gemeten: FPS op iPhone of in Safari/Xogot. Drie trucks LOD0 zijn samen ruim 150.000 driehoeken: dat is alleen binnen 70 m van de camera zo (daarachter
LOD1). Of dat op de native app soepel blijft moet Dennis testen (zie `docs/vq2/voorraad-meshy-rapport.md`).
