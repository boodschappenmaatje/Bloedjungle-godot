extends SceneTree
## Godot import regression for Airfield HQ 2.2. Run with:
## godot --headless --path . -s tests/airfield_hq_22_import_test.gd

const MODEL_PATH := "res://assets/airfield_hq_v22/runtime/Bloedjungle_Airfield_HQ_2_2_LOD0.glb"
const SHOWCASE_PATH := "res://scenes/airfield_hq_22_showcase.tscn"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load(MODEL_PATH) as PackedScene
	assert(packed != null, "Game GLB must import as a PackedScene")
	var model := packed.instantiate()
	root.add_child(model)
	await process_frame
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
	await create_timer(0.35).timeout
	assert(animation_player.is_playing(), "Left door clip must run in Godot")
	assert(absf(left_door.position.x - closed_x) > 0.05, "Left door node must move during playback")
	var right_door := model.find_child("Hangar sliding door RIGHT", true, false) as Node3D
	assert(right_door != null, "Animated right hangar door node missing")
	var right_closed_x := right_door.position.x
	animation_player.play("Open_Right_Door")
	await create_timer(0.35).timeout
	assert(absf(right_door.position.x - right_closed_x) > 0.05, "Right door node must move during playback")
	var marker_player: AnimationPlayer
	for candidate in players:
		if candidate.has_animation("Blink_Red_Markers"):
			marker_player = candidate
			break
	assert(marker_player != null, "Marker light clip must have a Godot animation player")
	marker_player.play("Blink_Red_Markers")
	await create_timer(0.35).timeout
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
	await create_timer(0.35).timeout
	assert(absf(windsock.get_blend_shape_value(0) - wind_start) > 0.01, "Windsock geometry must visibly deform")
	var showcase := (load(SHOWCASE_PATH) as PackedScene).instantiate()
	root.add_child(showcase)
	await process_frame
	var showcase_left := showcase.get_node("Airfield_HQ_22_LOD0").find_child("Hangar sliding door LEFT", true, false) as Node3D
	var showcase_collision := showcase.get_node("GameplayCollisions/LeftDoorCollision") as Node3D
	var showcase_door_x := showcase_left.position.x
	var collision_x := showcase_collision.position.x
	showcase.open_door(&"left")
	await create_timer(0.35).timeout
	assert(absf(showcase_left.position.x - showcase_door_x) > 0.05, "Showcase must play the left door clip")
	assert(absf(showcase_collision.position.x - collision_x) > 0.05, "Left door collision must follow the open door")
	var tower_door := showcase.get_node("Airfield_HQ_22_LOD0").find_child("Tower access door | animated", true, false) as Node3D
	assert(tower_door != null, "Animated tower access door node missing")
	var tower_door_rotation := tower_door.rotation.y
	var tower_collision := showcase.get_node("GameplayCollisions/TowerDoorCollision") as Node3D
	showcase.open_tower_door()
	await create_timer(0.35).timeout
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
	assert(flight.takeoff_profile_report()["fits_demonstration"], "900 m runway must fit the declared demo profile")
	for marker_name in ["P47_Hangar_Spawn", "P47_Apron_Parking", "P47_Taxi_Start", "P47_Runway_Hold", "P47_Runway_Start", "P47_Landing_Approach", "P47_Landing_Touchdown"]:
		assert(flight.get_node_or_null(marker_name) is Marker3D, "%s must be a marker" % marker_name)
	for path_name in ["P47_Taxi_Route", "P47_Takeoff_Path", "P47_Landing_Path"]:
		var path := flight.get_node(path_name) as Path3D
		assert(path.curve != null and path.curve.get_point_count() >= 5, "%s must contain a usable Curve3D" % path_name)
	print("AIRFIELD_22_GODOT_IMPORT_PASS meshes=%d materials=%d triangles=%d lights=%d animations=%s collisions=%d" % [metrics["meshes"], metrics["materials"], metrics["triangles"], metrics["lights"], animations, collision_metrics["count"]])
	quit(0)

func _walk(node: Node, callback: Callable) -> void:
	callback.call(node)
	for child in node.get_children(): _walk(child, callback)

func animation_players(node: Node) -> Array[AnimationPlayer]:
	var found: Array[AnimationPlayer] = []
	_walk(node, func(n: Node) -> void:
		if n is AnimationPlayer: found.append(n as AnimationPlayer)
	)
	return found
