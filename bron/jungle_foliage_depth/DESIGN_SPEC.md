# Jungle Depth Foliage — approved design

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

**Production:** reproducible Blender `.blend`/Python source; one optimized GLB with
three species and three static geometry LODs per species; one shared 1K PBR atlas
made from the project's existing 512px leaf/fern/palm maps plus an authored
red/bronze color variant and roughness map. All three species use a single surface
and existing cell MultiMeshes; the scene keeps the established scatter ceiling and
uses per-cell culling. No new texture was downloaded.

**Acceptance:** verify GLB/PBR import and all LOD triangle counts; inspect actual
Godot game-camera renders and retain an open visual judgment against approved B;
run the iOS export and leave on-device frame times, shimmer and thermals unmeasured
until the user tests on a physical iPhone.
