extends Node
## Godot import regression for Airfield HQ 2.2 and its compact HQ23 reuse.
## Run the wrapper scene so project autoloads (including Game) are initialized:
## godot --headless --path . res://tests/airfield_hq_22_import_test_scene.tscn

const MODEL_PATH := "res://assets/airfield_hq_v22/runtime/Bloedjungle_Airfield_HQ_2_2_LOD0.glb"
const SHOWCASE_PATH := "res://scenes/airfield_hq_22_showcase.tscn"

func _ready() -> void:
	# Een mislukte assert stopt _run zonder get_tree().quit(): zonder deze wachter blijft het proces eindeloos hangen
	# (in CI kostte dat de hele iOS-build een time-out van 45 minuten).
	get_tree().create_timer(180.0).timeout.connect(func() -> void:
		print("FOUT: time-out, een assert hierboven heeft de test afgebroken")
		get_tree().quit(1))
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
		# Vliegveld op basismaat (v236): korte vaste strook, de taxiroute is één rechte lijn deur -> strook.
		assert(path.curve != null and path.curve.get_point_count() >= 2, "%s must contain a usable Curve3D" % path_name)
	assert(flight.taxi_route.curve.get_baked_length() > 8.0, "Prepared taxi markers must retain their apron-to-runway path")
	var placed := AirfieldHQ23.make_complex()
	assert(placed != null, "The approved 2.2 scene must instantiate as the placed core")
	get_tree().root.add_child(placed)
	await get_tree().process_frame
	var complex_root := placed.get_meta("complex") as Node3D
	var compact_core := complex_root.get_meta("hangar") as Node3D
	assert(compact_core != null, "The compact complex must expose its scaled hangar core")
	assert(is_equal_approx(compact_core.scale.x, AirfieldHQ23.HANGAR_SCALE), "The hangar core must be scaled to the base-size factor")
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
	var world_hangar := hangar_bounds * AirfieldHQ23.HANGAR_SCALE
	assert(world_hangar.x <= AirfieldHQ23.HANGAR_SIZE.x + 0.5 and world_hangar.z <= AirfieldHQ23.HANGAR_SIZE.y + 0.5, "The scaled hangar must fit its build zone %s, got %s" % [AirfieldHQ23.HANGAR_SIZE, world_hangar])
	assert(AirfieldHQ23.FOOTPRINT.x <= 40.0 and AirfieldHQ23.FOOTPRINT.z <= 28.0, "The base-size airfield must stay about 36 × 25 m, got %s" % AirfieldHQ23.FOOTPRINT)
	var left_compact_door := compact_lod0.find_child("Hangar sliding door LEFT", true, false) as MeshInstance3D
	var right_compact_door := compact_lod0.find_child("Hangar sliding door RIGHT", true, false) as MeshInstance3D
	assert(left_compact_door != null and right_compact_door != null, "Both compact animated hangar doors must remain present")
	assert(compact_core.get_node_or_null("GameplayCollisions/LeftDoorCollision/LeftDoorShape") is CollisionShape3D, "Compact sliding-door collision must remain")
	assert(compact_core.get_node_or_null("GameplayCollisions/LeftHangarDoorJambCollision/LeftHangarDoorJambShape") is CollisionShape3D, "Doorway jamb collision must remain")
	assert(is_equal_approx(AirfieldFlightIntegration.DOOR_CLEAR_WIDTH_M, 15.0 * AirfieldHQ23.HANGAR_SCALE), "The doorway clear opening must scale with the hangar")
	var compact_driver := compact_core as AirfieldHQ23CompactShowcase
	assert(compact_driver != null, "The compact showcase must use its own door controller")
	var closed_collision_x := (compact_core.get_node("GameplayCollisions/LeftDoorCollision") as Node3D).position.x
	var closed_door_x := left_compact_door.position.x
	compact_driver.open_door(&"left")
	await get_tree().create_timer(0.35).timeout
	assert(absf((compact_core.get_node("GameplayCollisions/LeftDoorCollision") as Node3D).position.x - closed_collision_x) > 0.05, "Left-door collision must follow its compact opening animation")
	assert(absf(left_compact_door.position.x - closed_door_x) > 0.05, "The compact left door mesh must slide with the door tween")
	var left_animation_found := false
	for player in animation_players(compact_lod0):
		if player.has_animation("Open_Left_Door"):
			left_animation_found = true
			assert(not player.is_playing(), "The glTF door clips must stay stopped: the compact showcase drives both doors with one tween")
	assert(left_animation_found, "The compact LOD0 GLB must retain Open_Left_Door")
	var old_tower := compact_lod0.find_child("Control Tower 22", true, false) as MeshInstance3D
	assert(old_tower == null, "The 2.2 tower meshes must be absent from the compact 2.3 hangar GLB")
	var new_tower := complex_root.get_node_or_null("ControlTowerHQ23") as Node3D
	assert(new_tower != null, "The separate HQ2.3 tower must be integrated into the placed field")
	for lod_index in 3:
		var tower_lod := new_tower.get_node_or_null("Tower LOD%d" % lod_index) as Node3D
		assert(tower_lod != null and not tower_lod.find_children("*", "MeshInstance3D", true, false).is_empty(), "Tower LOD%d must import real geometry" % lod_index)
	for light in complex_root.find_children("*", "Light3D", true, false):
		assert(not light.is_visible_in_tree() or ((light as OmniLight3D) != null and (light as OmniLight3D).omni_range <= 8.0), "No airfield light may light the field beyond its local 8 m range by default: %s" % light.name)
	var old_runway := compact_lod0.find_child("Airfield Runway_00 100m section", true, false) as MeshInstance3D
	assert(old_runway == null, "The 2.2 showcase runway must not be part of the compact production GLB")
	var modules := complex_root.get_node("AirfieldHQ23PavementModules") as AirfieldPavementModules
	var runway_mesh := modules.get_node_or_null("Runway concrete slabs LOD0") as MultiMeshInstance3D
	var segments := int(roundf(AirfieldHQ23.RUNWAY_LENGTH_M / AirfieldPavementModules.RUNWAY_SEGMENT))
	assert(runway_mesh != null and runway_mesh.multimesh.instance_count == segments, "The short strip must use %d instanced concrete slabs" % segments)
	assert(not runway_mesh.multimesh.mesh is BoxMesh, "Runway visible surface must use the authored beveled PBR module, not a box placeholder")
	assert(runway_mesh.multimesh.mesh.get_surface_count() > 0 and runway_mesh.multimesh.mesh.surface_get_material(0) != null, "Runway module must retain its authored PBR material")
	var runway_colliders: Array[StaticBody3D] = []
	for collider in modules.find_children("*", "StaticBody3D", true, false):
		if collider.name.begins_with("Runway slab collision"):
			runway_colliders.append(collider as StaticBody3D)
	assert(runway_colliders.size() == segments, "Each runway module needs its own collision, found %d" % runway_colliders.size())
	var runway_centres: Array[float] = []
	var runway_z: Array[float] = []
	for collider in runway_colliders:
		var local_to_build := placed.to_local(collider.global_position)
		runway_centres.append(local_to_build.x)
		runway_z.append(local_to_build.z)
	runway_centres.sort()
	var half_seg := AirfieldPavementModules.RUNWAY_SEGMENT * 0.5
	assert(absf(runway_centres.front() - half_seg - AirfieldHQ23.RUNWAY_START_X) < 0.02, "The runway collision west endpoint must start at the configured strip")
	assert(absf(runway_centres.back() + half_seg - AirfieldHQ23.RUNWAY_END_X) < 0.02, "The runway collision east endpoint must end at the configured strip")
	assert(runway_z.all(func(z: float) -> bool: return absf(z - AirfieldHQ23.RUNWAY_CENTER_Z) < 0.02), "All runway segment centers must share one centerline")
	assert(AirfieldHQ23.footprint_area() <= AirfieldHQ23.MAX_GROUND_AREA, "The complete construction-area allocation must remain within the budget")
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
