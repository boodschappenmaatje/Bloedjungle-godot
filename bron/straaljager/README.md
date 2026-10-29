# Straaljager (napalm-luchtsteun)

> Vervangen op 2026-10-28 door de F-16 (`bron/f16/`). Dit is de bron van de oude jet (baseline V1 in `assets/vq2_baseline/straaljager.glb`).

Grondaanvalstoestel voor de killstreak Napalm-aanval (VQ2, zie `docs/ASSET_QUALITY_STANDARD.md`).

```sh
pip install bpy
python3 bron/straaljager/maak_straaljager.py bron/straaljager/uit [--render]
```

Levert `straaljager.blend` en `straaljager.glb` (kopieer glb + `straaljager_jet_*.jpg` naar `assets/`).
Nodes: `Straaljager > Body > Romp, Kap, Motoren, Vleugels, Rolroeren, Kanon, Pyloon1-4, Bom1-4 (napalmbussen), Naverbrander_L/R, Tiplichten`.
Clips: `Vliegen-loop` (2 s), `Bocht` (3 s), `Aanval` (3 s). 3956 driehoeken, 10 materialen, PBR 1024/512 (albedo, normal, ORM).
Gebruik in Godot: `scripts/napalm_aanval.gd`. Viewer: `tools/blender-vq2-viewer/`.
