# F-16C Fighting Falcon (napalm-luchtsteun)

Vervangt de oude napalm-straaljager (`assets/straaljager.glb`, baseline V1 staat in `assets/vq2_baseline/straaljager.glb`). Ontwerp: [ASSET_DESIGN_SPEC.md](ASSET_DESIGN_SPEC.md).

```sh
blender --background --python bron/f16/maak_f16.py -- <uitmap> [--2k] [--usdz]
```

Levert `straaljager.glb` (game, 1K/512 PBR), `straaljager.blend` (bron; met `--2k` 2K-texturen voor de Showcase-bron), `assets_jpg/` (kopieer naar `assets/`) en met `--usdz` `f16.usdz`.
Gebouwd en gecontroleerd met Blender 4.3.2 (zelfde als VQ2). `bron/f16/uit/f16.blend` is de bewerkbare bron.

- **Contract (ongewijzigd t.o.v. oude jet):** `Straaljager > Body > …`, `Bom1..Bom4` (napalmbussen), clips `Vliegen-loop`, `Bocht`, `Aanval`; voorkant -Z in Godot; `scripts/napalm_aanval.gd` is niet aangepast.
- **Nieuw:** clips `Rol` (2 s) en `Landingsgestel` (2,4 s: uit, vast, in; in rust ingeklapt), beweegbare `FlaperonL/R`, `StabilisatorL/R`, `GearNeus/GearL/GearR`, `AIM120_L/R` en `AIM9_L/R`.
- **Verf:** echte USAF-twee-tinten grijs (boven FS 36118 Gunship Grey, onder lichter), gouden kap, donkere radoom. Geen nep-emblemen. Materialen zijn procedureel gegenereerd (geen Poly Haven-set).
- **USDZ:** `docs/previews/f16.usdz` (Quick Look in Bestanden). De vijf clips staan achter elkaar op één tijdlijn (Vliegen, Rol, Bocht, Aanval, Landingsgestel, 412 beeldjes op 30 fps). Niet op een echte iPhone gecontroleerd.
- **Viewer:** `tools/blender-vq2-viewer/`, model "Straaljager F-16", V1 = oude jet; test `node test-straaljager.mjs`.
