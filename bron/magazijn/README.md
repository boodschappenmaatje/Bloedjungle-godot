# Militair magazijn — Blender v78 (werkbranch)

Nieuw gebouw op de bestaande stadspositie voor `magazijn`: 12 × 8 m. Ontwerp: verweerde betonnen plint, metalen ribben, dubbele schuifdeur, licht hellend golfplaten dak, rekken met legerkisten, vaten en zandzakken bij de laadplaats.

## Belangrijk
Deze branch is een **voorbereidende ontwerpbranch**. De Blender-bron `maak_magazijn.py`, `magazijn.blend` en `magazijn.glb` moeten na export en validatie nog aan deze branch worden toegevoegd. `main` en de stadseditor zijn niet aangepast. De bestaande `magazijn`-placeholder blijft dus werken.

## Contract voor integratie
- Footprint: x [-6,6], z [-4,4] in Godot; voorkant aan Godot +Z.
- Blender: x [-6,6], y [-4,4], z omhoog.
- Boom: `Magazijn/Begane`, `Dak/Dak_heel`, `Dak/Dak_kapot`, `Ruine`, `Puin`.
- Destructibele segmenten: `M0*` met `*_heel` en `*_kapot`; alle knoopnamen moeten aansluiten op `scripts/woonhuis.gd`.
- Laat toegang, dakzichtbaarheid, destructie, kollisie, en oude saves intact.
- Registreer pas `model=true` in `scripts/stad.gd` nadat GLB en `Woonhuis._spec("magazijn")` succesvol getest zijn.
- Uit te voeren tests: Blender headless export, Godot headless import, stadseditor, betreden/verlaten, explosie en tankinslag, iPhone/Xogot-performance.

Dit ontwerp is geïnspireerd op de bestaande modellen in `bron/woonhuis`, `bron/winkel`, `bron/kerk`, `bron/benzine`. Gebruik uitsluitend originele geometrie.
