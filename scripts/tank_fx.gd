class_name TankFx
extends RefCounted
## Cinematisch tankschot (keuzekaart 12 nov 2026, Dennis koos 1A-9A): voor de Tiger en de vijandelijke tank.
## Mondingsvuur met zijtongen van de mondingsrem, drukgolf, hangende rookwolk, stofwaaier, een lichtstreep als granaat en een eigen inslag met aardfontein.
## Alles komt uit de voorraden van WapenFx (vaste bovengrens, geen schaduwen) en alleen binnen 45 m van de camera.
## Instellingen > BEELD > Wapeneffecten: Klassiek geeft het oude tankschot terug. Flipbooks: bron/tankfx/maak_flipbooks.py.

const DIR := "res://assets/tankfx/"
const SHADER_VUUR := preload("res://assets/tankfx/tankfx_vuur.gdshader")
const SHADER_ROOK := preload("res://assets/tankfx/tankfx_rook.gdshader")
const G2_SHOCK := preload("res://shaders/g2_schokgolf.gdshader")
const FRAMES := 16
const MAX_RING := 4
const NEAR := 45.0

static var _tex := {}
static var _meshes := {}
static var _ringen := 0


## Nieuw of Klassiek (dezelfde knop als de shotgun- en pistooleffecten).
static func enabled() -> bool:
	return GameSettings.get_value("wapenfx") == "nieuw"


static func _texture(name: String) -> Texture2D:
	if not _tex.has(name):
		_tex[name] = load(DIR + name) as Texture2D
	return _tex[name]


static func _plane() -> PlaneMesh:
	if not _meshes.has("plane"):
		var p := PlaneMesh.new()
		p.size = Vector2.ONE
		_meshes["plane"] = p
	return _meshes["plane"]


## Rechtopstaand vlak met de onderkant op het punt zelf (voor de billboard van de fontein).
static func _quad() -> QuadMesh:
	if not _meshes.has("quad"):
		var q := QuadMesh.new()
		q.size = Vector2.ONE
		q.center_offset = Vector3(0.0, 0.5, 0.0)
		_meshes["quad"] = q
	return _meshes["quad"]


## Speelt één flipbook af (uit de voorraad): `flat` = plat op de grond/loophoogte, anders een billboard met de onderkant op `pos`.
static func _flipbook(parent: Node, key: String, sheet: String, vuur: bool, pos: Vector3, yaw: float, size: float, life: float, flat: bool, tint: Color, strength := 1.0, drift := Vector3.ZERO, intensity := 1.6) -> void:
	var n := WapenFx._acquire(key, parent, func() -> Node3D:
		var mi := MeshInstance3D.new()
		mi.mesh = _plane() if flat else _quad()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m := ShaderMaterial.new()
		m.shader = SHADER_VUUR if vuur else SHADER_ROOK
		m.set_shader_parameter("sheet", _texture(sheet))
		m.set_shader_parameter("billboard", not flat)
		mi.material_override = m
		return mi)
	if n == null:
		return
	var mat := (n as MeshInstance3D).material_override as ShaderMaterial
	mat.set_shader_parameter("frame_index", 0.0)
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("strength", strength)
	if vuur:
		mat.set_shader_parameter("intensity", intensity)
	n.rotation = Vector3(0.0, yaw, 0.0)
	var flip := 1.0 if randf() < 0.5 else -1.0
	n.scale = Vector3(size * flip, 1.0, size) if flat else Vector3(size * flip, size, 1.0)
	n.global_position = pos
	var tw := n.create_tween()
	tw.tween_method(func(fr: float) -> void: mat.set_shader_parameter("frame_index", fr), 0.0, float(FRAMES - 1), life)
	if drift != Vector3.ZERO:
		tw.parallel().tween_property(n, "global_position", pos + drift, life)
	tw.tween_callback(WapenFx._release.bind(n))


static func _light(parent: Node, pos: Vector3, energy: float, rng: float, life: float) -> void:
	var l := WapenFx._acquire("tanklicht", parent, func() -> Node3D:
		var o := OmniLight3D.new()
		o.shadow_enabled = false
		o.light_color = Color(1.0, 0.6, 0.22)
		return o)
	if l == null:
		return
	var o := l as OmniLight3D
	o.omni_range = rng
	o.light_energy = energy
	o.global_position = pos
	var tw := l.create_tween()
	tw.tween_property(o, "light_energy", energy * 0.35, life * 0.25)
	tw.tween_property(o, "light_energy", 0.0, life * 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(WapenFx._release.bind(l))


## Drukgolf: een ring van stof en gras die snel over de grond uitdijt (de schokgolf-shader van de gouden explosies).
static func _ring(parent: Node, pos: Vector3, size: float, secs: float) -> void:
	if _ringen >= MAX_RING or not parent.is_inside_tree():
		return
	_ringen += 1
	var m := ShaderMaterial.new()
	m.shader = G2_SHOCK
	m.render_priority = 1
	var r := MeshInstance3D.new()
	r.mesh = _plane()
	r.material_override = m
	r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	r.scale = Vector3(size, 1.0, size)
	parent.add_child(r)
	r.global_position = Vector3(pos.x, 0.08, pos.z)
	var tw := r.create_tween()
	tw.tween_method(func(v: float) -> void: m.set_shader_parameter("t", v), 0.0, 1.0, secs).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(r.queue_free)
	r.tree_exiting.connect(func() -> void: _ringen = maxi(0, _ringen - 1))


## Het schot zelf. `pos` = loopmond, `fwd` = richting van het schot (hoeft niet vlak te zijn), `own` = jouw Tiger (met geluid op volle sterkte, camerastoot en trilling als jij erin zit).
static func shot(parent: Node, pos: Vector3, fwd: Vector3, own := false, driven := false) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var f := Vector3(fwd.x, 0.0, fwd.z)
	f = f.normalized() if f.length() > 0.01 else Vector3.FORWARD
	if not enabled():
		Fx.muzzle(parent, pos)
		Fx.dust(parent, pos)
		if not own:
			Sfx.play("boom", 0.55, pos)
		return
	_sound(pos, own)
	_camera(pos, own, driven)
	if not Fx._near_camera(parent, pos, NEAR):
		return
	var t := WapenFx.tier()
	var yaw := atan2(f.x, f.z) + PI   # beeldboven van het vel wijst vooruit (het vlak ligt met zijn bovenkant op -Z)
	var y := maxf(pos.y, 1.0)
	# vuur: lange tong met twee zijtongen; Hoog en Ultra leggen er een tweede, kleinere tong schuin overheen
	_flipbook(parent, "tankvuur", "tankfx_mond.png", true, Vector3(pos.x, y, pos.z) + f * 3.5, yaw, 8.0, 0.3, true, Color(1.0, 0.92, 0.74), 1.0, Vector3.ZERO, 1.9)
	if t >= 1:
		_flipbook(parent, "tankvuur", "tankfx_mond.png", true, Vector3(pos.x, y + 0.05, pos.z) + f * 2.6, yaw + randf_range(-0.2, 0.2), 6.0, 0.24, true, Color(1.0, 0.8, 0.5), 1.0, Vector3.ZERO, 1.5)
	_light(parent, pos + f * 1.5 + Vector3.UP * 0.6, 16.0, 22.0, 0.3)
	Fx._flash_quad(parent, pos + f * 0.4 + Vector3.UP * 0.1, 5.0, 0.09, Color(1.0, 0.7, 0.3, 0.7))
	# drukgolf: ring van stof rond de loop
	_ring(parent, pos + f * 2.0, 15.0, 0.45)
	# rook: dikke wolk voor de tank die blijft hangen en met de wind meedrijft
	var wind := Vector3(0.7, 0.0, -0.4)
	_flipbook(parent, "tankrook", "tankfx_rook.png", false, Vector3(pos.x, y, pos.z) + f * 3.2, yaw, 7.0, 3.8, true, Color(0.92, 0.88, 0.8), 0.95, wind * 3.0 + f * 1.5)
	if t >= 1:
		_flipbook(parent, "tankrook", "tankfx_rook.png", false, Vector3(pos.x, y - 0.3, pos.z) + f * 1.6, yaw + 0.5, 5.0, 4.4, true, Color(0.85, 0.82, 0.75), 0.8, wind * 3.4)
	# stofwaaier op de grond, voor de loop
	_flipbook(parent, "tankstof", "tankfx_stof.png", false, Vector3(pos.x, 0.16, pos.z) + f * 3.8, yaw, 9.0, 1.5, true, Color(1.0, 0.95, 0.85), 0.85)
	if t >= 1:
		var side := f.cross(Vector3.UP)
		_flipbook(parent, "tankstof", "tankfx_stof.png", false, Vector3(pos.x, 0.17, pos.z) + f * 1.6 + side * 1.2, yaw + 0.9, 5.0, 1.2, true, Color(0.95, 0.9, 0.8), 0.7)
		_flipbook(parent, "tankstof", "tankfx_stof.png", false, Vector3(pos.x, 0.17, pos.z) + f * 1.6 - side * 1.2, yaw - 0.9, 5.0, 1.2, true, Color(0.95, 0.9, 0.8), 0.7)
		Fx._burst(parent, Vector3(pos.x, 0.3, pos.z) + f * 3.0, Vector3.UP, 14, Color(0.28, 0.42, 0.12), 0.06, 4.5, Vector3(0.07, 0.03, 0.07))
	# vonken uit de mondingsrem
	Fx._burst(parent, pos + f * 0.6, f, [8, 16, 26][t], Color(1.0, 0.72, 0.28), 0.04, 11.0, Vector3(0.025, 0.025, 0.12))


static func _sound(pos: Vector3, own: bool) -> void:
	if not Sfx.play_file("tankschot", 1.0 if own else 0.85, pos):
		Sfx.play("boom", 0.7, pos)


## Schok, inzoomstoot en trilling: vol voor de Tiger waar jij in zit, een zachte dreun voor een tank in de buurt.
static func _camera(pos: Vector3, own: bool, driven: bool) -> void:
	if Game.player == null or not is_instance_valid(Game.player):
		return
	var d: float = Game.player.global_position.distance_to(pos)
	if d > 40.0:
		return
	var cam := Game.player.get_parent().get_node_or_null("Camera") as Camera3D
	if cam == null:
		return
	if own and driven:
		if cam.has_method("combat_impulse"):
			cam.call("combat_impulse", 0.05)
		if cam.has_method("fov_punch") and WapenFx.tier() >= 1:
			cam.call("fov_punch", 1.2)
		if GameSettings.get_value("wapen_haptiek") == "on" and (OS.has_feature("ios") or OS.has_feature("android")):
			Input.vibrate_handheld(70, 0.9)
	elif cam.has_method("combat_impulse"):
		cam.call("combat_impulse", 0.02 * clampf(1.0 - d / 40.0, 0.0, 1.0) + 0.004)


# ---------- de granaat in de lucht ----------

## Een lichtstreep: een dikke oranje gloed met een witgele kern en een staart, vliegt langs +Z.
static func streak_mesh() -> ArrayMesh:
	if _meshes.has("streak"):
		return _meshes["streak"]
	var m := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lang := 4.4
	var breed := 0.075
	var halo := Color(1.0, 0.5, 0.12)
	var kern := Color(1.0, 0.95, 0.8)
	for laag in 2:
		var w: float = breed * (3.6 if laag == 0 else 1.0)
		var kop: Color = Color(halo.r, halo.g, halo.b, 0.5) if laag == 0 else kern
		var mid: Color = Color(halo.r, halo.g, halo.b, 0.22) if laag == 0 else kern.lerp(Color(1.0, 0.6, 0.2, 0.5), 0.5)
		var eind: Color = Color(halo.r, halo.g, halo.b, 0.0) if laag == 0 else Color(1.0, 0.5, 0.15, 0.0)
		var stations := [[-lang, 0.1, eind], [-lang * 0.45, 0.65, mid], [0.0, 1.0, kop], [0.2, 0.1, Color(kop.r, kop.g, kop.b, 0.0)]]
		for ang in [0.0, PI * 0.5]:
			var zijde := Vector3(cos(ang), sin(ang), 0.0)
			for i in stations.size() - 1:
				var a: Array = stations[i]
				var b: Array = stations[i + 1]
				var pa := Vector3(0, 0, a[0])
				var pb := Vector3(0, 0, b[0])
				var wa: Vector3 = zijde * w * float(a[1])
				var wb: Vector3 = zijde * w * float(b[1])
				var pts := [pa - wa, pa + wa, pb + wb, pb - wb]
				var cols := [a[2], a[2], b[2], b[2]]
				for k in [0, 1, 2, 0, 2, 3]:
					st.set_color(cols[k])
					st.add_vertex(pts[k])
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, st.commit_to_arrays())
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(2.2, 1.95, 1.6)
	m.surface_set_material(0, mat)
	_meshes["streak"] = m
	return m


static func streak() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = streak_mesh()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Granaat van jouw Tiger: een lichtstreep van `from` naar `to` in `secs` seconden (de inslag regelt de aanroeper).
static func flight(parent: Node, from: Vector3, to: Vector3, secs: float) -> void:
	if not enabled() or parent == null or not is_instance_valid(parent):
		return
	var node := Node3D.new()
	node.add_child(streak())
	parent.add_child(node)
	node.global_position = from
	var flat := Vector2(to.x - from.x, to.z - from.z)
	node.rotation.y = atan2(flat.x, flat.y)
	var arc := minf(from.distance_to(to) * 0.03, 1.6)
	var tw := node.create_tween()
	tw.tween_method(func(k: float) -> void:
		node.global_position = from.lerp(to, k) + Vector3.UP * (sin(k * PI) * arc), 0.0, 1.0, maxf(secs, 0.05))
	tw.tween_callback(node.queue_free)


# ---------- inslag ----------

## De inslag van een tankgranaat: de gouden explosie (vuurbal, brokstukken, krater, schokgolf, rookzuil) en erbovenop een fontein van aarde en stof.
static func impact(parent: Node, pos: Vector3, scale := 1.0) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	if not enabled():
		Fx.explosion(parent, pos + Vector3.UP * 0.2, scale)
		return
	Fx.explosion(parent, pos + Vector3.UP * 0.2, scale * 1.25)
	if not Fx._near_camera(parent, pos, 60.0):
		return
	_flipbook(parent, "tankaarde", "tankfx_aarde.png", false, Vector3(pos.x, 0.0, pos.z), 0.0, 7.5 * scale, 1.7, false, Color(1.0, 0.95, 0.9), 1.0)
	if WapenFx.tier() >= 1:
		_flipbook(parent, "tankstof", "tankfx_stof.png", false, Vector3(pos.x, 0.18, pos.z), randf() * TAU, 11.0 * scale, 1.8, true, Color(0.95, 0.88, 0.76), 0.8)
	Fx._burst(parent, Vector3(pos.x, 0.4, pos.z), Vector3.UP, [10, 18, 28][WapenFx.tier()], Color(0.25, 0.18, 0.1), 0.12, 9.0 * scale, Vector3(0.1, 0.1, 0.1))
