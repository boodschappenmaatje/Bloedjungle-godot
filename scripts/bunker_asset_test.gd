extends Node3D
## Standalone native-app inspection scene. It does not instantiate or modify the gameplay world.

const MODEL_PATH := "res://assets/tests/bunker/bloedjungle_bunker_hq.glb"
const EXPECTED_TRIANGLES := 37928
const EXPECTED_SIZE := Vector3(8.4, 4.852, 7.2) # Godot X/Y/Z, metres
const HISTORY_SECONDS := 30.0

var bunker: Node3D
var camera: Camera3D
var target := Vector3(0.0, 2.4, 0.0)
var yaw := deg_to_rad(37.0)
var pitch := deg_to_rad(32.0)
var camera_distance := 18.0
var drag_active := false
var touch_positions: Dictionary = {}
var previous_pinch := 0.0
var elapsed := 0.0
var sample_elapsed := 0.0
var fps_samples: Array[float] = []
var fps_min := INF
var fps_max := 0.0
var peak_process_mb := 0.0
var peak_video_mb := 0.0
var stats_label: Label
var model_label: Label
var status_label: Label


func _ready() -> void:
	_build_stage()
	_build_ui()
	_load_bunker()
	_update_camera()


func _build_stage() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("20251e")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("888274")
	environment.ambient_light_energy = 0.45
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)

	var floor := MeshInstance3D.new()
	floor.name = "AssetTestGround"
	var plane := PlaneMesh.new()
	plane.size = Vector2(26.0, 26.0)
	floor.mesh = plane
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("34382e")
	floor_material.roughness = 0.93
	floor.material_override = floor_material
	floor.position.y = -0.06
	add_child(floor)

	var sun := DirectionalLight3D.new()
	sun.name = "ShowcaseSun"
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_color = Color("f2dfbd")
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	add_child(sun)

	camera = Camera3D.new()
	camera.name = "AssetTestCamera"
	camera.fov = 45.0
	camera.near = 0.1
	camera.far = 250.0
	add_child(camera)
	camera.make_current()


func _load_bunker() -> void:
	var packed := load(MODEL_PATH) as PackedScene
	if packed == null:
		status_label_set("FAIL · GLB kon niet worden geïmporteerd")
		return
	bunker = packed.instantiate()
	bunker.name = "Bloedjungle_Bunker_HQ_Game"
	add_child(bunker)
	var audit := _audit_model()
	model_label.text = "BUNKER HQ · %.2f × %.2f × %.2f m · %d tris · %d meshes · %d PBR-materialen\nUV/base color/normal/ORM/AO/emissie: %s" % [
		audit.size.x, audit.size.y, audit.size.z, audit.triangles, audit.meshes, audit.materials,
		"PASS" if audit.textured_surfaces == audit.surfaces and audit.surfaces > 0 else "CONTROLEER"]
	status_label_set("Godot assetscene geladen · %d surfaces · %d texture-resources" % [audit.surfaces, audit.textures])
	if audit.triangles != EXPECTED_TRIANGLES:
		push_warning("Bunker GLB triangle count differs from Blender export: %d (expected %d)" % [audit.triangles, EXPECTED_TRIANGLES])


func _audit_model() -> Dictionary:
	var bounds := AABB()
	var has_bounds := false
	var mesh_count := 0
	var triangles := 0
	var surfaces := 0
	var textured_surfaces := 0
	var materials := {}
	var textures := {}
	for node in bunker.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		mesh_count += 1
		var mesh_bounds: AABB = mi.get_aabb() * (bunker.global_transform.affine_inverse() * mi.global_transform)
		bounds = mesh_bounds if not has_bounds else bounds.merge(mesh_bounds)
		has_bounds = true
		triangles += mi.mesh.get_faces().size() / 3
		for s in mi.mesh.get_surface_count():
			surfaces += 1
			var material := mi.get_active_material(s)
			if material == null:
				continue
			materials[material.get_instance_id()] = true
			if material is StandardMaterial3D:
				var std := material as StandardMaterial3D
				var albedo := std.albedo_texture != null
				var normal := std.normal_texture != null
				var rough := std.roughness_texture != null
				var metal := std.metallic_texture != null
				var ao := std.ao_texture != null
				var emission := std.emission_texture != null
				if albedo and normal and rough and metal and ao and emission:
					textured_surfaces += 1
				for texture in [std.albedo_texture, std.normal_texture, std.roughness_texture, std.metallic_texture, std.ao_texture, std.emission_texture]:
					if texture != null:
						textures[texture.get_instance_id()] = true
	return {"size": bounds.size if has_bounds else Vector3.ZERO, "triangles": triangles, "meshes": mesh_count,
		"surfaces": surfaces, "textured_surfaces": textured_surfaces, "materials": materials.size(), "textures": textures.size()}


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.box(Color(0.045, 0.055, 0.043, 0.94), UI.BRASS, 1, 6, 10))
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(14, 14)
	panel.custom_minimum_size.x = 410
	layer.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	box.add_child(UI.label("3D ASSET TEST ZONE", UI.display(1), 21, UI.BRASS))
	model_label = UI.label("Bunker laden…", UI.body(600), 15, UI.INK)
	model_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(model_label)
	stats_label = UI.label("Godot-meting initialiseren…", UI.body(600), 14, UI.INK_DIM)
	box.add_child(stats_label)
	var cameras := HBoxContainer.new()
	box.add_child(cameras)
	_add_button(cameras, "Schuin", func(): _set_preset(37.0, 32.0, 18.0))
	_add_button(cameras, "Gameplay", func(): _set_preset(45.0, 58.0, 28.0))
	_add_button(cameras, "Voorzijde", func(): _set_preset(0.0, 12.0, 17.0))
	var actions := HBoxContainer.new()
	box.add_child(actions)
	_add_button(actions, "Reset meting", _reset_metrics)
	_add_button(actions, "Bewaar meting", _save_metrics)
	_add_button(box, "Terug naar hoofdmenu", func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
	status_label = UI.label("Sleep om te draaien · knijp om te zoomen", UI.body(600), 13, UI.OLIVE_HI)
	box.add_child(status_label)
	for button in panel.find_children("*", "BaseButton", true, false):
		button.custom_minimum_size = Vector2(0, 42)
		button.add_to_group("hud_button")


func _add_button(parent: Control, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	UI.style_button(button, "secondary")
	button.pressed.connect(action)
	parent.add_child(button)


func _process(delta: float) -> void:
	elapsed += delta
	sample_elapsed += delta
	if sample_elapsed >= 0.5:
		var fps := float(Engine.get_frames_per_second())
		if fps > 0.0 and elapsed >= 2.0:
			fps_samples.append(fps)
			fps_min = minf(fps_min, fps)
			fps_max = maxf(fps_max, fps)
			if fps_samples.size() > int(HISTORY_SECONDS * 2):
				fps_samples.pop_front()
		var process_mb := float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0
		var video_bytes := int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
		var video_mb := float(video_bytes) / 1048576.0
		peak_process_mb = maxf(peak_process_mb, process_mb)
		peak_video_mb = maxf(peak_video_mb, video_mb)
		var average := 0.0
		for value in fps_samples:
			average += value
		if not fps_samples.is_empty():
			average /= fps_samples.size()
		stats_label.text = "FPS nu/gemiddeld/min: %.0f / %.1f / %s · piek: %.0f\nGodot RAM: %.1f MB (piek %.1f) · videogeheugen: %s MB (piek %.1f)" % [
			fps, average, "—" if fps_min == INF else "%.0f" % fps_min, fps_max, process_mb, peak_process_mb,
				"n/b" if video_bytes <= 0 else "%.1f" % video_mb, peak_video_mb]
		sample_elapsed = 0.0


func _set_preset(degrees_yaw: float, degrees_pitch: float, distance: float) -> void:
	yaw = deg_to_rad(degrees_yaw)
	pitch = deg_to_rad(degrees_pitch)
	camera_distance = distance
	_update_camera()


func _update_camera() -> void:
	if camera == null:
		return
	var horizontal := cos(pitch) * camera_distance
	camera.position = target + Vector3(sin(yaw) * horizontal, sin(pitch) * camera_distance, cos(yaw) * horizontal)
	camera.look_at(target, Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			touch_positions[touch.index] = touch.position
		else:
			touch_positions.erase(touch.index)
			if touch_positions.size() < 2:
				previous_pinch = 0.0
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		touch_positions[drag.index] = drag.position
		if touch_positions.size() >= 2:
			var points: Array = touch_positions.values()
			var pinch: float = points[0].distance_to(points[1])
			if previous_pinch > 0.0:
				camera_distance = clampf(camera_distance * previous_pinch / maxf(pinch, 1.0), 7.0, 38.0)
				_update_camera()
			previous_pinch = pinch
		else:
			yaw -= drag.relative.x * 0.006
			pitch = clampf(pitch + drag.relative.y * 0.0035, deg_to_rad(8.0), deg_to_rad(78.0))
			_update_camera()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		drag_active = event.pressed
	elif event is InputEventMouseMotion and drag_active:
		var motion := event as InputEventMouseMotion
		yaw -= motion.relative.x * 0.006
		pitch = clampf(pitch + motion.relative.y * 0.0035, deg_to_rad(8.0), deg_to_rad(78.0))
		_update_camera()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		camera_distance = maxf(7.0, camera_distance - 1.0)
		_update_camera()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		camera_distance = minf(38.0, camera_distance + 1.0)
		_update_camera()


func _reset_metrics() -> void:
	elapsed = 0.0
	fps_samples.clear()
	fps_min = INF
	fps_max = 0.0
	peak_process_mb = 0.0
	peak_video_mb = 0.0
	status_label_set("Meting gereset · laat shaders eerst 2 s opwarmen")


func _save_metrics() -> void:
	var mean := 0.0
	for value in fps_samples:
		mean += value
	if not fps_samples.is_empty():
		mean /= fps_samples.size()
	var data := {
		"asset": "Bloedjungle_Bunker_HQ_Game", "resolution": "%dx%d" % [get_viewport().size.x, get_viewport().size.y],
		"renderer": ProjectSettings.get_setting("rendering/renderer/rendering_method", "unknown"),
		"device": RenderingServer.get_video_adapter_name(), "os": OS.get_name(), "duration_seconds": elapsed,
		"fps_average_recent_30s": mean, "fps_min_since_reset": null if fps_min == INF else fps_min,
		"fps_max_since_reset": fps_max, "process_memory_mb": float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0,
		"process_memory_peak_mb": peak_process_mb, "video_memory_mb": float(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)) / 1048576.0,
		"video_memory_peak_mb": peak_video_mb, "triangle_count": EXPECTED_TRIANGLES,
		"note": "Renderer memory is Godot-reported. FPS/memory require a rendered device session; headless results are not representative."
	}
	var file := FileAccess.open("user://bunker_asset_test_latest.json", FileAccess.WRITE)
	if file == null:
		status_label_set("Meting niet opgeslagen · user:// kon niet worden geopend")
		return
	file.store_string(JSON.stringify(data, "\t"))
	status_label_set("Meting lokaal opgeslagen · user://bunker_asset_test_latest.json")


func status_label_set(value: String) -> void:
	if status_label != null:
		status_label.text = value
