extends Node
## Paired production-scene captures for the Airfield HQ lighting hotfix.
## Run with AIRFIELD_CAPTURE_PHASE=before on the parent and =after on the candidate.

const OUTPUT_ROOT := "res://docs/airfield_hq_v23/lighting_visibility"
const MAIN_SCENE := "res://scenes/main.tscn"
const WORKSHOP_LIGHT_PREFIX := "Warm workshop practical light"
const SHOP_LIGHT_MASK := 1 << 29

var _main: Node3D
var _capture_camera: Camera3D
var _building: Dictionary
var _phase := "before"

func _ready() -> void:
	_phase = OS.get_environment("AIRFIELD_CAPTURE_PHASE").strip_edges().to_lower()
	if _phase not in ["before", "after"]:
		_phase = "before"
	call_deferred("_run")

func _run() -> void:
	_main = (load(MAIN_SCENE) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child(_main)
	await get_tree().process_frame
	await _main.begin()
	var main_menu := get_tree().get_first_node_in_group("menus") as PauseMenu
	if main_menu != null:
		await main_menu._show("")
	Game.state = "prep"
	Game.points = 8000
	Game.build_credit = 0
	var original_time := GameSettings.get_value("time")
	var atmosphere := get_tree().get_first_node_in_group("atmosphere") as Atmosphere
	assert(atmosphere != null, "The production atmosphere must be available")

	var build_ui := _find_build_ui()
	assert(build_ui != null, "The production HUD must contain BuildMode")
	build_ui._enter()
	var card: BuildMode.Card
	for item in build_ui._cards:
		var candidate := item as BuildMode.Card
		if candidate.kind == "airfield":
			card = candidate
			break
	assert(card != null, "The production build menu must expose the airfield card")
	build_ui._down(0, card.get_global_rect().get_center())
	build_ui._up(0)
	await _settle_frames(20)
	var preview_status := Game.builds.placement_status("airfield", AirfieldHQ23.SUGGESTED_CENTER, 0.0)
	assert(preview_status.valid, "The paired build-mode image must show a valid airfield preview: %s" % preview_status.reason)
	build_ui._airfield_candidate = AirfieldHQ23.SUGGESTED_CENTER
	build_ui._airfield_preview_dirty = true
	build_ui._show_airfield_preview()
	await _settle_frames(8)
	await _save_view("build_mode.png")

	# Use the normal build-menu tap and production transaction to create the real building.
	var map_center := get_viewport().get_visible_rect().size * 0.5
	build_ui._down(1, map_center)
	build_ui._up(1)
	_building = _find_airfield()
	assert(not _building.is_empty(), "The build-menu tap must place the production airfield")
	assert(Game.points == 5200, "The capture fixture must charge the 2,800-point build exactly once")
	build_ui._exit()
	build_ui._ui.visible = false
	var complex := _building.node.get_meta("complex") as Node3D
	assert(complex != null, "The placed airfield must retain its production complex")
	var core := complex as AirfieldHQ22Showcase
	assert(core != null, "The original approved 2.2 showcase must be the installed runtime core")
	var runtime_lights := _workshop_lights(core.lod0)
	assert(runtime_lights.size() == 5, "Imported Airfield LOD0 must contain five named workshop OmniLight3D nodes; found %d" % runtime_lights.size())
	var visible_count := 0
	for light in runtime_lights:
		if light.visible:
			visible_count += 1
	if _phase == "before":
		# Reconstruct the parent-branch runtime state when generating its paired evidence
		# from the same candidate checkout: the only production delta is this visibility bit.
		for light in runtime_lights:
			light.visible = true
		visible_count = 0
		for light in runtime_lights:
			if light.visible:
				visible_count += 1
		assert(visible_count == 5, "The paired before fixture must leave all five imported workshop lamps enabled")
	else:
		assert(visible_count == 0, "Candidate runtime must disable all five workshop lamps; found %d still visible" % visible_count)
	# Check that the source GLB remains unmodified: an isolated import must still have all five nodes enabled.
	var source_model := (load("res://assets/airfield_hq_v22/runtime/Bloedjungle_Airfield_HQ_2_2_LOD0.glb") as PackedScene).instantiate()
	get_tree().root.add_child(source_model)
	await get_tree().process_frame
	var imported_lights := _workshop_lights(source_model)
	assert(imported_lights.size() == 5, "The protected imported HQ 2.2 LOD0 must retain its five original lights")
	for light in imported_lights:
		assert(light.visible, "The protected imported HQ 2.2 source light %s must remain enabled" % light.name)
	source_model.queue_free()

	# Paired daylight and dusk views use one locked camera, opened hangar doors, and the same render settings.
	core.open_door(&"left")
	core.open_door(&"right")
	_capture_camera = Camera3D.new()
	_capture_camera.name = "Airfield lighting comparison camera"
	_capture_camera.fov = 55.0
	_capture_camera.far = 260.0
	_main.add_child(_capture_camera)
	var airfield_at: Vector3 = _building.at
	_capture_camera.global_position = airfield_at + Vector3(-24.125, 10.8, 49.0)
	_capture_camera.look_at(airfield_at + Vector3(-24.125, 7.0, -0.3), Vector3.UP)
	_capture_camera.make_current()
	_hide_game_hud()
	GameSettings.values["time"] = "day"
	atmosphere.apply_settings()
	await _settle_frames(150)
	var measurements := await _measure_performance()
	await _save_view("daylight.png")
	GameSettings.values["time"] = "dusk"
	atmosphere.apply_settings()
	await _settle_frames(24)
	await _save_view("twilight.png")

	# Independent roof-visibility check: place the actual player under the hangar, keep the ordinary camera active,
	# then test whether a triangle-accurate proxy of the imported hangar intersects its camera-to-head sightline.
	_capture_camera.current = false
	var game_camera := _main.get_node("Camera") as Camera3D
	game_camera.make_current()
	Game.state = "prep"
	Game.build_mode = false
	Game.airfield_build_view = false
	var player: Node3D = Game.player
	assert(player != null, "The gameplay visibility check requires the real player")
	player.global_position = airfield_at + Vector3(-24.125, 0.0, 1.0)
	player.set("face", PI)
	await _settle_frames(90)
	var sightline := await _probe_hangar_sightline(core, game_camera, player)
	print("AIRFIELD_HANGAR_ROOF_VISIBILITY player_under_roof=true camera_ray_hit_hangar=%s hit_y=%.3f normal_y=%.3f hit_position=%s" % [sightline.hit_hangar, sightline.hit_y, sightline.normal_y, sightline.position])
	await _save_view("gameplay_hangar_player.png")

	GameSettings.values["time"] = original_time
	atmosphere.apply_settings()
	measurements.merge({"phase": _phase, "renderer": RenderingServer.get_current_rendering_method(), "gpu": RenderingServer.get_video_adapter_name(),
		"viewport": get_viewport().get_visible_rect().size, "runtime_enabled_workshop_lights": visible_count,
		"roof_ray_obstructed_player": sightline.hit_hangar, "roof_ray_hit_y_m": sightline.hit_y})
	_write_measurements(measurements)
	print("AIRFIELD_LIGHTING_CAPTURE_PASS phase=%s imported_lod0_lights=5 runtime_enabled=%d roof_ray_hit=%s fps_median=%.2f fps_1pct_low=%.2f static_memory_mb=%.1f screenshots=%s/%s viewport=%s" % [
		_phase, visible_count, sightline.hit_hangar, measurements.median_fps, measurements.one_percent_low_fps,
		measurements.static_memory_bytes / 1048576.0, OUTPUT_ROOT, _phase, get_viewport().get_visible_rect().size])
	get_tree().quit(0)

func _find_build_ui() -> BuildMode:
	var build_script := load("res://scripts/build_mode.gd") as Script
	for child in _main.get_node("Hud").get_children():
		if child.get_script() == build_script:
			return child as BuildMode
	return null

func _find_airfield() -> Dictionary:
	for building in Game.buildings:
		if building.kind == "airfield":
			return building
	return {}

func _workshop_lights(root: Node) -> Array[Light3D]:
	var found: Array[Light3D] = []
	for child in root.find_children("*", "Light3D", true, false):
		var light := child as Light3D
		if light.name.begins_with(WORKSHOP_LIGHT_PREFIX):
			found.append(light)
	return found

func _hide_game_hud() -> void:
	var hud := _main.get_node_or_null("Hud") as CanvasLayer
	if hud != null:
		hud.visible = false
	for layer in _main.find_children("*", "CanvasLayer", true, false):
		layer.visible = false

func _settle_frames(count: int) -> void:
	for _frame in count:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

func _measure_performance() -> Dictionary:
	# Same warmed production view and 180 synchronously presented frames in both runs.
	var frame_ms: Array[float] = []
	for _frame in 180:
		var started := Time.get_ticks_usec()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		frame_ms.append(float(Time.get_ticks_usec() - started) / 1000.0)
	frame_ms.sort()
	var total := 0.0
	for sample in frame_ms:
		total += sample
	var median_ms := frame_ms[frame_ms.size() / 2]
	var p99_ms := frame_ms[mini(frame_ms.size() - 1, ceili(frame_ms.size() * 0.99) - 1)]
	return {
		"frame_samples": frame_ms.size(),
		"median_frame_ms": median_ms,
		"p99_frame_ms": p99_ms,
		"mean_frame_ms": total / float(frame_ms.size()),
		"median_fps": 1000.0 / maxf(median_ms, 0.001),
		"one_percent_low_fps": 1000.0 / maxf(p99_ms, 0.001),
		"static_memory_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"static_memory_max_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC_MAX)),
	}

func _write_measurements(data: Dictionary) -> void:
	var directory := OUTPUT_ROOT.path_join(_phase)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var file := FileAccess.open(ProjectSettings.globalize_path(directory.path_join("measurements.json")), FileAccess.WRITE)
	assert(file != null, "Could not write paired desktop renderer measurements")
	file.store_string(JSON.stringify(data, "\t"))

func _save_view(filename: String) -> void:
	var directory := OUTPUT_ROOT.path_join(_phase)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path(directory.path_join(filename))
	var error := image.save_png(path)
	assert(error == OK, "Failed to save %s: %s" % [path, error])

func _probe_hangar_sightline(core: AirfieldHQ22Showcase, camera: Camera3D, player: Node3D) -> Dictionary:
	var hangar := core.lod0.find_child("Hangar HQ 22", true, false) as MeshInstance3D
	assert(hangar != null and hangar.mesh != null, "The roof visibility check requires the imported hangar mesh")
	var shape := hangar.mesh.create_trimesh_shape()
	assert(shape != null, "The imported hangar mesh must create a triangle-accurate visibility probe")
	var probe := StaticBody3D.new()
	probe.name = "Temporary airfield hangar sightline probe"
	probe.collision_layer = SHOP_LIGHT_MASK
	probe.collision_mask = 0
	var collision := CollisionShape3D.new()
	collision.shape = shape
	probe.add_child(collision)
	_main.add_child(probe)
	probe.global_transform = hangar.global_transform
	await get_tree().physics_frame
	var head := player.global_position + Vector3.UP * 1.25
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, head, SHOP_LIGHT_MASK)
	var hit := _main.get_world_3d().direct_space_state.intersect_ray(query)
	var result := {"hit_hangar": not hit.is_empty(), "hit_y": -1.0, "normal_y": 0.0, "position": Vector3.ZERO}
	if not hit.is_empty():
		result.hit_y = (hit.position as Vector3).y
		result.normal_y = (hit.normal as Vector3).y
		result.position = hit.position
	probe.queue_free()
	return result
