# Bloedjungle Meshy Animation Library 3.7 — integration record

## Output

- `meshy_player_animation_library.res` is a Godot `AnimationLibrary` with the 13 clips below. It contains animation tracks only; no imported MeshInstance3D, skin, or duplicate character mesh.
- Source GLBs and `manifest.md` in this folder were not modified.
- `extract_meshy_animation_library.gd` documents the repeatable Godot import/extraction step.

## Rig and track validation

Godot 4.7.2 imported the source and existing Meshy player GLBs. They have the same 28 bone names, order, parent hierarchy, and rest transforms (0 mismatches at 0.01 mm). Every clip has 26 Godot skeleton tracks; all target the existing `target_character/Skeleton3D` hierarchy. The central resource contains all 13 named clips.

The source includes one mesh and one skin in its GLB. The extracted resource has no mesh or skin and can be installed on the existing Meshy's AnimationPlayer.

## Root-motion treatment

The handed-over source bundle is retained untouched. In the extracted resource, horizontal Hips translation is removed linearly across the clip where the first-to-last horizontal displacement exceeded 5 mm. Vertical Hips motion is retained. This prevents clips from shifting the CharacterBody horizontally while preserving an actual rise in `Stand_Up2`.

| Clip | Use indicated by source manifest | Source Hips end displacement before → after horizontal cleanup |
| --- | --- | ---: |
| `Running` | standing running | 0 → 0 m |
| `Walking` | standing walking | 0 → 0 m |
| `RunFast` | standing sprint | 1.0 mm → 1.0 mm |
| `Cautious_Crouch_Walk_Forward` | crouch walk forward | 1.459 m → 0.54 mm vertical only |
| `Cautious_Crouch_Walk_Right_inplace` | in-place crouch walk right | 4.8 mm → 4.8 mm |
| `Crouch_Walk_Left_with_Gun` | crouch walk left | 1.001 m → 1.0 mm vertical only |
| `Hit_in_Back_While_Running` | hit reaction while running | 3.282 m horizontal + vertical → 83.4 mm vertical only |
| `Prone_Reload` | prone reload | 0.08 mm → unchanged |
| `Rifle_Aim_Turn_Right` | rifle aim/turn | 0.348 m → 0.05 mm vertical only |
| `Rifle_Charge_inplace` | rifle charge | 0 → 0 m |
| `Run_and_Shoot` | running fire | 1.154 m → 4 µm vertical only |
| `Stand_Up2` | stand-up motion | 56.8 mm horizontal + 380 mm vertical → 380 mm vertical only |
| `dying_backwards` | death motion | 934 mm horizontal + 650 mm vertical → 650 mm vertical only |

The six locomotion clips are marked looping; other action clips remain one-shots. `RunFast`, `Running`, and `Walking` are preserved.

## Missing animation coverage

Present clips do not provide a complete playable crouch/prone system. These are specifically absent or unverified:

- Dedicated crouch idle. `Cautious_Crouch_Walk_Right_inplace` is still a walking cycle even though the character stays in place; it is not an idle.
- Authored stand-to-crouch and crouch-to-stand transitions.
- Authored crouch-to-prone and prone-to-crouch transitions. `Stand_Up2` ends upright, but the exact starting pose is not verified as prone; it is not treated as a confirmed prone transition.
- Dedicated prone idle and true prone crawl forward/backward.
- Verified crouch aim/shoot/reload clips. `Rifle_Aim_Turn_Right` is not verified as crouched; `Prone_Reload` is the only supplied stance-specific reload.
- Verified prone aim/shoot clips.
- A stand-up clip from a verified prone starting pose.

Do not wire unverified clips into gameplay transitions or use a walking pose as an idle. These clips need to be sourced on the same existing rig before crouch/prone locomotion, colliders, and safe space-checked stand-up can be shipped.

## Godot 4.7.2 integration evidence

- The player AnimationPlayer receives the central animation-only library and keeps its existing `stil`, `lopen`, `rennen`, and `sprinten` API aliases.
- An AnimationTree exposes direct `STAND`, `CROUCH`, and `PRONE` review states. The 0.22 s transitions are generic crossfades only; they are not authored get-up/lie-down animations and are not connected to gameplay stance controls.
- The isolated integration test selects all 13 clips and verifies their track paths against the current skeleton. Existing Garand damage/ammo/reload, ordinary locomotion IK, and DEF regression tests are run separately.
- At the existing Garand anchor, the three crouch-walk clips measured right-hand errors of 1.4–10.4 mm and left-hand errors of 4.2–7.8 mm via `modification_processed`.
- `Prone_Reload` measured 256 mm right-hand error and 168 mm left-hand error against the standing Garand grip. This clip is **not accepted as an integrated prone reload**. It needs a calibrated prone weapon transform plus a reload-phase left-hand target (or source-clip retargeting); the current standing anchors must not be reused.
- The gameplay-camera video covers proven stand/walk/run/sprint/fire/reload only. The posture clips remain a library-review/test route and do not yet represent playable crouch/prone controls.

No collider, movement-speed, or player-controller stance changes are enabled by this library integration. The current authored clip set cannot support safe posture transitions, a dedicated crouch idle, or prone crawl/idle.
