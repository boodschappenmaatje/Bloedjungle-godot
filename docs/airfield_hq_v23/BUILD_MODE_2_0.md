# Airfield HQ 2.3 — Build mode 2.0

Implementation notes for the southern placement, foliage clearing, touch controls, and local validation.

## Placement and boundaries

- Default construction center: `(70, 0, 115)` world meters, south-east of the player compound and clear of its southern gate route.
- Playable southern boundary: `Data.WORLD_Z_S` is now `180 m`, extended by `100 m` from the previous `80 m`. The existing ground plate already reaches `z = 220 m`, so this uses the existing ground and does not move or resize the base, city, river, roads, bridges, spawns, or gameplay camera.
- The approved airport layout and `75 × 18 m` runway are unchanged. The constructed-area upper bound is `5,160.9318 m²`, below the established `6,452.435 m²` limit.
- For transparency, `AirfieldHQ23.FOOTPRINT` is a camera framing/envelope size of `113.25 × 87.4 m` (`9,898.05 m²`) and includes open space between components. It is not treated as paved area; placement checks and the preview use the occupied hangar, tower, runway, apron, and taxi regions separately.
- The suggested site envelope is approximately `x = 13.375..126.625 m`, `z = 71.3..158.7 m`. The map remains freely pannable and the airport rotates in 90-degree increments.

## Placement checks and foliage

`Buildings.placement_status()` is the shared result for preview and final placement. It returns validity, a specific reason, and the number of removable vegetation instances inside the construction regions. Protected walls/buildings, bunkers, rocks, water/river, spawn clearance, world bounds, and the southern gate corridor still reject the location. Clearable palms, shrubs, ferns, and grass do not reject it.

The build payment is charged through `Game.pay_build()` first. Only after the new building has been created, registered, and paid does `Foliage.clear_for_building()` clear instances within the occupied regions plus `0.75 m` margin. It moves the individual near/far LOD, shadow, and grass MultiMesh instances away, disables the associated palm collision shapes, removes entries from the tree/ram and spatial indexes, and discards any stump/fall nodes. Preview, cancellation, invalid placement, and insufficient funds do not call the clearing path. The saved regions are reapplied after foliage is rebuilt; selling or moving updates/releases the building’s reservation. Cleared vegetation is not restored on sale during that world instance, but the location is reusable; a later foliage rebuild restores it if no building remains there.

The existing south terrain plate had no vegetation coverage beyond the old boundary. A deterministic south foliage band was added to cover the newly playable area, while leaving the gate route, river, bridges, city and default airport site free of protected rocks.

## Touch controls

- One finger on empty map: pan using the build camera’s current screen-to-ground projection; the same input works while zoomed.
- Airfield selected: movement past a `10 px` drag threshold pans the map; a short tap chooses/places at the touched ground point. A drag cannot place the airfield.
- Two fingers that both start on the map: pinch to zoom the build map. A gesture beginning on UI/cards is blocked. The regular combat camera does not receive pinch input.
- Existing `+`, `−`, home and 90-degree rotation controls remain.
- After construction the wide construction camera stays active until leaving build mode, so the airport remains visible and selectable. A short tap selects the placed airport; the existing building panel supports moving it by dragging and rotating it with the normal `Draai` action. The ordinary combat camera is unchanged.

## Local validation

Run locally with Godot 4.7.2:

- `airfield_hq_23_contract_test_scene.tscn`: pass with the headless dummy renderer and the desktop OpenGL Compatibility renderer. Covers payment-before-clearance, insufficient points, invalid/south-gate/world/spawn cases, protected overlap, palm and grass removal across all LOD/shadow slots, collision/index cleanup, off-footprint foliage preservation, rotated placement, relocation/rotation and invalid-move rejection, one-airfield limit, damage/repair/rebuild/sale, and the disabled aircraft purchase path.
- `airfield_hq_23_visual_capture_scene.tscn`: its placement/touch assertions pass using the production main scene and desktop OpenGL Compatibility renderer. It simulates card selection, one-finger panning at default and zoomed levels, pinch, valid green vegetation preview, tap placement, and selection of the placed airport. It writes the screenshots listed below. The run also logs four `Lambda capture at index 0 was freed` engine errors after placement; they do not fail the capture assertions and their source remains unresolved.
- `airfield_hq_22_import_test_scene.tscn`: pass; reports 34 hangar meshes, 97 materials, 13 collisions and all expected door/windsock animations, plus the 75 × 18 m runway and three tower LODs.
- Existing bunker replacement, soldier VQ2, M1911 ammo/reload, demolition, and OTA logic tests exited 0 with their PASS/OK markers. The OTA test deliberately exercises corrupt/mismatched/missing patch rollback cases; it did not publish an update.
- The legacy `bouw_test.gd` exits 0 and builds/recruits/sells, but prints its existing three placement diagnostics as `true` where comments expect `false` (kazerne on wall, kazerne at gate, wall on wall line). This mismatch was present in the Airfield HQ 2.3 baseline report; it is not presented as a clean pass.
- Godot import logs retain existing invalid embedded-resource UID warnings with text-path fallback. The 107-entry approved 2.2 SHA-256 inventory was checked after implementation and passes.

The headless dummy renderer does not expose written MultiMesh transforms through `get_instance_transform()`. Therefore the contract test checks the registered per-instance removal count in headless mode, and also runs against desktop OpenGL Compatibility where the actual palm/grass transforms read back below the scene and the outside instance remains at its original position.

Game-scene screenshots (desktop OpenGL Compatibility):

- [Green preview over southern foliage](screenshots/14_airfield_south_site_green_vegetation_preview.png)
- [Player compound and placed airport south of it](screenshots/15_airfield_south_of_player_base.png)
- [Full placed field](screenshots/09_full_airfield_game_world.png)
- [75 × 18 m runway](screenshots/11_runway_75x18_game.png)

The Mac’s Vulkan initialization fails during compute-pipeline compilation, so these captures use OpenGL Compatibility. They are not evidence of iPhone rendering quality or FPS. The full-field images are visibly brighter than the in-game mobile renderer may appear; physical iPhone testing remains required.

## GitHub / iPhone status

PR #164 remains merged at `9880c409ac3c048d10b3259f7c1635d836a516e0` with original recorded head `9b1ed405331f779a9d142554a8f31cbf5b27bfab`. The follow-up code was fast-forwarded to both `main` and `feature/airfield-hq-2-0` at `b05acb0d112bd714415dd2f20f595744a2e1934c`; no new PR was created. The OTA workflow succeeded in [run 41228843638](https://github.com/boodschappenmaatje/Bloedjungle-godot/actions/runs/41228843638) and published manifest `20261031-182332-b05acb0` to the [`updates` release](https://github.com/boodschappenmaatje/Bloedjungle-godot/releases/tag/updates). Its 811,932,824-byte patch has SHA-256 `46f974d1701466738fb25fe1080cc6989ca5a6a7d55bf28ae888baaea6741fbc` and targets base `0b2824e2e970ef5bc10c205275c59cfb8e307e10` (`ota/basis.txt`). The OTA workflow passed; on-device download and activation are not yet tested.

The existing iOS workflow also succeeded in [run 41228843497](https://github.com/boodschappenmaatje/Bloedjungle-godot/actions/runs/41228843497) and uploaded unsigned artifact `bloedjungle-ios-unsigned-b05acb0d112bd714415dd2f20f595744a2e1934c` (878,624,075 bytes). This is not an App Store release. No physical iPhone test or performance measurement has been run.

No physical iPhone 18 Pro Max placement test, FPS measurement, 1%-low, frametime, or device memory measurement was run.
