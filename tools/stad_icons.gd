extends SceneTree
## Maakt de plaatjes voor de knoppen van de stadseditor: van elk wegdeel, gebouw en straatding één schuin plaatje.
## Draaien (met scherm, bv. xvfb): godot --rendering-driver vulkan --path . -s tools/stad_icons.gd
## Schrijft assets/stad_icons/<soort>.png (256 x 256, doorzichtige achtergrond).
## Alleen één groep opnieuw: zet de groep (weg, gebouw of straat) achter --, bv. ... -s tools/stad_icons.gd -- weg

const SIZE := 256
var Stad
var _kinds: Array = []
var _i := 0
var _vp: SubViewport
var _cam: Camera3D
var _stad
var _wait := 0


func _initialize() -> void:
	Stad = load("res://scripts/stad.gd")
	var only := OS.get_cmdline_user_args()
	for cat in Stad.ORDER:
		if not only.is_empty() and not only.has(cat):
			continue
		for k in Stad.ORDER[cat]:
			if Stad.available(k):
				_kinds.append(k)
	_vp = SubViewport.new()
	_vp.size = Vector2i(SIZE, SIZE)
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.msaa_3d = Viewport.MSAA_4X
	root.add_child(_vp)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 25, 0)
	sun.light_energy = 1.4
	_vp.add_child(sun)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.88, 0.95)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_vp.add_child(_cam)


func _process(_d: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	if _stad != null:
		var img := _vp.get_texture().get_image()
		img.save_png("res://assets/stad_icons/%s.png" % _kinds[_i])
		print("icoon ", _kinds[_i])
		_stad.queue_free()
		_stad = null
		_i += 1
	if _i >= _kinds.size():
		return true
	var kind: String = _kinds[_i]
	var k: Dictionary = Stad.KINDS[kind]
	_stad = Stad.new()
	_vp.add_child(_stad)
	_stad.set_items([{"k": kind, "x": 0.0, "z": 0.0, "r": 0, "m": 0}])
	var half: Vector2 = Stad.half_of({"k": kind, "x": 0.0, "z": 0.0, "r": 0, "m": 0})
	var h := float(k.get("h", 0.5))
	var r := maxf(half.x, half.y)
	var tilt := deg_to_rad(52.0)
	var fwd := Vector3(0, -sin(tilt), -cos(tilt))
	var focus := Vector3(0, minf(h, 8.0) * 0.4, 0)
	_cam.size = (r * 2.0 + h * 0.6) * 1.12 + 0.6
	_cam.position = focus - fwd * 60.0
	_cam.look_at(focus)
	_wait = 6
	return false
