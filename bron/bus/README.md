# Stadsbus (Blender-bron, VQ2)

`assets/bus.glb` is een zelfgemaakte lijnbus van 10,6 x 2,5 x 3,05 m, gebouwd met `maak_bus.py` (Blender 4.3+/bpy 5, headless):

```bash
python3 bron/bus/maak_bus.py /tmp/bus_uit            # bus.glb, bus.blend, texturen
python3 bron/bus/maak_bus.py /tmp/bus_uit --render   # idem + Cycles-studiorenders (SAMPLES=24 ONE=1 voor snel)
cp /tmp/bus_uit/bus.glb assets/bus.glb && cp /tmp/bus_uit/bus.blend bron/bus/bus.blend
```

- Voorkant is +Y in Blender, wordt -Z in Godot; 1 eenheid = 1 meter; oorsprong midden op de grond. Deuren zitten rechts (+X), het motorluik achter.
- PBR: 2K buslak (belettering-banen, plaatnaden met klinknagels, modder, regenstrepen, mos en bladresten op het dak; albedo, normal, ORM), 1K verkoold wrakmateriaal (`WrakRef`), band met profiel, chroom, kunststof, velg, glas, lichtbord met ledtekst. 2K alleen voor de lak: dat is een vlak van 10 m lang dat in de gamecamera groot in beeld komt.
- Knopen: `Bus` > `Carrosserie` (knielt) > `Romp` (shape key `Deuk`), `Voorruit`, `Achterruit`, `RuitenL/R`, `DeurVA/VB` (voordeur), `DeurMA/MB` (middendeur), `Motorluik`, `DakluikV/A`, `Airco`, `WisserL/R`, `Licht*` (verlichte lenzen, rustschaal 0), `WrakRef`; `Wiel_LV/RV` (voor) en `Wiel_LA/RA` (achter, dubbel) hangen direct onder `Bus`.
- Clips (echte transform-tracks): `VoordeurOpen`, `MiddendeurOpen`, `MotorluikOpen`, `Knielen`, `LichtenAan`, `Ruitenwissers-loop`, `Knipperen-loop`, `Alarm-loop`.
- Vuur, rook, ontploffing, stof en vliegende onderdelen zijn Godot-effecten (`scripts/bus.gd`, `Fx`), niet in de glb.
- Spelgedrag: `scripts/bus.gd` (bestuurbaar maar zwaar en traag, kogelpantser 0,35x, 1600 hp, schadefases, brand achterin bij de motor, ontploffing met 14 m straal); test `tests/bus_test.gd`; beelden `tests/bus_foto.gd`; demo `scenes/bus_demo.tscn`; telefoonviewer `tools/bus-viewer/` (`python3 tools/bus-viewer/bouw.py uit.html`); VQ2-viewer `tools/blender-vq2-viewer/` (asset Stadsbus, test `node test-bus.mjs`).
- Stad: soorten `bus`, `buswrak` en `busbrand` in de stadseditor (categorie straat), een bus staat aan de zijstraat in `StadData.ITEMS`.
- Kogels raken voertuigen via de laag `Bullet.MASK_VEHICLE` (ook als je tegen een muur aan staat) en via `inside()` als de kogel binnen de botsdoos begint.
