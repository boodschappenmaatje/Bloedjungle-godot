# Bloedjungle assetinventaris

Deze bibliotheek staat los van de bestaande gameplay. De nieuwe modellen zijn nog niet in scenes geplaatst.

## Bestaand en hergebruikt

| Asset | Locatie | Status |
| --- | --- | --- |
| Tank | `assets/tank.glb` | Bestaand; geen vervanging gedownload |
| Apache | `assets/apache.glb` | Bestaand; geen vervanging gedownload |
| Soldaat met Mixamo-animaties | `assets/soldaat.glb` | Bestaand; geen extra personage gedownload |
| Legerjeep | PR #4, `assets/jeep.glb` | Bestaand in de open PR; PR niet gewijzigd |
| Palmen, struiken, varens, rotsen | `scripts/foliage.gd` en `scripts/leaf_tex.gd` | Procedureel aanwezig; nieuwe GLB's zijn optionele losse varianten |
| Bunker, wachttorens, hutten, kratten, zandzakken | `scripts/base_props.gd` | Procedureel aanwezig; niet vervangen |
| Hout, rots en overige basismaterialen | `scripts/kit.gd` | Procedureel aanwezig; geen eerder gedownloade Poly Haven-bestanden gevonden |

## Nieuwe bibliotheek

| Batch | Inhoud | Status |
| --- | --- | --- |
| 1 Terrein | Junglegrond en gras, elk base color, Normal GL en roughness op 1K | Gedownload |
| 2 Gebouwen | Beton en metaal, elk base color, Normal GL en roughness op 1K | Gedownload |
| 3 Natuur en HDRI | Palm, tropische boom, varen, struik, rots, stronk, boomstam en 2K-HDRI | Gedownload |
| 4 Militaire objecten | Tent, torenbasis, brug, kist, vat, hek en brandstoftank | Gedownload |
| 5 Voertuigen | Basis voor een vrachtwagen; bestaande tank, Apache en jeep hergebruikt | In behandeling |

Het volledige goedgekeurde downloadmanifest staat in `assets/asset_manifest.json`. De hash en grootte van elk daadwerkelijk opgehaald bestand staan in `assets/licenses/downloaded_assets.json`.

## Nog ontbrekend

Poly Haven is vanuit de huidige omgeving direct geblokkeerd. Het manifest gebruikt daarom CC0-materiaalsets van ambientCG voor de eerste terreincategorieën. Modder, droge aarde, mos, rivierzand, grind en rotsgrond, en meerdere bouwmaterialen hebben nog geen geverifieerde eigen 1K-set. Losse Huey-helikopter, militair ingerichte vrachtwagen, bunker, controlepost, jerrycan en zandzakken zijn nog niet gevonden met zowel downloadmogelijkheid als controleerbare licentie. De procedurele bunker en zandzakken bestaan al in het project.
