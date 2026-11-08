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
	_glow.visible = true
	var mat := _glow.material_override as StandardMaterial3D
	var tw := create_tween()
	tw.tween_method(func(v: float): mat.albedo_color.a = v, 0.0, 0.9, 0.25)
	tw.tween_method(func(v: float): mat.albedo_color.a = v, 0.9, 0.0, 2.2)
	tw.tween_callback(func(): _glow.visible = false)
