# Personenauto (Blender-bron, VQ2)

`assets/auto.glb` is een zelfgemaakte sedan, gebouwd met `maak_auto.py` (Blender 4.3+/bpy 5, headless):

```bash
python3 bron/auto/maak_auto.py /tmp/auto_uit            # auto.glb, auto.blend, texturen
python3 bron/auto/maak_auto.py /tmp/auto_uit --render   # idem + Cycles-studiorenders (SAMPLES=24 ONE=1 voor snel)
cp /tmp/auto_uit/auto.glb assets/auto.glb && cp /tmp/auto_uit/auto.blend bron/auto/auto.blend
```

- Voorkant is +Y in Blender, wordt -Z in Godot; 1 eenheid = 1 meter; oorsprong midden op de grond; 4,3 x 1,8 x 1,45 m.
- PBR: 1K lak (albedo, normal, ORM met vuil, modder bij de wielkasten, krassen, afgebladderde plekken), band met profiel, chroom, kunststof, velg, glas; verkoold wrakmateriaal (`WrakRef`).
- Knopen: `Romp` (shape key `Deuk`), `Voorruit`, `Achterruit`, `DeurLV/RV/LA/RA` (met ruit en spiegel), `Motorkap`, `Kofferklep`, `WisserL/R`, `Wiel_LV/RV/LA/RA`, `Licht*` (verlichte lenzen, rustschaal 0), `WrakRef`.
- Clips (echte transform-tracks): `DeurenOpen`, `KapOpen`, `KofferOpen`, `Ruitenwissers-loop`, `Knipperen-loop`, `Alarm-loop`.
- Vuur, rook, ontploffing, stof en vliegende onderdelen zijn Godot-effecten (`scripts/auto.gd`, `Fx`), niet in de glb.
- Spelgedrag: `scripts/auto.gd` (bestuurbaar, kogelpantser 0,5x, schadefases, brand, ontploffing); test `tests/auto_test.gd`; beelden `tests/auto_foto.gd`; demo `scenes/auto_demo.tscn`; viewer `tools/blender-vq2-viewer/` (asset Personenauto).
