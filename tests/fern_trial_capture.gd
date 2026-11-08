extends Node
## One bounded, real main-scene camera comparison for the fern field trial.
## BJ_FERN_TRIAL_OUT=<dir> godot --path . res://tests/fern_trial_capture.tscn --resolution 1280x720

const AREA_Z := -57.0
const AREA_X_RANGE := Vector2(-70.0, 70.0)
const AREA_Z_RANGE := Vector2(-82.0, -38.0)
const UNDERSTORY_CELL_M := 24.0

var game_main: Node3D
var out_dir := ""

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	out_dir = OS.get_environment("BJ_FERN_TRIAL_OUT")
	if out_dir.is_empty() or DirAccess.make_dir_recursive_absolute(out_dir) != OK:
		push_error("BJ_FERN_TRIAL_OUT must be a writable capture directory")
		get_tree().quit(2)
		return
	var settings: GDScript = load("res://scripts/game_settings.gd")
	settings.values = settings.DEFAULTS.duplicate()
	settings.values.merge({"quality":"high", "time":"day", "weather":"clear", "wind":"off", "t_sun":"on", "t_jungle":"on", "t_post":"on", "hz":"120"}, true)
	settings._loaded = true
	var progress: GDScript = load("res://scripts/progress.gd")
	progress.autostart = false
	var governor: GDScript = load("res://scripts/perf_governor.gd")
	governor.paused = true
	game_main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(game_main)
	await game_main.begin()
	print("FERN TRIAL world built")
	game_main.set_process(false)
	game_main.get_node("Hud").hide()
	var player: Node3D = Game.player
	var camera: Camera3D = game_main.get_node("Camera")
	camera.set_process(false)
	camera.make_current()
	var level: Node = game_main.get_node("Level")
	var fern_cells := collect_bospad_fern_cells(level)
	var test_cell := select_test_cell(fern_cells)
	if test_cell.is_empty():
		push_error("No populated render-only fern cell is available along the bounded bospad route")
		get_tree().quit(1)
		return
	var center: Vector3 = test_cell.center
	var hidden := replace_fern_cell(level, int(test_cell.cell_x), int(test_cell.cell_z))
	if hidden < 2:
		push_error("The bounded bospad replacement cell must contain at least two existing render-only ferns; found %d" % hidden)
		get_tree().quit(1)
		return
	# Keep the exact main-scene camera node and its gameplay FOV/pitch; the close
	# field-test distance exists only in this harness so individual fronds resolve.
	var focus := center + Vector3(0.0, 0.25, 0.0)
	camera.fov = 45.0
	camera.global_position = focus + Vector3(0.0, 9.58, 7.22)
	camera.look_at(focus, Vector3.UP)
	var camera_attributes := camera.attributes as CameraAttributesPractical
	if camera_attributes != null:
		camera_attributes.dof_blur_far_enabled = false
	player.global_position = center + Vector3(0.0, 0.0, -2.8)
	player.set("face", 0.0)
	var old_mesh := JungleUnderstory.depth_mesh("arch_fern", 0)
	var trial_mesh := JungleUnderstory.fern_trial_mesh()
	if old_mesh == null or trial_mesh == null:
		push_error("The original and trial fern meshes must both load before capture")
		get_tree().quit(1)
		return
	var specimens := Node3D.new()
	specimens.name = "FernTrial_ReviewOnly"
	game_main.add_child(specimens)
	add_specimen(specimens, "Bestaande Fern 02", old_mesh, center + Vector3(-1.45, 0.012, 0.0))
	add_specimen(specimens, "Nieuwe veldproef · A+C", trial_mesh, center + Vector3(1.45, 0.012, 0.0))
	Foliage.update_visibility_focus(player.global_position, camera.global_position, 1.0, false)
	Foliage.update_pushers(player, get_tree(), false)
	add_comparison_overlay()
	get_tree().root.scaling_3d_scale = 1.0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	print("FERN TRIAL renderer=%s adapter=%s camera=%s center=%s replaced_ferns=%d" % [
		RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name(), str(camera.global_transform), str(center), hidden])
	for i in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_tree().root.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Godot returned an empty main-camera image")
		get_tree().quit(1)
		return
	var png_path := out_dir.path_join("comparison.png")
	var save_err := image.save_png(png_path)
	if save_err != OK:
		push_error("Could not save real Godot comparison capture: %s" % error_string(save_err))
		get_tree().quit(1)
		return
	var receipt := {
		"capture": "Real Godot render of scenes/main.tscn and its Camera node; comparison UI only adds labels and approved-b.jpg.",
		"renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"engine": Engine.get_version_info().string,
		"size": [image.get_width(), image.get_height()],
		"quality": settings.values.duplicate(),
		"camera": {"fov_degrees": camera.fov, "transform": str(camera.global_transform), "field_test_pitch_degrees": 53.0, "note": "same gameplay Camera node/FOV/pitch; moved closer for the single asset-review capture"},
		"test_area": {"label": "bospad · isolated render-only fern replacement", "center": [center.x, center.y, center.z], "replacement_cell_m": UNDERSTORY_CELL_M, "existing_fern_instances_temporarily_hidden": hidden},
		"samples": [
			{"label":"Bestaande Fern 02", "mesh":"jungle_depth_foliage.glb / HQ_arch_fern_V0_LOD0", "material":"depth_arch_fern"},
			{"label":"Nieuwe veldproef A+C", "mesh":"jungle_fern_trial.glb / HQ_fern_trial_LOD0", "material":"depth_arch_fern"}
		],
		"reference": "docs/visual_upgrade_b_1_0/reference/approved-b.jpg",
		"screenshot_file": "comparison.png",
		"gameplay_or_live_scatter_changed": false
	}
	var receipt_file := FileAccess.open(out_dir.path_join("comparison.json"), FileAccess.WRITE)
	if receipt_file == null:
		push_error("Could not write capture receipt")
		get_tree().quit(1)
		return
	receipt_file.store_string(JSON.stringify(receipt, "\t") + "\n")
	receipt_file.flush()
	if receipt_file.get_error() != OK:
		push_error("Capture receipt write failed")
		get_tree().quit(1)
		return
	print("FERN TRIAL CAPTURE PASS %s" % png_path)
	get_tree().quit(0)

func collect_bospad_fern_cells(level: Node) -> Dictionary:
	var cells: Dictionary = {}
	var z_min_cell := floori(AREA_Z_RANGE.x / UNDERSTORY_CELL_M)
	var z_max_cell := floori(AREA_Z_RANGE.y / UNDERSTORY_CELL_M)
	for node: MultiMeshInstance3D in level.get_tree().get_nodes_in_group("jungle_understory"):
		if not node.name.begins_with("Understory_arch_fern_0_"):
			continue
		var slices := node.name.get_slice_count("_")
		if slices < 5:
			continue
		var cell_x := node.name.get_slice("_", slices - 2).to_int()
		var cell_z := node.name.get_slice("_", slices - 1).to_int()
		if cell_z < z_min_cell or cell_z > z_max_cell:
			continue
		var key := "%d:%d" % [cell_x, cell_z]
		cells[key] = int(cells.get(key, 0)) + int(node.get_meta("full", 0))
	return cells

func select_test_cell(cells: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_score := -INF
	var z_min_cell := floori(AREA_Z_RANGE.x / UNDERSTORY_CELL_M)
	var z_max_cell := floori(AREA_Z_RANGE.y / UNDERSTORY_CELL_M)
	for cell_z in range(z_min_cell, z_max_cell + 1):
		var z := clampf(AREA_Z, cell_z * UNDERSTORY_CELL_M + 2.0, (cell_z + 1) * UNDERSTORY_CELL_M - 2.0)
		for side in [-1.0, 1.0]:
			var x: float = Data.path_x(z) + side * 6.4
			if x < AREA_X_RANGE.x or x > AREA_X_RANGE.y:
				continue
			var cell_x := floori(x / UNDERSTORY_CELL_M)
			var key := "%d:%d" % [cell_x, cell_z]
			var population := int(cells.get(key, 0))
			if population < 2:
				continue
			var score := float(population) * 10.0 - absf(z - AREA_Z)
			if score > best_score:
				best_score = score
				best = {"cell_x": cell_x, "cell_z": cell_z, "center": Vector3(x, 0.012, z), "existing_fern_instances": population}
	return best

func replace_fern_cell(level: Node, cell_x: int, cell_z: int) -> int:
	var hidden := 0
	for node: MultiMeshInstance3D in level.get_tree().get_nodes_in_group("jungle_understory"):
		if not node.name.begins_with("Understory_arch_fern_0_"):
			continue
		var slices := node.name.get_slice_count("_")
		if slices < 5:
			continue
		var node_cell_x := node.name.get_slice("_", slices - 2).to_int()
		var node_cell_z := node.name.get_slice("_", slices - 1).to_int()
		if node_cell_x == cell_x and node_cell_z == cell_z:
			node.visible = false
			hidden += int(node.get_meta("full", 0))
	return hidden

func add_specimen(parent: Node3D, label: String, mesh: Mesh, position_: Vector3) -> void:
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.material_override = Foliage.material("depth_arch_fern")
	instance.position = position_
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	instance.add_to_group("fern_trial_samples")
	parent.add_child(instance)

func add_comparison_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.name = "FernTrial_ComparisonLabels"
	layer.layer = 100
	game_main.add_child(layer)
	var root_control := Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root_control)
	var title := Label.new()
	title.text = "BOSPAD · FERN 02 VELDPROEF"
	title.position = Vector2(30, 20)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.95, 0.84, 0.56))
	title.add_theme_color_override("font_shadow_color", Color(0.02, 0.04, 0.025, 0.95))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	root_control.add_child(title)
	_add_tag(root_control, "BESTAANDE · FERN 02", Vector2(350, 555), Vector2(230, 42))
	_add_tag(root_control, "NIEUW · CLUSTER A + C", Vector2(585, 555), Vector2(240, 42))
	var panel := PanelContainer.new()
	panel.name = "ApprovedReferenceB"
	panel.position = Vector2(884, 54)
	panel.size = Vector2(366, 236)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.025, 0.04, 0.03, 0.94)
	box.border_color = Color(0.77, 0.58, 0.24, 1.0)
	box.set_border_width_all(2)
	box.set_corner_radius_all(10)
	box.content_margin_left = 7
	box.content_margin_right = 7
	box.content_margin_top = 7
	box.content_margin_bottom = 7
	panel.add_theme_stylebox_override("panel", box)
	panel.add_child(TextureRect.new())
	var preview := panel.get_child(0) as TextureRect
	preview.texture = load("res://docs/visual_upgrade_b_1_0/reference/approved-b.jpg") as Texture2D
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_control.add_child(panel)
	_add_tag(root_control, "GOEDGEKEURDE REFERENTIE B", Vector2(884, 298), Vector2(366, 38))

func _add_tag(parent: Control, text_: String, position_: Vector2, size_: Vector2) -> void:
	var panel := PanelContainer.new()
	panel.position = position_
	panel.size = size_
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.025, 0.035, 0.027, 0.91)
	box.border_color = Color(0.66, 0.50, 0.22, 0.9)
	box.set_border_width_all(1)
	box.set_corner_radius_all(7)
	box.content_margin_left = 9
	box.content_margin_right = 9
	box.content_margin_top = 5
	box.content_margin_bottom = 5
	panel.add_theme_stylebox_override("panel", box)
	var label := Label.new()
	label.text = text_
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.96, 0.88, 0.67))
	panel.add_child(label)
	parent.add_child(panel)
