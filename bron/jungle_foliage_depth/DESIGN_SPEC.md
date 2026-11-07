# Jungle Depth Foliage — approved design and implementation

**Approval:** Dennis approved the following design in this task before final model
production: “brede glanzende rozet, fijne boogvaren en compacte rood/brons
bloeiende ondergroeiplant.”

**Role:** render-only understory for the existing top-down jungle battlefield.
The models enrich open ground, tree-root groups, path shoulders and river shelves
while preserving road clearance, troop readability and firing lanes.

**Gameplay and motion:** no collision, selectable behavior, interaction, gameplay
logic or Blender/GLB animation clips. Existing Godot foliage wind and push shaders
drive the authored root-to-tip vertex weights. Existing cameras, HUD, routes,
controls, actors and collision rules stay unchanged.

**Production:** reproducible Blender `.blend`/Python source and one optimized GLB
with 36 render-only meshes: four runtime roles, three source variants and three
static geometry LODs per role. The three unique mobile material sets come from
the approved Poly Haven sources at 1K, with normal, roughness and packed AO. The
low groundcover role now uses a 0.34 m miniature built from the scanned
`fern_02` geometry; its 78–238 / 39–119 / 19–59 triangle LODs replace the old
illustrated fern mesh within the same 14,500-instance cap and use the fern PBR
maps. The three primary roles retain the existing cell MultiMeshes, with native
LOD and per-cell culling. The `red_bloom` name remains an internal alias for the
CC0 `shrub_04` branch clump; it is not documented as a scanned flowering model.
No collision, placement, or gameplay rules changed.

**Acceptance:** verify GLB/PBR import and all LOD triangle counts; inspect actual
Godot game-camera renders and retain an open visual judgment against approved B;
run the iOS export and leave on-device frame times, shimmer and thermals unmeasured
until the user tests on a physical iPhone.
