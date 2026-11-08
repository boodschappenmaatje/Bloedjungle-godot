# M-47 Photoreal Impact Hero Still 5.1 — visual review

## Scope

This phase delivers one still image of the M-47 projectile striking the wall. The required visual reference is the supplied M-47 VFX 2.1 storyboard (SHA-256 `0933401a1289f353164193f542e909cc85b377f679a62026aba301641318baee`). The final image is compared directly to its impact panel 4 in `renders/impact_vs_target.png`.

The approved M-47 GLB was imported unchanged from `docs/assets/m47-muurbreker-1.0/M47_Muurbreker_1.0_animated.glb`. Its recorded SHA-256 is `4031e935c5ef19a96a10257334a3cc99db92410a01389ef708259d887cf89872`; the rendered LOD0 remains 50,000 triangles. PBR textures and the five approved GLB actions remain part of the saved Blender scene. The new wall and impact effects are separate cinematic geometry.

## Render

- Blender 4.3.2 official Linux build, Cycles CPU with OpenImageDenoise.
- 1920×1080, 96 samples, AgX Medium High Contrast.
- Still: `renders/M47_Impact_Hero_Cycles.png`.
- Scene: `blender/M47_Impact_Hero_5_1.blend`.
- Render time: 27:16.78; 16-bit RGB PNG, 9.5 MiB.
- Render SHA-256: `db247891ed42612d6624eebbebf095db3376852b0fe816b1ecada1cbbacf8a4a`.
- Batch output: `logs/cycles_impact_final.log`.
- Source and render details: `render_metrics.json`.

The saved `.blend` reopened successfully in the official Blender build. The saved-scene check confirms Cycles at 1920×1080 and 96 samples, frame 122, LOD0/1/2 at 50,000/25,000/9,999 triangles, LOD1/LOD2 excluded from render, the five approved actions, both M-47 materials, and packed PBR image textures. See `logs/blender_saved_scene_validation.log`.

The shot combines the approved M-47 and soldier with the project's 2K exposed-aggregate concrete PBR maps, an irregular fractured wall field, dark branching cracks, torn reinforcement, airborne and settled rubble, blue-white impact geometry, sparks, and layered procedural volume billows. The foliage uses existing project grass and linked Poly Haven assets.

## Direct comparison with the target

The new render improves the earlier impact frame by keeping the M-47 visible, using the approved 2K concrete PBR set, opening a jagged strike cavity, placing non-uniform fragments at the wall and ground, and adding a volumetric smoke wake around a broad blue-white pressure shell. The storyboard's left-to-right composition is retained.

Visible differences remain:

1. The supplied target has more photographic microdetail and a more natural camera finish. This Blender scene still reads as a CG render, especially on the wall face and the character.
2. The target's wall has larger, naturally eroded masonry and a more chaotic aperture. The new wall is more varied than the earlier square blocks, but its procedural fracture-cell seams can still be recognized.
3. The target smoke forms a fuller, more turbulent spiral and dust cloud. The new volume billows and wake are visible but more controlled and less dense.
4. The target's energy shell reads as a single irregular hexagonal shockwave with a soft blue-white bloom. The new impact keeps the hexagonal form, but its electrical filaments are more visibly graphic and the white core is less photographic.
5. The target has denser jungle foliage behind the action. The shot uses the existing PBR foliage assets but shows less understory and leaf variation.
6. The target crops closer to the impact. The new still includes the commando and a wider ground/wall area, so the impact reads smaller in the frame.
7. The supplied M-47 target depiction has a different silhouette and more exposed mechanism detail than the approved source model. The source model was intentionally preserved, so this visual difference remains.

This is a single review still, not an exact recreation. No full animation or video was rendered. No Godot conversion, gameplay edits, merge, or OTA publication are part of this branch.
