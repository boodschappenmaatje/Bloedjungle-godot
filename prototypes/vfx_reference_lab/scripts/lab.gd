extends Node3D
## Opt-in visual-only A/B viewer. Runs inside the real Bloedjungle project context
## so it can call the existing Fx/WapenFx/Bullet systems without copying them.
## It never creates a Bullet, plays audio, changes damage, or saves settings.

const M1911_SCENE: PackedScene = preload("res://assets/meshy_m1911.glb")
const MATERIALS := [
	{"name": "WOOD", "id": "wood", "color": Color("6d4b31"), "rough": 0.84, "metal": 0.0},
	{"name": "CONCRETE", "id": "concrete", "color": Color("858780"), "rough": 0.96, "metal": 0.0},
	{"name": "METAL", "id": "metal", "color": Color("3f4943"), "rough": 0.48, "metal": 0.72},
]
const LANE_X := [-2.8, 2.8]
const LANE_NAMES := ["CLASSIC · EXISTING", "ENHANCED · EXISTING WAPENFX"]
const TARGET_Z := -0.9
const MUZZLE_LOCAL := Vector3(0.105, 0.035, 0.0)
const MAX_TRACERS := 2
const HIGH_QUALITY := "high"
const MOBILE_QUALITY := "low"

var selected_material := 0
var preset := "HIGH"
var comparison_mode := "BOTH"
var auto_fire := true
var auto_timer := 0.18
var shot_cooldown := 0.0
var shot_count := 0
var stats_label: Label
var selection_label: Label
var material_picker: OptionButton
var view_picker: OptionButton
var preset_picker: OptionButton
var auto_button: Button
var old_setting_values: Dictionary = {}
var environment: Environment
var key_lights: Array[OmniLight3D] = []
var guns: Array[Node3D] = []
var gun_animators: Array[AnimationPlayer] = []
var muzzle_points: Array[Vector3] = []
var targets: Array[Array] = [[], []]
var lane_headings: Array[Label3D] = []
var tracers: Array[MeshInstance3D] = []
var tracer_tweens: Array[Tween] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 1911
	if OS.get_cmdline_user_args().has("--vfx-mobile"):
		preset = "MOBILE"
	_snapshot_settings()
	_build_world()
	_build_targets()
	_build_guns()
	_build_tracers()
	_build_hud()
	_apply_preset()
	_update_hud()


func _exit_tree() -> void:
	_restore_settings()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1: _select_material(0)
		KEY_2: _select_material(1)
		KEY_3: _select_material(2)
		KEY_SPACE: _fire()
		KEY_A: _toggle_auto()
		KEY_B: _toggle_comparison()
		KEY_H: _set_preset("HIGH")
		KEY_M: _set_preset("MOBILE")
	_update_hud()


func _process(delta: float) -> void:
	shot_cooldown = maxf(0.0, shot_cooldown - delta)
	if auto_fire:
		auto_timer -= delta
		if auto_timer <= 0.0:
			shot_cooldown = 0.0
			_fire()
			selected_material = (selected_material + 1) % MATERIALS.size()
			_update_hud()
			auto_timer = 0.72
	_update_stats()


func _snapshot_settings() -> void:
	# GameSettings.values is changed only in memory while this preview is open.
	# Never call set_value(): that writes user://instellingen.cfg.
	for key in ["quality", "wapenfx"]:
		GameSettings.get_value(key)
	old_setting_values = GameSettings.values.duplicate(true)


func _restore_settings() -> void:
	if not old_setting_values.is_empty():
		GameSettings.values = old_setting_values.duplicate(true)


func _build_world() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("111817")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("94a29b")
	environment.ambient_light_energy = 0.34
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.58
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)

	# Gameplay reference: match scenes/main.tscn's 40-degree, elevated oblique camera.
	var camera := Camera3D.new()
	camera.name = "GameplayReferenceCamera"
	camera.fov = 40.0
	camera.near = 0.05
	camera.far = 90.0
	camera.position = Vector3(0.0, 7.45, 3.9)
	add_child(camera)
	camera.look_at(Vector3(0, 0.75, 0.0), Vector3.UP)
	camera.current = true

	var sun := DirectionalLight3D.new()
	sun.name = "LabKey"
	sun.rotation_degrees = Vector3(-48.0, -24.0, 0.0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	add_child(sun)
	for x in LANE_X:
		var light := OmniLight3D.new()
		light.position = Vector3(x, 4.0, -0.7)
		light.light_color = Color("ffc882")
		light.light_energy = 1.05
		light.omni_range = 8.0
		light.shadow_enabled = false
		add_child(light)
		key_lights.append(light)

	_box(Vector3(0, -0.18, -0.1), Vector3(15.0, 0.35, 13.0), Color("1c2521"), 0.92)
	for x in LANE_X:
		_box(Vector3(x, 0.02, 0.0), Vector3(3.6, 0.08, 5.8), Color("2d3932"), 0.86)
		_box(Vector3(x, 0.075, 0.7), Vector3(2.1, 0.08, 1.15), Color("3c4139"), 0.68)


func _build_targets() -> void:
	for lane in 2:
		for material_index in MATERIALS.size():
			var x: float = float(LANE_X[lane]) + (material_index - 1) * 1.12
			var material: Dictionary = MATERIALS[material_index]
			var board := Node3D.new()
			board.name = "%s_%s" % ["Classic" if lane == 0 else "Enhanced", material.id]
			board.position = Vector3(x, 0.95, TARGET_Z)
			add_child(board)
			_build_material_target(board, material)
			targets[lane].append(board)
			var label := Label3D.new()
			label.text = material.name
			label.position = Vector3(0.0, 1.17, 0.0)
			label.font_size = 28
			label.pixel_size = 0.006
			label.modulate = Color("e4e3d4")
			label.outline_size = 6
			label.outline_modulate = Color("131716")
			board.add_child(label)

	for lane in 2:
		var heading := Label3D.new()
		heading.text = LANE_NAMES[lane]
		heading.position = Vector3(LANE_X[lane], 2.65, -1.45)
		heading.font_size = 34
		heading.pixel_size = 0.005
		heading.modulate = Color("ffd58a") if lane == 1 else Color("c3c8c2")
		heading.outline_size = 7
		heading.outline_modulate = Color("131716")
		add_child(heading)
		lane_headings.append(heading)


func _build_material_target(parent: Node3D, material: Dictionary) -> void:
	var base := _mat(material.color, material.rough, material.metal)
	_box_child(parent, Vector3.ZERO, Vector3(0.9, 1.3, 0.24), material.color, material.rough, material.metal)
	# A beveled frame and backing make the target read as a physical surface from the game camera.
	var frame_mat := _mat(Color("292d29"), 0.62, 0.34)
	for x_side in [-0.5, 0.5]:
		_box_child(parent, Vector3(x_side, 0.0, -0.15), Vector3(0.08, 1.44, 0.12), Color("292d29"), 0.62, 0.34, frame_mat)
	for y_side in [-0.7, 0.7]:
		_box_child(parent, Vector3(0.0, y_side, -0.15), Vector3(1.05, 0.08, 0.12), Color("292d29"), 0.62, 0.34, frame_mat)
	if material.id == "wood":
		for row in 3:
			var seam_y := -0.43 + row * 0.43
			_box_child(parent, Vector3(0.0, seam_y, 0.125), Vector3(0.87, 0.016, 0.014), Color("30231b"), 0.96, 0.0)
			_box_child(parent, Vector3(0.0, seam_y + 0.08, 0.127), Vector3(_rng.randf_range(0.4, 0.76), 0.008, 0.006), Color("8b6745"), 0.92, 0.0)
			for bolt_x in [-0.37, 0.37]:
				_cylinder_child(parent, Vector3(bolt_x, seam_y, 0.145), 0.028, 0.018, Color("514c43"), 0.44, 0.7)
	elif material.id == "concrete":
		var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		for py in image.get_height():
			for px in image.get_width():
				var grain := _rng.randf_range(0.47, 0.62)
				image.set_pixel(px, py, Color(grain, grain, grain, 1.0))
		var tex := ImageTexture.create_from_image(image)
		var rough := StandardMaterial3D.new()
		rough.albedo_color = Color("d0d0c8")
		rough.albedo_texture = tex
		rough.roughness = 0.94
		var face := _find_mesh(parent)
		if face:
			face.material_override = rough
	elif material.id == "metal":
		for bolt_x in [-0.37, 0.37]:
			for bolt_y in [-0.57, 0.57]:
				_cylinder_child(parent, Vector3(bolt_x, bolt_y, 0.145), 0.038, 0.026, Color("a2a28e"), 0.82, 0.28)
			_box_child(parent, Vector3(0.0, 0.0, 0.145), Vector3(0.9, 0.022, 0.012), Color("697365"), 0.6, 0.55)


func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _find_mesh(child)
		if found:
			return found
	return null


func _build_guns() -> void:
	for lane in 2:
		var holder := M1911_SCENE.instantiate() as Node3D
		holder.name = "M1911A1_Classic" if lane == 0 else "M1911A1_Enhanced"
		holder.position = Vector3(LANE_X[lane], 0.36, 0.7)
		holder.rotation.y = PI * 0.5
		holder.scale = Vector3.ONE * 3.1
		add_child(holder)
		guns.append(holder)
		muzzle_points.append(holder.to_global(MUZZLE_LOCAL))
		var animator := holder.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if animator:
			gun_animators.append(animator)
		else:
			gun_animators.append(null)


func _build_tracers() -> void:
	for i in MAX_TRACERS:
		var trail := MeshInstance3D.new()
		trail.name = "PreviewOnlyTracer_%d" % i
		trail.visible = false
		trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(trail)
		tracers.append(trail)
		tracer_tweens.append(null)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var root_control := Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root_control)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.offset_left = 12.0
	panel.offset_top = 10.0
	panel.offset_right = -12.0
	panel.offset_bottom = 102.0
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.055, 0.075, 0.07, 0.94)
	panel_style.border_color = Color("617163")
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(5)
	panel.add_theme_stylebox_override("panel", panel_style)
	root_control.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	panel.add_child(column)
	var summary := HBoxContainer.new()
	summary.add_theme_constant_override("separation", 18)
	column.add_child(summary)
	var title := Label.new()
	title.text = "BLOEDJUNGLE · COLT M1911A1 VFX REFERENCE"
	title.add_theme_font_size_override("font_size", 16)
	summary.add_child(title)
	selection_label = Label.new()
	summary.add_child(selection_label)
	stats_label = Label.new()
	summary.add_child(stats_label)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 7)
	column.add_child(controls)
	var fire_button := Button.new()
	fire_button.text = "FIRE BOTH · SPACE"
	fire_button.custom_minimum_size = Vector2(150, 38)
	fire_button.pressed.connect(_fire)
	controls.add_child(fire_button)
	material_picker = OptionButton.new()
	material_picker.custom_minimum_size = Vector2(138, 38)
	for item in MATERIALS:
		material_picker.add_item(item.name)
	material_picker.item_selected.connect(_select_material)
	controls.add_child(material_picker)
	view_picker = OptionButton.new()
	view_picker.custom_minimum_size = Vector2(155, 38)
	for item in ["BOTH LANES", "CLASSIC ONLY", "ENHANCED ONLY"]:
		view_picker.add_item(item)
	view_picker.item_selected.connect(_select_view)
	controls.add_child(view_picker)
	preset_picker = OptionButton.new()
	preset_picker.custom_minimum_size = Vector2(135, 38)
	preset_picker.add_item("HIGH PRESET")
	preset_picker.add_item("MOBILE PRESET")
	preset_picker.item_selected.connect(func(index: int): _set_preset("HIGH" if index == 0 else "MOBILE"))
	controls.add_child(preset_picker)
	preset_picker.select(0 if preset == "HIGH" else 1)
	auto_button = Button.new()
	auto_button.text = "AUTO: ON · A"
	auto_button.custom_minimum_size = Vector2(135, 38)
	auto_button.pressed.connect(_toggle_auto)
	controls.add_child(auto_button)


func _select_view(index: int) -> void:
	comparison_mode = ["BOTH", "CLASSIC", "ENHANCED"][clampi(index, 0, 2)]
	_update_lane_visibility()
	_update_hud()


func _set_preset(value: String) -> void:
	preset = value
	_apply_preset()
	if preset_picker:
		preset_picker.select(0 if preset == "HIGH" else 1)
	_update_hud()


func _apply_preset() -> void:
	# Preview-only presets. The game config and persisted settings are untouched.
	GameSettings.values["quality"] = HIGH_QUALITY if preset == "HIGH" else MOBILE_QUALITY
	if environment:
		environment.glow_enabled = preset == "HIGH"
		environment.glow_intensity = 0.58 if preset == "HIGH" else 0.18
	for light in key_lights:
		light.shadow_enabled = preset == "HIGH"
	if preset_picker:
		preset_picker.select(0 if preset == "HIGH" else 1)


func _select_material(index: int) -> void:
	selected_material = clampi(index, 0, MATERIALS.size() - 1)
	if material_picker:
		material_picker.select(selected_material)
	_update_hud()


func _toggle_comparison() -> void:
	match comparison_mode:
		"BOTH": comparison_mode = "CLASSIC"
		"CLASSIC": comparison_mode = "ENHANCED"
		_: comparison_mode = "BOTH"
	_update_lane_visibility()
	if view_picker:
		view_picker.select({"BOTH": 0, "CLASSIC": 1, "ENHANCED": 2}[comparison_mode])
	_update_hud()


func _toggle_auto() -> void:
	auto_fire = not auto_fire
	_update_hud()


func _update_lane_visibility() -> void:
	for lane in 2:
		var enabled := comparison_mode == "BOTH" or (comparison_mode == "CLASSIC" and lane == 0) or (comparison_mode == "ENHANCED" and lane == 1)
		for item in targets[lane]:
			item.visible = enabled
		guns[lane].visible = enabled
		lane_headings[lane].visible = enabled


func _fire() -> void:
	if shot_cooldown > 0.0:
		return
	shot_cooldown = 0.14
	shot_count += 1
	var material: Dictionary = MATERIALS[selected_material]
	for lane in 2:
		var enabled := comparison_mode == "BOTH" or (comparison_mode == "CLASSIC" and lane == 0) or (comparison_mode == "ENHANCED" and lane == 1)
		if not enabled:
			continue
		_fire_lane(lane, material)
	_update_hud()


func _fire_lane(lane: int, material: Dictionary) -> void:
	var is_enhanced := lane == 1
	var previous_wapenfx := GameSettings.get_value("wapenfx")
	GameSettings.values["wapenfx"] = "nieuw" if is_enhanced else "klassiek"
	var muzzle: Vector3 = muzzle_points[lane]
	if is_enhanced:
		WapenFx.muzzle(self, muzzle, "m1911", PI)
	else:
		var visual: Dictionary = Data.WEAPON_VISUALS["m1911"]
		Fx._show_muzzle_flash(self, muzzle, Fx._muzzle_mesh("m1911", _rng.randi_range(0, 2)), PI, visual.flash_life, visual.flash_width * 0.28, "m1911", visual.flash_particles, visual.flash_color, visual.flash_energy, visual.flash_range)
	if gun_animators[lane]:
		_play_shot_animation(lane)
	var target: Vector3 = (targets[lane][selected_material] as Node3D).global_position + Vector3(0.0, 0.0, 0.19)
	_spawn_tracer(lane, muzzle, target, is_enhanced)
	# Immediate, visual-only impact; no Bullet, collision, damage or audio path is used.
	var hit_normal := Vector3.BACK
	if is_enhanced:
		Fx.impact(self, target, hit_normal, material.id, true)
		WapenFx.surface_hit(self, target, hit_normal, material.id, "m1911")
	else:
		Fx.impact(self, target, hit_normal, material.id, false)
	GameSettings.values["wapenfx"] = previous_wapenfx


func _play_shot_animation(lane: int) -> void:
	var animator: AnimationPlayer = gun_animators[lane]
	if animator == null:
		return
	var anims := animator.get_animation_list()
	for preferred in ["M1911_Schot", "M1911_schot", "M1911_shoot", "M1911_fire", "M1911_Shoot"]:
		if animator.has_animation(preferred):
			animator.play(preferred)
			return
	for clip in anims:
		if "schot" in String(clip).to_lower() or "shoot" in String(clip).to_lower() or "fire" in String(clip).to_lower():
			animator.play(clip)
			return


func _spawn_tracer(lane: int, from: Vector3, to: Vector3, enhanced: bool) -> void:
	var index := lane
	var trail := tracers[index]
	if tracer_tweens[index] and tracer_tweens[index].is_valid():
		tracer_tweens[index].kill()
	var previous_wapenfx := GameSettings.get_value("wapenfx")
	GameSettings.values["wapenfx"] = "nieuw" if enhanced else "klassiek"
	if enhanced:
		trail.mesh = WapenFx.tracer_mesh("m1911")
	else:
		var visual: Dictionary = Data.WEAPON_VISUALS["m1911"]
		trail.mesh = Bullet._glow(visual.trail_head, visual.trail_tail, visual.trail_length, visual.trail_width, 0.16, 0.028)
	GameSettings.values["wapenfx"] = previous_wapenfx
	trail.visible = true
	trail.global_position = from
	# WapenFx/Bullet tracer meshes put the hot head at local origin and their tail on -Z.
	# Godot look_at aims -Z at the target, so aim its -Z axis away from the shot.
	trail.look_at(from - (to - from), Vector3.UP)
	var tw := create_tween()
	tracer_tweens[index] = tw
	tw.tween_property(trail, "global_position", to, 0.14).set_trans(Tween.TRANS_LINEAR)
	tw.tween_callback(func(): trail.visible = false)


func _update_hud() -> void:
	if selection_label:
		selection_label.text = "NEXT: %s   |   preset: %s   |   view: %s   |   auto: %s" % [MATERIALS[selected_material].name, preset, comparison_mode, "ON" if auto_fire else "OFF"]
	if auto_button:
		auto_button.text = "AUTO: ON · A" if auto_fire else "AUTO: OFF · A"


func _update_stats() -> void:
	if not stats_label:
		return
	var counts := Fx.combat_counts()
	stats_label.text = "Shots %d   bursts %d/%d   flashes %d/%d   marks %d/%d" % [shot_count, counts.burst_nodes, Fx.MAX_BURST_NODES, counts.muzzle_flashes, Fx.MAX_MUZZLE_FLASHES, Fx._decals.size(), Fx.MAX_DECALS]


func _box(pos: Vector3, size: Vector3, tint: Color, roughness := 0.8) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var item := MeshInstance3D.new()
	item.mesh = mesh
	item.material_override = _mat(tint, roughness)
	item.position = pos
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(item)
	return item


func _box_child(parent: Node3D, pos: Vector3, size: Vector3, tint: Color, roughness: float, metallic: float, shared: StandardMaterial3D = null) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var item := MeshInstance3D.new()
	item.mesh = mesh
	item.material_override = shared if shared else _mat(tint, roughness, metallic)
	item.position = pos
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(item)
	return item


func _cylinder_child(parent: Node3D, pos: Vector3, radius: float, height: float, tint: Color, metallic: float, roughness: float) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	var item := MeshInstance3D.new()
	item.mesh = mesh
	item.material_override = _mat(tint, roughness, metallic)
	item.position = pos
	item.rotation.x = PI * 0.5
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(item)


func _mat(tint: Color, roughness: float, metallic := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = roughness
	material.metallic = metallic
	return material
