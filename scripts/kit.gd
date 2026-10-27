class_name Kit
## Bouwstenen voor de 3D-wereld: materialen met zelf gemaakte texturen, en kleine vormen
## (blok, cilinder, zandzakken) die met een regel op hun plek gezet worden.

const LAYER_GROUND := 1
const LAYER_WALL := 2
const LAYER_BUNKER := 16
const LAYER_NATURE := 128  # stammen en rotsen: houdt mensen en voertuigen tegen, en kogels en granaten
const LAYER_WATER := 64  # onzichtbare oever van de rivier: houdt mensen tegen, kogels vliegen erover

static var _mats := {}


## Zachte ruistextuur, als kleurvlak of als normal map (voor korrel en oneffenheid).
static func noise_tex(freq: float, seed_: int, c0 := Color.BLACK, c1 := Color.WHITE, normal := false, size := 256) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.seed = seed_
	n.fractal_octaves = 4
	var t := NoiseTexture2D.new()
	t.noise = n
	t.width = size
	t.height = size
	t.seamless = true
	if normal:
		t.as_normal_map = true
		t.bump_strength = 4.0
	else:
		var g := Gradient.new()
		g.set_color(0, c0)
		g.set_color(1, c1)
		t.color_ramp = g
	return t


## Materiaal met korrel, over de wereld heen gespannen zodat blokken van elke maat goed staan.
static func surface(key: String, c0: Color, c1: Color, rough := 0.9, metal := 0.0, freq := 0.05, scale := 0.4) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = noise_tex(freq, key.hash() % 1000, c0, c1)
	m.normal_enabled = true
	m.normal_texture = noise_tex(freq * 3.0, key.hash() % 777, Color.BLACK, Color.WHITE, true)
	m.normal_scale = 0.7
	m.roughness = rough
	m.metallic = metal
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	_mats[key] = m
	return m


## Foto-materiaal uit assets/textures: kleur, oneffenheden en glans, over de wereld heen gespannen.
## tile = meters per herhaling; tint kleurt het materiaal bij (donker/warm), zodat het bij de jungle past.
static func photo(dir: String, tile := 3.0, tint := Color.WHITE, rough := 1.0) -> StandardMaterial3D:
	var key := "photo%s%s%s" % [dir, tile, tint.to_html()]
	if _mats.has(key):
		return _mats[key]
	var base := "res://assets/textures/%s/" % dir
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(base + "base_color.jpg")
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = load(base + "normal_gl.jpg")
	m.normal_scale = 0.8
	m.roughness_texture = load(base + "roughness.jpg")
	m.roughness = rough
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / tile
	_mats[key] = m
	return m


static func concrete() -> StandardMaterial3D:
	return photo("buildings/concrete", 3.0, Color(0.74, 0.74, 0.71))


static func concrete_dark() -> StandardMaterial3D:
	return photo("buildings/concrete", 3.0, Color(0.5, 0.5, 0.46))


static func wood() -> StandardMaterial3D:
	return photo("buildings/weathered_wood", 2.2, Color(0.66, 0.58, 0.5))


## Zet foto-materialen op een Blender-model: de naam van het materiaal in het .glb bepaalt de textuur.
static func skin(root: Node, kind: String) -> void:
	var all := _skins()
	if not all.has(kind):
		return
	var map: Dictionary = all[kind]
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var old := mi.mesh.surface_get_material(i)
			if old and map.has(old.resource_name):
				mi.set_surface_override_material(i, map[old.resource_name].call())


static var _skin_cache := {}


## Pas bij het eerste gebruik gebouwd: in de editor (@tool) bestaat een static var nog niet tijdens het laden.
static func _skins() -> Dictionary:
	if _skin_cache.is_empty():
		_skin_cache = _build_skins()
	return _skin_cache


static func _build_skins() -> Dictionary:
	return {
	"toren": {
		"Paal": func(): return photo("buildings/weathered_wood", 1.6, Color(0.5, 0.42, 0.34)),
		"Plank1": func(): return photo("buildings/weathered_wood", 1.4, Color(0.72, 0.62, 0.5)),
		"Plank2": func(): return photo("buildings/weathered_wood", 1.4, Color(0.6, 0.52, 0.42)),
		"Plank3": func(): return photo("buildings/weathered_wood", 1.4, Color(0.8, 0.7, 0.56)),
		"Dak": func(): return photo("buildings/corrugated_iron", 1.5, Color(0.85, 0.6, 0.5)),
		"Dakrib": func(): return photo("buildings/rusted_metal", 1.0, Color(0.75, 0.5, 0.4)),
		"Metaal": func(): return photo("buildings/metal", 0.8, Color(0.55, 0.55, 0.55)),
		"Zak": func(): return canvas(),
		"Kist": func(): return photo("buildings/army_green_paint", 0.9, Color(0.7, 0.75, 0.6)),
	},
	"kazerne": {
		"Wand1": func(): return photo("buildings/army_green_paint", 1.8, Color(0.82, 0.86, 0.7)),
		"Wand2": func(): return photo("buildings/army_green_paint", 1.8, Color(0.68, 0.72, 0.58)),
		"Wand3": func(): return photo("buildings/army_green_paint", 1.8, Color(0.92, 0.95, 0.78)),
		"Plank1": func(): return photo("buildings/weathered_wood", 1.4, Color(0.72, 0.62, 0.5)),
		"Paal": func(): return photo("buildings/weathered_wood", 1.6, Color(0.5, 0.42, 0.34)),
		"Dak": func(): return photo("buildings/corrugated_iron", 1.5, Color(0.6, 0.7, 0.55)),
		"Dakrib": func(): return photo("buildings/corrugated_iron", 1.5, Color(0.5, 0.58, 0.46)),
		"Beton": func(): return concrete(),
		"Zak": func(): return canvas(),
		"Metaal": func(): return photo("buildings/metal", 0.8, Color(0.55, 0.55, 0.55)),
	},
	"poort": {
		"Staal": func(): return photo("buildings/metal", 1.4, Color(0.84, 0.88, 0.93)),
		"StaalDonker": func(): return photo("buildings/metal", 1.4, Color(0.5, 0.53, 0.58)),
		"Metaal": func(): return photo("buildings/metal", 0.8, Color(0.6, 0.61, 0.63)),
	},
	"brug": {
		"Hout1": func(): return photo("buildings/weathered_wood", 1.4, Color(1.25, 1.1, 0.9)),
		"Hout2": func(): return photo("buildings/weathered_wood", 1.4, Color(1.05, 0.92, 0.75)),
		"Hout3": func(): return photo("buildings/weathered_wood", 1.4, Color(1.4, 1.22, 1.0)),
		"Balk": func(): return photo("buildings/weathered_wood", 1.6, Color(0.8, 0.68, 0.54)),
		"Paal": func(): return photo("nature/tree_bark", 1.2, Color(0.55, 0.47, 0.38)),
		"Metaal": func(): return photo("buildings/metal", 0.8, Color(0.6, 0.62, 0.64)),
		"Touw": func(): return photo("buildings/jute", 1.2, Color(0.8, 0.72, 0.55)),
	},
	"loopgraaf": {
		"Hout1": func(): return photo("buildings/weathered_wood", 1.4, Color(0.72, 0.62, 0.5)),
		"Hout2": func(): return photo("buildings/weathered_wood", 1.4, Color(0.58, 0.5, 0.4)),
		"Hout3": func(): return photo("buildings/weathered_wood", 1.4, Color(0.8, 0.7, 0.56)),
		"Balk": func(): return photo("buildings/weathered_wood", 1.6, Color(0.45, 0.38, 0.3)),
		"Zak1": func(): return canvas(),
		"Zak2": func(): return photo("buildings/jute", 1.2, Color(0.66, 0.62, 0.5)),
		"Aarde": func(): return photo("terrain/dry_earth", 1.5, Color(0.75, 0.65, 0.55)),
		"AardeDonker": func(): return photo("terrain/dry_earth", 1.5, Color(0.5, 0.42, 0.34)),
		"Modder": func(): return photo("terrain/mud", 1.5, Color(0.45, 0.4, 0.35)),
		"Metaal": func(): return photo("buildings/metal", 0.8, Color(0.55, 0.55, 0.55)),
		"Kist": func(): return photo("buildings/army_green_paint", 0.9, Color(0.7, 0.75, 0.6)),
	},
}


static func olive() -> StandardMaterial3D:
	return photo("buildings/army_green_paint", 2.5, Color(0.8, 0.85, 0.7))


static func rust() -> StandardMaterial3D:
	return photo("buildings/rusted_metal", 1.6, Color(0.62, 0.5, 0.42))


static func roof() -> StandardMaterial3D:
	return photo("buildings/rusted_metal", 3.5, Color(0.36, 0.3, 0.27))


static func canvas() -> StandardMaterial3D:
	return photo("buildings/jute", 1.2, Color(0.78, 0.74, 0.6))


static func rock() -> StandardMaterial3D:
	return photo("nature/rock_material", 2.0, Color(0.7, 0.7, 0.66))


static func flat(color: Color, rough := 0.9, metal := 0.0) -> StandardMaterial3D:
	var key := "flat%s%s%s" % [color.to_html(), rough, metal]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = rough
		m.metallic = metal
		_mats[key] = m
	return _mats[key]


## Een blok met de onderkant op pos.y. layer > 0 geeft het ook botsing (muur, bunker).
static func box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, yaw := 0.0, layer := 0) -> Node3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	return _place(parent, mi, pos, size, yaw, layer)


static func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, mat: Material, sides := 12, top_radius := -1.0) -> Node3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = radius
	cm.top_radius = radius if top_radius < 0.0 else top_radius
	cm.height = height
	cm.radial_segments = sides
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos + Vector3.UP * height / 2.0
	parent.add_child(mi)
	return mi


## Onzichtbare botsing alleen (voor torens, waar de poten zelf geen massief blok zijn).
static func collider(parent: Node3D, pos: Vector3, size: Vector3, layer: int) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	body.position = pos
	parent.add_child(body)


## Dak met twee schuine kanten (kap van een hut of toren).
static func gable(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, yaw := 0.0) -> Node3D:
	var mi := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = size
	mi.mesh = pm
	mi.material_override = mat
	return _place(parent, mi, pos, size, yaw, 0)


static func _place(parent: Node3D, mi: MeshInstance3D, pos: Vector3, size: Vector3, yaw: float, layer: int) -> Node3D:
	var root: Node3D = mi
	mi.position = Vector3(0, size.y / 2.0, 0)
	if layer > 0:
		var body := StaticBody3D.new()
		body.collision_layer = layer
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		cs.position = mi.position
		body.add_child(cs)
		body.add_child(mi)
		root = body
	root.position = pos
	root.rotation.y = yaw
	parent.add_child(root)
	return root


## Veel kopieën van één vorm in één tekenopdracht (zandzakken, bomen, struiken).
static func scatter(parent: Node3D, mesh: Mesh, mat: Material, xforms: Array, colors: Array = [], shadows := true) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors.size() > 0
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		if mm.use_colors:
			mm.set_instance_color(i, colors[i])
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	if mat != null:
		inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(inst)
	return inst


## Rij zandzakken langs een lijn: twee lagen, een beetje scheef en wisselend van kleur.
static func sandbags(parent: Node3D, from: Vector3, to: Vector3, courses := 2, seed_ := 1) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var bag := SphereMesh.new()
	bag.radius = 0.5
	bag.height = 1.0
	bag.radial_segments = 8
	bag.rings = 4
	var xf: Array = []
	var cols: Array = []
	var len := from.distance_to(to)
	var dir := (to - from) / maxf(len, 0.01)
	var yaw := atan2(dir.x, dir.z) + PI / 2.0
	var n := int(len / 0.6)
	for c in courses:
		for i in n:
			var p := from + dir * (0.3 + i * 0.6 + (0.3 if c % 2 else 0.0))
			p.y = 0.12 + c * 0.2
			var b := Basis.from_euler(Vector3(0, yaw + rng.randf_range(-0.12, 0.12), 0)).scaled(Vector3(0.62, 0.24, 0.38))
			xf.append(Transform3D(b, p))
			var v := rng.randf_range(0.85, 1.1)
			cols.append(Color(v, v, v * 0.95))
	var m: StandardMaterial3D = canvas().duplicate()
	m.vertex_color_use_as_albedo = true  # de kleurtjes per zak
	scatter(parent, bag, m, xf, cols)
