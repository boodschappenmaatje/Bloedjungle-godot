extends Node
## Godot import regression for Airfield HQ 2.2. Run with:
## godot --headless --path . -s tests/airfield_hq_22_import_test.gd

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
		elif n is AnimationPlayer:
			for anim in (n as AnimationPlayer).get_animation_list(): animations.append(anim)
	)
	assert(metrics["meshes"] >= 4, "Expected modular environment meshes, got %s" % metrics["meshes"])
	assert(metrics["missing_uv"] == 0, "All runtime surfaces need UVs, missing: %s" % metrics["missing_uv"])
	assert(metrics["bad_materials"] == 0, "All runtime surfaces need materials, missing: %s" % metrics["bad_materials"])
	assert(metrics["lights"] >= 5, "LOD0 needs its exported hangar lamps; found %s" % metrics["lights"])
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
	assert(flight != null, "Separate P-47 flight integration must exist")
	assert(flight.clearance_report()["fits_hangar"], "P-47 must fit the hangar door")
	assert(flight.clearance_report()["fits_taxiway"], "P-47 must fit the taxi route")
	assert(flight.takeoff_profile_report()["fits_demonstration"], "The shortened arcade runway must fit its explicitly non-historical demo profile")
	assert(flight.takeoff_profile_report()["available_roll_from_start_marker_m"] == 18.0, "The 30 m runway must leave the configured 18 m gameplay roll")
	for marker_name in ["P47_Hangar_Spawn", "P47_Apron_Parking", "P47_Taxi_Start", "P47_Runway_Hold", "P47_Runway_Start", "P47_Landing_Approach", "P47_Landing_Touchdown"]:
		assert(flight.get_node_or_null(marker_name) is Marker3D, "%s must be a marker" % marker_name)
	for path_name in ["P47_Taxi_Route", "P47_Takeoff_Path", "P47_Landing_Path"]:
		var path := flight.get_node(path_name) as Path3D
		assert(path.curve != null and path.curve.get_point_count() >= 5, "%s must contain a usable Curve3D" % path_name)
	assert(flight.taxi_route.curve.get_baked_length() > 30.0, "Taxi route must connect apron parking to the runway hold point")
	var placed := AirfieldHQ23.make_complex()
	assert(placed != null, "The approved 2.2 scene must instantiate as the placed core")
	get_tree().root.add_child(placed)
	await get_tree().process_frame
	var compact_core := placed.get_meta("complex") as Node3D
	var compact_lod0 := compact_core.get_node("Airfield_HQ_22_LOD0")
	var preserved_hangar := compact_lod0.find_child("Hangar HQ 22", true, false) as MeshInstance3D
	var preserved_tower := compact_lod0.find_child("Control Tower 22", true, false) as MeshInstance3D
	assert(preserved_hangar != null and preserved_hangar.visible, "The approved hangar mesh must stay present and visible")
	assert(preserved_tower != null and preserved_tower.visible, "The approved tower mesh must stay present and visible")
	var old_runway := compact_lod0.find_child("Airfield Runway_00 100m section", true, false) as MeshInstance3D
	assert(old_runway != null and not old_runway.visible, "The obsolete showcase runway must not be duplicated in the compact build")
	var modules := compact_core.get_node("AirfieldHQ23PavementModules") as AirfieldPavementModules
	var runway_mesh := modules.get_node_or_null("Runway concrete slabs LOD0") as MultiMeshInstance3D
	assert(runway_mesh != null and runway_mesh.multimesh.instance_count == 2, "Placed runway must use two instanced concrete 3D slabs")
	assert(modules.get_node_or_null("Runway concrete slabs LOD1") is MultiMeshInstance3D and modules.get_node_or_null("Runway concrete slabs LOD2") is MultiMeshInstance3D, "Runway must include far LOD meshes")
	assert(modules.get_node_or_null("Aircraft apron parking slab LOD0") is MultiMeshInstance3D, "The apron must use a distinct pavement system")
	assert(modules.get_node_or_null("Aircraft apron parking slab LOD2") is MultiMeshInstance3D, "The apron must include its far LOD mesh")
	assert(modules.find_children("Taxiway slab collision *", "StaticBody3D", true, false).size() >= 4, "The curved taxiway must have segmented collision")
	var parking_marker := compact_core.get_node("AirfieldFlightIntegration/P47_Apron_Parking") as Marker3D
	assert(parking_marker.global_position.distance_to(placed.to_global(Vector3(18.0, 0.22, -20.0))) < 0.02, "The parking marker must align with the compact apron")
	print("AIRFIELD_22_GODOT_IMPORT_PASS meshes=%d materials=%d triangles=%d lights=%d animations=%s collisions=%d" % [metrics["meshes"], metrics["materials"], metrics["triangles"], metrics["lights"], animations, collision_metrics["count"]])
	print("AIRFIELD_23_COMPACT_LAYOUT_PASS area=%.2fm2 max=%.2fm2 runway=%.1fm" % [AirfieldHQ23.footprint_area(), AirfieldHQ23.MAX_GROUND_AREA, AirfieldFlightIntegration.RUNWAY_LENGTH_M])
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
