# Legerjeep (Blender-bron)

`assets/legerjeep.glb` is een originele, in Blender gemaakte open militaire terreinwagen. De bewerkbare onderdelen staan in `jeep.blend`; `preview.png` laat het resultaat zien. Het model heeft terreinbanden met profiel, een reservewiel, voorruit, stoelen, dashboard, verlichting, een jerrycan en een schep.

`scenes/legerjeep.tscn` behoudt zijn eenvoudige botsingsvorm. De voorkant wijst naar -Z. VQ2 bevat één exportmesh, 13 materiaalvlakken en 46.436 driehoeken, tegenover 75.628 in V1. Bandsegmenten en kleine bevels zijn verminderd; carrosseriedetail en fotografische PBR-materialen zijn toegevoegd. Dit is de statische jeep; de speelbare jeep staat apart in `bron/jeep/`.

Opnieuw bouwen met Blender 4.3 of nieuwer:

```bash
cd ../..
python3 tools/build_vq2.py --only legerjeep
```

De generator exporteert rechtstreeks naar `assets/legerjeep.glb` en bewaart alle bewerkbare onderdelen en gepackte texturen in deze map in `jeep.blend`. Vergelijkbare renders worden met `tools/render_vq2.py` gemaakt; `--render` bij deze generator maakt de oorspronkelijke studiopreview opnieuw. De PBR-foto's zijn afgeleid van de bestaande CC0-bronnen, met provenance in `assets/textures/vq2/`. Zie `docs/vq2/README.md` voor tests, meetgegevens en de interactieve viewer.
