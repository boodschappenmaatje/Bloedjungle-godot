# Voorraad (Generals-plan stap 4b): depot, truck, wrak en stapel — stijl "Intendance"

Echte Blender-modellen met reproduceerbare Python-generators. Ontwerp en goedgekeurde keuzes: [ASSET_DESIGN_SPEC.md](ASSET_DESIGN_SPEC.md);
metingen en afwijkingen: [docs/vq2/voorraad-4b-rapport.md](../../docs/vq2/voorraad-4b-rapport.md).

| Generator | Niveau's | Uitvoer |
|---|---|---|
| `maak_depot.py` | `hq`, `game`, `lod1` | `assets/voorraaddepot.glb`, `assets/voorraaddepot_lod1.glb`, `uit/Voorraaddepot.usdz` |
| `maak_truck.py` | `hq`, `game`, `lod1` | `assets/voorraadtruck.glb`, `assets/voorraadtruck_lod1.glb`, `uit/Voorraadtruck.usdz` |
| `maak_truck_wrak.py` | `hq`, `game` | `assets/voorraadtruck_wrak.glb`, `uit/Voorraadtruck_wrak.usdz` |
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
* Clips (echte glTF-animaties, NLA): truck `Laden` en `Lossen` (4,5 s), depot `Poort` (2 s) en `Kraan-lossen` (4,5 s). Wrak en stapel zijn
  statisch; de stapel heeft drie groepen (`Stapel_vol`, `Stapel_half`, `Stapel_leeg`) waarvan Godot er één toont.
* `render.py` maakt Cycles-voorbeeldbeelden (`VR_FRAME`, `VR_CLIP`, `VR_SAMPLES`, `VR_RES`).
* Lettertype Big Shoulders (OFL, `BigShoulders-OFL.txt`) voor de stencil. Alle texturen en geometrie zijn procedureel; geen externe assets.
* Gameplay: `scripts/voorraad*.gd`; tests: `tests/voorraad_test.gd` (contract), `tests/voorraad_modellen_test.gd` (modellen en clips),
  `tests/voorraad_foto.gd` (opnames met de spelcamera), `tools/blender-vq2-viewer/test-voorraad.mjs` (viewer).
