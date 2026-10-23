# Militair bevoorradingsmagazijn — v78

Het magazijn vervangt de bestaande stadsplaceholder op dezelfde opgeslagen positie. Het is een 12 × 8 m gebouw met één open vloer, een hoge laadopening aan Godot `+Z`, dubbele draaideuren, een aparte personeelsdeur, metalen stellingen en voorraad als dekking.

## Bron en export

- `maak_magazijn.py` bouwt de meshes, materialen en texturen in Blender.
- `magazijn.blend` is het bewerkbare Blender-bronbestand.
- `assets/magazijn.glb` is de zelfstandige Godot-export; de beelden zijn in de GLB ingebed.
- `assets/magazijn_*_base.png` en `assets/magazijn_*_normal.png` bevatten de procedureel gemaakte 512 px textures voor de Godot-import.

Herbouw vanaf de repository-root:

```sh
blender -b --python bron/magazijn/maak_magazijn.py -- assets
```

De bron gebruikt originele beton-, pleister-, staal-, golfplaat- en houttexturen. De blend bevat gepakte afbeeldingen; losse PNG's laten Godot de textures via zijn importpipeline comprimeren. De GLB bevat eveneens alle texturedata en blijft zelfstandig.

## Godot- en sloopintegratie

`scripts/stad.gd` registreert `magazijn` als model met dezelfde 6 × 8 m plaatsingsvoetprint, rasterstap, kosten, opgeslagen soortnaam en positie als de oude placeholder. `scripts/woonhuis.gd` laadt het gebouw met de gedeelde deur-, collision-, camera-, schade- en instortcode.

De achttien structurele segmenten heten `M000`–`M017` en hebben directe mesh-kinderen `_heel` en `_kapot`. `Dak/Dak_heel` en `Dak/Dak_kapot` tonen de twee daktoestanden. Na vijf ingestorte segmenten bezwijkt het dak; na twaalf segmenten verschijnt `Ruine` en wordt de speler naar buiten gezet. Bestaande kogelschade blijft ongewijzigd; explosies en tankgranaten gebruiken de bestaande explosieschade.

## Controle

De geautomatiseerde magazijntest staat in `tests/magazijn_test.gd`:

```sh
godot --headless --path . -s tests/magazijn_test.gd --fixed-fps 60
```

De projectinstellingen blijven op Godot 4.7 staan.
