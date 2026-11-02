# Voorraad (Generals-plan stap 4b): depot, truck, wrak en stapel — stijl "Intendance"

Echte Blender-modellen met reproduceerbare Python-generators. Ontwerp en goedgekeurde keuzes: [ASSET_DESIGN_SPEC.md](ASSET_DESIGN_SPEC.md);
metingen en afwijkingen: [docs/vq2/voorraad-4b-rapport.md](../../docs/vq2/voorraad-4b-rapport.md).

| Generator | Niveau's | Uitvoer |
|---|---|---|
| `maak_depot.py` | `hq`, `game`, `lod1` | `assets/voorraaddepot.glb`, `assets/voorraaddepot_lod1.glb`, `uit/Voorraaddepot.usdz` |
| `maak_truck.py` | `hq`, `game`, `lod1` | **vervangen in v182** door het Meshy-model (zie hieronder); nu alleen de vergelijking `assets/vq2_baseline/voorraadtruck_v1.glb` |
| `maak_truck_wrak.py` | `hq`, `game` | idem, vergelijking `assets/vq2_baseline/voorraadtruck_wrak_v1.glb` |
| `maak_stapel.py` | `hq`, `game` | `assets/voorraadstapel.glb` (drie standen), `uit/Voorraadstapel.usdz` |

```
pip install bpy numpy pillow          # Blender als Python-module (getest met bpy 5.2.3)
python3 bron/voorraad/maak_truck.py hq     # alleen de bewerkbare HQ-.blend (live procedurele materialen), snel
python3 bron/voorraad/maak_truck.py game   # bakt 2K-PBR (albedo/ORM/normal), schrijft .blend, .glb en .usdz (5 tot 30 min)
```

* `vc.py` is de gedeelde module (Godot-assenstelsel `P(x, y, z)`, bevel/UV-hulp, stencilplaat, materialen, kisten, pallets, ketting, bake,
  GLB- en USDZ-export). Hergebruikt `bron/hoofdkwartier/` (camonet, bake) en `bron/verzamelvlag/`.
* Niveau `hq` = hoogste detail met live procedurele materialen (alleen `uit/*_HQ.blend`); `game` = geoptimaliseerd voor Godot (één gebakken
  2K-atlas per model); `lod1` = ver weg (1K-atlas, geen kleine details).
* **Voorraadtruck en wrak sinds v182**: het model uit Dennis' Meshy-vrachtwagen, zie [../voorraad_meshy/README.md](../voorraad_meshy/README.md) en
  [docs/vq2/voorraad-meshy-rapport.md](../../docs/vq2/voorraad-meshy-rapport.md). `assets/voorraadtruck*.glb` komen daar vandaan; `maak_truck.py` en `maak_truck_wrak.py`
  leveren niet meer de spelbestanden. Het depot en de stapel blijven hier (het depot is in v182 donkerder geverfd en opnieuw gebakken: `vc.py`).
* Clips (echte glTF-animaties, NLA): truck `Laden` en `Lossen` (6,0 s sinds v182, daarvoor 4,5 s), depot `Poort` (2 s) en `Kraan-lossen` (4,5 s). Wrak en stapel zijn
  statisch; de stapel heeft drie groepen (`Stapel_vol`, `Stapel_half`, `Stapel_leeg`) waarvan Godot er één toont.
* `render.py` maakt Cycles-voorbeeldbeelden (`VR_FRAME`, `VR_CLIP`, `VR_SAMPLES`, `VR_RES`).
* Lettertype Big Shoulders (OFL, `BigShoulders-OFL.txt`) voor de stencil. Alle texturen en geometrie zijn procedureel; geen externe assets.
* Gameplay: `scripts/voorraad*.gd`; tests: `tests/voorraad_test.gd` (contract), `tests/voorraad_modellen_test.gd` (modellen en clips),
  `tests/voorraad_foto.gd` (opnames met de spelcamera), `tools/blender-vq2-viewer/test-voorraad.mjs` (viewer).
