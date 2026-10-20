# Bloedjungle assetinventaris

De bibliotheek staat los van de bestaande gameplay. De nieuwe modellen zijn niet in bestaande scenes geplaatst.

## Bestaand en hergebruikt

| Asset | Locatie | Besluit |
| --- | --- | --- |
| Tank plus kleurtextuur | `assets/tank.glb`, `assets/tank_tank_camo.png` | Behouden; geen tweede tank |
| Apache plus kleurtextuur | `assets/apache.glb`, `assets/apache_apache_olijf.png` | Behouden; geen tweede Apache |
| Geanimeerde soldaat | `assets/soldaat.glb` | Behouden; geen extra Mixamo-kopie |
| Legerjeep | [PR #4](https://github.com/boodschappenmaatje/Bloedjungle-godot/pull/4), `assets/jeep.glb` | Niet gekopieerd of gewijzigd; na samenvoegen beschikbaar |
| Palmen, struiken, varens, rotsen | `scripts/foliage.gd`, `scripts/leaf_tex.gd` | Procedurele level-assets blijven bestaan |
| Bunker, wachttorens, hutten, kratten, zandzakken | `scripts/base_props.gd` | Procedurele level-assets blijven bestaan |
| Hout- en rotsmaterialen | `scripts/kit.gd` | Procedurele materialen blijven bestaan |

Op deze branch stonden geen eerder gedownloade Poly Haven-texturen of losse junglemodellen. De vijf bestaande binaire assetbestanden zijn niet gedupliceerd.

## Nieuwe materialen

Elke set bevat `base_color.jpg`, `normal_gl.jpg`, `roughness.jpg` en een Godot-materiaal `material.tres`.

| Groep | Materiaalsets | Bron |
| --- | --- | --- |
| Terrein | `mud`, `dry_earth`, `jungle_ground`, `moss`, `grass`, `river_sand`, `gravel_rock` | Poly Haven-spiegel; `jungle_ground` en `grass` van ambientCG |
| Gebouwen | `concrete`, `weathered_wood`, `corrugated_iron`, `rusted_metal`, `plywood`, `painted_metal`, `jute`, `army_green_paint` | Poly Haven-spiegel; `concrete` van ambientCG |
| Natuur | `tree_bark`, `rock_material` | Poly Haven-spiegel |
| Extra | `metal` | ambientCG; generieke metaalset |

De Poly Haven-spiegel bevat maximaal 512px detail per map. De bestanden zijn tot 1024 × 1024 omgezet voor uniform gebruik in Godot. Dit voegt geen detail toe. `moss` is mos op rots; `river_sand` is vochtig zand; `jute` is hessian-doek; `army_green_paint` is verweerd groen metaal.

## Nieuwe modellen en HDRI

| Groep | Inhoud | Aantal |
| --- | --- | ---: |
| Natuur | Palm, tropische boom, varen, struik, rots, stronk, boomstam | 7 GLB |
| Gebouwen en objecten | Tent, torenmodule, brug, kist, vat, hek, brandstoftank | 7 GLB |
| Voertuigen | Vrachtwagenbasis, nog zonder militaire details | 1 GLB |
| Omgeving | Poly Haven `kloppenheim_06_puresky_2k.hdr` | 1 HDRI |

De HDRI is gekozen als diffuse, bewolkte buitenlucht zonder stedelijke bebouwing. Het bestand is 2048 × 1024 pixels. De bestaande belichting blijft actief tot de HDRI bewust in een scene wordt gebruikt.

## Nog ontbrekend als los model

Een Huey-achtige helikopter, bunker, specifiek militaire hut, controlepost, jerrycan en zandzakken zijn niet gevonden met zowel controleerbare licentie als toegankelijke download. De vrachtwagen is een ongepantserde basis. De Jeep uit PR #4 moet nog via die PR worden samengevoegd. Bunker, hut en zandzakken zijn al procedureel aanwezig.

Het downloadmanifest staat in `assets/asset_manifest.json`. De SHA-256 en grootte van ieder nieuw bestand staan in `assets/licenses/downloaded_assets.json`.
