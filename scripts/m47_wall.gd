class_name M47Wall
extends Node3D
## Betonmuur voor de M-47: heel -> breuk (Blender-clip "Breach" met 42 brokken) -> blijvende doorgang.
## Model: assets/m47/muur_breuk.glb (gemaakt door Codex, PR #240). Collision verdwijnt bij de breuk, zodat kogels en
## soldaten er doorheen kunnen; de brokken blijven liggen waar de clip eindigt.

const GLB := "res://assets/m47/muur_breuk.glb"
const FRAGMENTS := 42
const WALL_LAYER := 1 << 7

var kapot := false
var body: StaticBody3D
var _intact: Node3D
var _breach: Node3D
var _anim: AnimationPlayer
var _pieces: Array[Node3D] = []
var _glow: Sprite3D
# Extra grote, kantige betonbrokken (procedureel): vliegen uit het gat in een boog en blijven liggen.
const CHUNKS := 16
var _chunks: Array[MeshInstance3D] = []
var _c_from: Array[Vector3] = []
var _c_to: Array[Vector3] = []
var _c_spin: Array[Vector3] = []
var _c_dur: Array[float] = []
var _c_h: Array[float] = []
var _age := -1.0


func _ready() -> void:
	var scene := load(GLB) as PackedScene
	if scene == null:
		push_error("M47Wall: muurmodel ontbreekt")
		return
	var root := scene.instantiate() as Node3D
	add_child(root)
	_anim = root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_intact = root.find_child("Wall_Intact", true, false) as Node3D
	_breach = root.find_child("Wall_Permanent_Breach", true, false) as Node3D
	for i in FRAGMENTS:
		var p := root.find_child("Concrete_Fragment_%02d" % i, true, false) as Node3D
		if p != null:
			_pieces.append(p)
	body = StaticBody3D.new()
	body.name = "MuurBotsing"
	body.collision_layer = WALL_LAYER
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.65, 2.75, 3.75)
	cs.shape = box
	body.add_child(cs)
	add_child(body)
	# Blauwe nagloed achter de opening (paneel 5: licht schijnt door het gat).
	var tex: Texture2D = M47Vfx.textures()["glow"]
	_glow = Sprite3D.new()
	_glow.texture = tex
	_glow.pixel_size = 2.6 / tex.get_width()
	_glow.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_glow.shaded = false
	_glow.transparent = true
	_glow.modulate = Color(0.2, 0.55, 1.0, 0.0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = tex
	m.albedo_color = Color(0.2, 0.55, 1.0, 0.0)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_glow.material_override = m
	_glow.position = Vector3(0.45, 0.0, 0.0)
	add_child(_glow)
	for p in _pieces:
		p.scale = Vector3.ONE * 1.45   # de clip beweegt alleen positie: grotere stukken
	_build_chunks()
	set_process(false)
	reset()


func reset() -> void:
	kapot = false
	if _anim != null:
		_anim.stop()
		_anim.seek(0.0, true)
	if _intact != null:
		_intact.visible = true
	if _breach != null:
		_breach.visible = false
	for p in _pieces:
		p.visible = false
	if body != null:
		body.collision_layer = WALL_LAYER
	if _glow != null:
		_glow.visible = false
	for c in _chunks:
		c.visible = false
	_age = -1.0
	set_process(false)


## Hoekig brok: icosaëder met willekeurige straal per hoekpunt, plat geschaduwd, concrete-triplanar.
func _make_chunk(rng: RandomNumberGenerator, size: float) -> ArrayMesh:
	var t := (1.0 + sqrt(5.0)) * 0.5
	var v: Array[Vector3] = [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0), Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t), Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	var f := [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	var stretch := Vector3(rng.randf_range(0.8, 1.5), rng.randf_range(0.45, 0.8), rng.randf_range(0.7, 1.3))
	for i in v.size():
		v[i] = v[i].normalized() * size * rng.randf_range(0.62, 1.1) * stretch
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tri in f:
		for k in 3:
			st.add_vertex(v[tri[k]])
	st.generate_normals()
	return st.commit()


func _build_chunks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4747
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/m47/muur_breuk_albedo.jpg")
	mat.albedo_color = Color(0.78, 0.8, 0.8)
	mat.normal_enabled = true
	mat.normal_texture = load("res://assets/m47/muur_breuk_normal.jpg")
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3.ONE * 0.9
	mat.roughness = 0.92
	for i in CHUNKS:
		var size := rng.randf_range(0.2, 0.46) if i > 3 else rng.randf_range(0.46, 0.62)   # 4 grote stukken
		var m := MeshInstance3D.new()
		m.mesh = _make_chunk(rng, size)
		m.material_override = mat
		m.visible = false
		add_child(m)
		_chunks.append(m)
		_c_from.append(Vector3(rng.randf_range(-0.1, 0.1), rng.randf_range(0.5, 1.8), rng.randf_range(-0.8, 0.8)))
		# Landen aan de kant van de schutter (-X lokaal), verspreid over de breedte.
		_c_to.append(Vector3(-rng.randf_range(0.5, 3.0), -1.36 + size * 0.45, rng.randf_range(-2.2, 2.2)))
		_c_spin.append(Vector3(rng.randf_range(-6, 6), rng.randf_range(-6, 6), rng.randf_range(-6, 6)))
		_c_dur.append(rng.randf_range(0.45, 0.85))
		_c_h.append(rng.randf_range(0.8, 2.2))


func _process(delta: float) -> void:
	if _age < 0.0:
		return
	_age += delta
	for i in _chunks.size():
		var u := clampf(_age / _c_dur[i], 0.0, 1.0)
		var c := _chunks[i]
		c.position = _c_from[i].lerp(_c_to[i], u) + Vector3.UP * (_c_h[i] * 4.0 * u * (1.0 - u))
		c.rotation = _c_spin[i] * minf(_age, _c_dur[i]) * 0.6
	if _age > 1.0:
		set_process(false)


func begin_breuk() -> void:
	if kapot:
		return
	kapot = true
	if _intact != null:
		_intact.visible = false
	if _breach != null:
		_breach.visible = true
	for p in _pieces:
		p.visible = true
	if body != null:
		body.collision_layer = 0
	if _anim != null:
		for clip in _anim.get_animation_list():
			if String(clip) == "Breach" or String(clip).ends_with("/Breach"):
				_anim.play(clip)
				break
	for c in _chunks:
		c.visible = true
	_age = 0.0
	set_process(true)
	_glow.visible = true
	var mat := _glow.material_override as StandardMaterial3D
	var tw := create_tween()
	tw.tween_method(func(v: float): mat.albedo_color.a = v, 0.0, 0.9, 0.25)
	tw.tween_method(func(v: float): mat.albedo_color.a = v, 0.9, 0.0, 2.2)
	tw.tween_callback(func(): _glow.visible = false)
