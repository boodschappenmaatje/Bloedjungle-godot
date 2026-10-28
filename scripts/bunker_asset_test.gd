extends Node3D
## Isolated native-app showcase/performance scene. It does not alter gameplay or renderer settings.

const MODEL_PATH := "res://assets/tests/bunker/bloedjungle_bunker_hq.glb"
const EXPECTED_TRIANGLES := 37928
const WARMUP_SECONDS := 5.0
const MEASURE_SECONDS := 30.0
const METRICS := preload("res://scripts/bunker_asset_metrics.gd")
const SCENARIOS := ["A · Baseline", "B · Jungleomgeving", "C · Drie bunkers", "D · Zware stresstest"]
const CAMERA_PROFILES := ["Gameplay · Normaal", "Gameplay · Gevecht", "Schuin", "Voorzijde", "Handmatig"]
const LIGHTING_PROFILES := ["Standaardbelichting", "Verbeterde belichting"]

var bunker: Node3D
var bunker_instances: Array[Node3D] = []
var camera: Camera3D
var target := Vector3(0.0, 2.4, 0.0)
var yaw := 0.0
var pitch := deg_to_rad(58.0)
var camera_distance := 28.0
var camera_profile_index := 0
var scenario_index := 0
var lighting_index := 0
var drag_active := false
var touch_positions: Dictionary = {}
var previous_pinch := 0.0
var scenario_root: Node3D
var environment_root: Node3D
var sun: DirectionalLight3D
var world_environment: WorldEnvironment

var hud_expanded := false
var hud_root: Control
var collapsed_bar: PanelContainer
var expanded_panel: PanelContainer
var fps_compact: Label
var metrics_label: Label
var model_label: Label
var status_label: Label
var scenario_option: OptionButton
var camera_option: OptionButton
var lighting_option: OptionButton

var current_fps := 0.0
var current_frame_ms := 0.0
var display_refresh_hz := 0.0
var ui_elapsed := 0.0
var measurement_state := "idle" # idle, warmup, measuring, complete
var warmup_elapsed := 0.0
var measured_elapsed := 0.0
var frame_times_ms: Array[float] = []
var last_summary: Dictionary = {}
var current_godot_mb: float = -1.0
var peak_godot_mb: float = -1.0
var current_renderer_mb: float = -1.0
var peak_renderer_mb: float = -1.0
var current_draw_calls := -1
var peak_draw_calls := -1
var current_primitives := -1
var peak_primitives := -1


func _ready() -> void:
	_build_stage()
	_build_ui()
	_set_scenario(0)
	_set_lighting(0)
	_update_camera()
	var reported_refresh := DisplayServer.screen_get_refresh_rate()
	if reported_refresh > 0.0:
		display_refresh_hz = reported_refresh


func _build_stage() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("252a22")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("aaa28a")
	environment.ambient_light_energy = 0.42
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment = WorldEnvironment.new()
	world_environment.name = "AssetTestEnvironment"
	world_environment.environment = environment
	add_child(world_environment)

	var floor := MeshInstance3D.new()
	floor.name = "AssetTestTerrain"
	var plane := PlaneMesh.new()
	plane.size = Vector2(100.0, 100.0)
	floor.mesh = plane
	var terrain := StandardMaterial3D.new()
	terrain.albedo_color = Color("464536")
	terrain.roughness = 0.98
	floor.material_override = terrain
	floor.position.y = -0.08
	add_child(floor)

	sun = DirectionalLight3D.new()
	sun.name = "BloedjungleSun"
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_color = Color("f2dfbd")
	sun.light_energy = 1.15
	sun.shadow_enabled = false
	add_child(sun)

	camera = Camera3D.new()
	camera.name = "AssetTestCamera"
	camera.fov = 45.0
	camera.near = 0.1
	camera.far = 250.0
	add_child(camera)
	camera.make_current()

	environment_root = Node3D.new()
	environment_root.name = "ScenarioEnvironment"
	add_child(environment_root)
	scenario_root = Node3D.new()
	scenario_root.name = "ScenarioAssets"
	add_child(scenario_root)


func _build_ui() -> void:
	hud_root = Control.new()
	hud_root.name = "CompactTestHUD"
	hud_root.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud_root)
	var viewport_size := get_viewport().get_visible_rect().size
	var safe := UI.safe_margins(viewport_size, 14.0)
	hud_root.position = Vector2(safe.x, safe.y)
	hud_root.size = Vector2(maxf(0.0, viewport_size.x - safe.x - safe.z), maxf(0.0, viewport_size.y - safe.y - safe.w))
	var panel_width := clampf(viewport_size.x * 0.34, 300.0, 430.0)

	collapsed_bar = PanelContainer.new()
	collapsed_bar.name = "CollapsedHUD"
	collapsed_bar.custom_minimum_size = Vector2(panel_width, 56.0)
	collapsed_bar.size = collapsed_bar.custom_minimum_size
	collapsed_bar.add_theme_stylebox_override("panel", UI.box(Color(0.035, 0.045, 0.032, 0.72), UI.BRASS, 1, 8, 5))
	hud_root.add_child(collapsed_bar)
	var compact_row := HBoxContainer.new()
	compact_row.add_theme_constant_override("separation", 8)
	collapsed_bar.add_child(compact_row)
	fps_compact = UI.label("FPS  —  ·  1% low  —", UI.body(700), 15, UI.INK)
	fps_compact.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	compact_row.add_child(fps_compact)
	var open_button := _add_button(compact_row, "TEST ▾", _toggle_hud)
	open_button.custom_minimum_size = Vector2(92.0, 48.0)

	expanded_panel = PanelContainer.new()
	expanded_panel.name = "ExpandedHUD"
	expanded_panel.visible = false
	expanded_panel.custom_minimum_size = Vector2(panel_width, minf(500.0, viewport_size.y * 0.72))
	expanded_panel.size = expanded_panel.custom_minimum_size
	expanded_panel.add_theme_stylebox_override("panel", UI.box(Color(0.035, 0.045, 0.032, 0.87), UI.BRASS, 1, 8, 8))
	hud_root.add_child(expanded_panel)
	var scroll := ScrollContainer.new()
	scroll.name = "HUDSettingsScroll"
	scroll.custom_minimum_size.y = minf(500.0, viewport_size.y * 0.72)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	expanded_panel.add_child(scroll)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	var title_row := HBoxContainer.new()
	content.add_child(title_row)
	title_row.add_child(UI.label("BUNKER · TEST CONTROLS", UI.display(1), 15, UI.BRASS))
	var close_button := _add_button(title_row, "INKLAPPEN ▴", _toggle_hud)
	close_button.custom_minimum_size = Vector2(112.0, 48.0)

	model_label = UI.label("Bunker laden…", UI.body(600), 14, UI.INK)
	model_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(model_label)
	content.add_child(_section_label("SCENARIO"))
	scenario_option = _add_option(content, SCENARIOS, func(index: int): _set_scenario(index))
	content.add_child(_section_label("CAMERA"))
	camera_option = _add_option(content, CAMERA_PROFILES, func(index: int): _set_camera_profile(index))
	content.add_child(_section_label("BELICHTING"))
	lighting_option = _add_option(content, LIGHTING_PROFILES, func(index: int): _set_lighting(index))

	metrics_label = UI.label("Start een vaste meting van 30 s.\nOpwarming: 5 s · per-frame registratie.", UI.body(600), 14, UI.INK_DIM)
	metrics_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(metrics_label)
	var controls_row := HBoxContainer.new()
	controls_row.add_theme_constant_override("separation", 5)
	content.add_child(controls_row)
	_add_button(controls_row, "START 30 S", _start_measurement)
	_add_button(controls_row, "RESET", _reset_metrics)
	var actions_row := HBoxContainer.new()
	actions_row.add_theme_constant_override("separation", 5)
	content.add_child(actions_row)
	_add_button(actions_row, "BEWAAR JSON", _save_metrics)
	_add_button(actions_row, "HOOFDMENU", func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
	status_label = UI.label("Sleep om te draaien · knijp om te zoomen", UI.body(600), 13, UI.OLIVE_HI)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(status_label)


func _section_label(text: String) -> Label:
	return UI.label(text, UI.body(700, 1), 12, UI.BRASS)


func _add_option(parent: Control, items: Array, action: Callable) -> OptionButton:
	var option := OptionButton.new()
	option.custom_minimum_size.y = 48.0
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.add_theme_font_override("font", UI.body(700))
	option.add_theme_font_size_override("font_size", 15)
	option.add_theme_color_override("font_color", UI.INK)
	option.add_theme_stylebox_override("normal", UI.box(Color("252a1d"), UI.PANEL_LINE, 1, 4, 6))
	option.add_theme_stylebox_override("hover", UI.box(Color("343b24"), UI.OLIVE_HI, 1, 4, 6))
	for choice in items:
		option.add_item(choice)
	option.item_selected.connect(action)
	parent.add_child(option)
	return option


func _add_button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 48.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.style_button(button, "secondary")
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _toggle_hud() -> void:
	hud_expanded = not hud_expanded
	collapsed_bar.visible = not hud_expanded
	expanded_panel.visible = hud_expanded


func _set_scenario(index: int) -> void:
	scenario_index = clampi(index, 0, SCENARIOS.size() - 1)
	for child in scenario_root.get_children():
		scenario_root.remove_child(child)
		child.free()
	for child in environment_root.get_children():
		environment_root.remove_child(child)
		child.free()
	bunker_instances.clear()
	bunker = null
	var bunker_positions: Array[Vector3] = [Vector3.ZERO]
	if scenario_index >= 2:
		bunker_positions = [Vector3(-8.7, 0.0, 0.0), Vector3.ZERO, Vector3(8.7, 0.0, 0.0)]
	for i in bunker_positions.size():
		var new_bunker := _add_asset(MODEL_PATH, "Bloedjungle_Bunker_HQ_%02d" % (i + 1), bunker_positions[i])
		if new_bunker != null:
			bunker_instances.append(new_bunker)
			if bunker == null:
				bunker = new_bunker
	match scenario_index:
		1:
			_add_visual_environment()
		3:
			_add_heavy_environment()
	_update_model_label()
	if is_instance_valid(scenario_option):
		scenario_option.select(scenario_index)
	if camera_profile_index < 2:
		_set_camera_profile(camera_profile_index)
	status_label_set("Scenario geladen · %d bunker(s)" % bunker_instances.size())


func _add_asset(path: String, instance_name: String, at: Vector3, scale_value := 1.0, rotation_y := 0.0, parent: Node3D = null) -> Node3D:
	var packed := load(path) as PackedScene
	if packed == null:
		push_warning("Asset Test Zone: kan niet laden: " + path)
		return null
	var instance := packed.instantiate() as Node3D
	if instance == null:
		push_warning("Asset Test Zone: root is niet Node3D: " + path)
		return null
	instance.name = instance_name
	instance.position = at
	instance.rotation.y = rotation_y
	instance.scale = Vector3.ONE * scale_value
	(scenario_root if parent == null else parent).add_child(instance)
	return instance


func _add_visual_environment() -> void:
	# Bestaande game-GLB's; vaste locaties houden herhaalde metingen reproduceerbaar.
	_add_asset("res://assets/jungle.glb", "Jungle_NW", Vector3(-14.0, 0.0, -12.0), 0.82, 0.3, environment_root)
	_add_asset("res://assets/jungle.glb", "Jungle_NE", Vector3(14.0, 0.0, -10.0), 0.82, 1.1, environment_root)
	_add_asset("res://assets/jungle.glb", "Jungle_SW", Vector3(-13.0, 0.0, 12.0), 0.82, 2.2, environment_root)
	_add_asset("res://assets/props.glb", "Military_Props", Vector3(6.0, 0.0, 6.0), 1.0, -0.35, environment_root)
	_add_asset("res://assets/straatmeubilair.glb", "Field_Furniture", Vector3(12.0, 0.0, 7.0), 0.72, 0.0, environment_root)


func _add_props_cluster(at: Vector3) -> void:
	_add_asset("res://assets/props.glb", "Military_Props", at, 1.0, 0.0, environment_root)
	_add_asset("res://assets/straatmeubilair.glb", "Field_Furniture", at + Vector3(5.0, 0.0, 1.0), 0.8, 0.4, environment_root)


func _add_heavy_environment() -> void:
	_add_visual_environment()
	_add_asset("res://assets/wachtpost.glb", "Guard_Post", Vector3(-14.0, 0.0, 10.0), 0.9, 0.7, environment_root)
	_add_asset("res://assets/wachttoren.glb", "Watch_Tower", Vector3(15.0, 0.0, 10.0), 0.95, -0.4, environment_root)
	_add_asset("res://assets/woonhuis.glb", "Rural_Building", Vector3(0.0, 0.0, -17.0), 0.72, 0.15, environment_root)
	_add_asset("res://assets/props.glb", "Supply_Props_02", Vector3(-13.0, 0.0, -2.0), 1.0, 1.1, environment_root)
	_add_asset("res://assets/props.glb", "Supply_Props_03", Vector3(13.0, 0.0, -2.0), 1.0, -1.1, environment_root)
	_add_asset("res://assets/jungle.glb", "Jungle_SE", Vector3(14.0, 0.0, -15.0), 0.72, 2.1, environment_root)
	_add_asset("res://assets/jungle.glb", "Jungle_NE_02", Vector3(-14.0, 0.0, -15.0), 0.72, -0.7, environment_root)
	_add_asset("res://assets/jungle.glb", "Jungle_SE_02", Vector3(20.0, 0.0, 8.0), 0.72, 0.9, environment_root)


func _set_lighting(index: int) -> void:
	lighting_index = clampi(index, 0, LIGHTING_PROFILES.size() - 1)
	var improved := lighting_index == 1
	world_environment.environment.ambient_light_energy = 0.48 if improved else 0.34
	world_environment.environment.ambient_light_color = Color("b7ad92") if improved else Color("aaa28a")
	sun.rotation_degrees = Vector3(-42.0, -30.0, 0.0) if improved else Vector3(-48.0, -32.0, 0.0)
	sun.light_energy = 1.45 if improved else 1.0
	sun.light_color = Color("fff0d4") if improved else Color("f2dfbd")
	sun.shadow_enabled = improved
	if is_instance_valid(lighting_option):
		lighting_option.select(lighting_index)
	status_label_set("Verbeterde belichting · zachte zon + schaduwen" if improved else "Standaardbelichting · directe zon zonder schaduwkaart")


func _set_camera_profile(index: int) -> void:
	camera_profile_index = clampi(index, 0, CAMERA_PROFILES.size() - 1)
	match camera_profile_index:
		0: # Gameplay: scripts/camera_rig.gd, normal view.
			yaw = 0.0
			pitch = deg_to_rad(58.0)
			camera_distance = 28.0
			camera.fov = 45.0
			camera.far = 220.0
		1: # Gameplay combat view uses the same 45-degree lens in CameraRig._ready().
			yaw = 0.0
			pitch = deg_to_rad(48.0)
			camera_distance = 16.0
			camera.fov = 45.0
			camera.far = 220.0
		2:
			yaw = deg_to_rad(37.0)
			pitch = deg_to_rad(32.0)
			camera_distance = 18.0
			camera.fov = 45.0
		3:
			yaw = 0.0
			pitch = deg_to_rad(12.0)
			camera_distance = 17.0
			camera.fov = 45.0
		4: # Touch orbit/zoom leaves the current values in place.
			pass
	if is_instance_valid(camera_option):
		camera_option.select(camera_profile_index)
	_update_camera()
	status_label_set("%s · FOV %.0f° · %.0f m" % [CAMERA_PROFILES[camera_profile_index], camera.fov, camera_distance])


func _update_camera() -> void:
	if camera == null:
		return
	var landscape := get_viewport().get_visible_rect().size.x >= get_viewport().get_visible_rect().size.y
	# camera_rig.gd schuift in landschap het target 7% van de afstand vooruit.
	var look_ahead := 0.07 if landscape else 0.05
	var focus := target + Vector3(0.0, 0.0, -camera_distance * look_ahead)
	var horizontal := cos(pitch) * camera_distance
	camera.position = focus + Vector3(sin(yaw) * horizontal, sin(pitch) * camera_distance, cos(yaw) * horizontal)
	camera.look_at(focus, Vector3.UP)


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	current_frame_ms = delta * 1000.0
	current_fps = 1.0 / delta
	_sample_resource_monitors()
	if measurement_state == "warmup":
		warmup_elapsed += delta
		if warmup_elapsed >= WARMUP_SECONDS:
			measurement_state = "measuring"
			measured_elapsed = 0.0
			frame_times_ms.clear()
			_reset_peak_monitors()
	elif measurement_state == "measuring":
		frame_times_ms.append(current_frame_ms)
		measured_elapsed += delta
		if measured_elapsed >= MEASURE_SECONDS:
			measurement_state = "complete"
			last_summary = METRICS.summarize(frame_times_ms)
	ui_elapsed += delta
	if ui_elapsed >= 0.15:
		_update_hud()
		ui_elapsed = 0.0


func _sample_resource_monitors() -> void:
	var godot_bytes := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	current_godot_mb = float(godot_bytes) / 1048576.0 if godot_bytes > 0 else -1.0
	if current_godot_mb > 0.0:
		peak_godot_mb = maxf(peak_godot_mb, current_godot_mb)
	var video_bytes := int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
	current_renderer_mb = float(video_bytes) / 1048576.0 if video_bytes > 0 else -1.0
	if current_renderer_mb > 0.0:
		peak_renderer_mb = maxf(peak_renderer_mb, current_renderer_mb)
	var draw_calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	current_draw_calls = draw_calls if draw_calls > 0 else -1
	peak_draw_calls = maxi(peak_draw_calls, current_draw_calls)
	var primitives := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	current_primitives = primitives if primitives > 0 else -1
	peak_primitives = maxi(peak_primitives, current_primitives)


func _reset_peak_monitors() -> void:
	peak_godot_mb = current_godot_mb
	peak_renderer_mb = current_renderer_mb
	peak_draw_calls = current_draw_calls
	peak_primitives = current_primitives


func _update_hud() -> void:
	var average := float(last_summary.get("average_fps", 0.0))
	var one_low := float(last_summary.get("one_percent_low_fps", 0.0))
	if measurement_state == "complete":
		fps_compact.text = "FPS %.0f  ·  gem %.1f  ·  1%% low %.1f" % [current_fps, average, one_low]
	else:
		fps_compact.text = "FPS %.0f  ·  %s" % [current_fps, "meting…" if measurement_state == "measuring" else "gem — · 1%% low —"]
	if not hud_expanded or metrics_label == null:
		return
	var state_text := "Klaar voor 30 s-meting"
	if measurement_state == "warmup":
		state_text = "Opwarming · %.1f / %.0f s" % [warmup_elapsed, WARMUP_SECONDS]
	elif measurement_state == "measuring":
		state_text = "Meten · %.1f / %.0f s" % [measured_elapsed, MEASURE_SECONDS]
	elif measurement_state == "complete":
		state_text = "Meting gereed · %d frames" % frame_times_ms.size()
	var refresh_text := "n/b" if display_refresh_hz <= 0.0 else "%.0f Hz" % display_refresh_hz
	var project_fps_cap := float(ProjectSettings.get_setting("run/max_fps", 0))
	var refresh_cap_hit := display_refresh_hz > 0.0 and average >= display_refresh_hz * 0.98
	var project_cap_hit := project_fps_cap > 0.0 and average >= project_fps_cap * 0.98
	var cap_text := "n/b" if project_fps_cap <= 0.0 else "%.0f FPS" % project_fps_cap
	var capped_text := " · limiet waarschijnlijk" if refresh_cap_hit or project_cap_hit else ""
	var values := last_summary
	var process_text := "n/b" # Godot has no portable actual process-RSS monitor.
	var godot_text := "n/b" if current_godot_mb <= 0.0 else "%.1f MB (piek %.1f)" % [current_godot_mb, maxf(peak_godot_mb, current_godot_mb)]
	var gpu_text := "n/b" if current_renderer_mb <= 0.0 else "%.1f MB (piek %.1f)" % [current_renderer_mb, maxf(peak_renderer_mb, current_renderer_mb)]
	metrics_label.text = "%s\nNu %.1f ms / %.0f FPS · gem %.1f FPS · min/max %.0f/%.0f\n1%% low %.1f FPS · p99 %.2f ms · scherm %s · spelcap %s%s\nGodot allocatie %s · renderergeheugen %s · proces-RSS %s\nDrawcalls %s (piek %s) · renderprimitieven %s (piek %s)\n%0.1f / 30 s gemeten" % [
		state_text, current_frame_ms, current_fps, float(values.get("average_fps", 0.0)),
		float(values.get("minimum_fps", 0.0)), float(values.get("maximum_fps", 0.0)),
		float(values.get("one_percent_low_fps", 0.0)), float(values.get("p99_frame_time_ms", 0.0)), refresh_text, cap_text, capped_text,
		godot_text, gpu_text, process_text,
		"n/b" if current_draw_calls < 0 else str(current_draw_calls), "n/b" if peak_draw_calls < 0 else str(peak_draw_calls),
		"n/b" if current_primitives < 0 else str(current_primitives), "n/b" if peak_primitives < 0 else str(peak_primitives), measured_elapsed]


func _start_measurement() -> void:
	measurement_state = "warmup"
	warmup_elapsed = 0.0
	measured_elapsed = 0.0
	frame_times_ms.clear()
	last_summary.clear()
	_reset_peak_monitors()
	status_label_set("Opwarming gestart · houd camera en scenario gelijk")
	_update_hud()


func _reset_metrics() -> void:
	measurement_state = "idle"
	warmup_elapsed = 0.0
	measured_elapsed = 0.0
	frame_times_ms.clear()
	last_summary.clear()
	_reset_peak_monitors()
	status_label_set("Meting gereset · 5 s opwarming + 30 s meting")
	_update_hud()


func _save_metrics() -> void:
	if measurement_state != "complete" or last_summary.is_empty():
		status_label_set("Nog geen volledige meting · start eerst 30 s")
		return
	var refresh_match := display_refresh_hz > 0.0 and float(last_summary.average_fps) >= display_refresh_hz * 0.98
	var project_fps_cap := float(ProjectSettings.get_setting("run/max_fps", 0))
	var project_cap_match := project_fps_cap > 0.0 and float(last_summary.average_fps) >= project_fps_cap * 0.98
	var report := {
		"schema": 2,
		"asset": "Bloedjungle_Bunker_HQ_Game",
		"scenario": SCENARIOS[scenario_index],
		"camera_profile": CAMERA_PROFILES[camera_profile_index],
		"camera_fov_degrees": camera.fov,
		"camera_elevation_degrees": rad_to_deg(pitch),
		"camera_distance_m": camera_distance,
		"lighting_profile": LIGHTING_PROFILES[lighting_index],
		"viewport": "%dx%d" % [get_viewport().size.x, get_viewport().size.y],
		"renderer": ProjectSettings.get_setting("rendering/renderer/rendering_method", "unknown"),
		"display_adapter": RenderingServer.get_video_adapter_name(),
		"os": OS.get_name(),
		"reported_refresh_hz": display_refresh_hz if display_refresh_hz > 0.0 else null,
		"duration_seconds": measured_elapsed,
		"warmup_seconds": WARMUP_SECONDS,
		"fps": last_summary,
		"godot_static_memory_mb": current_godot_mb if current_godot_mb > 0.0 else null,
		"godot_static_memory_peak_mb": peak_godot_mb if peak_godot_mb > 0.0 else null,
		"renderer_video_memory_estimate_mb": current_renderer_mb if current_renderer_mb > 0.0 else null,
		"renderer_video_memory_peak_estimate_mb": peak_renderer_mb if peak_renderer_mb > 0.0 else null,
		"process_rss_mb": null,
		"draw_calls_current": current_draw_calls if current_draw_calls > 0 else null,
		"draw_calls_peak": peak_draw_calls if peak_draw_calls > 0 else null,
		"render_primitives_current": current_primitives if current_primitives > 0 else null,
		"render_primitives_peak": peak_primitives if peak_primitives > 0 else null,
		"refresh_ceiling_likely": refresh_match,
		"project_fps_cap_likely": project_cap_match,
		"frame_times_ms": frame_times_ms,
		"project_max_fps": project_fps_cap,
		"measurement_notes": {
			"fps": "Per-frame process delta; average FPS is frames divided by elapsed sampled time.",
			"one_percent_low": "Arithmetic mean FPS of the slowest ceil(1% of frames), ranked by frame time.",
			"p99_frame_time": "Nearest-rank 99th percentile of per-frame delta in milliseconds.",
			"godot_static_memory": "Godot-reported allocation, not total process RSS.",
			"renderer_video_memory": "Godot renderer estimate; may be unavailable and is not a measured physical VRAM allocation.",
			"process_rss": "Unavailable through the portable Godot API; null is intentional.",
			"refresh_ceiling": "Average within 2% of reported display refresh suggests a refresh/vsync ceiling; it does not measure uncapped GPU throughput.",
			"project_fps_cap": "Average within 2% of project run/max_fps suggests the application cap is active."
		}
	}
	var file := FileAccess.open("user://bunker_asset_test_v2_latest.json", FileAccess.WRITE)
	if file == null:
		status_label_set("Meting niet opgeslagen · user:// kon niet worden geopend")
		return
	file.store_string(JSON.stringify(report, "\t"))
	status_label_set("Meting opgeslagen · user://bunker_asset_test_v2_latest.json")


func _update_model_label() -> void:
	if bunker == null or model_label == null:
		return
	var audit := _audit_model(bunker)
	model_label.text = "%s · %d bunker(s) · %.1f × %.1f × %.1f m · %d tris/bunker · %d PBR-materialen · kaarten %d · PBR-surfaces %d/%d" % [
		SCENARIOS[scenario_index], bunker_instances.size(), audit.size.x, audit.size.y, audit.size.z,
		audit.triangles, audit.materials, audit.textures, audit.textured_surfaces, audit.surfaces]


func _audit_model(model: Node3D) -> Dictionary:
	var bounds := AABB()
	var has_bounds := false
	var mesh_count := 0
	var triangles := 0
	var surfaces := 0
	var textured_surfaces := 0
	var materials := {}
	var textures := {}
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		mesh_count += 1
		var mesh_bounds: AABB = mi.get_aabb() * (model.global_transform.affine_inverse() * mi.global_transform)
		bounds = mesh_bounds if not has_bounds else bounds.merge(mesh_bounds)
		has_bounds = true
		triangles += mi.mesh.get_faces().size() / 3
		for surface_index in mi.mesh.get_surface_count():
			surfaces += 1
			var material := mi.get_active_material(surface_index)
			if material == null:
				continue
			materials[material.get_instance_id()] = true
			if material is StandardMaterial3D:
				var standard := material as StandardMaterial3D
				if standard.albedo_texture and standard.normal_texture and standard.roughness_texture and standard.metallic_texture and standard.ao_texture and standard.emission_texture:
					textured_surfaces += 1
				for texture in [standard.albedo_texture, standard.normal_texture, standard.roughness_texture, standard.metallic_texture, standard.ao_texture, standard.emission_texture]:
					if texture != null:
						textures[texture.get_instance_id()] = true
	return {"size": bounds.size if has_bounds else Vector3.ZERO, "triangles": triangles, "meshes": mesh_count,
		"surfaces": surfaces, "textured_surfaces": textured_surfaces, "materials": materials.size(), "textures": textures.size()}


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if hud_expanded and _point_over_hud(touch.position):
			return
		if touch.pressed:
			touch_positions[touch.index] = touch.position
		else:
			touch_positions.erase(touch.index)
			if touch_positions.size() < 2:
				previous_pinch = 0.0
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if hud_expanded and _point_over_hud(drag.position):
			return
		touch_positions[drag.index] = drag.position
		if touch_positions.size() >= 2:
			var points: Array = touch_positions.values()
			var pinch: float = points[0].distance_to(points[1])
			if previous_pinch > 0.0:
				camera_distance = clampf(camera_distance * previous_pinch / maxf(pinch, 1.0), 7.0, 60.0)
				_set_manual_camera()
				_update_camera()
			previous_pinch = pinch
		else:
			yaw -= drag.relative.x * 0.006
			pitch = clampf(pitch + drag.relative.y * 0.0035, deg_to_rad(8.0), deg_to_rad(78.0))
			_set_manual_camera()
			_update_camera()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		drag_active = event.pressed
	elif event is InputEventMouseMotion and drag_active:
		var motion := event as InputEventMouseMotion
		yaw -= motion.relative.x * 0.006
		pitch = clampf(pitch + motion.relative.y * 0.0035, deg_to_rad(8.0), deg_to_rad(78.0))
		_set_manual_camera()
		_update_camera()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		camera_distance = maxf(7.0, camera_distance - 1.0)
		_set_manual_camera()
		_update_camera()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		camera_distance = minf(60.0, camera_distance + 1.0)
		_set_manual_camera()
		_update_camera()


func _point_over_hud(point: Vector2) -> bool:
	if not is_instance_valid(hud_root):
		return false
	var visible_rect := Rect2(hud_root.global_position, expanded_panel.size if hud_expanded else collapsed_bar.size)
	return visible_rect.has_point(point)


func _set_manual_camera() -> void:
	camera_profile_index = CAMERA_PROFILES.size() - 1
	if is_instance_valid(camera_option):
		camera_option.select(camera_profile_index)


func status_label_set(value: String) -> void:
	if status_label != null:
		status_label.text = value
