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


func _corners(node: Node, points: PackedVector3Array) -> void:
	if node is Node3D and not node.is_visible_in_tree():
		return
	if node is MeshInstance3D and node.mesh:
		var box: AABB = node.mesh.get_aabb()
		for i in 8:
			points.append(node.global_transform * box.get_endpoint(i))
	for child in node.get_children():
		_corners(child, points)


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
		if not RenderingServer.is_render_loop_enabled():
			RenderingServer.force_draw()
		var img := _vp.get_texture().get_image()
		if img.is_empty():
			push_error("Leeg icoon: " + _kinds[_i])
			quit(1)
			return true
		if img.save_png("res://assets/stad_icons/%s.png" % _kinds[_i]) != OK:
			push_error("Icoon kon niet worden opgeslagen: " + _kinds[_i])
			quit(1)
			return true
		_stad.queue_free()
		_stad = null
		_i += 1
	if _i >= _kinds.size():
		print("ICONEN KLAAR: ", _i)
		return true
	var kind: String = _kinds[_i]
	_stad = Stad.new()
	_vp.add_child(_stad)
	# De vuur-FX hebben een parent in de sceneboom nodig; het wrak zelf is dezelfde geometrie.
	_stad.set_items([{"k": "autowrak" if kind == "autobrand" else ("buswrak" if kind == "busbrand" else kind), "x": 0.0, "z": 0.0, "r": 0, "m": 0}])
	if kind == "autobrand" or kind == "busbrand":
		load("res://scripts/fx.gd").burning(_stad.items[0].node, Vector3.ZERO, true).position = Vector3(0, 0.8, 0)
	if kind == "brandkraan":
		var animation: AnimationPlayer = _stad.items[0].node._anim
		if animation and animation.has_animation("Spuit"):
			animation.play("Spuit")
			animation.advance(0)
			animation.pause()
	var points := PackedVector3Array()
	_corners(_stad, points)
	if points.is_empty():
		push_error("Geen zichtbare geometrie: " + kind)
		quit(1)
		return true
	var bounds := AABB(points[0], Vector3.ZERO)
	for p in points:
		bounds = bounds.expand(p)
	var focus := bounds.get_center()
	_cam.position = focus + Vector3(0.8, 1.15, 1.35).normalized() * 60.0
	_cam.look_at(focus)
	var extent := Vector2.ZERO
	for p in points:
		var local: Vector3 = _cam.global_basis.inverse() * (p - focus)
		extent.x = maxf(extent.x, absf(local.x))
		extent.y = maxf(extent.y, absf(local.y))
	_cam.size = maxf(extent.x, extent.y) * 2.0 * 1.12
	_wait = 3
	return false
