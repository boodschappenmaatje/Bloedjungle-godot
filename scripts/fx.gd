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
	decal(parent, pos, normal, "hole", 0.35, 60.0)


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
		_flash_mesh.radius = 0.16
		_flash_mesh.height = 0.32
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.8, 0.35)
		_flash_mesh.material = mat
	var f := MeshInstance3D.new()
	f.mesh = _flash_mesh
	parent.add_child(f)
	f.global_position = pos
	parent.get_tree().create_timer(0.05).timeout.connect(f.queue_free)
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
static func explosion(parent: Node, pos: Vector3, scale := 1.0) -> void:
	Sfx.play("boom", clampf(scale, 0.6, 1.2), pos)
	var fire := _puff(18, 0.8, 3.6 * scale, true, _ramp([Color(1, 0.9, 0.5, 0.0), Color(1, 0.7, 0.2, 1.0), Color(0.8, 0.25, 0.05, 0.8), Color(0.2, 0.05, 0.02, 0.0)], [0.0, 0.12, 0.55, 1.0]), Vector2(1.5, 5.0) * scale, 0.9)
	var smoke := _puff(14, 3.2, 3.2 * scale, false, _ramp([Color(0.15, 0.13, 0.12, 0.0), Color(0.2, 0.18, 0.16, 0.85), Color(0.28, 0.27, 0.26, 0.5), Color(0.35, 0.35, 0.35, 0.0)], [0.0, 0.1, 0.55, 1.0]), Vector2(1.0, 3.0) * scale, 2.2)
	var sparks := CPUParticles3D.new()
	sparks.amount = 22
	sparks.lifetime = 0.9
	sparks.local_coords = false
	sparks.direction = Vector3.UP
	sparks.spread = 70.0
	sparks.initial_velocity_min = 4.0 * scale
	sparks.initial_velocity_max = 10.0 * scale
	sparks.gravity = Vector3(0, -16, 0)
	sparks.color = Color(1.0, 0.7, 0.25)
	var sm := BoxMesh.new()
	sm.size = Vector3(0.06, 0.06, 0.06)
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.albedo_color = Color(1.0, 0.75, 0.3)
	sm.material = smat
	sparks.mesh = sm
	for p in [fire, smoke, sparks]:
		p.one_shot = true
		p.explosiveness = 0.9
		parent.add_child(p)
		p.global_position = pos + Vector3.UP * 0.4
		p.emitting = true
		parent.get_tree().create_timer(4.5).timeout.connect(p.queue_free)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.6, 0.25)
	l.light_energy = 8.0
	l.omni_range = 14.0 * scale
	l.shadow_enabled = false
	parent.add_child(l)
	l.global_position = pos + Vector3.UP * 1.2
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.5)
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
