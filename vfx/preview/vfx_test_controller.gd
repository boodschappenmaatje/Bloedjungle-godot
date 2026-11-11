extends Node3D
## Bloedjungle VFX Studio 1.0 — isolated visual benchmark.
## This scene never calls Bullet.fire(), modifies GameSettings or changes the main scene.
## Existing Fx pooling and impact effects are deliberately reused.

const RATE := 9.5
const MUZZLE_HEIGHT := 1.4
const TARGET_Z := 9.0
const M2_PREVIEW_FX = preload("res://vfx/weapons/m2_preview_fx.gd")
const MATERIALS := ["dirt", "concrete", "metal", "wood", "vehicle"]
const PROFILES := ["Laag", "Hoog", "Ultra"]

var _world: Node3D
var _muzzle_nodes: Array[Node3D] = []
var _target_nodes: Array[Node3D] = []
var _camera: Camera3D
var _hud: Label
var _mode := "Gestopt"
var _profile := 1
var _material_index := 1
var _active_guns := 1
var _shots := 0
var _run_time := 0.0
var _accumulator := 0.0
var _stats_clock := 0.0
var _frame_times := PackedFloat32Array()
var _tracer_pool: Array[MeshInstance3D] = []
var _tracer_live := 0
var _tracer_created := 0
var _tracer_mesh: BoxMesh
var _tracer_material: StandardMaterial3D
var _status: Label


func _ready() -> void:
	name = "VFX Studio Preview — NO GAMEPLAY"
	_build_world()
	_build_ui()
	_start_mode("Gestopt")


func _build_world() -> void:
	_world = Node3D.new()
	_world.name = "IsolatedVFXWorld"
	add_child(_world)

	var env := WorldEnvironment.new()
	env.name = "VFXPreviewEnvironment"
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.105, 0.14, 0.14)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.59, 0.58)
	e.ambient_light_energy = 0.7
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-54, -35, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = false
	add_child(sun)

	_make_box("Grond — aarde", Vector3(0, -0.22, 3.5), Vector3(22, 0.4, 25), Color(0.28, 0.26, 0.19))
	_make_box("Betonnen muur", Vector3(0, 1.55, 11), Vector3(19, 3.1, 0.7), Color(0.37, 0.4, 0.39))
	for i in 5:
		var x := (float(i) - 2.0) * 3.5
		var col := Color(0.42, 0.29, 0.16)
		match i:
			0: col = Color(0.32, 0.25, 0.13)
			1: col = Color(0.42, 0.44, 0.42)
			2: col = Color(0.27, 0.33, 0.35)
			3: col = Color(0.43, 0.27, 0.16)
			4: col = Color(0.35, 0.4, 0.29)
		var target := _make_box("Doel — " + MATERIALS[i], Vector3(x, 1.0, TARGET_Z), Vector3(1.25, 2, 0.3), col)
		_target_nodes.append(target)

	# Purposefully modest test stands: no high-polygon or unlicensed weapon asset.
	for i in 12:
		var x := (float(i) - 5.5) * 1.55
		var receiver := _make_box("M2 proxy receiver", Vector3(x, 1.3, -4), Vector3(0.72, 0.35, 1.25), Color(0.19, 0.23, 0.21))
		var barrel := _make_box("M2 proxy barrel", Vector3(x, MUZZLE_HEIGHT, -2.85), Vector3(0.13, 0.13, 1.3), Color(0.24, 0.28, 0.25))
		receiver.visible = i == 0
		barrel.visible = i == 0
		var muzzle := Node3D.new()
		muzzle.name = "Muzzle"
		muzzle.position = Vector3(x, MUZZLE_HEIGHT, -2.15)
		_world.add_child(muzzle)
		_muzzle_nodes.append(muzzle)

	_camera = Camera3D.new()
	_camera.name = "PreviewCamera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 23.5
	_camera.position = Vector3(0, 23, 24)
	add_child(_camera)
	_camera.look_at(Vector3(0, 0, 3))
	_camera.current = true


func _make_box(label: String, center: Vector3, box_size: Vector3, tint: Color) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.name = label
	var geom := BoxMesh.new()
	geom.size = box_size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = 0.9
	geom.material = mat
	item.mesh = geom
	item.position = center
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(item)
	return item


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "PreviewControls"
	add_child(layer)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.offset_bottom = 138
	layer.add_child(panel)
	var outer := VBoxContainer.new()
	panel.add_child(outer)
	var title := Label.new()
	title.text = "BLOEDJUNGLE  |  VFX STUDIO 1.0  |  GEÏSOLEERDE TEST"
	title.add_theme_font_size_override("font_size", 19)
	outer.add_child(title)
	var actions := HBoxContainer.new()
	outer.add_child(actions)
	_add_button(actions, "1 schot", func(): _single_shot())
	_add_button(actions, "Burst", func(): _start_mode("Burst"))
	_add_button(actions, "Continu", func(): _start_mode("Continu"))
	_add_button(actions, "Stop", func(): _start_mode("Gestopt"))
	_add_button(actions, "1 MG", func(): _set_guns(1))
	_add_button(actions, "5 MG", func(): _set_guns(5))
	_add_button(actions, "12 MG", func(): _set_guns(12))
	var options := HBoxContainer.new()
	outer.add_child(options)
	_add_button(options, "Materiaal wisselen", func(): _cycle_material())
	_add_button(options, "Kwaliteit wisselen", func(): _cycle_profile())
	_status = Label.new()
	outer.add_child(_status)
	_hud = Label.new()
	_hud.add_theme_font_size_override("font_size", 13)
	outer.add_child(_hud)
	_refresh_hud()


func _add_button(parent: Control, title: String, action: Callable) -> void:
	var b := Button.new()
	b.text = title
	b.custom_minimum_size = Vector2(96, 42)
	parent.add_child(b)
	b.pressed.connect(action)


func _set_guns(count: int) -> void:
	_active_guns = count
	_refresh_hud()


func _cycle_material() -> void:
	_material_index = (_material_index + 1) % MATERIALS.size()
	_refresh_hud()


func _cycle_profile() -> void:
	_profile = (_profile + 1) % PROFILES.size()
	_refresh_hud()


func _start_mode(mode: String) -> void:
	_mode = mode
	_accumulator = 0.0
	_run_time = 0.0
	_refresh_hud()


func _single_shot() -> void:
	_mode = "Gestopt"
	_fire_salvo()
	_refresh_hud()


func _process(delta: float) -> void:
	if delta > 0.0:
		_frame_times.append(delta * 1000.0)
		if _frame_times.size() > 900:
			_frame_times.remove_at(0)
	if _mode != "Gestopt":
		_run_time += delta
		_accumulator += delta
		var period := 1.0 / RATE
		var safety := 0
		while _accumulator >= period and safety < 4:
			_accumulator -= period
			_fire_salvo()
			safety += 1
		if _mode == "Burst" and _run_time > 0.8:
			_start_mode("Gestopt")
	_stats_clock += delta
	if _stats_clock >= 0.3:
		_stats_clock = 0.0
		_refresh_hud()


func _fire_salvo() -> void:
	var pos_index := _material_index
	for i in _active_guns:
		var muzzle := _muzzle_nodes[i]
		var pos := muzzle.global_position
		# Preview-only M2 flame/smoke; regular gameplay Fx remains untouched.
		if _profile > 0 or i % 3 == 0:
			M2_PREVIEW_FX.fire(_world, pos, 0.0, _profile, _shots + i)
		if (_shots + i) % (6 if _profile == 0 else 4) == 0:
			_spawn_tracer(pos, _target_nodes[pos_index].global_position + Vector3.UP * 0.2)
		if (_shots + i) % (5 if _profile == 0 else 3) == 0:
			Fx.casing(_world, pos + Vector3(0.35, 0.0, -0.5))
		if (_shots + i) % (5 if _profile == 0 else 3) == 0:
			Fx.impact(_world, _target_nodes[pos_index].global_position + Vector3(0, 0.5, -0.2), Vector3(0, 0, -1), "metal" if MATERIALS[pos_index] == "vehicle" else MATERIALS[pos_index])
		_shots += 1


func _spawn_tracer(start: Vector3, hit: Vector3) -> void:
	var tracer: MeshInstance3D
	while not _tracer_pool.is_empty() and tracer == null:
		var candidate: MeshInstance3D = _tracer_pool.pop_back()
		if is_instance_valid(candidate):
			tracer = candidate
	if tracer == null:
		if _tracer_created >= 48:
			return
		tracer = MeshInstance3D.new()
		tracer.name = "PooledPreviewTracer"
		if _tracer_mesh == null:
			_tracer_mesh = BoxMesh.new()
			_tracer_mesh.size = Vector3(0.035, 0.035, 1.0)
			_tracer_material = StandardMaterial3D.new()
			_tracer_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_tracer_material.albedo_color = Color(1.0, 0.82, 0.28)
			_tracer_mesh.material = _tracer_material
		tracer.mesh = _tracer_mesh
		_world.add_child(tracer)
		_tracer_created += 1
	tracer.visible = true
	_tracer_live += 1
	tracer.global_position = (start + hit) * 0.5
	tracer.look_at(hit, Vector3.UP)
	tracer.scale = Vector3(1, 1, start.distance_to(hit))
	var tween := create_tween()
	tween.tween_interval(0.035)
	tween.tween_callback(_release_tracer.bind(tracer))


func _release_tracer(tracer: MeshInstance3D) -> void:
	if not is_instance_valid(tracer):
		return
	tracer.visible = false
	_tracer_live = maxi(0, _tracer_live - 1)
	_tracer_pool.append(tracer)


func _refresh_hud() -> void:
	if _status == null or _hud == null:
		return
	_status.text = "Modus: %s  |  MG: %d  |  Doel: %s  |  VFX: %s" % [_mode, _active_guns, MATERIALS[_material_index], PROFILES[_profile]]
	var stats: Dictionary = Fx.combat_counts()
	var sorted: Array = Array(_frame_times)
	sorted.sort()
	var p99 := 0.0
	if sorted.size() >= 120:
		p99 = float(sorted[clampi(int(ceil(float(sorted.size()) * 0.99)) - 1, 0, sorted.size() - 1)])
	var fps_low := (1000.0 / p99) if p99 > 0.0 else 0.0
	var m2_stats: Dictionary = M2_PREVIEW_FX.counts()
	_hud.text = "FPS: %d | 1%% low: %s | Drawcalls: %d | Objecten: %d | RAM: %.1f MiB | Shots: %d | Tracers: %d/%d | M2: %s | FX: %s" % [
		Engine.get_frames_per_second(), ("%.1f" % fps_low) if p99 > 0 else "meting loopt",
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0,
		_shots, _tracer_live, _tracer_created, str(m2_stats), str(stats)
	]
