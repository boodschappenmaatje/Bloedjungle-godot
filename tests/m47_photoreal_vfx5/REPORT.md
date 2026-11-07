# M-47 Photoreal Cinematic 5.0 — production and visual comparison report

## Scope and status

This is a Blender-only Cycles showcase on the approved M-47 asset branch. The mandatory supplied storyboard is preserved byte-for-byte at `reference/M47_VFX_2_1_TARGET.jpg` (SHA-256 `0933401a1289f353164193f542e909cc85b377f679a62026aba301641318baee`). `renders/target_vs_cycles.png` compares its five corresponding panels with the five final Cycles captures. The project does not convert the scene to Godot and does not modify gameplay or root project settings.

The saved scene is `blender/M47_Photoreal_Cinematic_5_0.blend`. It was produced and rendered with official Blender 4.3.2 in batch mode using Cycles CPU, AgX and OpenImageDenoise. The 8-second video render is currently running at 960×540, 24 fps and 8 Cycles samples per frame; its completed file metadata will be appended after the render and ffprobe check.

## Asset integrity and scene data

- Approved source: `docs/assets/m47-muurbreker-1.0/M47_Muurbreker_1.0_animated.glb`.
- Source SHA-256: `4031e935c5ef19a96a10257334a3cc99db92410a01389ef708259d887cf89872`.
- The source GLB geometry and its material graphs were not edited. VFX additions are separate objects parented to a cinematic mount.
- Imported LOD triangle counts: LOD0 50,000; LOD1 25,000; LOD2 9,999. LOD0 is rendered while LOD1/LOD2 are hidden from render.
- The five original mechanism actions have animated curves and keyframes: Idle (382 keys), Equip (298), Aim (256), Fire (220), Reload (640). They remain separate GLB-derived actions in the Blender scene.
- The GLB contains a metallic steel material using its authored factors, plus `Material_0` with packed base-color, normal and metallic/roughness images. The separate soil and concrete surfaces use the project PBR maps.
- Two Mantaflow domains are baked to OpenVDB: blue-grey projectile smoke and warm concrete dust. Each has data and noise caches covering frames 1–192 at resolution 48 with noise scale 2 (384 VDB files per domain).
- The environment includes 7 linked Poly Haven tree instances, 48 fern patches, project grass, 35,916 leaf-litter faces, a 74-piece masonry wall including 19 animated fracture pieces, and 56 large fractured concrete debris pieces. Poly Haven tree/fern libraries are CC0 and their source pages and checksums are in `assets/polyhaven/README.md`.

## Render outputs

- Five final stills: 960×540, Cycles, 8 samples, denoised.
- Video: 8 seconds, 192 frames, 24 fps, 960×540, Cycles, 8 samples, denoised; H.264/MPEG-4 output.
- `renders/render_overview.png` gives a five-frame contact sheet. The full-size individual images are the five `0*.png` captures in `renders/`.
- The side-by-side reference comparison is `renders/target_vs_cycles.png`.

## Panel-by-panel visual review

1. **Laden / kernrotatie:** The commando, wall edge, PBR forest floor and rotating blue-white core are visible in a wider three-quarter view. The source M-47 remains much plainer than the reference gun, and the separate core reads as a small luminous collar rather than the reference's detailed exposed mechanism. The floor and understory are visibly less lush and photoreal than the target.
2. **Afvuren:** Recoil, a bright muzzle flash and blue light spill are present. The flash remains a sharp, radial CG burst instead of the reference's broad blue-white flame and volumetric bloom; smoke is less full.
3. **Projectiel in vlucht:** The projectile travels toward the wall with a blue-white core, containment hoops and animated helicoidal filaments. It is legible and blue, but the body is still more schematic and the wake is thinner and less smoky/spark-rich than the reference.
4. **Impact / schokgolf:** The impact core, enlarged polygonal hex pressure front, masonry cracking, smoke and debris are visible. The pressure front remains several clean nested wire-like polygons, while the target has one more irregular, textured electric shell and a tighter impact crop.
5. **Muurdoorbraak / eindfase:** A persistent opening, fractured wall edges, angular rubble and warm dust are visible. The hole and rubble apron are narrower and less chaotic than the target; the wall courses remain too regular, and the dust plume is compact.

**Overall:** the output is an actual Cycles-rendered scene with real baked volumetrics and the approved source GLB, but it does not yet match the reference's photographic finish. The clearest remaining gaps are the source weapon's visual detail, denser natural jungle dressing, broad volumetric muzzle/projectile smoke, irregular stone fracture silhouettes and the larger rubble field. The comparison board makes those differences visible; no exact-match claim is made.

## Reproduction and verification

See `README.md` for batch build, bake, finalize and render commands. `blender/validate_scene.py` inspects the saved scene, source hash, LOD triangle counts, actual action curves, packed M-47 images and baked cache files and writes `build_metrics.json`. The video is verified after completion with `ffprobe`; no Godot conversion or game integration is part of this phase.
