# Tropical Shop A

Dit assetpakket bevat het originele Meshy-model, het bewerkbare Blender-bestand,
de reproduceerbare Blender-generator, de game-GLB, de losse bouwmodules,
renders en de Quick Look-preview.

## Bestanden

- `source/Meshy_AI_Photorealistic_1940s__1113185619_texture.glb` — origineel, ongewijzigd.
- `Tropical_Shop_A.blend` — bronbestand met de Meshy-referentie en modulaire winkel.
- `build_tropical_shop_a.py` — generator voor de Blender-bron en GLB-export.
- `output/tropical_shop_a.glb` — uitvoer van de generator; de Godot-runtimekopie is `assets/tropical_shop_a.glb`.
- `previews/01_...png` t/m `previews/07_...png` — zeven renders, waaronder de winkelvloer met de echte soldaat-GLB.
- `previews/usdz/Tropical_Shop_A_iPhone.usdz` — iPhone Quick Look-preview; de begeleidende JSON bevat exportmetadata.

De editor gebruikt `assets/stad_icons/tropical_shop_a.png`, een 256×256 transparant
icoon dat met `render_tropical_shop_a.py` uit het gebouwmodel wordt gerenderd.

## Godot testen

Open de bestaande stadseditor en kies **Tropisch winkelpand A · 2 lagen** onder
**Gebouw**. Plaats het als gewone editorplaatsing; het staat niet vooraf in de
opgeslagen standaardstad. De testscene is `scenes/tropical_shop_a_test.tscn`.

Desktopbesturing in de testscene: WASD bewegen, muis kijken, Shift rennen, E
deur bedienen, linkermuisknop schieten en Tab wisselen tussen third-person en
de top-down bouwcamera. Deze geïsoleerde scene wijzigt de standaardcamera of de
standaardstad niet.

Gerichte headless controle (Godot 4.7.2):

```sh
godot --headless --path . --scene res://scenes/tropical_shop_a_test.tscn --quit-after 2000 -- --shop-self-test
godot --headless --path . -s tests/stad_editor_2_test.gd --fixed-fps 60
```

Zie `docs/city_buildings_2_0/TROPICAL_SHOP_A_PRODUCTION_REPORT.md` voor gemeten
geometrie, uitgevoerde controles en resterende beperkingen.
