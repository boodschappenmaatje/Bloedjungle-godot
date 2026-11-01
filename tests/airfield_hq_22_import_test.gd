extends Node
## Godot import regression for Airfield HQ 2.2 and its compact HQ23 reuse.
## Run the wrapper scene so project autoloads (including Game) are initialized:
## godot --headless --path . res://tests/airfield_hq_22_import_test_scene.tscn

const MODEL_PATH := "res://assets/airfield_hq_v22/runtime/Bloedjungle_Airfield_HQ_2_2_LOD0.glb"
const SHOWCASE_PATH := "res://scenes/airfield_hq_22_showcase.tscn"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load(MODEL_PATH) as PackedScene
	assert(packed != null, "Game GLB must import as a PackedScene")
	var model := packed.instantiate()
	get_tree().root.add_child(model)
	await get_tree().process_frame
	var metrics := {"meshes": 0, "triangles": 0, "lights": 0, "materials": 0, "missing_uv": 0, "bad_materials": 0}
	var animations: Array[String] = []
	var workshop_lights: Array[OmniLight3D] = []
	_walk(model, func(n: Node) -> void:
		if n is MeshInstance3D:
			metrics["meshes"] += 1
			var instance := n as MeshInstance3D
			if instance.mesh:
				for surface in instance.mesh.get_surface_count():
					var arrays := instance.mesh.surface_get_arrays(surface)
					if arrays.size() <= Mesh.ARRAY_TEX_UV or arrays[Mesh.ARRAY_TEX_UV] == null:
						metrics["missing_uv"] += 1
					var mat := instance.get_active_material(surface)
					if mat == null: metrics["bad_materials"] += 1
					else: metrics["materials"] += 1
				metrics["triangles"] += instance.mesh.get_faces().size() / 3
		elif n is OmniLight3D:
			metrics["lights"] += 1
			if n.name.begins_with(AirfieldHQ23.UNWANTED_WORKSHOP_LIGHT_PREFIX):
				workshop_lights.append(n as OmniLight3D)
		elif n is AnimationPlayer:
			for anim in (n as AnimationPlayer).get_animation_list(): animations.append(anim)
	)
	assert(metrics["meshes"] >= 4, "Expected modular environment meshes, got %s" % metrics["meshes"])
	assert(metrics["missing_uv"] == 0, "All runtime surfaces need UVs, missing: %s" % metrics["missing_uv"])
	assert(metrics["bad_materials"] == 0, "All runtime surfaces need materials, missing: %s" % metrics["bad_materials"])
	assert(metrics["lights"] == 5 and workshop_lights.size() == 5, "Imported LOD0 must contain the five known workshop lamps, got %s total and %s matched" % [metrics["lights"], workshop_lights.size()])
	for light in workshop_lights:
		assert(light.visible, "The protected source GLB must retain its original lamp nodes and enabled state")
		assert(is_equal_approx(light.omni_range, 4096.0) and absf(light.light_energy - 38045.99) < 0.1, "Unexpected imported workshop light values on %s: energy=%s range=%s" % [light.name, light.light_energy, light.omni_range])
	assert(animations.any(func(s: String) -> bool: return "Open_Left_Door" in s), "Left door animation missing: %s" % [animations])
	assert(animations.any(func(s: String) -> bool: return "Open_Right_Door" in s), "Right door animation missing: %s" % [animations])
	assert(animations.any(func(s: String) -> bool: return "Blink_Red_Markers" in s), "Warning-light blink animation missing: %s" % [animations])
	assert(animations.any(func(s: String) -> bool: return "Wind_Sock_Gust" in s), "Windsock gust animation missing: %s" % [animations])
	assert(animations.any(func(s: String) -> bool: return "Open_Tower_Door" in s), "Tower access door animation missing: %s" % [animations])
	var players := animation_players(model)
	assert(not players.is_empty(), "Imported scene must have an AnimationPlayer")
	var left_door := model.find_child("Hangar sliding door LEFT", true, false) as Node3D
	assert(left_door != null, "Animated left hangar door node missing")
	var animation_player: AnimationPlayer = players.front() as AnimationPlayer
	var closed_x := left_door.position.x
	animation_player.play("Open_Left_Door")
	await get_tree().create_timer(0.35).timeout
	assert(animation_player.is_playing(), "Left door clip must run in Godot")
	assert(absf(left_door.position.x - closed_x) > 0.05, "Left door node must move during playback")
	var right_door := model.find_child("Hangar sliding door RIGHT", true, false) as Node3D
	assert(right_door != null, "Animated right hangar door node missing")
	var right_closed_x := right_door.position.x
	animation_player.play("Open_Right_Door")
	await get_tree().create_timer(0.35).timeout
	assert(absf(right_door.position.x - right_closed_x) > 0.05, "Right door node must move during playback")
	var marker_player: AnimationPlayer
	for candidate in players:
		if candidate.has_animation("Blink_Red_Markers"):
			marker_player = candidate
			break
	assert(marker_player != null, "Marker light clip must have a Godot animation player")
	marker_player.play("Blink_Red_Markers")
	await get_tree().create_timer(0.35).timeout
	assert(marker_player.is_playing(), "Red marker light animation must run in Godot")
	var windsock := model.find_child("Tower wind sock | wind animation", true, false) as MeshInstance3D
	assert(windsock != null and windsock.mesh.get_blend_shape_count() > 0, "Windsock must have actual deforming mesh shape")
	var wind_start := windsock.get_blend_shape_value(0)
	var wind_player: AnimationPlayer
	for candidate in players:
		if candidate.has_animation("Wind_Sock_Gust"):
			wind_player = candidate
			break
	assert(wind_player != null, "Wind gust must have an animation player")
	wind_player.play("Wind_Sock_Gust")
	await get_tree().create_timer(0.35).timeout
	assert(absf(windsock.get_blend_shape_value(0) - wind_start) > 0.01, "Windsock geometry must visibly deform")
	var showcase := (load(SHOWCASE_PATH) as PackedScene).instantiate()
	get_tree().root.add_child(showcase)
	await get_tree().process_frame
	var showcase_left := showcase.get_node("Airfield_HQ_22_LOD0").find_child("Hangar sliding door LEFT", true, false) as Node3D
	var showcase_collision := showcase.get_node("GameplayCollisions/LeftDoorCollision") as Node3D
	var showcase_door_x := showcase_left.position.x
	var collision_x := showcase_collision.position.x
	showcase.open_door(&"left")
	await get_tree().create_timer(0.35).timeout
	assert(absf(showcase_left.position.x - showcase_door_x) > 0.05, "Showcase must play the left door clip")
	assert(absf(showcase_collision.position.x - collision_x) > 0.05, "Left door collision must follow the open door")
	var tower_door := showcase.get_node("Airfield_HQ_22_LOD0").find_child("Tower access door | animated", true, false) as Node3D
	assert(tower_door != null, "Animated tower access door node missing")
	var tower_door_rotation := tower_door.rotation.y
	var tower_collision := showcase.get_node("GameplayCollisions/TowerDoorCollision") as Node3D
	showcase.open_tower_door()
	await get_tree().create_timer(0.35).timeout
	assert(absf(tower_door.rotation.y - tower_door_rotation) > 0.02, "Tower access door must rotate in Godot")
	assert(absf(tower_collision.rotation.y) > 0.02, "Tower access collision must follow the door")
	var lod1 := showcase.get_node("Airfield_HQ_22_LOD1")
	var lod2 := showcase.get_node("Airfield_HQ_22_LOD2")
	assert(not lod2.find_children("*", "MeshInstance3D", true, false).is_empty(), "LOD2 must import real mesh geometry")
	assert(not lod1.find_children("*", "MeshInstance3D", true, false).is_empty(), "LOD1 must import real mesh geometry")
	var collision_metrics := {"count": 0}
	_walk(showcase, func(n: Node) -> void:
		if n is CollisionShape3D and n.shape != null: collision_metrics["count"] += 1
	)
	assert(collision_metrics["count"] >= 8, "Runway, walls, doors and tower need collision proxies; found %s" % collision_metrics["count"])
	var flight := showcase.get_node("AirfieldFlightIntegration") as AirfieldFlightIntegration
	assert(flight != null, "Prepared local-to-complex route markers must remain available")
	for marker_name in ["P47_Hangar_Spawn", "P47_Apron_Parking", "P47_Taxi_Start", "P47_Runway_Hold", "P47_Runway_Start", "P47_Landing_Approach", "P47_Landing_Touchdown"]:
		assert(flight.get_node_or_null(marker_name) is Marker3D, "%s must be a marker" % marker_name)
	for path_name in ["P47_Taxi_Route", "P47_Takeoff_Path", "P47_Landing_Path"]:
		var path := flight.get_node(path_name) as Path3D
		assert(path.curve != null and path.curve.get_point_count() >= 5, "%s must contain a usable Curve3D" % path_name)
	assert(flight.taxi_route.curve.get_baked_length() > 20.0, "Prepared taxi markers must retain their apron-to-runway path")
	var placed := AirfieldHQ23.make_complex()
	assert(placed != null, "The approved 2.2 scene must instantiate as the placed core")
	get_tree().root.add_child(placed)
	await get_tree().process_frame
	var compact_core := placed.get_meta("complex") as Node3D
	var compact_lod0 := compact_core.get_node("Airfield_HQ_23_Compact_LOD0")
	var runtime_workshop_lights: Array[OmniLight3D] = []
	for node in compact_lod0.find_children("*", "OmniLight3D", true, false):
		var light := node as OmniLight3D
		if light.name.begins_with(AirfieldHQ23.UNWANTED_WORKSHOP_LIGHT_PREFIX):
			runtime_workshop_lights.append(light)
	assert(runtime_workshop_lights.size() == 5, "The placed 2.3 copy must retain exactly five imported workshop lamp nodes")
	for light in runtime_workshop_lights:
		assert(not light.visible, "The placed 2.3 copy must disable workshop lamp %s" % light.name)
	var preserved_hangar := compact_lod0.find_child("Hangar HQ 22", true, false) as MeshInstance3D
	assert(preserved_hangar != null and preserved_hangar.visible, "The approved hangar mesh must stay present and visible")
	var hangar_bounds := preserved_hangar.get_aabb().size * preserved_hangar.scale
	assert(hangar_bounds.x <= 22.6 and hangar_bounds.z <= 21.1, "The compact shell plus shortened door guides and foundation must fit about 22 × 20.65 m, got %s" % hangar_bounds)
	assert(AirfieldHQ23.HANGAR_SIZE.is_equal_approx(Vector2(28.0, 24.0)), "The compact hangar build zone must measure 28 × 24 m")
	assert(AirfieldHQ23.TOWER_SIZE.is_equal_approx(Vector2(8.0, 8.0)), "The compact tower core zone must measure 8 × 8 m")
	var left_compact_door := compact_lod0.find_child("Hangar sliding door LEFT", true, false) as MeshInstance3D
	var right_compact_door := compact_lod0.find_child("Hangar sliding door RIGHT", true, false) as MeshInstance3D
	assert(left_compact_door != null and right_compact_door != null, "Both compact animated hangar doors must remain present")
	var leaf_size := left_compact_door.get_aabb().size * left_compact_door.scale
	assert(absf(leaf_size.x - 7.37) < 0.15 and absf(leaf_size.y - 5.89) < 0.15, "Each animated leaf's scaled world geometry must be about 7.37 × 5.89 m")
	var left_door_shape := (compact_core.get_node("GameplayCollisions/LeftDoorCollision/LeftDoorShape") as CollisionShape3D).shape as BoxShape3D
	assert(left_door_shape.size.is_equal_approx(Vector3(7.5, 6.0, 0.36)), "Compact sliding-door collision must match its 7.5 × 6 m leaf")
	var left_jamb_shape := (compact_core.get_node("GameplayCollisions/LeftHangarDoorJambCollision/LeftHangarDoorJambShape") as CollisionShape3D).shape as BoxShape3D
	assert(left_jamb_shape.size.is_equal_approx(Vector3(3.5, 6.0, 0.35)), "Doorway side jamb collision must close the 3.5 m shoulder beside the 15 m opening")
	assert(is_equal_approx(AirfieldFlightIntegration.DOOR_CLEAR_WIDTH_M, 15.0) and is_equal_approx(AirfieldFlightIntegration.DOOR_CLEAR_HEIGHT_M, 5.89), "The doorway clear opening must be 15 × 5.89 m")
	var compact_clearance := AirfieldFlightIntegration.new().clearance_report()
	assert(is_equal_approx(compact_clearance.door_wing_margin_each_side_m, 1.28) and is_equal_approx(compact_clearance.door_height_margin_m, 1.44), "A 12.44 m span / 4.45 m high plane envelope must fit the door with requested clearance")
	assert(compact_clearance.clear_interior_m.is_equal_approx(Vector3(15.0, 6.0, 13.0)), "The central hangar zone must retain the requested 15 × 13 × 6 m clearance envelope")
	var compact_driver := compact_core as AirfieldHQ23CompactShowcase
	assert(compact_driver != null, "The compact showcase must use its own door controller")
	var closed_collision_x := (compact_core.get_node("GameplayCollisions/LeftDoorCollision") as Node3D).position.x
	compact_driver.open_door(&"left")
	await get_tree().create_timer(0.35).timeout
	assert(absf((compact_core.get_node("GameplayCollisions/LeftDoorCollision") as Node3D).position.x - closed_collision_x) > 0.05, "Left-door collision must follow its compact opening animation")
	var left_animation_found := false
	for player in animation_players(compact_lod0):
		if player.has_animation("Open_Left_Door"):
			left_animation_found = true
			assert(player.is_playing(), "The compact left-door GLB action must play in Godot")
	assert(left_animation_found, "The compact LOD0 GLB must retain Open_Left_Door")
	var old_tower := compact_lod0.find_child("Control Tower 22", true, false) as MeshInstance3D
	assert(old_tower == null, "The 2.2 tower meshes must stay in the protected 2.2 asset and be absent from the compact 2.3 hangar GLB")
	var new_tower := compact_core.get_node_or_null("ControlTowerHQ23") as Node3D
	assert(new_tower != null, "The separate HQ2.3 tower must be integrated into the placed field")
	for lod_index in 3:
		var tower_lod := new_tower.get_node_or_null("Tower LOD%d" % lod_index) as Node3D
		assert(tower_lod != null and not tower_lod.find_children("*", "MeshInstance3D", true, false).is_empty(), "Tower LOD%d must import real geometry" % lod_index)
	var tower_collisions := compact_core.get_node_or_null("HQ23 Tower stair and level collisions") as StaticBody3D
	assert(tower_collisions != null and tower_collisions.find_children("*", "CollisionShape3D", true, false).size() >= 75, "The external stair must have walkable step and landing collisions")
	var tower_motion := compact_core.get_node_or_null("HQ22 Approved Tower Motion Details") as Node3D
	assert(tower_motion != null, "The compact tower must reuse the approved HQ2.2 moving door and windsock geometry")
	assert(tower_motion.find_children("*", "Light3D", true, false).is_empty(), "The HQ2.2 motion details must not add the unbounded imported workshop lights (≈38,000 energy, 4 km range) that bleached the airfield")
	for light in compact_core.find_children("*", "Light3D", true, false):
		assert(not light.is_visible_in_tree() or ((light as OmniLight3D) != null and (light as OmniLight3D).omni_range <= 8.0), "No airfield light may light the field beyond its local 8 m range by default: %s" % light.name)
	var compact_tower_door := tower_motion.find_child("Tower access door | animated", true, false) as MeshInstance3D
	var compact_windsock := tower_motion.find_child("Tower wind sock | wind animation", true, false) as MeshInstance3D
	assert(compact_tower_door != null and compact_tower_door.visible, "The imported HQ2.2 animated tower-door leaf must be visible in HQ2.3")
	assert(compact_windsock != null and compact_windsock.visible and compact_windsock.mesh.get_blend_shape_count() > 0, "The imported HQ2.2 wind sock must retain its deforming shape")
	var tower_door_player: AnimationPlayer
	var windsock_player: AnimationPlayer
	for player in animation_players(tower_motion):
		if player.name == "HQ22 Wind Sock Loop": windsock_player = player
		elif player.has_animation("Open_Tower_Door"): tower_door_player = player
	assert(tower_door_player != null and tower_door_player.has_animation("Open_Tower_Door"), "The compact tower must contain the exact HQ2.2 tower-door clip")
	assert(windsock_player != null and windsock_player.has_animation("Wind_Sock_Gust"), "The compact tower must contain a separate HQ2.2 wind-sock player")
	var wind_value_start := compact_windsock.get_blend_shape_value(0)
	await get_tree().create_timer(0.4).timeout
	assert(windsock_player.is_playing() and absf(compact_windsock.get_blend_shape_value(0) - wind_value_start) > 0.01, "The HQ2.2 wind-sock gust clip must deform the compact HQ2.3 wind sock in Godot (playing=%s animation=%s blend_start=%.3f blend_now=%.3f tracks=%d)" % [windsock_player.is_playing(), windsock_player.current_animation, wind_value_start, compact_windsock.get_blend_shape_value(0), windsock_player.get_animation("Wind_Sock_Gust").get_track_count()])
	var compact_tower_door_start := compact_tower_door.rotation.y
	var compact_tower_door_basis_start := compact_tower_door.transform.basis
	var compact_tower_collision := compact_core.get_node("GameplayCollisions/TowerDoorCollision") as Node3D
	var tower_collision_start := compact_tower_collision.rotation.y
	compact_driver.open_tower_door()
	await get_tree().create_timer(0.4).timeout
	var tower_clip := tower_door_player.get_animation("Open_Tower_Door")
	var tower_clip_paths: Array[String] = []
	for track in tower_clip.get_track_count(): tower_clip_paths.append(String(tower_clip.track_get_path(track)))
	var tower_clip_values: Array[String] = []
	for track in tower_clip.get_track_count(): tower_clip_values.append(str(tower_clip.track_get_key_value(track, tower_clip.track_get_key_count(track) - 1)))
	var player_root := tower_door_player.get_node_or_null(tower_door_player.root_node)
	assert(tower_door_player.is_playing() and not compact_tower_door.transform.basis.is_equal_approx(compact_tower_door_basis_start), "The HQ2.2 tower-door clip must rotate its visible leaf in Godot (playing=%s clip=%s euler=%s basis_changed=%s time=%.3f root=%s paths=%s last_keys=%s target=%s player_root=%s)" % [tower_door_player.is_playing(), tower_door_player.current_animation, compact_tower_door.rotation, not compact_tower_door.transform.basis.is_equal_approx(compact_tower_door_basis_start), tower_door_player.current_animation_position, tower_door_player.root_node, tower_clip_paths, tower_clip_values, compact_tower_door.get_path(), player_root.get_path() if player_root != null else "null"])
	assert(absf(compact_tower_collision.rotation.y - tower_collision_start) > 0.02, "The compact tower-door collision must follow the opening leaf")
	compact_driver.close_tower_door()
	await get_tree().create_timer(1.35).timeout
	assert(absf(compact_tower_collision.rotation.y - tower_collision_start) < 0.03, "The compact tower-door collision must return when the leaf closes")
	await get_tree().create_timer(tower_door_player.get_animation("Open_Tower_Door").length + 0.1).timeout
	assert(not tower_door_player.is_playing() or tower_door_player.current_animation == "Wind_Sock_Gust", "The reverse tower-door clip must finish and leave the door closed")
	assert(windsock_player.is_playing(), "The wind-sock loop must continue independently while the tower door moves")
	var old_runway := compact_lod0.find_child("Airfield Runway_00 100m section", true, false) as MeshInstance3D
	assert(old_runway == null, "The 2.2 showcase runway must not be part of the compact production GLB")
	var modules := compact_core.get_node("AirfieldHQ23PavementModules") as AirfieldPavementModules
	var runway_mesh := modules.get_node_or_null("Runway concrete slabs LOD0") as MultiMeshInstance3D
	assert(runway_mesh != null and runway_mesh.multimesh.instance_count == 5, "Placed 75 m runway must use five instanced concrete 3D slabs")
	assert(not runway_mesh.multimesh.mesh is BoxMesh, "Runway visible surface must use the authored beveled PBR module, not a box placeholder")
	assert(runway_mesh.multimesh.mesh.get_surface_count() > 0 and runway_mesh.multimesh.mesh.surface_get_material(0) != null, "Runway module must retain its authored PBR material")
	assert(runway_mesh.multimesh.mesh.get_faces().size() / 3 > 24, "Runway module must contain bevelled manufactured geometry")
	assert(modules.get_node_or_null("Runway concrete slabs LOD1") is MultiMeshInstance3D and modules.get_node_or_null("Runway concrete slabs LOD2") is MultiMeshInstance3D, "Runway must include far LOD meshes")
	assert(modules.get_node_or_null("Aircraft apron parking slab LOD0") is MultiMeshInstance3D, "The apron must use a distinct pavement system")
	assert(modules.get_node_or_null("Aircraft apron parking slab LOD2") is MultiMeshInstance3D, "The apron must include its far LOD mesh")
	var taxi_surface := modules.get_node_or_null("Taxiway continuous PBR curve LOD0") as MeshInstance3D
	assert(taxi_surface != null and not taxi_surface.mesh is PlaneMesh and not taxi_surface.mesh is BoxMesh, "Taxiway must be a continuous authored curved 3D surface")
	assert(taxi_surface.mesh.get_surface_count() > 0 and taxi_surface.mesh.surface_get_material(0) != null, "Taxiway must retain its authored PBR material")
	assert(taxi_surface.mesh.get_faces().size() / 3 > 500, "Taxiway curved module must contain continuous curve geometry")
	var psp_lod0 := modules.get_node_or_null("Historic PSP apron patch LOD0") as MultiMeshInstance3D
	var psp_lod1 := modules.get_node_or_null("Historic PSP apron patch LOD1") as MultiMeshInstance3D
	var psp_lod2 := modules.get_node_or_null("Historic PSP apron patch LOD2") as MultiMeshInstance3D
	assert(psp_lod0 != null and psp_lod0.multimesh.instance_count == 8, "The historic PSP apron patch must contain eight individual plates in one draw batch")
	assert(psp_lod1 != null and psp_lod2 != null, "The PSP strip must provide all three distance LODs")
	assert(FileAccess.file_exists("res://source_assets/airfield_hq_v23/psp/PSP_plate_library.blend"), "The editable Blender PSP source must be delivered")
	var taxi_collision_count := 0
	for collider in modules.find_children("*", "StaticBody3D", true, false):
		if collider.name.begins_with("Taxiway slab collision"):
			taxi_collision_count += 1
	assert(taxi_collision_count >= 3, "The curved taxiway must have segmented collision, found %d" % taxi_collision_count)
	var parking_marker := compact_core.get_node("AirfieldFlightIntegration/P47_Apron_Parking") as Marker3D
	assert(parking_marker.global_position.distance_to(placed.to_global(Vector3(AirfieldHQ23.APRON_CENTER.x, 0.22, AirfieldHQ23.APRON_CENTER.y))) < 0.02, "The parking marker must align with the compact apron")
	var runway_colliders: Array[StaticBody3D] = []
	for collider in modules.find_children("*", "StaticBody3D", true, false):
		if collider.name.begins_with("Runway slab collision"):
			runway_colliders.append(collider as StaticBody3D)
	assert(runway_colliders.size() == 5, "Each 15 m runway module needs its own collision, found %d" % runway_colliders.size())
	var runway_centres: Array[float] = []
	var runway_z: Array[float] = []
	for collider in runway_colliders:
		var local_to_build := placed.to_local(collider.global_position)
		runway_centres.append(local_to_build.x)
		runway_z.append(local_to_build.z)
		assert(is_equal_approx(collider.rotation.y, PI * 0.5), "Every runway segment must share the exact same straight axis")
	runway_centres.sort()
	assert(is_equal_approx(runway_centres.front() - 7.5, AirfieldHQ23.RUNWAY_START_X), "The runway collision west endpoint must start at the configured 75 m strip")
	assert(is_equal_approx(runway_centres.back() + 7.5, AirfieldHQ23.RUNWAY_END_X), "The runway collision east endpoint must end at the configured 75 m strip")
	assert(is_equal_approx(runway_centres.back() - runway_centres.front(), 60.0), "Five evenly joined runway collision modules must span four 15 m centre intervals")
	assert(is_equal_approx(runway_centres[1] - runway_centres[0], 15.0) and is_equal_approx(runway_centres[2] - runway_centres[1], 15.0) and is_equal_approx(runway_centres[3] - runway_centres[2], 15.0) and is_equal_approx(runway_centres[4] - runway_centres[3], 15.0), "Runway segments must be evenly spaced without stepped joints")
	assert(runway_z.all(func(z: float) -> bool: return is_equal_approx(z, AirfieldHQ23.RUNWAY_CENTER_Z)), "All runway segment centers must share one centerline")
	var runway_start_expected := placed.to_global(Vector3(AirfieldFlightIntegration.TAKEOFF_START_X,0.22,AirfieldHQ23.RUNWAY_CENTER_Z))
	var runway_start_actual := (compact_core.get_node("AirfieldFlightIntegration/P47_Runway_Start") as Marker3D).global_position
	assert(runway_start_actual.distance_to(runway_start_expected) < 0.02, "Prepared runway start marker must align with the shortened runway (%s vs %s)" % [runway_start_actual, runway_start_expected])
	assert(AirfieldHQ23.footprint_area() <= AirfieldHQ23.MAX_GROUND_AREA, "The complete conservative construction-area allocation must remain within 6,452.435 m²")
	print("AIRFIELD_22_GODOT_IMPORT_PASS meshes=%d materials=%d triangles=%d imported_workshop_lights=%d placed_workshop_lights_enabled=0 animations=%s collisions=%d" % [metrics["meshes"], metrics["materials"], metrics["triangles"], metrics["lights"], animations, collision_metrics["count"]])
	print("AIRFIELD_23_COMPACT_LAYOUT_PASS constructed_area_upper_bound=%.2fm2 max=%.2fm2 hangar_zone=%.1fx%.1fm tower_zone=%.1fx%.1fm door=%.1fx%.1fm runway=%.1fx%.1fm" % [AirfieldHQ23.footprint_area(), AirfieldHQ23.MAX_GROUND_AREA, AirfieldHQ23.HANGAR_SIZE.x, AirfieldHQ23.HANGAR_SIZE.y, AirfieldHQ23.TOWER_SIZE.x, AirfieldHQ23.TOWER_SIZE.y, AirfieldFlightIntegration.DOOR_CLEAR_WIDTH_M, AirfieldFlightIntegration.DOOR_CLEAR_HEIGHT_M, AirfieldFlightIntegration.RUNWAY_LENGTH_M, AirfieldFlightIntegration.RUNWAY_WIDTH_M])
	get_tree().quit(0)

func _walk(node: Node, callback: Callable) -> void:
	callback.call(node)
	for child in node.get_children(): _walk(child, callback)

func animation_players(node: Node) -> Array[AnimationPlayer]:
	var found: Array[AnimationPlayer] = []
	_walk(node, func(n: Node) -> void:
		if n is AnimationPlayer: found.append(n as AnimationPlayer)
	)
	return found
