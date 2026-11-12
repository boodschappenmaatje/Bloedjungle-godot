class_name M47Proefveld
extends Node3D
## M-47 Muurbreker proefveld: soldaat met het wapen, een betonmuur en het volledige schoteffect (VFX 2.1 doelbeeld).
## Bereikbaar via hoofdmenu > "M-47". Knoppen: SCHIET, MUUR HERSTELLEN, TERUG. Draaien: godot --path . scenes/m47_proefveld.tscn
## Testopname: godot ... scenes/m47_proefveld.tscn -- --auto [--shots=pad/]  schiet vanzelf en slaat beelden op.
## Gloed (Glow) staat hier op ALLE grafiekstanden aan (keuze 2B); alleen de kwaliteitstrap van het spel kan hem uitzetten.

const MUZZLE := Vector3(0.72, 1.42, 0.36)
const IMPACT := Vector3(4.04, 1.42, 0.36)
const WALL_POS := Vector3(4.28, 1.36, 0.36)
const GLB_WEAPON := "res://assets/m47/M47_Muurbreker.glb"
const CHARGE_TIME := 1.3

var vfx: M47Vfx
var arena: Node3D   # soldaat + muur; 90 graden gedraaid zodat de camera (achter de soldaat) de muur van voren ziet
var wall: M47Wall
var env: Environment
var camera: Camera3D
var weapon_mount: Node3D
var weapon_anim: AnimationPlayer
var core: Node3D
var _spin := 1.0
var _phase := "idle"  # idle | laden | vuurt | klaar
var _timer := 0.0
var _btn_fire: Button
var _fps: Label
var _status: Label
var auto := false
var shots_dir := ""
var _shot_i := 0
var _t := 0.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	auto = args.has("--auto")
	for a in args:
		if a.begins_with("--shots="):
			shots_dir = a.substr(8)
	arena = Node3D.new()
	arena.rotation.y = PI * 0.5
	add_child(arena)
	_build_world()
	_build_hero()
	wall = M47Wall.new()
	wall.position = WALL_POS
	wall.rotation.y = 0.0
	arena.add_child(wall)
	vfx = M47Vfx.new()
	add_child(vfx)
	vfx.klaar.connect(_on_klaar)
	vfx.impact.connect(func(_p): _shake = 0.5)
	_build_ui()
	_play("Idle", 0.45)
	if auto:
		get_tree().create_timer(1.2).timeout.connect(schiet)


var _shake := 0.0


func _build_world() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("050d12")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("5f8a96")
	env.ambient_light_energy = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	apply_glow(env)
	env.fog_enabled = true
	env.fog_light_color = Color("0c2229")
	env.fog_density = 0.012
	we.environment = env
	add_child(we)
	camera = Camera3D.new()
	camera.fov = 45.0
	camera.current = true
	add_child(camera)
	camera.position = arena.to_global(Vector3(-5.8, 7.6, 1.4))
	camera.look_at(arena.to_global(Vector3(2.6, 0.5, 0.36)), Vector3.UP)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -26, 0)
	sun.light_color = Color("a9c6d0")
	sun.light_energy = 0.7
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 30.0
	add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(26, 20)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_texture = load("res://assets/textures/terrain/jungle_ground/base_color.jpg")
	gm.albedo_color = Color(0.38, 0.42, 0.4)
	gm.normal_enabled = true
	gm.normal_texture = load("res://assets/textures/terrain/jungle_ground/normal_gl.jpg")
	gm.roughness_texture = load("res://assets/textures/terrain/jungle_ground/roughness.jpg")
	gm.uv1_scale = Vector3(5, 5, 1)
	ground.material_override = gm
	ground.position = Vector3(2.0, -0.01, 0.0)
	add_child(ground)
	var fl := StaticBody3D.new()
	fl.collision_layer = 1 << 3
	var cs := CollisionShape3D.new()
	cs.shape = WorldBoundaryShape3D.new()
	fl.add_child(cs)
	add_child(fl)
	var jungle := load("res://assets/jungle.glb") as PackedScene
	if jungle != null:
		var proto := jungle.instantiate()
		var meshes: Array[MeshInstance3D] = []
		_collect(proto, meshes)
		var rng := RandomNumberGenerator.new()
		rng.seed = 4704
		var bark := StandardMaterial3D.new()
		bark.albedo_color = Color("342f29")
		var leaf := StandardMaterial3D.new()
		leaf.albedo_texture = load("res://assets/textures/foliage/leaf_color.png")
		leaf.albedo_color = Color("617a5a")
		leaf.cull_mode = BaseMaterial3D.CULL_DISABLED
		for i in 28:
			if meshes.is_empty():
				break
			var src := meshes[i % meshes.size()]
			var c := MeshInstance3D.new()
			c.mesh = src.mesh
			for s in c.mesh.get_surface_count():
				c.set_surface_override_material(s, leaf if s == 1 else bark)
			var tree := src.name.begins_with("Boom") or src.name.begins_with("Palm")
			c.position = Vector3(rng.randf_range(-4.5, 9.0), -0.02, -8.5 - rng.randf_range(0.0, 3.0)) if tree else Vector3(rng.randf_range(-3.0, 8.0), -0.02, (-1.0 if i % 2 == 0 else 1.0) * rng.randf_range(3.2, 5.2))
			c.rotation.y = rng.randf_range(0.0, TAU)
			c.scale = Vector3.ONE * (rng.randf_range(0.55, 0.95) if tree else rng.randf_range(0.4, 0.8))
			add_child(c)
		proto.free()


## Gloed op alle grafiekstanden. In het echte spel kan de kwaliteitstrap (Atmosphere.tier >= 1) hem alsnog uitzetten.
static func apply_glow(e: Environment) -> void:
	e.glow_enabled = true
	e.glow_intensity = 0.8
	e.glow_strength = 1.0
	e.glow_bloom = 0.06
	e.glow_hdr_threshold = 0.9
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	e.set_glow_level(2, 1.0)
	e.set_glow_level(3, 0.8)
	e.set_glow_level(5, 0.5)


func _collect(n: Node, out: Array[MeshInstance3D]) -> void:
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		_collect(c, out)


func _build_hero() -> void:
	var soldier := load("res://assets/soldaat_vq2.glb") as PackedScene
	if soldier != null:
		var s := soldier.instantiate() as Node3D
		arena.add_child(s)
		var ap := s.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap != null and ap.has_animation("stil"):
			ap.play("stil")
	var m47 := load(GLB_WEAPON) as PackedScene
	weapon_mount = Node3D.new()
	weapon_mount.position = Vector3(-0.165, 1.45, 0.38)
	weapon_mount.rotation.y = PI
	weapon_mount.scale = Vector3.ONE * 0.72
	arena.add_child(weapon_mount)
	var weapon := m47.instantiate() as Node3D
	weapon_mount.add_child(weapon)
	weapon_anim = weapon.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for lod in ["M47_LOD0", "M47_LOD1", "M47_LOD2"]:
		var n := weapon.find_child(lod, true, false) as Node3D
		if n != null:
			n.visible = lod == "M47_LOD0"
	# Gloeiende kernringen op de loop (paneel 1): draaien harder tijdens het laden.
	core = Node3D.new()
	core.position = Vector3(-0.58, 0.04, -0.20)
	weapon_mount.add_child(core)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.1, 0.55, 1.0) * 2.2
	for i in 3:
		var tm := TorusMesh.new()
		tm.inner_radius = 0.125 + i * 0.03
		tm.outer_radius = 0.142 + i * 0.03
		tm.rings = 24
		tm.ring_segments = 6
		var r := MeshInstance3D.new()
		r.mesh = tm
		r.material_override = mat
		r.position = Vector3(0, 0, (i - 1) * 0.11)
		r.rotation.x = PI * 0.5
		core.add_child(r)


func _play(clip: String, speed := 1.0) -> void:
	if weapon_anim != null and weapon_anim.has_animation(clip):
		weapon_anim.play(clip, 0.1, speed)


func _build_ui() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)
	var box := HBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	box.offset_top = -120
	box.offset_bottom = -24
	box.offset_left = 24
	box.offset_right = -24
	box.add_theme_constant_override("separation", 16)
	cl.add_child(box)
	var back := _btn("TERUG", func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
	var reset := _btn("MUUR HERSTELLEN", reset_all)
	_btn_fire = _btn("SCHIET", schiet)
	_btn_fire.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(back)
	box.add_child(reset)
	box.add_child(_btn_fire)
	_fps = Label.new()
	_fps.position = Vector2(24, 18)
	_fps.add_theme_font_size_override("font_size", 20)
	cl.add_child(_fps)
	_status = Label.new()
	_status.position = Vector2(24, 48)
	_status.add_theme_font_size_override("font_size", 18)
	cl.add_child(_status)


func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(170, 84)
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(cb)
	return b


func schiet() -> void:
	if _phase == "laden" or _phase == "vuurt":
		return
	if wall.kapot:
		reset_all()
	_phase = "laden"
	_timer = 0.0
	_btn_fire.disabled = true
	_play("Aim", 0.9)
	_status.text = "Laden"


func reset_all() -> void:
	wall.reset()
	_phase = "idle"
	_btn_fire.disabled = false
	_status.text = ""
	_play("Idle", 0.45)


func _on_klaar() -> void:
	_phase = "klaar"
	_btn_fire.disabled = false
	_status.text = "Muur kapot: doorgang blijft"


func _process(delta: float) -> void:
	_t += delta
	_fps.text = "%d fps" % Engine.get_frames_per_second()
	if _phase == "laden":
		_timer += delta
		_spin = lerpf(1.0, 22.0, clampf(_timer / CHARGE_TIME, 0.0, 1.0))
		if _timer >= CHARGE_TIME:
			_phase = "vuurt"
			_play("Fire", 1.0)
			vfx.fire(arena.to_global(MUZZLE), arena.to_global(IMPACT), wall)
			_status.text = "Vuur"
	else:
		_spin = lerpf(_spin, 1.0, 1.0 - exp(-2.0 * delta))
	core.rotation.z += _spin * delta
	# Terugslag en schermtrilling
	if _phase == "vuurt" and _timer < 99.0:
		_timer += delta
	var recoil := 0.0
	if _phase == "vuurt":
		recoil = maxf(0.0, 1.0 - absf((_timer - CHARGE_TIME) - 0.08) / 0.2)
	weapon_mount.position.x = -0.165 - recoil * 0.22
	_shake = maxf(0.0, _shake - delta)
	camera.h_offset = sin(_t * 85.0) * 0.05 * clampf(_shake / 0.5, 0.0, 1.0)
	if auto and shots_dir != "":
		_auto_capture()


const CAPS := [0.05, 0.12, 0.28, 0.55, 0.9, 1.4, 2.2, 3.0, 4.2]
var _t_fire := -1.0
var _charge_shot := false


func _auto_capture() -> void:
	if _phase == "laden" and _timer > 1.15 and not _charge_shot:
		_charge_shot = true
		DirAccess.make_dir_recursive_absolute(shots_dir)
		get_viewport().get_texture().get_image().save_png("%s/m47_charge.png" % shots_dir)
	if _phase == "vuurt" and _t_fire < 0.0:
		_t_fire = _t
	if _t_fire >= 0.0 and _shot_i < CAPS.size() and _t - _t_fire >= CAPS[_shot_i]:
		var img := get_viewport().get_texture().get_image()
		DirAccess.make_dir_recursive_absolute(shots_dir)
		img.save_png("%s/m47_%02d.png" % [shots_dir, _shot_i])
		_shot_i += 1
		if _shot_i >= CAPS.size():
			print("M47_PROEFVELD_KLAAR")
			get_tree().quit(0)
