# Assetbronnen en licenties

De commit-gefixeerde download-URL's, licenties, makers, verwachte bron-hashes en outputbestanden staan in `assets/asset_manifest.json`. Gecontroleerde bron- en output-SHA-256, bestandsgroottes en importmetadata staan in `assets/licenses/downloaded_assets.json`.

| Bron | Licentie | Gebruik en beperking |
| --- | --- | --- |
| [Poly Haven CC0-mirror](https://github.com/Papyszoo/CC0-Public-Domain-Textures/tree/fcc4ff97a5a843dc2e242ec9e195389bc46ed7d2/packs/polyhaven-textures) | CC0 volgens mirror | 14 materiaalsets. Originele mirror-maps zijn maximaal 512px (jute 512×509); 1K-bestanden zijn opgeschaald. |
| [ambientCG-collectie](https://github.com/petroulacl/fps-buildings-env-kit/tree/1dd8e932402deb82422920df2e7fd079391e55d3/environment/ground-textures/ambientcg) | CC0 volgens broncollectie | `Ground037`, `Grass004`, `Concrete012`, `Metal063`; alle bronmaps 2048×2048, omgezet naar 1024×1024. |
| [Poly Haven HDRI-mirror](https://github.com/petroulacl/fps-buildings-env-kit/tree/1dd8e932402deb82422920df2e7fd079391e55d3/environment/skyboxes/polyhaven-hdri) | CC0 volgens broncollectie | `kloppenheim_06_puresky_2k`, 2048×1024; diffuse bewolkte buitenlucht zonder stedelijke bebouwing. |
| [Kenney 3D-collectie](https://github.com/shorepine/kenney/tree/3694c6879e487c108f55677be7dd2ca75b07cc3b/3d) | CC0 | De bestaande 14 GLB-modellen. Licentietekst staat in de broncollectie. |
| [Quaternius Stylized Nature MegaKit-mirror](https://github.com/petroulacl/fps-buildings-env-kit/tree/1dd8e932402deb82422920df2e7fd079391e55d3/environment/vegetation) | CC0 volgens broncollectie | Varen-GLB. |
| [D A York / medmatix H-Hut](https://github.com/medmatix/WW2_Building_Models/tree/d9583dee0864b4519541ee3dea6172eb200a72d1/Blender_Sources) | MIT | Eén H-hut uit `H-hut.blend`, omgezet naar GLB. Volledige licentie staat in `assets/licenses/MIT_H-hut.txt`. |

De Poly Haven-mirror fetchcode vraagt `nor_gl` aan bij de officiële API; de bijbehorende oorspronkelijke Poly Haven-assetpagina's staan in het manifest. De geselecteerde HDRI is `kloppenheim_06_puresky_2k`: de wolkenhemel is bruikbaar als tropische buitenlucht en bevat geen zichtbare bebouwing die afleidt van de jungleomgeving.

## Niet bereikbare bronnen

Op 2026-10-20 gaven `api.polyhaven.com`, `polyhaven.com`, `dl.polyhaven.org`, `poly.pizza` en `sketchfab.com` HTTP 403 van de netwerkproxy. Er is geen toegangscontrole omzeild. Daardoor zijn geen hoogwaardige directe Poly Haven-texturen of modellen van die catalogi toegevoegd. Bestaande werkende texturen zijn behouden. De enige nieuwe militaire modelbron in deze fase is het gecontroleerde MIT H-Hut-model.

## Opnieuw downloaden

Installeer Python 3 en Pillow. Voor bestaande Poly Haven-KTX2-bronnen is ook Basis Universal `basisu` nodig (`BASISU_BIN` mag het uitvoerpad aanwijzen). Voor `.blend`-bronnen is Blender CLI nodig (`BLENDER_BIN` mag het uitvoerpad aanwijzen). Het script leest alleen URL's uit het goedgekeurde manifest, controleert bron- en outputhashes en laat bestaande bestanden staan. Onderbroken downloads blijven in de genegeerde cachemap `.asset-download-cache/` staan; een herhaling gebruikt HTTP Range als de host dit ondersteunt. Een host zonder Range wordt veilig vanaf byte nul opnieuw opgehaald.

```bash
python3 tools/download_assets.py --batch military
python3 tools/download_assets.py --batch all
```

Windows: gebruik `py -3 tools/download_assets.py --batch all`.
