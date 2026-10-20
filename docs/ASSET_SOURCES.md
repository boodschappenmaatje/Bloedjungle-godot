# Assetbronnen en licenties

Alle toegevoegde bestanden komen van commit-gefixeerde publieke GitHub-URL's in `assets/asset_manifest.json`. `assets/licenses/downloaded_assets.json` bevat de SHA-256 van zowel de bron als het geplaatste bestand. Het Python-script weigert dubbele inhoud, corrupte bestanden, ontbrekende GLB-afhankelijkheden en overschrijven van bestaande bestanden.

| Maker | Gebruikte bron | Licentie | Opmerking |
| --- | --- | --- | --- |
| ambientCG | [CC0-collectie](https://github.com/petroulacl/fps-buildings-env-kit/tree/1dd8e932402deb82422920df2e7fd079391e55d3/environment/ground-textures/ambientcg) | CC0 volgens de broncollectie | 2K Color, NormalGL en Roughness worden naar 1K verkleind |
| Kenney | [Kenney-collectie](https://github.com/shorepine/kenney/tree/3694c6879e487c108f55677be7dd2ca75b07cc3b/3d) en [licentietekst](https://github.com/shorepine/kenney/blob/3694c6879e487c108f55677be7dd2ca75b07cc3b/LICENSE.txt) | CC0 | GLB-modellen; maker Kenney |
| Quaternius | [Stylized Nature MegaKit-spiegel](https://github.com/petroulacl/fps-buildings-env-kit/tree/1dd8e932402deb82422920df2e7fd079391e55d3/environment/vegetation) | CC0 volgens de broncollectie | Varen |
| Poly Haven | [HDRI-spiegel](https://github.com/petroulacl/fps-buildings-env-kit/tree/1dd8e932402deb82422920df2e7fd079391e55d3/environment/skyboxes/polyhaven-hdri) | CC0 volgens de broncollectie | `kloppenheim_06_puresky_2k.hdr`; diffuse buitenlucht zonder stedelijke elementen |

Directe verzoeken aan `api.polyhaven.com`, `polyhaven.com`, `dl.polyhaven.org`, Poly Pizza en Sketchfab leveren in deze omgeving HTTP 403 van de netwerkproxy. Er is geen toegangscontrole omzeild. Daarom zijn er nog geen rechtstreekse Poly Haven 1K-materiaalsets gedownload. De gekozen HDRI is een expliciet als Poly Haven CC0 aangeduide kopie in de toegestane GitHub-bron.

Er zijn geen CC-BY-bestanden toegevoegd; naamsvermelding is daarom juridisch niet vereist. De makers en exacte herkomst blijven hierboven en in het manifest vermeld.
