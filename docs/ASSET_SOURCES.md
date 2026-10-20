# Assetbronnen en licenties

Alle downloads staan met commit-gefixeerde URL, licentie, maker, bron-SHA-256 en geplaatste SHA-256 in `assets/asset_manifest.json` en `assets/licenses/downloaded_assets.json`.

| Maker | Controleerbare bron | Licentie | Gebruik |
| --- | --- | --- | --- |
| Poly Haven | [CC0-spiegel met bronlinks](https://github.com/Papyszoo/CC0-Public-Domain-Textures/tree/fcc4ff97a5a843dc2e242ec9e195389bc46ed7d2/packs/polyhaven-textures) | CC0 volgens de spiegel | 14 materiaalsets; de spiegel heeft maximaal 512px KTX2-maps |
| Poly Haven | [HDRI-spiegel](https://github.com/petroulacl/fps-buildings-env-kit/tree/1dd8e932402deb82422920df2e7fd079391e55d3/environment/skyboxes/polyhaven-hdri) | CC0 volgens de broncollectie | `kloppenheim_06_puresky_2k` |
| ambientCG | [CC0-collectie](https://github.com/petroulacl/fps-buildings-env-kit/tree/1dd8e932402deb82422920df2e7fd079391e55d3/environment/ground-textures/ambientcg) | CC0 volgens de broncollectie | `Ground037`, `Grass004`, `Concrete012`, `Metal063` |
| Kenney | [Kenney-collectie](https://github.com/shorepine/kenney/tree/3694c6879e487c108f55677be7dd2ca75b07cc3b/3d) en [licentietekst](https://github.com/shorepine/kenney/blob/3694c6879e487c108f55677be7dd2ca75b07cc3b/LICENSE.txt) | CC0 | 14 GLB's |
| Quaternius | [Stylized Nature MegaKit-spiegel](https://github.com/petroulacl/fps-buildings-env-kit/tree/1dd8e932402deb82422920df2e7fd079391e55d3/environment/vegetation) | CC0 volgens de broncollectie | Varen-GLB |

De [importcode van de Poly Haven-spiegel](https://github.com/Papyszoo/CC0-Public-Domain-Textures/blob/fcc4ff97a5a843dc2e242ec9e195389bc46ed7d2/scripts/fetch-polyhaven-textures.mjs) vraagt eerst `nor_gl` bij de officiële API op. De oorspronkelijke Poly Haven-assetpagina staat per materiaal als `upstream_url` in het manifest. De ambientCG-broncollectie bewaart afzonderlijke `NormalGL`-bestanden.

Het script verkleint ambientCG's 2K-kaarten tot 1K. De Poly Haven KTX2-spiegel bevat hoogstens 512px-kaarten; het script decodeert deze met de open `basisu`-tool en maakt er 1K-JPEG's van. Het effectieve brondetail blijft maximaal 512px. De ruwe KTX2-bestanden worden niet mee gecommit.

Directe verzoeken aan `api.polyhaven.com`, `polyhaven.com`, `dl.polyhaven.org`, Poly Pizza en Sketchfab leverden hier HTTP 403 van de netwerkproxy. De GitHub-spiegels waren via de toegestane route bereikbaar. Er is geen toegangscontrole omzeild.

Er zijn geen CC-BY-bestanden toegevoegd. Makers en bronlinks blijven wel vermeld.

## Opnieuw downloaden

Installeer Python 3 en Pillow. Voor ontbrekende Poly Haven KTX2-bronnen is ook de [Basis Universal `basisu`-decoder](https://github.com/BinomialLLC/basis_universal) nodig; zet hem in `PATH` of wijs hem met `BASISU_BIN` aan. Het script haalt uitsluitend URL's uit het manifest op, controleert hashes en behoudt bestaande bestanden:

```bash
python3 tools/download_assets.py --batch all
```

Op Windows kan dezelfde opdracht met `py -3` worden gestart. Beschikbare batches: `terrain`, `buildings`, `nature`, `military`, `vehicles`. Na een netwerkfout kan dezelfde opdracht veilig opnieuw worden gedraaid. Voor de Poly Haven-bestanden is de decoder alleen nodig als die bestanden ontbreken.
