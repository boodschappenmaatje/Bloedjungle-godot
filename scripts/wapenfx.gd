class_name WapenFx
extends RefCounted
## Wapeneffecten AAA voor de shotgun (Winchester M1897, "trench") en het pistool (M1911A1, "m1911").
## Aan/uit via Instellingen > BEELD > Wapeneffecten (Nieuw/Klassiek); Klassiek laat alles zoals het was.
##
## Lagen per schot (alles uit voorraden, geen nieuwe objecten per schot, geen echte schaduwen):
##   vlam (flipbook, plat op loophoogte), gloed (bestaande flash-quad), lichtvlek op de grond, kort omni-licht (max 2),
##   rookpluim (billboards die wegdrijven), vonken (bestaande burst-voorraad).
## Daarbij: dunne kogelsporen, kogels die op de grond landen, hulzen met stuit en tink, camerakick en trilling.
## Bronnen van de plaatjes en geluiden: bron/wapenfx/maak_wapenfx.py en maak_geluid.py.

const DIR := "res://assets/wapenfx/"
const SHADER: Shader = preload("res://assets/wapenfx/wapenfx_flipbook.gdshader")
const FLASH_FRAMES := 10   # van de 16 beelden worden de eerste 10 afgespeeld; de rest is al bijna gedoofd

const PROFIEL := {
	"m1911": {
		"atlas": "flash_pistool_4x4.png", "flash": 3.8, "flash_life": 0.085, "flash_int": 1.7,
		"glow": 2.0, "patch": 1.3, "patch_life": 0.09, "patch_a": 0.12,
		"light": 4.2, "light_range": 10.0, "light_life": 0.11,
		"smoke_n": 4, "smoke_size": 0.3, "smoke_grow": 3.2, "smoke_life": 1.2, "smoke_speed": 2.6, "smoke_a": 0.3,
		"sparks": 8, "kick": 0.012, "fov": 0.35, "haptic_ms": 12, "haptic_amp": 0.25,
		"trace_len": 3.4, "trace_w": 0.05, "trace_head": Color(1.0, 0.97, 0.78, 1.0), "trace_tail": Color(1.0, 0.5, 0.1, 0.0),
		"dust": 0.7, "hole": true, "bank": 0,
	},
	"trench": {
		"atlas": "flash_shotgun_4x4.png", "flash": 7.0, "flash_life": 0.12, "flash_int": 1.8,
		"glow": 3.6, "patch": 2.6, "patch_life": 0.14, "patch_a": 0.2,
		"light": 7.5, "light_range": 14.0, "light_life": 0.16,
		"smoke_n": 9, "smoke_size": 0.5, "smoke_grow": 3.4, "smoke_life": 1.9, "smoke_speed": 3.6, "smoke_a": 0.4,
		"sparks": 18, "kick": 0.04, "fov": 0.9, "haptic_ms": 30, "haptic_amp": 0.7,
		"trace_len": 2.0, "trace_w": 0.034, "trace_head": Color(1.0, 0.9, 0.55, 1.0), "trace_tail": Color(1.0, 0.42, 0.06, 0.0),
		"dust": 0.55, "hole": false, "bank": 1,
	},
}

const CAP := {"flash": 6, "patch": 4, "light": 3, "rook": 40, "bank": 8, "stof": 18, "ring": 8, "barst": 10, "gloed": 24, "brok": 6}

## Referentiestijl (17 nov): heet palet in HDR, zodat de gloed op Ultra het oppakt en het op Hoog fel blijft.
const HEET_WIT := Color(2.4, 2.1, 1.6)
const HEET_GEEL := Color(2.6, 1.7, 0.5)
const HEET_ORANJE := Color(2.2, 0.85, 0.18)
const HEET_ROOD := Color(1.6, 0.28, 0.06)

static var _pools := {}    # naam -> vrije knopen
static var _made := {}     # naam -> aantal knopen dat bestaat
static var _tex := {}
static var _meshes := {}
static var _mats := {}


## True als dit wapen de nieuwe effecten krijgt (instelling Nieuw, en alleen shotgun en pistool).
static func enabled(weapon: String) -> bool:
	return PROFIEL.has(weapon) and GameSettings.get_value("wapenfx") == "nieuw"


## Kwaliteitstrap voor de zwaarste lagen: 0 = Prestatie (of de regelaar heeft een onderdeel uitgezet), 1 = Hoog, 2 = Ultra.
static func tier() -> int:
	var q: int = {"low": 0, "high": 1, "ultra": 2}.get(GameSettings.get_value("quality"), 1)
	return clampi(q - Atmosphere.tier, 0, 2)


static func profile(weapon: String) -> Dictionary:
	return PROFIEL.get(weapon, PROFIEL["m1911"])


static func counts() -> Dictionary:
	return _made.duplicate()


static func _texture(name: String) -> Texture2D:
	if not _tex.has(name):
		_tex[name] = load(DIR + name) as Texture2D
	return _tex[name]


# ---------- voorraad ----------

static func _acquire(key: String, parent: Node, make: Callable) -> Node3D:
	var base := key.get_slice(":", 0)
	var pool: Array = _pools.get(key, [])
	var n: Node3D = null
	while not pool.is_empty() and n == null:
		var candidate = pool.pop_back()
		if is_instance_valid(candidate):
			n = candidate
	_pools[key] = pool
	if n == null:
		if int(_made.get(key, 0)) >= int(CAP.get(base, 8)):
			return null   # liever een effect overslaan dan de beeldsnelheid opofferen
		n = make.call()
		n.set_meta("wfx_key", key)
		n.tree_exiting.connect(_forget.bind(n, key))
		_made[key] = int(_made.get(key, 0)) + 1
	if n.get_parent() != parent:
		if n.get_parent() != null:
			n.reparent(parent, false)
		else:
			parent.add_child(n)
	n.visible = true
	n.set_meta("wfx_active", true)
	return n


static func _release(n: Node3D) -> void:
	if not is_instance_valid(n) or not n.get_meta("wfx_active", false):
		return
	n.set_meta("wfx_active", false)
	n.visible = false
	var key: String = n.get_meta("wfx_key")
	var pool: Array = _pools.get(key, [])
	pool.append(n)
	_pools[key] = pool


static func _forget(n: Node3D, key: String) -> void:
	var pool: Array = _pools.get(key, [])
	pool.erase(n)
	_made[key] = maxi(0, int(_made.get(key, 0)) - 1)


# ---------- mondingsvuur ----------

static func muzzle(parent: Node, pos: Vector3, weapon: String, angle: float) -> void:
	if not enabled(weapon) or not Fx._near_camera(parent, pos, 38.0):
		return
	var p: Dictionary = PROFIEL[weapon]
	var t := tier()
	var fwd := Vector3(sin(angle), 0.0, cos(angle))
	_flash(parent, pos, weapon, angle, p, 1.0)
	if t >= 1:
		_flash(parent, pos, weapon, angle + randf_range(-0.22, 0.22), p, 0.62)   # tweede, kleinere tong ernaast: de vlam flakkert
	Fx._flash_quad(parent, pos + Vector3.UP * 0.1 + fwd * 0.12, p.glow, p.flash_life * 0.9, Color(1.0, 0.66, 0.24, 0.6))
	# felle ster met lichtlijnen over de vlam heen (referentie): leest ook op afstand als een echte flits
	Fx._flash_quad(parent, pos + Vector3.UP * 0.15 + fwd * 0.35, float(p.glow) * 1.25, float(p.flash_life) * 1.1, Color(HEET_GEEL.r, HEET_GEEL.g, HEET_GEEL.b, 0.95), "star")
	if t >= 1:
		_gloed(parent, pos + fwd * 0.6 + Vector3.UP * 0.2, fwd, 5 if weapon == "trench" else 3)
	_patch(parent, pos + fwd * 0.3, p)
	_light(parent, pos + fwd * 0.6 + Vector3.UP * 0.5, p)
	var n := [3, int(p.smoke_n * 0.7), int(p.smoke_n)][t] as int
	for i in n:
		_puff(parent, pos, fwd, p, i, "rook", Color(0.64, 0.6, 0.54))
	if t >= 1 and int(p.bank) > 0:
		_bank(parent, pos + fwd * 0.9, p, t)
	Fx._burst(parent, pos + fwd * 0.3, fwd, int(p.sparks * (1.0 if t >= 1 else 0.5)), Color(1.0, 0.72, 0.28), 0.03, 7.5 if weapon == "trench" else 6.0, Vector3(0.02, 0.02, 0.08))


static func _flash(parent: Node, pos: Vector3, weapon: String, angle: float, p: Dictionary, mul: float) -> void:
	var f := _acquire("flash:" + weapon, parent, func() -> Node3D:
		var mi := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2.ONE
		mi.mesh = plane
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m := ShaderMaterial.new()
		m.shader = SHADER
		m.set_shader_parameter("flipbook_atlas", _texture(p.atlas))
		mi.material_override = m
		return mi)
	if f == null:
		return
	var size: float = p.flash * mul * randf_range(0.9, 1.15)
	f.scale = Vector3(size * (1.0 if randf() < 0.5 else -1.0), 1.0, size)
	f.rotation = Vector3(0.0, angle, 0.0)
	# het loopeinde zit bovenaan in het plaatje: leg de vlam een beetje voor de loop
	f.global_position = pos + Vector3(sin(angle), 0.0, cos(angle)) * size * 0.47 + Vector3.UP * 0.12
	var mat := (f as MeshInstance3D).material_override as ShaderMaterial
	mat.set_shader_parameter("intensity", p.flash_int)
	mat.set_shader_parameter("frame_index", 0.0)
	var tw := f.create_tween()
	tw.tween_method(func(fr: float): mat.set_shader_parameter("frame_index", fr), 0.0, float(FLASH_FRAMES - 1), p.flash_life * mul)
	tw.tween_callback(_release.bind(f))


## Zachte oranje lichtvlek op de grond: de flits "licht de grond op" zonder schaduw.
static func _patch(parent: Node, pos: Vector3, p: Dictionary) -> void:
	var q := _acquire("patch", parent, func() -> Node3D:
		var mi := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2.ONE
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.albedo_texture = Fx.soft()
		m.albedo_color = Color(1.0, 0.55, 0.16, 1.0)
		plane.material = m
		mi.mesh = plane
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return mi)
	if q == null:
		return
	q.scale = Vector3(p.patch, 1.0, p.patch)
	q.rotation = Vector3.ZERO
	q.global_position = Vector3(pos.x, 0.07, pos.z)
	(q as MeshInstance3D).transparency = 1.0 - float(p.patch_a)
	var tw := q.create_tween()
	tw.tween_property(q, "transparency", 1.0, p.patch_life)
	tw.tween_callback(_release.bind(q))


static func _light(parent: Node, pos: Vector3, p: Dictionary) -> void:
	var l := _acquire("light", parent, func() -> Node3D:
		var o := OmniLight3D.new()
		o.shadow_enabled = false
		o.light_color = Color(1.0, 0.58, 0.2)
		return o)
	if l == null:
		return
	var o := l as OmniLight3D
	o.omni_range = p.light_range
	o.light_energy = p.light
	o.global_position = pos
	var tw := l.create_tween()
	tw.tween_property(o, "light_energy", 0.0, p.light_life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_release.bind(l))


# ---------- rook en stof ----------

static func _puff_material() -> StandardMaterial3D:
	if not _mats.has("puff"):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.albedo_texture = _texture("rook.png")
		m.no_depth_test = false
		m.albedo_color = Color(0.76, 0.69, 0.58)   # warm grijs: het gouden zonlicht kleurt de rook
		_mats["puff"] = m
	return _mats["puff"]


static func _puff_mesh() -> QuadMesh:
	if not _meshes.has("puff"):
		var q := QuadMesh.new()
		q.size = Vector2.ONE
		q.material = _puff_material()
		_meshes["puff"] = q
	return _meshes["puff"]


## Een rookwolkje dat uit de loop drijft (eerst snel, dan afremmend), opzwelt en vervaagt.
static func _puff(parent: Node, pos: Vector3, fwd: Vector3, p: Dictionary, i: int, key: String, tint: Color) -> void:
	var s := _acquire(key, parent, func() -> Node3D:
		var mi := MeshInstance3D.new()
		mi.mesh = _puff_mesh()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return mi)
	if s == null:
		return
	var mi := s as MeshInstance3D
	mi.material_override = null
	var side := fwd.cross(Vector3.UP)
	var origin := pos + fwd * (0.18 + 0.16 * i) + side * randf_range(-0.08, 0.08) + Vector3.UP * 0.05
	var speed: float = p.smoke_speed * (1.0 - 0.1 * i) * randf_range(0.7, 1.15)
	var vel := fwd * speed + side * randf_range(-0.5, 0.5) * (0.4 + 0.2 * i) + Vector3.UP * randf_range(0.25, 0.6)
	var life: float = p.smoke_life * randf_range(0.8, 1.15)
	var size0: float = p.smoke_size * randf_range(0.8, 1.2)
	var grow: float = p.smoke_grow
	var alpha: float = p.smoke_a * randf_range(0.75, 1.0)
	var wind := Vector3(0.18, 0.0, -0.1)
	mi.global_position = origin
	mi.scale = Vector3.ONE * size0
	mi.transparency = 1.0 - alpha
	var tw := s.create_tween()
	tw.tween_method(func(u: float) -> void:
		var drift := (1.0 - exp(-3.2 * u * life)) / 3.2   # afremmend: snel uit de loop, dan blijft hij hangen
		mi.global_position = origin + vel * drift + wind * u * life + Vector3.UP * 0.18 * u * life
		mi.scale = Vector3.ONE * size0 * (1.0 + grow * (1.0 - pow(1.0 - u, 2.0)))
		mi.transparency = 1.0 - alpha * (1.0 - u) * minf(1.0, u * 14.0 + 0.35), 0.0, 1.0, life)
	tw.tween_callback(_release.bind(s))


## Rookbank: grote, trage, doorzichtige wolk die blijft hangen; na een paar schoten staat er een grijze waas boven de schutter (Hoog en Ultra).
static func _bank(parent: Node, pos: Vector3, p: Dictionary, t: int) -> void:
	var q: Dictionary = p.duplicate()
	q.smoke_size = 1.0
	q.smoke_grow = 1.8
	q.smoke_life = 4.2 if t >= 2 else 2.8
	q.smoke_speed = 0.35
	q.smoke_a = 0.17
	_puff(parent, pos, Vector3(0.0, 0.0, 0.0), q, 0, "bank", Color(0.7, 0.66, 0.6))


## Klein rookje uit de loop als je herlaadt (alleen kort na het schieten).
static func reload_wisp(parent: Node, pos: Vector3, weapon: String, angle: float) -> void:
	if not enabled(weapon) or not Fx._near_camera(parent, pos, 30.0):
		return
	var p: Dictionary = PROFIEL[weapon].duplicate()
	p.smoke_size = 0.14
	p.smoke_grow = 2.2
	p.smoke_life = 1.1
	p.smoke_speed = 0.25
	p.smoke_a = 0.26
	_puff(parent, pos, Vector3(sin(angle), 0.0, cos(angle)), p, 0, "rook", Color(0.7, 0.68, 0.64))


# ---------- kogelsporen ----------

## Dun, kort lichtstreepje met een hete kop en een uitdovende oranje staart (geen ronde kop: een kogel is geen lamp).
static func tracer_mesh(weapon: String) -> ArrayMesh:
	var key := "tracer:" + weapon
	if _meshes.has(key):
		return _meshes[key]
	var p: Dictionary = PROFIEL.get(weapon, PROFIEL["m1911"])
	var m := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lang: float = p.trace_len
	var head: Color = p.trace_head
	var tail: Color = p.trace_tail
	# twee lagen in één vlak: een brede zachte oranje halo en daarbinnen een dunne, witgele kern.
	# Elke laag bestaat uit twee kruislings gezette linten met een kop die toespitst en een staart die uitdooft.
	# drie lagen in één vlak: brede rode/oranje halo, witgele kern met staart, en een korte felle kogelkop (referentie).
	for laag in 3:
		var breed: float = float(p.trace_w) * [3.6, 1.0, 2.0][laag]
		var kleur_kop: Color
		var kleur_mid: Color
		var kleur_eind: Color
		var stations: Array
		if laag == 0:
			kleur_kop = Color(1.0, 0.5, 0.12, 0.45)
			kleur_mid = Color(1.0, 0.32, 0.06, 0.22)
			kleur_eind = Color(0.9, 0.15, 0.03, 0.0)
			stations = [[-lang, 0.1], [-lang * 0.45, 0.62], [0.0, 1.0], [0.16, 0.12]]
		elif laag == 1:
			kleur_kop = head
			kleur_mid = Color(1.0, 0.6, 0.16, 0.75)
			kleur_eind = tail
			stations = [[-lang, 0.1], [-lang * 0.45, 0.62], [0.0, 1.0], [0.16, 0.12]]
		else:
			kleur_kop = Color(1.0, 1.0, 0.92, 1.0)
			kleur_mid = Color(1.0, 0.85, 0.5, 0.9)
			kleur_eind = Color(1.0, 0.6, 0.2, 0.0)
			stations = [[-0.42, 0.3], [-0.2, 0.8], [0.0, 1.0], [0.12, 0.2]]
		var kleuren := [kleur_eind, kleur_mid, kleur_kop, Color(kleur_kop.r, kleur_kop.g, kleur_kop.b, 0.0)]
		var st_list: Array = []
		for i in 4:
			st_list.append([stations[i][0], stations[i][1], kleuren[i]])
		for ang in [0.0, PI * 0.5]:
			var zijde := Vector3(cos(ang), sin(ang), 0.0)
			for i in st_list.size() - 1:
				var a_ : Array = st_list[i]
				var b_ : Array = st_list[i + 1]
				var pa: Vector3 = Vector3(0, 0, a_[0])
				var pb: Vector3 = Vector3(0, 0, b_[0])
				var wa: Vector3 = zijde * breed * a_[1]
				var wb: Vector3 = zijde * breed * b_[1]
				var pts := [pa - wa, pa + wa, pb + wb, pb - wb]
				var cols := [a_[2], a_[2], b_[2], b_[2]]
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
	mat.albedo_color = Color(2.5, 2.1, 1.6)   # HDR: de kern straalt, de halo kleurt het gras eromheen warm
	m.surface_set_material(0, mat)
	_meshes[key] = m
	return m


static func trace_length(weapon: String) -> float:
	return float(PROFIEL.get(weapon, PROFIEL["m1911"]).trace_len)


# ---------- kogel landt op de grond ----------

## Een schot dat niets raakt landt zichtbaar: stofwolkje, graspluk en (pistool) een klein gaatje dat na 20 s verdwijnt.
static func ground_hit(parent: Node, at: Vector3, weapon: String) -> void:
	if not enabled(weapon) or not is_instance_valid(parent) or not Fx._near_camera(parent, at, 34.0):
		return
	var p: Dictionary = PROFIEL[weapon]
	var g := Vector3(at.x, Data.ground_y(at.x, at.z), at.z)
	if weapon == "trench" and randf() > 0.4:
		_dust(parent, g, p, 0.7)   # van de negen korrels laten er een paar een volledig effect achter
		_vonken(parent, g + Vector3.UP * 0.05, Vector3.UP, 0.6)
		return
	_dust(parent, g, p, 1.0)
	inslag(parent, g, Vector3.UP, weapon, true)
	Fx._burst(parent, g + Vector3.UP * 0.05, Vector3.UP, 7, Color(0.36, 0.26, 0.14), 0.05, 4.2, Vector3(0.05, 0.04, 0.05))
	Fx._burst(parent, g + Vector3.UP * 0.05, Vector3.UP, 5, Color(0.22, 0.42, 0.1), 0.04, 3.4, Vector3(0.02, 0.05, 0.02))   # grassprieten
	if tier() >= 1:
		Fx._burst(parent, g + Vector3.UP * 0.1, Vector3.UP, 6, Color(0.3, 0.5, 0.12), 0.07, 2.6, Vector3(0.07, 0.01, 0.045))   # rondtollende blaadjes
	if p.hole:
		Fx.decal(parent, g, Vector3.UP, "hole", 0.3, 20.0)


static func _dust(parent: Node, g: Vector3, p: Dictionary, scale_mul: float) -> void:
	var s := _acquire("stof", parent, func() -> Node3D:
		var mi := MeshInstance3D.new()
		mi.mesh = _puff_mesh()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return mi)
	if s == null:
		return
	var mi := s as MeshInstance3D
	var dust_mat: StandardMaterial3D
	if _mats.has("dust"):
		dust_mat = _mats["dust"]
	else:
		dust_mat = _puff_material().duplicate()
		dust_mat.albedo_color = Color(0.5, 0.42, 0.3)
		_mats["dust"] = dust_mat
	mi.material_override = dust_mat
	var size0: float = float(p.dust) * scale_mul
	mi.global_position = g + Vector3.UP * 0.12
	mi.scale = Vector3.ONE * size0 * 0.5
	mi.transparency = 0.45
	var tw := s.create_tween()
	tw.tween_method(func(u: float) -> void:
		mi.scale = Vector3.ONE * size0 * (0.5 + 1.6 * (1.0 - pow(1.0 - u, 2.0)))
		mi.global_position = g + Vector3.UP * (0.12 + 0.35 * u)
		mi.transparency = 0.45 + 0.55 * u, 0.0, 1.0, 0.7)
	tw.tween_callback(_release.bind(s))


## Extra inslageffect op bomen, muren en voertuigen, bovenop Fx.impact (alleen voor kogels van de speler met de nieuwe effecten).
static func surface_hit(parent: Node, pos: Vector3, normal: Vector3, material: String, weapon: String) -> void:
	if not enabled(weapon) or not is_instance_valid(parent) or not Fx._near_camera(parent, pos, 30.0):
		return
	var n := normal.normalized()
	inslag(parent, pos, n, weapon, false)
	match material:
		"wood":
			Fx._burst(parent, pos, n, 6, Color(0.3, 0.5, 0.12), 0.08, 2.4, Vector3(0.08, 0.012, 0.05))   # blaadjes dwarrelen weg
			if tier() >= 1:
				Fx._burst(parent, pos, n, 4, Color(0.7, 0.55, 0.35), 0.03, 6.0, Vector3(0.02, 0.1, 0.02))   # splinters
		"metal", "concrete":
			Fx._burst(parent, pos, n, 5, Color(1.0, 0.7, 0.25), 0.025, 8.0, Vector3(0.02, 0.07, 0.02))
			if tier() >= 1:
				_dust(parent, pos, PROFIEL[weapon], 0.55)
		_:
			_dust(parent, pos, PROFIEL[weapon], 0.5)


# ---------- inslag in referentiestijl ----------

## Korte hete flits, vonkenregen en gloedstipjes; op de grond ook gloeiende barstjes en een lage stofring (Hoog en Ultra).
static func inslag(parent: Node, pos: Vector3, normal: Vector3, weapon: String, op_grond: bool) -> void:
	if not enabled(weapon) or not is_instance_valid(parent) or not Fx._near_camera(parent, pos, 34.0):
		return
	var t := tier()
	var n := normal.normalized()
	var zwaar := 1.0 if weapon == "m1911" else 0.75   # shotgun: negen korrels, dus per korrel iets kleiner
	Fx._flash_quad(parent, pos + n * 0.08, 0.75 * zwaar, 0.07, Color(HEET_GEEL.r, HEET_GEEL.g, HEET_GEEL.b, 0.95), "star")
	_vonken(parent, pos + n * 0.04, n, zwaar)
	if t >= 1:
		_gloed(parent, pos + n * 0.1, n, 3 if t >= 2 else 2)
		if op_grond:
			_barst(parent, pos, zwaar)
			if t >= 2 or weapon == "m1911":
				_ring(parent, pos, zwaar)


static func _vonken(parent: Node, pos: Vector3, n: Vector3, mul: float) -> void:
	Fx._burst(parent, pos, n, int(10 * mul) + 2, HEET_GEEL, 0.022, 9.5, Vector3(0.016, 0.016, 0.12))
	Fx._burst(parent, pos, n, int(6 * mul) + 1, HEET_ORANJE, 0.03, 5.5, Vector3(0.024, 0.024, 0.024))


## Zwevende gloedstipjes: kleine hete vonkjes die omhoog drijven en in ruim een seconde doven.
static func _gloed(parent: Node, pos: Vector3, dir: Vector3, n: int) -> void:
	var e := _acquire("gloed", parent, func() -> Node3D:
		var c := CPUParticles3D.new()
		c.one_shot = true
		c.explosiveness = 0.85
		c.lifetime = 1.3
		c.amount = 6
		c.spread = 70.0
		c.initial_velocity_min = 0.6
		c.initial_velocity_max = 2.2
		c.gravity = Vector3(0.15, 0.9, 0.0)
		c.damping_min = 1.5
		c.damping_max = 2.5
		var b := BoxMesh.new()
		b.size = Vector3.ONE * 0.035
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = HEET_ORANJE
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.vertex_color_use_as_albedo = true
		b.material = m
		c.mesh = b
		var ramp := Gradient.new()
		ramp.set_color(0, Color(1.0, 0.9, 0.6, 1.0))
		ramp.set_color(1, Color(1.0, 0.25, 0.05, 0.0))
		c.color_ramp = ramp
		return c)
	if e == null:
		return
	var c := e as CPUParticles3D
	c.amount = clampi(n, 1, 6)
	c.global_position = pos
	c.direction = (dir + Vector3.UP).normalized()
	c.emitting = false
	c.restart()
	c.emitting = true
	var tw := c.create_tween()
	tw.tween_interval(c.lifetime + 0.1)
	tw.tween_callback(_release.bind(c))


static var _barst_tex_albedo: ImageTexture
static var _barst_tex_emissie: ImageTexture


## Gloeiende barstjes: een donker plekje met hete oranje scheuren die in ruim twee seconden uitdoven (zoals in de referentie).
static func _barst_textures() -> void:
	if _barst_tex_albedo != null:
		return
	var n := 128
	var alb := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var emi := Image.create(n, n, false, Image.FORMAT_RGBA8)
	alb.fill(Color(0, 0, 0, 0))
	emi.fill(Color(0, 0, 0, 1))
	var rng := RandomNumberGenerator.new()
	rng.seed = 2611
	var c := Vector2(n, n) * 0.5
	for y in n:
		for x in n:
			var d := Vector2(x, y).distance_to(c) / (n * 0.5)
			if d < 1.0:
				alb.set_pixel(x, y, Color(0.035, 0.025, 0.02, clampf((1.0 - d) * 1.6, 0.0, 0.8)))
	for arm in 7:
		var ang := float(arm) / 7.0 * TAU + rng.randf_range(-0.3, 0.3)
		var p := c
		var lengte := rng.randf_range(0.55, 0.95) * n * 0.5
		var stap := 0.0
		while stap < lengte:
			ang += rng.randf_range(-0.45, 0.45)
			p += Vector2(cos(ang), sin(ang)) * 1.5
			stap += 1.5
			var hitte := 1.0 - stap / lengte
			for o in [Vector2.ZERO, Vector2(1, 0), Vector2(0, 1)]:
				var q: Vector2 = p + o
				if q.x >= 0 and q.y >= 0 and q.x < n and q.y < n:
					emi.set_pixel(int(q.x), int(q.y), Color(1.0, 0.35 + 0.4 * hitte, 0.08, 1.0) * (0.4 + 0.6 * hitte))
					alb.set_pixel(int(q.x), int(q.y), Color(0.05, 0.02, 0.01, 0.95))
			if rng.randf() < 0.05:
				ang += rng.randf_range(-1.0, 1.0)   # zijtak
	_barst_tex_albedo = ImageTexture.create_from_image(alb)
	_barst_tex_emissie = ImageTexture.create_from_image(emi)


static func _barst(parent: Node, pos: Vector3, mul: float) -> void:
	var d := _acquire("barst", parent, func() -> Node3D:
		_barst_textures()
		var dc := Decal.new()
		dc.texture_albedo = _barst_tex_albedo
		dc.texture_emission = _barst_tex_emissie
		dc.distance_fade_enabled = true
		dc.distance_fade_begin = 45.0
		dc.distance_fade_length = 10.0
		return dc)
	if d == null:
		return
	var dc := d as Decal
	var size := randf_range(0.9, 1.3) * mul
	dc.size = Vector3(size, 0.5, size)
	dc.rotation = Vector3(0.0, randf() * TAU, 0.0)
	dc.global_position = pos + Vector3.UP * 0.05
	dc.emission_energy = 3.0
	dc.modulate = Color(1, 1, 1, 1)
	var tw := dc.create_tween()
	tw.tween_property(dc, "emission_energy", 0.0, 2.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_interval(3.0)
	tw.tween_property(dc, "modulate:a", 0.0, 1.5)
	tw.tween_callback(_release.bind(dc))


static var _ring_mesh: PlaneMesh


## Lage stofring die van de inslag wegrolt.
static func _ring(parent: Node, pos: Vector3, mul: float) -> void:
	var r := _acquire("ring", parent, func() -> Node3D:
		if _ring_mesh == null:
			var n := 64
			var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
			for y in n:
				for x in n:
					var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(n, n) * 0.5) / (n * 0.5)
					var a := clampf(1.0 - absf(d - 0.75) / 0.22, 0.0, 1.0)
					img.set_pixel(x, y, Color(1, 1, 1, a * a))
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_texture = ImageTexture.create_from_image(img)
			m.albedo_color = Color(0.62, 0.52, 0.38)
			_ring_mesh = PlaneMesh.new()
			_ring_mesh.size = Vector2.ONE
			_ring_mesh.material = m
		var mi := MeshInstance3D.new()
		mi.mesh = _ring_mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return mi)
	if r == null:
		return
	var mi := r as MeshInstance3D
	mi.global_position = pos + Vector3.UP * 0.08
	mi.rotation = Vector3(0.0, randf() * TAU, 0.0)
	mi.scale = Vector3.ONE * 0.3
	mi.transparency = 0.35
	var eind := 2.2 * mul
	var tw := mi.create_tween()
	tw.tween_method(func(u: float) -> void:
		var k := 1.0 - pow(1.0 - u, 3.0)
		mi.scale = Vector3.ONE * lerpf(0.3, eind, k)
		mi.transparency = lerpf(0.35, 1.0, u), 0.0, 1.0, 0.55)
	tw.tween_callback(_release.bind(mi))


## Kill-effect: donkere brokstukken (kleding, uitrusting) en een korte rookstreep, zwaarder bij de shotgun.
static func kill_fx(parent: Node, at: Vector3, dir: Vector3, weapon: String) -> void:
	if not enabled(weapon) or not is_instance_valid(parent) or not Fx._near_camera(parent, at, 34.0):
		return
	var flat := Vector3(dir.x, 0.0, dir.z).normalized()
	var zwaar := weapon == "trench"
	Fx._burst(parent, at + Vector3.UP * 0.3, flat + Vector3.UP * 0.5, 10 if zwaar else 6, Color(0.16, 0.14, 0.1), 0.07, 6.5 if zwaar else 4.5, Vector3(0.09, 0.05, 0.07))
	Fx._burst(parent, at + Vector3.UP * 0.3, flat + Vector3.UP * 0.3, 18 if zwaar else 10, Color(0.5, 0.02, 0.02), 0.06, 7.0, Vector3.ZERO)
	_dust(parent, Vector3(at.x, Data.ground_y(at.x, at.z), at.z), PROFIEL[weapon], 1.3 if zwaar else 1.0)
	if tier() >= 1:
		_gloed(parent, at + Vector3.UP * 0.5, flat, 4)


# ---------- hulzen ----------

static func casing_mesh(weapon: String) -> Mesh:
	if weapon != "trench":
		return null   # pistool: het bestaande messing hulsje uit wapens.glb
	if _meshes.has("shell"):
		return _meshes["shell"]
	var m := ArrayMesh.new()
	_add_cylinder(m, 0.0105, 0.046, 0.012, Color(0.78, 0.07, 0.05), 0.0, 0.5)    # rode kunststof huls
	_add_cylinder(m, 0.0112, 0.019, -0.022, Color(0.92, 0.66, 0.26), 0.85, 0.28)  # koperen bodem
	_meshes["shell"] = m
	return m


## Hoeveel hulzen er op de grond mogen blijven liggen (Prestatie, Hoog, Ultra).
static func casings_max() -> int:
	return [20, 40, 60][tier()]


static func casing_scale(weapon: String) -> float:
	return 2.6 if weapon == "trench" else 2.1


static func _add_cylinder(m: ArrayMesh, radius: float, length: float, z_mid: float, color: Color, metallic: float, rough: float) -> void:
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = length
	c.radial_segments = 8
	c.rings = 1
	var arrays := c.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i in verts.size():
		verts[i] = Vector3(verts[i].x, verts[i].z, verts[i].y + z_mid)   # as van Y naar Z, zoals het messing hulsje
		norms[i] = Vector3(norms[i].x, norms[i].z, norms[i].y)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = rough
	m.surface_set_material(m.get_surface_count() - 1, mat)


# ---------- gevoel ----------

static func kick(weapon: String) -> float:
	return float(PROFIEL.get(weapon, PROFIEL["m1911"]).kick) if enabled(weapon) else -1.0


## Korte inzoomstoot van de camera bij een schot, in graden (Hoog en Ultra; 0 = geen).
static func fov_punch(weapon: String) -> float:
	return float(PROFIEL[weapon].fov) if enabled(weapon) and tier() >= 1 else 0.0


## Korte tik in je hand (alleen op telefoons, en uit te zetten in Instellingen).
static func haptic(weapon: String) -> void:
	if not enabled(weapon) or GameSettings.get_value("wapen_haptiek") != "on":
		return
	if not (OS.has_feature("ios") or OS.has_feature("android")):
		return
	var p: Dictionary = PROFIEL[weapon]
	Input.vibrate_handheld(int(p.haptic_ms), float(p.haptic_amp))


## Het geluid van een schot: shotgun krijgt zijn eigen gelaagde bestand, het pistool zijn knal plus een staart.
static func shot_sound(weapon: String) -> void:
	if not enabled(weapon):
		Sfx.play(Data.WEAPON_SND[weapon])
		return
	if weapon == "trench":
		if not Sfx.play_file("shotgun_schot", 1.0):
			Sfx.play("shotgun")
	else:
		Sfx.play(Data.WEAPON_SND[weapon])
		Sfx.play_file("pistool_staart", 0.5)


## Treffergevoel op een vijand: bloedspat in de richting van het schot, een extra stevige terugslag in zijn animatie en een tik.
static func treffer(parent: Node, target: Node, at: Vector3, dir: Vector3, weapon: String) -> void:
	if not enabled(weapon) or not is_instance_valid(parent):
		return
	var flat := Vector3(dir.x, 0.0, dir.z).normalized()
	Fx.blood(parent, at + Vector3.UP * 0.1, flat + Vector3.UP * 0.15, 32 if weapon == "trench" else 20)
	Fx.ground_blood(parent, at + flat * 0.9, 0.9 if weapon == "trench" else 0.6)
	Fx._flash_quad(parent, at + Vector3.UP * 0.15 - flat * 0.1, 1.1 if weapon == "trench" else 0.8, 0.06, Color(HEET_WIT.r, HEET_WIT.g, HEET_WIT.b, 0.9), "star")   # korte treffer-flits
	if target != null and is_instance_valid(target) and target.get("hp") != null and float(target.get("hp")) <= 0.0:
		kill_fx(parent, at, dir, weapon)
	if target != null and is_instance_valid(target) and target.get("model") != null and target.get("model").has_method("hit_reaction"):
		target.get("model").hit_reaction(flat, 2.8 if weapon == "trench" else 1.9)
	Sfx.play_file("tik_treffer", 0.45)
