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
		"trace_len": 1.7, "trace_w": 0.05, "trace_head": Color(1.0, 0.97, 0.78, 1.0), "trace_tail": Color(1.0, 0.5, 0.1, 0.0),
		"dust": 0.7, "hole": true, "bank": 0,
	},
	"trench": {
		"atlas": "flash_shotgun_4x4.png", "flash": 7.0, "flash_life": 0.12, "flash_int": 1.8,
		"glow": 3.6, "patch": 2.6, "patch_life": 0.14, "patch_a": 0.2,
		"light": 7.5, "light_range": 14.0, "light_life": 0.16,
		"smoke_n": 9, "smoke_size": 0.5, "smoke_grow": 3.4, "smoke_life": 1.9, "smoke_speed": 3.6, "smoke_a": 0.4,
		"sparks": 18, "kick": 0.04, "fov": 0.9, "haptic_ms": 30, "haptic_amp": 0.7,
		"trace_len": 1.0, "trace_w": 0.032, "trace_head": Color(1.0, 0.9, 0.55, 1.0), "trace_tail": Color(1.0, 0.42, 0.06, 0.0),
		"dust": 0.55, "hole": false, "bank": 1,
	},
}

const CAP := {"flash": 6, "patch": 4, "light": 3, "rook": 40, "bank": 8, "stof": 18}

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
	var z0: float = -float(p.trace_len)
	var z1 := 0.07
	for ang in [0.0, PI * 0.5]:
		var side := Vector3(cos(ang), sin(ang), 0.0) * float(p.trace_w)
		var pts := [Vector3(0, 0, z0) - side * 0.15, Vector3(0, 0, z0) + side * 0.15, Vector3(0, 0, z1) + side, Vector3(0, 0, z1) - side]
		var cols := [p.trace_tail, p.trace_tail, p.trace_head, p.trace_head]
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_color(cols[i])
			st.add_vertex(pts[i])
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, st.commit_to_arrays())
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(1.7, 1.6, 1.4)   # heldere kop met vurige staart: goed te zien op afstand, geen witte staaf
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
	var g := Vector3(at.x, 0.0, at.z)
	if weapon == "trench" and randf() > 0.4:
		_dust(parent, g, p, 0.7)   # van de negen korrels laten er een paar een volledig effect achter
		return
	_dust(parent, g, p, 1.0)
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
	if target != null and is_instance_valid(target) and target.get("model") != null and target.get("model").has_method("hit_reaction"):
		target.get("model").hit_reaction(flat, 2.8 if weapon == "trench" else 1.9)
	Sfx.play_file("tik_treffer", 0.45)
