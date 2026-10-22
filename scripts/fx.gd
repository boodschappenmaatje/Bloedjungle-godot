class_name Fx
## Effecten: bloed, stof, mondingsflits met licht, plekken op de grond (decals), explosies, vuur en rook.

const MAX_DECALS := 70

static var _flash_mesh: SphereMesh
static var _soft: GradientTexture2D
static var _tex := {}
static var _mats := {}
static var _decals: Array = []


## Zachte ronde vlek: de basis van vuur en rook.
static func soft() -> GradientTexture2D:
	if _soft == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		_soft = GradientTexture2D.new()
		_soft.gradient = g
		_soft.fill = GradientTexture2D.FILL_RADIAL
		_soft.fill_from = Vector2(0.5, 0.5)
		_soft.fill_to = Vector2(1.0, 0.5)
		_soft.width = 64
		_soft.height = 64
	return _soft


## Getekende plekken: kind "blood" (spetters), "hole" (kogelgat met schroeirand) of "scorch" (zwarte brandvlek).
static func _decal_tex(kind: String) -> ImageTexture:
	if _tex.has(kind):
		return _tex[kind]
	var n := 96
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = kind.hash()
	var blobs: Array = []
	match kind:
		"blood":
			for i in 11:
				var a := rng.randf() * TAU
				var d := rng.randf_range(0.0, 0.34) * n
				blobs.append([n / 2.0 + cos(a) * d, n / 2.0 + sin(a) * d, rng.randf_range(0.06, 0.2) * n])
		"hole":
			blobs.append([n / 2.0, n / 2.0, 0.34 * n])
			blobs.append([n / 2.0, n / 2.0, 0.14 * n])
		_:
			for i in 16:
				var a := rng.randf() * TAU
				var d := rng.randf_range(0.0, 0.3) * n
				blobs.append([n / 2.0 + cos(a) * d, n / 2.0 + sin(a) * d, rng.randf_range(0.18, 0.3) * n])
	for y in n:
		for x in n:
			var a := 0.0
			for b in blobs:
				var dd: float = Vector2(x - b[0], y - b[1]).length() / b[2]
				a = maxf(a, clampf(1.0 - dd, 0.0, 1.0))
			if a > 0.0:
				var col := Color(0.22, 0.015, 0.015)
				if kind == "hole":
					col = Color(0.02, 0.02, 0.02)
				elif kind == "scorch":
					col = Color(0.03, 0.03, 0.025)
				img.set_pixel(x, y, Color(col.r, col.g, col.b, clampf(a * 2.4, 0.0, 0.95)))
	var t := ImageTexture.create_from_image(img)
	_tex[kind] = t
	return t


## Legt een plek op een oppervlak (normal = waar het oppervlak naartoe kijkt). Oudste verdwijnen vanzelf.
static func decal(parent: Node, pos: Vector3, normal: Vector3, kind: String, size: float, life := 40.0) -> void:
	var d := Decal.new()
	d.texture_albedo = _decal_tex(kind)
	d.size = Vector3(size, 0.6, size)
	d.distance_fade_enabled = true
	d.distance_fade_begin = 55.0
	d.distance_fade_length = 15.0
	parent.add_child(d)
	var y := normal.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	d.global_transform = Transform3D(Basis(x, y, z).rotated(y, randf() * TAU), pos + y * 0.05)
	_decals.append(d)
	while _decals.size() > MAX_DECALS:
		var old = _decals.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	var tw := d.create_tween()
	tw.tween_interval(life)
	tw.tween_property(d, "modulate:a", 0.0, 6.0)
	tw.tween_callback(d.queue_free)


## Bloedplek op de grond onder een plek in de lucht.
static func ground_blood(parent: Node, pos: Vector3, size := 1.2) -> void:
	decal(parent, Vector3(pos.x, 0.0, pos.z), Vector3.UP, "blood", size)


static func blood(parent: Node, pos: Vector3, dir: Vector3, amount := 14) -> void:
	_burst(parent, pos, dir, amount, Color(0.42, 0.02, 0.02), 0.07, 5.0)


static func dust(parent: Node, pos: Vector3) -> void:
	_burst(parent, pos, Vector3.UP, 6, Color(0.55, 0.5, 0.42), 0.05, 2.5)


## Inslag in een muur of bunker: stof en een kogelgat.
static func impact(parent: Node, pos: Vector3, normal: Vector3) -> void:
	dust(parent, pos)
	spark(parent, pos, normal)
	decal(parent, pos, normal, "hole", 0.35, 60.0)


## Felle vonkjes met een korte flits: inslag in muur of bunker, en bij een raak op een mens.
static func spark(parent: Node, pos: Vector3, normal: Vector3) -> void:
	_flash_quad(parent, pos, randf_range(0.35, 0.55), 0.06, Color(1.0, 0.85, 0.5, 0.9))
	_burst(parent, pos, normal, 5, Color(1.0, 0.8, 0.4), 0.035, 7.0)


static func _flash_quad(parent: Node, pos: Vector3, size: float, life: float, col: Color) -> void:
	if not _mats.has("flash"):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.albedo_texture = soft()
		m.albedo_color = Color(1.0, 0.72, 0.3, 0.8)
		m.no_depth_test = true
		_mats["flash"] = m
		var q := QuadMesh.new()
		q.size = Vector2.ONE
		q.material = m
		_mats["flash_mesh"] = q
	var f := MeshInstance3D.new()
	f.mesh = _mats["flash_mesh"]
	f.scale = Vector3.ONE * size
	f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(f)
	f.global_position = pos
	parent.get_tree().create_timer(life).timeout.connect(f.queue_free)


## Uitgeworpen huls: vliegt in een boogje weg, stuitert niet maar blijft even liggen.
static var _casing_mesh: Mesh
static var _casings := 0


static func casing(parent: Node, pos: Vector3) -> void:
	if _casings >= 36:
		return
	if _casing_mesh == null:
		# het echte hulsmodel uit bron/wapens; terugval op een blokje
		var holder: Node = (load("res://assets/wapens.glb") as PackedScene).instantiate()
		var mi := holder.find_child("Huls_Messing", true, false) as MeshInstance3D
		if mi:
			_casing_mesh = mi.mesh
		holder.free()
	if _casing_mesh == null:
		var bx := BoxMesh.new()
		bx.size = Vector3(0.025, 0.025, 0.075)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.85, 0.62, 0.22)
		mat.metallic = 0.7
		mat.roughness = 0.35
		bx.material = mat
		_casing_mesh = bx
	var c := MeshInstance3D.new()
	c.mesh = _casing_mesh
	c.scale = Vector3.ONE * 1.8  # iets groter dan echt, anders zie je ze niet
	c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(c)
	c.global_position = pos
	_casings += 1
	c.tree_exited.connect(func(): _casings -= 1)
	var a := randf() * TAU
	var v := Vector3(cos(a), 0.0, sin(a)) * randf_range(1.2, 2.6) + Vector3.UP * randf_range(2.0, 3.2)
	var g := 9.8
	var y0 := maxf(pos.y - 0.03, 0.0)
	var d := (v.y + sqrt(v.y * v.y + 2.0 * g * y0)) / g
	var spin := Vector3(randf_range(-25.0, 25.0), randf_range(-25.0, 25.0), randf_range(-25.0, 25.0))
	var tw := c.create_tween()
	tw.tween_method(func(t: float):
		c.global_position = pos + Vector3(v.x * t, v.y * t - 0.5 * g * t * t, v.z * t)
		c.rotation = spin * t, 0.0, d, d)
	tw.tween_interval(9.0)
	tw.tween_property(c, "scale", Vector3.ZERO, 1.0)
	tw.tween_callback(c.queue_free)


static func _burst(parent: Node, pos: Vector3, dir: Vector3, amount: int, col: Color, size: float, spd: float) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.6
	p.explosiveness = 1.0
	p.direction = (dir + Vector3.UP * 0.6).normalized()
	p.spread = 35.0
	p.initial_velocity_min = spd * 0.4
	p.initial_velocity_max = spd
	p.gravity = Vector3(0, -14, 0)
	p.scale_amount_min = 0.6
	var m := BoxMesh.new()
	m.size = Vector3.ONE * size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material = mat
	p.mesh = m
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)


## Mondingsflits: een felgele bol die na een paar honderdsten verdwijnt.
static var _flash_lights := 0


static func muzzle(parent: Node, pos: Vector3) -> void:
	if _flash_mesh == null:
		_flash_mesh = SphereMesh.new()
		_flash_mesh.radius = 0.09
		_flash_mesh.height = 0.18
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.8, 0.35)
		_flash_mesh.material = mat
	var f := MeshInstance3D.new()
	f.mesh = _flash_mesh
	parent.add_child(f)
	f.global_position = pos
	parent.get_tree().create_timer(0.05).timeout.connect(f.queue_free)
	_flash_quad(parent, pos, randf_range(0.45, 0.65), 0.05, Color.WHITE)
	_burst(parent, pos, Vector3.UP * 0.2, 4, Color(1.0, 0.8, 0.4), 0.03, 6.0)
	# hooguit twee flitslichten tegelijk: elk licht kost op de telefoon beeldkracht en vertraagt drukke gevechten
	if _flash_lights < 2:
		_flash_lights += 1
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.75, 0.4)
		l.light_energy = 3.0
		l.omni_range = 7.0
		l.shadow_enabled = false
		f.add_child(l)
		l.tree_exited.connect(func(): _flash_lights -= 1)


static func _particle_mat(col: Color, additive: bool) -> StandardMaterial3D:
	var key := "p%s%s" % [col.to_html(), additive]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		m.albedo_texture = soft()
		m.albedo_color = col
		m.no_depth_test = false
		_mats[key] = m
	return _mats[key]


static func _puff(amount: int, life: float, size: float, additive: bool, ramp: Gradient, vel: Vector2, grow: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 50.0
	p.initial_velocity_min = vel.x
	p.initial_velocity_max = vel.y
	p.gravity = Vector3(0, 0.6 if not additive else 0.0, 0)
	p.color_ramp = ramp
	p.scale_amount_min = size * 0.7
	p.scale_amount_max = size * 1.2
	var c := Curve.new()
	c.add_point(Vector2(0, 0.45))
	c.add_point(Vector2(1, grow))
	p.scale_amount_curve = c
	p.angle_min = -180.0
	p.angle_max = 180.0
	p.mesh = _quad()
	p.mesh.material = _particle_mat(Color.WHITE, additive)
	return p


static func _quad() -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	return q


static func _ramp(cols: Array, offs: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offs)
	g.colors = PackedColorArray(cols)
	return g


## Explosie: vuurbal, rook, vonken, een lichtflits en een zwarte vlek op de grond.
static func explosion(parent: Node, pos: Vector3, scale := 1.0, chunks: Array = CHUNKS_GROUND) -> void:
	Sfx.play("boom", clampf(scale, 0.6, 1.2), pos)
	PerfMonitor.note("explosie")
	_fireball(parent, pos, scale)
	_debris(parent, pos, scale, chunks)
	# vonkenregen: lichtstrepen die langs hun vliegrichting wijzen, en aarde die wegspat
	var sparks := _spray(48, 1.2, Vector3(0.025, 0.24, 0.025), Color(1.0, 0.8, 0.35), 6.0 * scale, 15.0 * scale, 72.0, 16.0, true)
	var dirt := _spray(30, 1.3, Vector3(0.11, 0.11, 0.11), Color(0.2, 0.14, 0.09), 3.0 * scale, 8.0 * scale, 80.0, 18.0, false)
	for p in [sparks, dirt]:
		p.one_shot = true
		p.explosiveness = 0.95
		parent.add_child(p)
		p.global_position = pos + Vector3.UP * 0.3
		p.emitting = true
		parent.get_tree().create_timer(4.5).timeout.connect(p.queue_free)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.6, 0.25)
	l.light_energy = 14.0
	l.omni_range = 20.0 * scale
	l.shadow_enabled = false
	parent.add_child(l)
	l.global_position = pos + Vector3.UP * 1.2
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 5.0, 0.12)
	tw.tween_property(l, "light_energy", 0.0, 0.9)
	tw.tween_callback(l.queue_free)
	decal(parent, Vector3(pos.x, 0.0, pos.z), Vector3.UP, "scorch", 3.6 * scale, 80.0)


## Blijvende rook of vuur op een plek (bijvoorbeeld op een beschadigde bunker). Geeft de knoop terug.
static func burning(parent: Node, pos: Vector3, flames: bool) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = pos
	var smoke := _puff(10, 3.0, 1.6, false, _ramp([Color(0.1, 0.1, 0.1, 0.0), Color(0.18, 0.17, 0.16, 0.7), Color(0.3, 0.3, 0.3, 0.0)], [0.0, 0.2, 1.0]), Vector2(0.8, 1.6), 2.4)
	smoke.position = Vector3(0, 0.6, 0)
	root.add_child(smoke)
	smoke.emitting = true
	if flames:
		var f := _puff(8, 0.7, 1.0, true, _ramp([Color(1, 0.85, 0.4, 0.0), Color(1, 0.55, 0.15, 0.9), Color(0.6, 0.15, 0.03, 0.0)], [0.0, 0.2, 1.0]), Vector2(0.6, 1.4), 0.5)
		root.add_child(f)
		f.emitting = true
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.55, 0.2)
		l.light_energy = 2.5
		l.omni_range = 7.0
		l.shadow_enabled = false
		l.position = Vector3(0, 0.8, 0)
		root.add_child(l)
		var tw := l.create_tween().set_loops()
		tw.tween_property(l, "light_energy", 1.6, 0.13)
		tw.tween_property(l, "light_energy", 3.0, 0.17)
	return root


const FLIPBOOK := preload("res://shaders/flipbook.gdshader")
const FIREBALL_TIME := 2.4  # seconden voor de hele beeldreeks
const MAX_FIREBALLS := 4  # meer tegelijk tekenen kost een telefoon te veel; extra explosies houden vonken, licht en puin
# Elke variant komt uit een eigen Blender-render (bron/explosie, andere ruis en vorm); size = afmeting in meters van het uitgesneden beeld
const FIREBALLS := [
	{"sheet": preload("res://assets/fx/explosie_vuur.png"), "cols": 6, "rows": 6, "frames": 36, "size": Vector2(7.06, 7.92)},  # de eerste: middelhoog
	{"sheet": preload("res://assets/fx/explosie_vuur2.png"), "cols": 6, "rows": 5, "frames": 30, "size": Vector2(7.06, 8.0)},  # hoog met een grote rookkop
	{"sheet": preload("res://assets/fx/explosie_vuur3.png"), "cols": 6, "rows": 5, "frames": 30, "size": Vector2(7.53, 6.8)},  # laag en breed: een grondexplosie
]
static var _fire_quad := {}
static var _fireballs_live := 0
static var _last_variant := -1


## Vuurbal met rook: een beeldreeks uit Blender op een vlak dat naar de camera kijkt, met de voet op de grond.
## Elke explosie kiest een andere variant (niet twee keer dezelfde achter elkaar), soms gespiegeld en iets groter of kleiner.
static func _fireball(parent: Node, pos: Vector3, scale: float) -> void:
	if _fireballs_live >= MAX_FIREBALLS:
		return
	var v := randi() % FIREBALLS.size()
	if FIREBALLS.size() > 1 and v == _last_variant:
		v = (v + 1 + randi() % (FIREBALLS.size() - 1)) % FIREBALLS.size()
	_last_variant = v
	var def: Dictionary = FIREBALLS[v]
	if not _fire_quad.has(v):
		var q := QuadMesh.new()
		q.size = def.size
		q.center_offset = Vector3(0.0, def.size.y * 0.5, 0.0)  # draaipunt = de voet, zodat de vuurbal niet wegkantelt van de grond
		_fire_quad[v] = q
	var size := 1.2 * scale * randf_range(0.92, 1.1)  # in Blender is de vuurbal zo'n 4 m breed; bij schaal 1 wordt hij ~5 m
	var m := ShaderMaterial.new()
	m.shader = FLIPBOOK
	m.set_shader_parameter("sheet", def.sheet)
	m.set_shader_parameter("cols", def.cols)
	m.set_shader_parameter("rows", def.rows)
	m.set_shader_parameter("frames", def.frames)
	m.set_shader_parameter("flip_x", randf() < 0.5)
	var mi := MeshInstance3D.new()
	mi.mesh = _fire_quad[v]
	mi.material_override = m
	mi.scale = Vector3(size, size, size)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos + Vector3(0.0, -0.05, 0.0)  # voet van het beeld = grond
	_fireballs_live += 1
	var tw := mi.create_tween()
	tw.tween_method(func(t: float): m.set_shader_parameter("progress", t), 0.0, 1.0, FIREBALL_TIME * (0.6 + 0.4 * scale))
	tw.tween_callback(func():
		_fireballs_live -= 1
		mi.queue_free())
	mi.tree_exiting.connect(func():
		if tw.is_valid():
			_fireballs_live = maxi(0, _fireballs_live - 1))


const FLAME_SHEET := preload("res://assets/fx/vlam.png")  # bron/explosie/maak_vlam.py: lus van 16 beeldjes
const FLAME_FRAME := 3.2  # meter per beeld in Blender
const FLAME_HEIGHT := 2.24  # zichtbare hoogte van de vlam in dat beeld
static var _flame_quad: QuadMesh


## Een flikkerende lus-vlam met schijnsel (brandend vat, wrak). height = zichtbare hoogte in meters. Geeft de knoop terug.
static func flame(parent: Node3D, local_pos: Vector3, height: float, light := true) -> Node3D:
	if _flame_quad == null:
		_flame_quad = QuadMesh.new()
		_flame_quad.size = Vector2(FLAME_FRAME, FLAME_FRAME)
		_flame_quad.center_offset = Vector3(0.0, FLAME_FRAME * 0.5, 0.0)  # draaipunt = de voet van de vlam: hij blijft in het vat staan
	var k := height / FLAME_HEIGHT
	var root := Node3D.new()
	parent.add_child(root)
	root.position = local_pos
	var m := ShaderMaterial.new()
	m.shader = FLIPBOOK
	m.set_shader_parameter("sheet", FLAME_SHEET)
	m.set_shader_parameter("cols", 4)
	m.set_shader_parameter("rows", 4)
	m.set_shader_parameter("frames", 16)
	m.set_shader_parameter("looping", true)
	m.set_shader_parameter("flip_x", randf() < 0.5)
	var mi := MeshInstance3D.new()
	mi.mesh = _flame_quad
	mi.material_override = m
	mi.scale = Vector3(k, k, k)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	var tw := root.create_tween().set_loops()
	tw.tween_method(func(t: float): m.set_shader_parameter("progress", t), 0.0, 1.0, 0.6)
	if light:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.55, 0.2)
		l.light_energy = 3.2
		l.omni_range = 6.0 + height * 2.5
		l.shadow_enabled = false
		l.position = Vector3(0.0, height * 0.5, 0.0)
		root.add_child(l)
		var lt := l.create_tween().set_loops()
		lt.tween_property(l, "light_energy", 1.9, 0.11)
		lt.tween_property(l, "light_energy", 3.8, 0.15)
	return root


const WRECK_BURN_TIME := 9.0
const WRECK_STAY := 4.0


## Het uitgebrande vat blijft liggen: verkoold wrak met een vlam die langzaam dooft en rook; daarna verdwijnt het.
static func wreck(parent: Node, pos: Vector3) -> void:
	var mesh := _chunk("Wrak1" if randf() < 0.5 else "Wrak2")
	if mesh == null:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.rotation.y = randf() * TAU
	parent.add_child(mi)
	mi.global_position = Vector3(pos.x, 0.0, pos.z)
	var fire := flame(parent, Vector3(pos.x, 0.45, pos.z), 0.8)
	var smoke := burning(parent, Vector3(pos.x, 0.0, pos.z), false)
	var tw := mi.create_tween()
	tw.tween_interval(WRECK_BURN_TIME)
	tw.tween_callback(func():
		if is_instance_valid(fire):
			var ft := fire.create_tween()
			ft.tween_property(fire, "scale", Vector3(1.0, 0.0, 1.0), 1.5)
			ft.tween_callback(fire.queue_free))
	tw.tween_interval(WRECK_STAY)
	tw.tween_property(mi, "scale", Vector3.ZERO, 1.0)
	tw.tween_callback(func():
		if is_instance_valid(smoke):
			smoke.queue_free()
		mi.queue_free())


const DEBRIS_MODELS := preload("res://assets/fx/brokstukken.glb")  # bron/explosie: stukken vatblik, splinters, aardkluiten
const CHUNKS_GROUND := ["Kluit1", "Kluit2", "Splinter1", "Splinter2"]
const CHUNKS_BARREL := ["Plaat1", "Plaat2", "Plaat3", "Band", "Splinter1", "Kluit1"]
static var _chunk_mesh := {}


static func _chunk(name: String) -> Mesh:
	if not _chunk_mesh.has(name):
		var holder := DEBRIS_MODELS.instantiate()
		var mi := holder.find_child(name, true, false) as MeshInstance3D
		_chunk_mesh[name] = mi.mesh if mi != null else null
		holder.queue_free()
	return _chunk_mesh[name]


## Rondvliegende brokstukken uit Blender: elk stuk vliegt in een boog, tolt om alle assen en blijft even liggen.
static func _debris(parent: Node, pos: Vector3, scale: float, names: Array) -> void:
	var count := 8 + roundi(8.0 * scale)
	for i in count:
		var mesh := _chunk(names[i % names.size()])
		if mesh == null:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var sc := randf_range(0.8, 1.5) * (0.7 + 0.4 * scale)
		mi.scale = Vector3.ONE * sc
		parent.add_child(mi)
		var a := randf() * TAU
		var out := randf_range(2.5, 7.0) * scale
		var v := Vector3(cos(a) * out, randf_range(4.5, 9.0) * (0.6 + 0.4 * scale), sin(a) * out)
		var spin := Vector3(randf_range(-9.0, 9.0), randf_range(-9.0, 9.0), randf_range(-9.0, 9.0))
		var start := pos + Vector3(0.0, 0.5, 0.0)
		var g := 18.0
		var t_land := (v.y + sqrt(v.y * v.y + 2.0 * g * start.y)) / g
		mi.global_position = start
		var rest := Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		var trail: CPUParticles3D = null
		if sc > 1.0 and i % 2 == 0:
			trail = _smoke_trail()  # grotere stukken trekken een rookspoor
			mi.add_child(trail)
		var tw := mi.create_tween()
		tw.tween_method(_fly.bind(mi, start, v, spin, rest, g, t_land), 0.0, t_land, t_land)
		if trail != null:
			tw.tween_callback(func():
				if is_instance_valid(trail):
					trail.emitting = false)
		tw.tween_interval(5.0)  # brokstukken blijven even liggen
		tw.tween_property(mi, "scale", Vector3.ZERO, 0.5)
		tw.tween_callback(mi.queue_free)


static func _fly(t: float, mi: MeshInstance3D, start: Vector3, v: Vector3, spin: Vector3, rest: Vector3, g: float, t_land: float) -> void:
	if not is_instance_valid(mi):
		return
	var p := start + Vector3(v.x * t, v.y * t - 0.5 * g * t * t, v.z * t)
	mi.global_position = Vector3(p.x, maxf(p.y, 0.03), p.z)
	mi.rotation = rest + spin * minf(t, t_land)


## Opstijgende vonken (brandend vat): kleine lichtstrepen die omhoog vliegen en terugvallen. Geeft de knoop terug.
static func embers(parent: Node3D, local_pos: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 14
	p.lifetime = 1.1
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 40.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 4.2
	p.gravity = Vector3(0.0, -6.0, 0.0)
	p.particle_flag_align_y = true  # de streep wijst langs de vliegrichting
	var bm := BoxMesh.new()
	bm.size = Vector3(0.025, 0.14, 0.025)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.65, 0.2)
	bm.material = mat
	p.mesh = bm
	p.color_ramp = _ramp([Color(1.0, 0.85, 0.4, 1.0), Color(1.0, 0.4, 0.08, 0.8), Color(0.5, 0.1, 0.02, 0.0)], [0.0, 0.5, 1.0])
	parent.add_child(p)
	p.position = local_pos
	p.emitting = true
	return p


## Een uitbarsting van deeltjes uit één punt. streak = de deeltjes wijzen langs hun vliegrichting (vonken als lichtstreepjes).
static func _spray(amount: int, life: float, box: Vector3, color: Color, vmin: float, vmax: float, spread: float, gravity: float, streak: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = spread
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.gravity = Vector3(0.0, -gravity, 0.0)
	p.particle_flag_align_y = streak
	var bm := BoxMesh.new()
	bm.size = box
	var mat := StandardMaterial3D.new()
	if streak:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	bm.material = mat
	p.mesh = bm
	if streak:
		p.color_ramp = _ramp([Color(1.0, 0.9, 0.5, 1.0), Color(1.0, 0.5, 0.1, 1.0), Color(0.6, 0.15, 0.03, 0.0)], [0.0, 0.5, 1.0])
	return p


static func _smoke_trail() -> CPUParticles3D:
	var p := _puff(10, 0.9, 0.5, false, _ramp([Color(0.12, 0.11, 0.1, 0.0), Color(0.18, 0.17, 0.16, 0.6), Color(0.3, 0.3, 0.3, 0.0)], [0.0, 0.15, 1.0]), Vector2(0.1, 0.3), 1.6)
	p.one_shot = false
	p.local_coords = false
	p.emitting = true
	return p
