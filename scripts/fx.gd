class_name Fx
## Effecten: bloed, stof, mondingsflits met licht, plekken op de grond (decals), explosies, vuur en rook.

const MAX_DECALS := 70
const MAX_CASINGS := 36
const MAX_MUZZLE_SMOKE := 16
const MAX_ROCKET_TRAILS := 3
const MAX_MUZZLE_FLASHES := 18
const MAX_FLASH_LIGHTS := 2
const MAX_FLASH_QUADS := 48
const MAX_BURST_NODES := 64
const MAX_ACTIVE_BURSTS := 40

static var _muzzle_meshes := {}
static var _muzzle_flash_pool: Array[Node3D] = []
static var _muzzle_flash_live := 0
static var _flash_quad_pools := {}
static var _flash_quad_live := 0
static var _flash_quad_nodes := 0
static var _burst_pools := {}
static var _burst_nodes := 0
static var _burst_live := 0
static var _muzzle_smoke_mesh: QuadMesh
static var _muzzle_smoke_mat: StandardMaterial3D
static var _muzzle_smoke_pool: Array[MeshInstance3D] = []
static var _muzzle_smoke_live := 0
static var _rocket_trails_live := 0
static var _rocket_flame_mesh: ArrayMesh
static var _soft: GradientTexture2D
static var _impact_star_texture: ImageTexture
static var _tex := {}
static var _mats := {}
static var _decals: Array = []


## Kleine telling voor tests/debug; heeft geen invloed op het spelverloop.
static func combat_counts() -> Dictionary:
	return {"casings": _casings, "pooled_casings": _casing_pool.size(), "muzzle_smoke": _muzzle_smoke_live, "pooled_muzzle_smoke": _muzzle_smoke_pool.size(), "muzzle_flashes": _muzzle_flash_live, "pooled_muzzle_flashes": _muzzle_flash_pool.size(), "flash_quads": _flash_quad_live, "burst_nodes": _burst_nodes, "burst_live": _burst_live, "rocket_trails": _rocket_trails_live, "flash_lights": _flash_lights}


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


static func blood(parent: Node, pos: Vector3, dir: Vector3, amount := 14, color := Color(0.52, 0.015, 0.015)) -> void:
	_burst(parent, pos, dir, maxi(amount, 20), color, 0.085, 6.0)


static func dust(parent: Node, pos: Vector3) -> void:
	_burst(parent, pos, Vector3.UP, 9, Color(0.58, 0.52, 0.42), 0.055, 2.8)


## Inslagreactie op aarde, hout, metaal of steen/beton.
static func impact(parent: Node, pos: Vector3, normal: Vector3, material := "concrete") -> void:
	match material:
		"dirt":
			_burst(parent, pos, normal, 11, Color(0.34, 0.24, 0.13), 0.055, 4.5, Vector3(0.05, 0.04, 0.05))
			_burst(parent, pos, normal, 7, Color(0.58, 0.48, 0.33, 0.8), 0.1, 2.0)
		"wood":
			_burst(parent, pos, normal, 8, Color(0.62, 0.37, 0.17), 0.08, 5.2, Vector3(0.03, 0.11, 0.02))
			_burst(parent, pos, normal, 5, Color(0.54, 0.4, 0.26, 0.76), 0.09, 2.0)
		"metal":
			spark(parent, pos, normal)
		_:
			dust(parent, pos)
			_burst(parent, pos, normal, 7, Color(0.46, 0.44, 0.4), 0.065, 3.8, Vector3(0.06, 0.05, 0.055))
			_flash_quad(parent, pos + normal.normalized() * 0.03, 0.3, 0.06, Color(1.0, 0.82, 0.5, 0.9))
			decal(parent, pos, normal, "hole", 0.42, 60.0)


## Felle vonkjes met een korte flits: inslag in muur of bunker, en bij een raak op een mens.
static func spark(parent: Node, pos: Vector3, normal: Vector3) -> void:
	_flash_quad(parent, pos + normal.normalized() * 0.035, randf_range(0.34, 0.48), 0.075, Color(1.0, 0.62, 0.12, 0.96), "star")
	_burst(parent, pos, normal, 8, Color(1.0, 0.58, 0.12), 0.03, 8.5, Vector3(0.02, 0.075, 0.02))


static func _impact_star() -> ImageTexture:
	if _impact_star_texture != null:
		return _impact_star_texture
	var side := 96
	var img := Image.create(side, side, false, Image.FORMAT_RGBA8)
	img.fill(Color(1.0, 1.0, 1.0, 0.0))
	for y in side:
		for x in side:
			var p := Vector2((float(x) + 0.5) / side * 2.0 - 1.0, (float(y) + 0.5) / side * 2.0 - 1.0)
			var radius := p.length()
			if radius > 1.0:
				continue
			var angle := atan2(p.y, p.x)
			var ray := pow(absf(cos(angle * 4.0)), 9.0)
			var reach := lerpf(0.25, 0.96, ray)
			var edge_alpha := clampf((reach - radius) * 14.0, 0.0, 1.0)
			var center_alpha := clampf((0.27 - radius) * 8.0, 0.0, 1.0)
			var fade := clampf((1.0 - radius) * 7.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, maxf(edge_alpha, center_alpha) * fade))
	_impact_star_texture = ImageTexture.create_from_image(img)
	return _impact_star_texture


static func _flash_quad(parent: Node, pos: Vector3, size: float, life: float, col: Color, shape := "soft") -> void:
	var key := "flash_quad_%s_%s" % [shape, col.to_html(true)]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.albedo_texture = _impact_star() if shape == "star" else soft()
		m.albedo_color = col
		m.no_depth_test = false
		var q := QuadMesh.new()
		q.size = Vector2.ONE
		q.material = m
		_mats[key] = q
	var pool: Array = _flash_quad_pools.get(key, [])
	var f: MeshInstance3D
	while not pool.is_empty() and f == null:
		var candidate: MeshInstance3D = pool.pop_back()
		if is_instance_valid(candidate):
			f = candidate
	if f == null:
		if _flash_quad_nodes >= MAX_FLASH_QUADS:
			return
		f = MeshInstance3D.new()
		f.name = "PooledFlashQuad"
		f.mesh = _mats[key]
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		f.tree_exiting.connect(_on_flash_quad_tree_exiting.bind(f))
		_flash_quad_nodes += 1
	if f.get_parent() != parent:
		if f.get_parent() != null:
			f.reparent(parent)
		else:
			parent.add_child(f)
	f.visible = true
	f.set_meta("fx_active", true)
	f.set_meta("fx_pool_key", key)
	_flash_quad_live += 1
	f.scale = Vector3.ONE * size
	f.transparency = 0.0
	f.global_position = pos
	var tw := f.create_tween()
	tw.tween_property(f, "scale", Vector3.ONE * size * 0.3, life)
	tw.parallel().tween_property(f, "transparency", 1.0, life)
	tw.tween_callback(_release_flash_quad.bind(f, key))


static func _release_flash_quad(f: MeshInstance3D, key: String) -> void:
	if not is_instance_valid(f) or not f.get_meta("fx_active", false):
		return
	f.set_meta("fx_active", false)
	_flash_quad_live = maxi(0, _flash_quad_live - 1)
	f.visible = false
	f.scale = Vector3.ONE
	f.transparency = 0.0
	var pool: Array = _flash_quad_pools.get(key, [])
	pool.append(f)
	_flash_quad_pools[key] = pool


static func _on_flash_quad_tree_exiting(f: MeshInstance3D) -> void:
	for key in _flash_quad_pools:
		_flash_quad_pools[key].erase(f)
	if is_instance_valid(f) and f.get_meta("fx_active", false):
		f.set_meta("fx_active", false)
		_flash_quad_live = maxi(0, _flash_quad_live - 1)
	_flash_quad_nodes = maxi(0, _flash_quad_nodes - 1)


## Uitgeworpen huls: vliegt in een boogje weg, stuitert niet maar blijft even liggen.
static var _casing_mesh: Mesh
static var _casings := 0
static var _casing_pool: Array[MeshInstance3D] = []


static func casing(parent: Node, pos: Vector3, eject_right := Vector3.RIGHT, forward := Vector3.FORWARD) -> void:
	if _casings >= MAX_CASINGS or not _near_camera(parent, pos, 42.0):
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
	var c: MeshInstance3D
	while not _casing_pool.is_empty() and c == null:
		var candidate: MeshInstance3D = _casing_pool.pop_back()
		if is_instance_valid(candidate):
			c = candidate
	if c == null:
		c = MeshInstance3D.new()
		c.mesh = _casing_mesh
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		c.tree_exiting.connect(_on_casing_tree_exiting.bind(c))
	if c.get_parent() != parent:
		if c.get_parent() != null:
			c.reparent(parent)
		else:
			parent.add_child(c)
	c.visible = true
	c.scale = Vector3.ONE * 1.45
	c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	c.global_position = pos
	c.set_meta("casing_active", true)
	_casings += 1
	var side := eject_right.normalized() if eject_right.length() > 0.01 else Vector3.RIGHT
	var fwd := forward.normalized() if forward.length() > 0.01 else Vector3.FORWARD
	var v := side * randf_range(1.25, 2.1) + fwd * randf_range(-0.45, 0.45) + Vector3.UP * randf_range(2.0, 2.8)
	var g := 9.8
	var y0 := maxf(pos.y - 0.03, 0.0)
	var d := (v.y + sqrt(v.y * v.y + 2.0 * g * y0)) / g
	var spin := Vector3(randf_range(-25.0, 25.0), randf_range(-25.0, 25.0), randf_range(-25.0, 25.0))
	var tw := c.create_tween()
	tw.tween_method(func(t: float):
		c.global_position = pos + Vector3(v.x * t, v.y * t - 0.5 * g * t * t, v.z * t)
		c.rotation = spin * t, 0.0, d, d)
	tw.tween_interval(0.9)
	tw.tween_property(c, "scale", Vector3.ZERO, 0.28)
	tw.tween_callback(_recycle_casing.bind(c))


static func _recycle_casing(c: MeshInstance3D) -> void:
	if not is_instance_valid(c) or not c.get_meta("casing_active", false):
		return
	c.set_meta("casing_active", false)
	_casings = maxi(0, _casings - 1)
	c.visible = false
	c.scale = Vector3.ONE
	c.position = Vector3.ZERO
	if _casing_pool.size() < MAX_CASINGS:
		_casing_pool.append(c)
	else:
		c.queue_free()


static func _on_casing_tree_exiting(c: MeshInstance3D) -> void:
	_casing_pool.erase(c)
	if is_instance_valid(c) and c.get_meta("casing_active", false):
		c.set_meta("casing_active", false)
		_casings = maxi(0, _casings - 1)


static func _near_camera(parent: Node, pos: Vector3, max_distance: float) -> bool:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return true
	var camera := parent.get_viewport().get_camera_3d()
	return camera == null or camera.global_position.distance_to(pos) <= max_distance


static func _burst(parent: Node, pos: Vector3, dir: Vector3, amount: int, col: Color, size: float, spd: float, mesh_size := Vector3.ZERO) -> void:
	if _burst_live >= MAX_ACTIVE_BURSTS or not _near_camera(parent, pos, 48.0):
		return
	var key := "%d:%s:%.3f:%.3f:%s" % [amount, col.to_html(true), size, spd, str(mesh_size)]
	var pool: Array = _burst_pools.get(key, [])
	var p: CPUParticles3D
	while not pool.is_empty() and p == null:
		var candidate: CPUParticles3D = pool.pop_back()
		if is_instance_valid(candidate):
			p = candidate
	if p == null:
		if _burst_nodes >= MAX_BURST_NODES:
			return
		p = CPUParticles3D.new()
		p.name = "PooledImpactBurst"
		p.one_shot = true
		p.amount = amount
		p.lifetime = 0.48
		p.explosiveness = 1.0
		p.spread = 35.0
		p.initial_velocity_min = spd * 0.4
		p.initial_velocity_max = spd
		p.gravity = Vector3(0, -14, 0)
		p.scale_amount_min = 0.6
		var m := BoxMesh.new()
		m.size = mesh_size if mesh_size != Vector3.ZERO else Vector3.ONE * size
		var mat := StandardMaterial3D.new()
		mat.albedo_color = col
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.material = mat
		p.mesh = m
		p.angular_velocity_min = -220.0
		p.angular_velocity_max = 220.0
		p.set_meta("burst_pool_key", key)
		p.finished.connect(_release_burst.bind(p, key))
		p.tree_exiting.connect(_on_burst_tree_exiting.bind(p))
		_burst_nodes += 1
	if p.get_parent() != parent:
		if p.get_parent() != null:
			p.reparent(parent)
		else:
			parent.add_child(p)
	p.visible = true
	p.set_meta("fx_active", true)
	_burst_live += 1
	p.global_position = pos
	p.direction = (dir + Vector3.UP * 0.6).normalized()
	p.emitting = false
	p.restart()
	p.emitting = true


static func _release_burst(p: CPUParticles3D, key: String) -> void:
	if not is_instance_valid(p) or not p.get_meta("fx_active", false):
		return
	p.set_meta("fx_active", false)
	_burst_live = maxi(0, _burst_live - 1)
	p.emitting = false
	p.visible = false
	var pool: Array = _burst_pools.get(key, [])
	pool.append(p)
	_burst_pools[key] = pool


static func _on_burst_tree_exiting(p: CPUParticles3D) -> void:
	for key in _burst_pools:
		_burst_pools[key].erase(p)
	if is_instance_valid(p) and p.get_meta("fx_active", false):
		p.set_meta("fx_active", false)
		_burst_live = maxi(0, _burst_live - 1)
	_burst_nodes = maxi(0, _burst_nodes - 1)


## Mondingsflits: een felgele bol die na een paar honderdsten verdwijnt.
static var _flash_lights := 0


static func _muzzle_triangle(st: SurfaceTool, a: Vector3, ca: Color, b: Vector3, cb: Color, c: Vector3, cc: Color) -> void:
	st.set_color(ca)
	st.add_vertex(a)
	st.set_color(cb)
	st.add_vertex(b)
	st.set_color(cc)
	st.add_vertex(c)


static func _muzzle_mesh(weapon: String, variant: int) -> ArrayMesh:
	var key := "%s:%d" % [weapon, variant]
	if _muzzle_meshes.has(key):
		return _muzzle_meshes[key]
	var v: Dictionary = Data.WEAPON_VISUALS.get(weapon, Data.WEAPON_VISUALS["m1911"])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var length: float = v.flash_length * 0.62 * rng.randf_range(0.91, 1.08)
	var width: float = v.flash_width * 0.7 * rng.randf_range(0.88, 1.12)
	var hot := Color(1.0, 0.9, 0.48, 0.98)
	var middle: Color = v.flash_color
	var fade := Color(middle.r, middle.g * 0.55, middle.b * 0.24, 0.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Onregelmatige, platte flitsvorm met witte kern en warme, snel uitdovende randen.
	var asymmetry := rng.randf_range(0.78, 1.22)
	for side in [-1.0, 1.0]:
		var edge := width * rng.randf_range(0.34, 0.51)
		var tip := length * rng.randf_range(0.82, 1.08) * (asymmetry if side > 0.0 else 2.0 - asymmetry)
		_muzzle_triangle(st, Vector3(0, 0.04, 0), hot, Vector3(side * edge, 0.04, length * 0.13), middle, Vector3(side * width * rng.randf_range(0.03, 0.16), 0.04, tip), fade)
		_muzzle_triangle(st, Vector3(0, 0.04, 0), hot, Vector3(side * width * 0.06, 0.04, length * 0.66), Color(middle.r, middle.g * 0.74, middle.b * 0.42, 0.56), Vector3(side * edge, 0.04, length * 0.13), middle)
		_muzzle_triangle(st, Vector3(0, 0.06, 0), Color(1.0, 0.94, 0.58), Vector3(side * width * 0.11, 0.06, length * 0.1), hot, Vector3(side * width * 0.025, 0.06, length * 0.57), Color(hot.r, hot.g * 0.72, hot.b * 0.4, 0.0))
	var m := st.commit()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.surface_set_material(0, mat)
	_muzzle_meshes[key] = m
	return m


static func muzzle(parent: Node, pos: Vector3, weapon := "m1911", angle := 0.0) -> void:
	var v: Dictionary = Data.WEAPON_VISUALS.get(weapon, Data.WEAPON_VISUALS["m1911"])
	if weapon == "bazooka" or float(v.flash_life) <= 0.0:
		return
	_show_muzzle_flash(parent, pos, _muzzle_mesh(weapon, randi() % 3), angle, v.flash_life, v.flash_width * 0.28, weapon, v.flash_particles, v.flash_color, v.flash_energy, v.flash_range)


static func _show_muzzle_flash(parent: Node, pos: Vector3, flash_mesh: ArrayMesh, angle: float, life: float, glow_size: float, smoke_style: String, particles: int, color: Color, light_energy: float, light_range: float) -> void:
	if _muzzle_flash_live >= MAX_MUZZLE_FLASHES or not _near_camera(parent, pos, 38.0):
		return
	var f: Node3D
	while not _muzzle_flash_pool.is_empty() and f == null:
		var candidate: Node3D = _muzzle_flash_pool.pop_back()
		if is_instance_valid(candidate):
			f = candidate
	if f == null:
		f = Node3D.new()
		f.name = "PooledMuzzleFlash"
		var flame := MeshInstance3D.new()
		flame.name = "Flame"
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		f.add_child(flame)
		f.tree_exiting.connect(_on_muzzle_flash_tree_exiting.bind(f))
	if f.get_parent() != parent:
		if f.get_parent() != null:
			f.reparent(parent)
		else:
			parent.add_child(f)
	var flame: MeshInstance3D = f.get_node("Flame")
	flame.mesh = flash_mesh
	flame.visible = true
	flame.scale = Vector3.ONE
	f.visible = true
	f.set_meta("fx_active", true)
	_muzzle_flash_live += 1
	f.rotation.y = angle
	f.scale = Vector3(randf_range(0.94, 1.08), 1.0, randf_range(0.92, 1.1))
	# Hef de flits net boven de loop uit; zo valt hij vanuit de gameplaycamera niet weg in de grond of het geweermodel.
	f.global_position = pos + Vector3.UP * 0.1
	var warm_light := f.get_node_or_null("WarmMuzzleLight") as OmniLight3D
	if warm_light == null and _flash_lights < MAX_FLASH_LIGHTS:
		warm_light = OmniLight3D.new()
		warm_light.name = "WarmMuzzleLight"
		warm_light.shadow_enabled = false
		f.add_child(warm_light)
		_flash_lights += 1
		warm_light.tree_exited.connect(func(): _flash_lights = maxi(0, _flash_lights - 1))
	if warm_light != null:
		var old_light_tween := f.get_meta("light_tween") as Tween if f.has_meta("light_tween") else null
		if old_light_tween != null and old_light_tween.is_valid():
			old_light_tween.kill()
		warm_light.light_color = Color(1.0, 0.55, 0.12)
		warm_light.omni_range = light_range * 0.7
		warm_light.light_energy = light_energy * 0.5
		var light_tween := f.create_tween()
		light_tween.tween_property(warm_light, "light_energy", 0.0, maxf(life, 0.2)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		f.set_meta("light_tween", light_tween)
	var tw := flame.create_tween()
	tw.tween_property(flame, "scale", Vector3(0.72, 0.78, 0.72), life)
	tw.tween_callback(func(): flame.visible = false)
	var release_tween := f.create_tween()
	release_tween.tween_interval(maxf(life, 0.2 if warm_light != null else life))
	release_tween.tween_callback(_release_muzzle_flash.bind(f))
	_flash_quad(parent, pos + Vector3.UP * 0.12, glow_size, life * 0.7, Color(1.0, 0.62, 0.18, 0.3))
	_muzzle_smoke(parent, pos - Vector3(sin(angle), 0.0, cos(angle)) * 0.05, smoke_style, angle)
	if particles > 0:
		_burst(parent, pos, Vector3.UP * 0.2, particles, color, 0.025, 4.8, Vector3(0.025, 0.035, 0.025))


static func _release_muzzle_flash(f: Node3D) -> void:
	if not is_instance_valid(f) or not f.get_meta("fx_active", false):
		return
	f.set_meta("fx_active", false)
	_muzzle_flash_live = maxi(0, _muzzle_flash_live - 1)
	f.visible = false
	f.scale = Vector3.ONE
	var flame := f.get_node_or_null("Flame") as MeshInstance3D
	if flame:
		flame.visible = false
		flame.scale = Vector3.ONE
	_muzzle_flash_pool.append(f)


static func _on_muzzle_flash_tree_exiting(f: Node3D) -> void:
	_muzzle_flash_pool.erase(f)
	if is_instance_valid(f) and f.get_meta("fx_active", false):
		f.set_meta("fx_active", false)
		_muzzle_flash_live = maxi(0, _muzzle_flash_live - 1)


static func _muzzle_smoke(parent: Node, pos: Vector3, weapon: String, angle: float) -> void:
	if _muzzle_smoke_live >= MAX_MUZZLE_SMOKE or not _near_camera(parent, pos, 30.0):
		return
	if _muzzle_smoke_mesh == null:
		_muzzle_smoke_mesh = QuadMesh.new()
		_muzzle_smoke_mesh.size = Vector2.ONE
		_muzzle_smoke_mat = StandardMaterial3D.new()
		_muzzle_smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_muzzle_smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_muzzle_smoke_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_muzzle_smoke_mat.albedo_texture = soft()
		_muzzle_smoke_mat.albedo_color = Color(0.42, 0.38, 0.31, 0.28)
		_muzzle_smoke_mat.no_depth_test = false
		_muzzle_smoke_mesh.material = _muzzle_smoke_mat
	var smoke: MeshInstance3D
	while not _muzzle_smoke_pool.is_empty() and smoke == null:
		var candidate: MeshInstance3D = _muzzle_smoke_pool.pop_back()
		if is_instance_valid(candidate):
			smoke = candidate
	if smoke == null:
		smoke = MeshInstance3D.new()
		smoke.name = "PooledMuzzleSmoke"
		smoke.mesh = _muzzle_smoke_mesh
		smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		smoke.tree_exiting.connect(_on_muzzle_smoke_tree_exiting.bind(smoke))
	if smoke.get_parent() != parent:
		if smoke.get_parent() != null:
			smoke.reparent(parent)
		else:
			parent.add_child(smoke)
	smoke.visible = true
	smoke.set_meta("fx_active", true)
	smoke.global_position = pos
	var base := 0.46 if weapon == "bazooka" else (0.36 if weapon == "trench" else 0.3)
	smoke.scale = Vector3.ONE * base * randf_range(0.8, 1.2)
	smoke.rotation.y = angle
	_muzzle_smoke_live += 1
	var duration := 0.55 if weapon == "bazooka" else (0.38 if weapon == "trench" else 0.3)
	var tw := smoke.create_tween()
	tw.tween_property(smoke, "scale", Vector3.ONE * base * 1.7, duration)
	tw.parallel().tween_property(smoke, "transparency", 1.0, duration)
	tw.parallel().tween_property(smoke, "global_position", pos + Vector3.UP * 0.09 - Vector3(sin(angle), 0.0, cos(angle)) * 0.07, duration)
	tw.tween_callback(_release_muzzle_smoke.bind(smoke))


static func _release_muzzle_smoke(smoke: MeshInstance3D) -> void:
	if not is_instance_valid(smoke) or not smoke.get_meta("fx_active", false):
		return
	smoke.set_meta("fx_active", false)
	_muzzle_smoke_live = maxi(0, _muzzle_smoke_live - 1)
	smoke.visible = false
	smoke.scale = Vector3.ONE
	smoke.transparency = 0.0
	_muzzle_smoke_pool.append(smoke)


static func _on_muzzle_smoke_tree_exiting(smoke: MeshInstance3D) -> void:
	_muzzle_smoke_pool.erase(smoke)
	if is_instance_valid(smoke) and smoke.get_meta("fx_active", false):
		smoke.set_meta("fx_active", false)
		_muzzle_smoke_live = maxi(0, _muzzle_smoke_live - 1)


static func rocket_launch(parent: Node, pos: Vector3, angle: float, _weapon := "bazooka") -> void:
	if not _near_camera(parent, pos, 34.0):
		return
	var forward := Vector3(sin(angle), 0.0, cos(angle))
	_show_muzzle_flash(parent, pos, _rocket_flash_mesh(), angle, 0.1, 0.95, "bazooka", 10, Color(1.0, 0.56, 0.19), 1.5, 4.8)
	_muzzle_smoke(parent, pos - forward * 0.3, "bazooka", angle)
	_muzzle_smoke(parent, pos - forward * 0.62, "bazooka", angle)
	_burst(parent, pos, Vector3.UP * 0.4 - forward * 0.3, 8, Color(1.0, 0.68, 0.28), 0.035, 3.6, Vector3(0.04, 0.05, 0.04))


static func rocket_trail(projectile: Node3D) -> void:
	if _rocket_trails_live >= MAX_ROCKET_TRAILS:
		return
	var smoke_ramp := _ramp([Color(0.2, 0.18, 0.15, 0.0), Color(0.34, 0.32, 0.29, 0.62), Color(0.38, 0.36, 0.32, 0.0)], [0.0, 0.2, 1.0])
	var smoke := _puff(12, 0.55, 0.32, false, smoke_ramp, Vector2(0.25, 0.75), 2.0)
	smoke.name = "RocketSmokeTrail"
	smoke.direction = Vector3(0.0, 0.0, -1.0)
	smoke.spread = 20.0
	smoke.gravity = Vector3(0.0, 0.25, 0.0)
	smoke.position = Vector3(0.0, 0.0, -0.24)
	projectile.add_child(smoke)
	smoke.emitting = true
	var flame_ramp := _ramp([Color(1.0, 0.94, 0.66, 0.96), Color(1.0, 0.42, 0.08, 0.85), Color(0.7, 0.12, 0.02, 0.0)], [0.0, 0.38, 1.0])
	var flame := _puff(8, 0.16, 0.18, true, flame_ramp, Vector2(0.45, 1.3), 0.35)
	flame.name = "RocketFlameTrail"
	flame.direction = Vector3(0.0, 0.0, -1.0)
	flame.spread = 13.0
	flame.gravity = Vector3.ZERO
	flame.position = Vector3(0.0, 0.0, -0.23)
	projectile.add_child(flame)
	flame.emitting = true
	_rocket_trails_live += 1
	projectile.tree_exiting.connect(func(): _rocket_trails_live = maxi(0, _rocket_trails_live - 1), CONNECT_ONE_SHOT)


static func _rocket_flash_mesh() -> ArrayMesh:
	if _rocket_flame_mesh != null:
		return _rocket_flame_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hot := Color(1.0, 0.98, 0.78, 1.0)
	var edge := Color(1.0, 0.58, 0.18, 0.94)
	var fade := Color(1.0, 0.28, 0.04, 0.0)
	_muzzle_triangle(st, Vector3.ZERO, hot, Vector3(-0.18, 0.015, 0.2), edge, Vector3(-0.06, 0.0, 1.15), fade)
	_muzzle_triangle(st, Vector3.ZERO, hot, Vector3(0.18, 0.015, 0.2), edge, Vector3(0.06, 0.0, 1.15), fade)
	_muzzle_triangle(st, Vector3.ZERO, Color.WHITE, Vector3(-0.08, 0.025, 0.18), hot, Vector3(0.0, 0.02, 0.88), Color(1.0, 0.75, 0.35, 0.0))
	_muzzle_triangle(st, Vector3.ZERO, Color.WHITE, Vector3(0.08, 0.025, 0.18), hot, Vector3(0.0, 0.02, 0.88), Color(1.0, 0.75, 0.35, 0.0))
	_rocket_flame_mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_rocket_flame_mesh.surface_set_material(0, mat)
	return _rocket_flame_mesh


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
	if Game.player and is_instance_valid(Game.player) and Game.player.global_position.distance_to(pos) < 32.0:
		var camera: Camera3D = Game.player.get_parent().get_node_or_null("Camera") as Camera3D
		if camera and camera.has_method("combat_impulse"):
			camera.call("combat_impulse", 0.035 * clampf(scale, 0.7, 1.4))
	_fireball(parent, pos, scale)
	_debris(parent, pos, scale, chunks)
	crater(parent, pos, scale)
	# vonkenregen: lichtstrepen die langs hun vliegrichting wijzen, en aarde die wegspat
	spray_once(parent, "vonken", pos + Vector3.UP * 0.3, 6.0 * scale, 15.0 * scale, 0.95, 1.3,
		func(): return _spray(48, 1.2, Vector3(0.025, 0.24, 0.025), Color(1.0, 0.8, 0.35), 0.0, 0.0, 72.0, 16.0, true))
	spray_once(parent, "aarde", pos + Vector3.UP * 0.3, 3.0 * scale, 8.0 * scale, 0.95, 1.4,
		func(): return _spray(30, 1.3, Vector3(0.11, 0.11, 0.11), Color(0.2, 0.14, 0.09), 0.0, 0.0, 80.0, 18.0, false))
	# lichtflits: hooguit MAX_BLAST_LIGHTS tegelijk (elke extra lamp kost elk object eromheen een lichtberekening)
	if _blast_lights < MAX_BLAST_LIGHTS:
		_blast_lights += 1
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.6, 0.25)
		l.light_energy = 9.0
		l.omni_range = 15.0 * scale
		l.shadow_enabled = false
		l.tree_exited.connect(func(): _blast_lights = maxi(0, _blast_lights - 1))
		parent.add_child(l)
		l.global_position = pos + Vector3.UP * 1.2
		var tw := l.create_tween()
		tw.tween_property(l, "light_energy", 3.5, 0.12)
		tw.tween_property(l, "light_energy", 0.0, 0.9)
		tw.tween_callback(l.queue_free)
	decal(parent, Vector3(pos.x, 0.0, pos.z), Vector3.UP, "scorch", 3.6 * scale, 80.0)


const MAX_BLAST_LIGHTS := 3
static var _blast_lights := 0
static var _spray_pools := {}  # sleutel -> [CPUParticles3D, ...] die klaar zijn


## Eenmalige deeltjeswolk (vonken, aarde, stof) uit een pool: geen nieuwe node, mesh en materiaal per explosie.
## make maakt de wolk de eerste keer; vmin/vmax = snelheid (hangt van de grootte van de knal af); hold = hoe lang hij
## bezet blijft (iets langer dan zijn levensduur).
static func spray_once(parent: Node, key: String, pos: Vector3, vmin: float, vmax: float, explosiveness: float, hold: float, make: Callable) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var pool: Array = _spray_pools.get(key, [])
	_spray_pools[key] = pool
	var p: CPUParticles3D = null
	while not pool.is_empty() and p == null:
		var c = pool.pop_back()
		if is_instance_valid(c):
			p = c
	if p == null:
		p = make.call()
		p.one_shot = true
		parent.add_child(p)
	elif p.get_parent() != parent:
		p.reparent(parent, false)
	p.explosiveness = explosiveness
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.global_position = pos
	p.visible = true
	p.restart()
	p.emitting = true
	parent.get_tree().create_timer(hold).timeout.connect(func():
		if is_instance_valid(p):
			p.emitting = false
			p.visible = false
			pool.append(p))


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
	{"sheet": preload("res://assets/fx/explosie_vuur.png"), "cols": 6, "rows": 5, "frames": 30, "size": Vector2(5.9, 7.9)},  # middelhoog
	{"sheet": preload("res://assets/fx/explosie_vuur2.png"), "cols": 6, "rows": 5, "frames": 30, "size": Vector2(5.95, 8.0)},  # hoog met een grote rookkop
	{"sheet": preload("res://assets/fx/explosie_vuur3.png"), "cols": 6, "rows": 5, "frames": 30, "size": Vector2(7.74, 6.8)},  # laag en breed: een grondexplosie
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
	m.set_shader_parameter("bright", 0.8)  # niet witheet: een vat brandt oranje
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


const NAPALM_FLAME := preload("res://shaders/napalm_vlam.gdshader")
static var _napalm_flame_mat: ShaderMaterial
const NAPALM_FLAME_SIM := preload("res://shaders/napalm_vlam_sim.gdshader")
const NAPALM_ATLAS := "res://assets/napalm_vlam_atlas.png"
const NAPALM_ATLAS_LAAG := "res://assets/napalm_vlam_laag_atlas.png"
const NAPALM_ROOK_ATLAS := "res://assets/napalm_rook_atlas.png"
const NAPALM_ROOK := preload("res://shaders/napalm_rook.gdshader")
static var _napalm_rook_mat: ShaderMaterial
static var _napalm_sim_mat: ShaderMaterial
static var _napalm_sim_laag_mat: ShaderMaterial


## Vlam uit een echte vuursimulatie (Blender, bron/napalm): beeldreeks op een vlak dat met de camera meedraait.
## h = zichtbare vlamhoogte in meters. Zonder atlas valt het terug op de shader-vlam.
static func napalm_flame_sim(parent: Node3D, local_pos: Vector3, h: float, low := false) -> MeshInstance3D:
	if not ResourceLoader.exists(NAPALM_ATLAS):
		return napalm_flame(parent, local_pos, h, h)
	if low and ResourceLoader.exists(NAPALM_ATLAS_LAAG):
		if _napalm_sim_laag_mat == null:
			_napalm_sim_laag_mat = ShaderMaterial.new()
			_napalm_sim_laag_mat.shader = NAPALM_FLAME_SIM
			_napalm_sim_laag_mat.set_shader_parameter("atlas", load(NAPALM_ATLAS_LAAG))
	elif _napalm_sim_mat == null:
		_napalm_sim_mat = ShaderMaterial.new()
		_napalm_sim_mat.shader = NAPALM_FLAME_SIM
		_napalm_sim_mat.set_shader_parameter("atlas", load(NAPALM_ATLAS))
	var use_low := low and _napalm_sim_laag_mat != null
	var s := h * (2.1 if use_low else 1.55)   # staande vlam: ~65% van het beeld; lage vlam is breed en vlak
	var quad := QuadMesh.new()
	quad.size = Vector2(s, s)
	quad.center_offset = Vector3(0.0, s * 0.39, 0.0)   # de voet van de vlam staat iets boven de onderrand van het beeld
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.material_override = _napalm_sim_laag_mat if use_low else _napalm_sim_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.position = local_pos
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("grow", 1.0)
	return mi


## Rookpluim uit de Blender-simulatie, eenmalig afspelend; null als het beeldenblad ontbreekt. fade_after = seconden tot hij wegtrekt.
static func napalm_rook(parent: Node3D, pos: Vector3, size: float, fade_after := 100.0) -> MeshInstance3D:
	if not ResourceLoader.exists(NAPALM_ROOK_ATLAS):
		return null
	if _napalm_rook_mat == null:
		_napalm_rook_mat = ShaderMaterial.new()
		_napalm_rook_mat.shader = NAPALM_ROOK
		_napalm_rook_mat.set_shader_parameter("atlas", load(NAPALM_ROOK_ATLAS))
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.center_offset = Vector3(0.0, size * 0.42, 0.0)
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.material_override = _napalm_rook_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.position = pos
	mi.set_instance_shader_parameter("age", 0.0)
	mi.set_instance_shader_parameter("fade_after", fade_after)
	var life := minf(fade_after + 3.5, 40.0)
	mi.create_tween().tween_method(func(v: float) -> void: mi.set_instance_shader_parameter("age", v), 0.0, life, life)
	return mi


## Realistische vlamtong (shader met stromende ruis) met de voet op local_pos; de breedte w en hoogte h zijn in meters.
## Zet de instance-parameter "grow" (0..1) om hem te laten groeien en doven. Draait om de verticale as mee met de camera.
static func napalm_flame(parent: Node3D, local_pos: Vector3, w: float, h: float) -> MeshInstance3D:
	if _napalm_flame_mat == null:
		_napalm_flame_mat = ShaderMaterial.new()
		_napalm_flame_mat.shader = NAPALM_FLAME
	var quad := QuadMesh.new()
	quad.size = Vector2(w, h)
	quad.center_offset = Vector3(0.0, h * 0.5, 0.0)
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.material_override = _napalm_flame_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.position = local_pos
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("grow", 1.0)
	return mi


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
## Via Puin (MultiMesh): alle stukken van één soort samen zijn één draw call, zonder node of tween per stuk.
static func _debris(parent: Node, pos: Vector3, scale: float, names: Array) -> void:
	var count := 8 + roundi(8.0 * scale)
	for i in count:
		var mesh := _chunk(names[i % names.size()])
		if mesh == null:
			continue
		var sc := randf_range(0.8, 1.5) * (0.7 + 0.4 * scale)
		var a := randf() * TAU
		var out := randf_range(2.5, 7.0) * scale
		var v := Vector3(cos(a) * out, randf_range(4.5, 9.0) * (0.6 + 0.4 * scale), sin(a) * out)
		var spin := Vector3(randf_range(-9.0, 9.0), randf_range(-9.0, 9.0), randf_range(-9.0, 9.0))
		var rest := Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		# grotere stukken trekken een rookspoor; blijven 5 s liggen en krimpen dan weg
		Puin.toss(parent, mesh, pos + Vector3(0.0, 0.5, 0.0), v, 18.0, 0.03, rest, spin, Vector3.ONE * sc, 5.0, false, null, sc > 1.0 and i % 2 == 0)


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


const CRATER_MODELS := preload("res://assets/fx/krater.glb")  # bron/explosie/maak_krater.py: drie kraters met opgeworpen rand
const MAX_CRATERS := 40  # daarboven verdwijnt de oudste, zodat het terrein niet eindeloos vol raakt
static var _crater_mesh := {}
static var _crater_mat: ShaderMaterial


## Een explosie op de grond laat een blijvende krater achter: zwartgeblakerde bodem, opgeworpen rand, wat aardkluiten en kort wat nagloeiende hitte.
## Niet in de rivier, op een bouwwerk, de muur of de bunker.
static func crater(parent: Node, pos: Vector3, scale: float, force := false) -> void:
	if scale < 0.5 or not (force or _crater_ok(pos)):
		return
	var n := 1 + randi() % 3
	if not _crater_mesh.has(n):
		var holder := CRATER_MODELS.instantiate()
		var mi0 := holder.find_child("Krater%d" % n, true, false) as MeshInstance3D
		_crater_mesh[n] = mi0.mesh if mi0 != null else null
		holder.queue_free()
	if _crater_mesh[n] == null:
		return
	if _crater_mat == null:
		_crater_mat = ShaderMaterial.new()
		_crater_mat.shader = load("res://shaders/crater.gdshader")
	var k := scale * randf_range(0.95, 1.1)
	var mi := MeshInstance3D.new()
	mi.mesh = _crater_mesh[n]
	mi.material_override = _crater_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.rotation.y = randf() * TAU
	mi.add_to_group("craters")
	parent.add_child(mi)
	mi.global_position = Vector3(pos.x, 0.004, pos.z)
	mi.scale = Vector3(k * 0.6, k, k * 0.6)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(k, k, k), 0.25).set_ease(Tween.EASE_OUT)
	# een paar aardkluiten die op de berm zijn blijven liggen
	for i in 4:
		var cm := _chunk("Kluit1" if i % 2 == 0 else "Kluit2")
		if cm == null:
			continue
		var c := MeshInstance3D.new()
		c.mesh = cm
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := randf() * TAU
		var rr := randf_range(0.7, 1.25)
		c.position = Vector3(cos(a) * rr, 0.08, sin(a) * rr)
		c.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		c.scale = Vector3.ONE * randf_range(0.7, 1.3) / maxf(k, 0.1)
		mi.add_child(c)
	_crater_glow(mi, k)
	# te veel kraters: de oudste weg
	var all := parent.get_tree().get_nodes_in_group("craters")
	if all.size() > MAX_CRATERS:
		var old: Node = all[0]
		var ot := old.create_tween()
		ot.tween_property(old, "scale", Vector3(0.01, 0.01, 0.01), 0.8)
		ot.tween_callback(old.queue_free)
		old.remove_from_group("craters")


## Nagloeiende hitte in de krater: een zwakke oranje gloed en een heel klein schijnsel, beide doven in enkele seconden. Bewust niet fel.
static func _crater_glow(crater_node: Node3D, k: float) -> void:
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.62
	cm.bottom_radius = 0.62
	cm.height = 0.01
	cm.radial_segments = 20
	cm.rings = 1
	disc.mesh = cm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(1.0, 0.35, 0.08, 0.0)
	disc.material_override = m
	disc.position.y = 0.02
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	crater_node.add_child(disc)
	var tw := disc.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.32, 0.3)
	tw.tween_property(m, "albedo_color:a", 0.0, 9.0)
	tw.tween_callback(disc.queue_free)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.45, 0.15)
	l.light_energy = 0.0
	l.omni_range = 4.5
	l.shadow_enabled = false
	l.position.y = 0.4
	crater_node.add_child(l)
	var lt := l.create_tween()
	lt.tween_property(l, "light_energy", 0.9, 0.4)
	lt.tween_property(l, "light_energy", 0.0, 7.0)
	lt.tween_callback(l.queue_free)


static func _crater_ok(pos: Vector3) -> bool:
	if pos.y > 1.2:
		return false
	if absf(pos.z - Data.river_z(pos.x)) < Data.RIVER_HALF + 2.5:
		return false  # rivier en brug
	var c := Data.COMPOUND
	if maxf(absf(pos.x), absf(pos.z)) < Data.BUNKER_HALF + 1.5:
		return false  # de bunker
	if absf(maxf(absf(pos.x), absf(pos.z)) - c) < 2.0 and minf(absf(pos.x), absf(pos.z)) < c + 1.0:
		return false  # tegen de muur
	if Game.builds != null:
		for b in Game.buildings:
			var sz: Vector3 = Game.builds.DEFS[b.kind].size
			if Vector2(b.at.x - pos.x, b.at.z - pos.z).length() < maxf(sz.x, sz.z) * 0.5 + 1.0:
				return false
	return true
