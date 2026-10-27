class_name GrassField
extends Node3D
## Blender grass extends the existing foliage scatter; no colliders or AI behavior.

const KINDS := ["short", "medium", "tall"]
const ZONE_DATA := preload("res://resources/grass_zones.tres")
const CELL := 24.0
const LIMIT := {"short": 6200, "medium": 2200, "tall": 1600}
const END := {"short": 52.0, "medium": 62.0, "tall": 72.0}
static var _meshes := {}
static var _material: ShaderMaterial
static var _zones: Array = []
var batches: Array = []
var counts := {"short": 0, "medium": 0, "tall": 0}
var _tick := 0.0


static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = preload("res://shaders/grass_3d.gdshader")
		_material.set_shader_parameter("albedo_tex", load("res://assets/textures/grass_2k/albedo.jpg"))
		_material.set_shader_parameter("normal_tex", load("res://assets/textures/grass_2k/normal.png"))
		_material.set_shader_parameter("orm_tex", load("res://assets/textures/grass_2k/orm.png"))
		_material.set_shader_parameter("wind", 1.0 if GameSettings.get_value("wind") == "on" else 0.0)
	return _material


static func meshes(kind: String, lod := 0) -> Array:
	var key := kind + str(lod)
	if not _meshes.has(key):
		var scene: Node3D = load("res://assets/grass/grass_%s_lod%d.glb" % [kind, lod]).instantiate()
		var found: Array = []
		for node: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
			found.append([String(node.name), node.mesh])
		found.sort_custom(func(a, b): return a[0] < b[0])
		_meshes[key] = found.map(func(item): return item[1])
		scene.free()
	return _meshes[key]


static func zones() -> Array:
	if _zones.is_empty():
		_zones = ZONE_DATA.get_meta("zones")
	return _zones


static func zone_at(pos: Vector3, border := 1.0) -> Dictionary:
	if not _allowed(pos):
		return {}
	return _zone_match(pos, border)


static func _zone_match(pos: Vector3, border := 1.0) -> Dictionary:
	for zone: Dictionary in zones():
		var q := Vector2((pos.x - zone.center[0]) / zone.radius[0], (pos.z - zone.center[1]) / zone.radius[1])
		var edge := 1.0 + 0.08 * sin(pos.x * 1.7) * sin(pos.z * 1.3)
		if q.length() < border * edge:
			return zone
	return {}


static func _allowed(pos: Vector3) -> bool:
	if maxf(absf(pos.x), absf(pos.z)) < Data.COMPOUND + 1.8:
		return false
	if absf(pos.x) < 4.6 and absf(pos.z) < 70.0:
		return false
	if pos.x > Data.COMPOUND and pos.x < Data.COMPOUND + 11.5 and absf(pos.z) < 23.0:
		return false
	return not Foliage._in_river(pos)


static func set_wind(on: bool) -> void:
	material().set_shader_parameter("wind", 1.0 if on else 0.0)


static func set_focus(pos: Vector3, active: bool) -> void:
	if _material:
		_material.set_shader_parameter("player_bend", 1.0 if active else 0.0)


## Wie er door het gras loopt (zie Foliage.update_pushers).
static func set_pushers(list: PackedVector4Array) -> void:
	if _material:
		_material.set_shader_parameter("pushers", list)


static func spawn(parent: Node3D, existing_positions: Array) -> GrassField:
	var field := GrassField.new()
	field.name = "GrassField3D"
	parent.add_child(field)
	field.add_to_group("grass_fields")
	field._populate(existing_positions)
	return field


func _populate(existing: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 27102026
	var groups := {}
	for transform: Transform3D in existing:
		for _j in 3:
			var p := transform.origin + Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.5, 0.5))
			if not _allowed(p):
				continue
			var kind := "medium" if rng.randf() < 0.20 or not _zone_match(p, 1.3).is_empty() else "short"
			if not _zone_match(p).is_empty():
				kind = "tall"
			_add_point(groups, rng, kind, p)
	# Denser, deliberately bounded tall fields with a shorter fringe. Routes stay open.
	for zone: Dictionary in zones():
		for _i in 650:
			var p := Vector3(zone.center[0] + rng.randf_range(-zone.radius[0]*1.2, zone.radius[0]*1.2), 0,
				zone.center[1] + rng.randf_range(-zone.radius[1]*1.2, zone.radius[1]*1.2))
			if not _allowed(p) or _zone_match(p, 1.18).is_empty():
				continue
			_add_point(groups, rng, "medium" if _zone_match(p).is_empty() else "tall", p)
	for key in groups:
		var data: Dictionary = groups[key]
		var nodes: Array = []
		for lod in 3:
			var inst := Kit.scatter(self, meshes(data.kind, lod)[data.variant], material(), data.xf, data.colors, false)
			inst.name = "Grass_%s_%d_LOD%d" % [data.kind, data.variant, lod]
			inst.add_to_group("foliage_grass")
			inst.add_to_group("grass_3d")
			inst.set_meta("kind", data.kind)
			inst.set_meta("lod", lod)
			inst.set_meta("full", data.xf.size())
			inst.multimesh.visible_instance_count = roundi(data.xf.size() * {"low": 0.2, "high": 0.45, "ultra": 1.0}[GameSettings.get_value("quality")])
			inst.extra_cull_margin = 0.4
			inst.visible = lod == 0
			nodes.append(inst)
		batches.append({"nodes": nodes, "positions": PackedVector3Array(data.xf.map(func(t): return t.origin)),
			"center": Vector3((data.cell.x + 0.5)*CELL, 0, (data.cell.y + 0.5)*CELL), "kind": data.kind, "lod": -2})
	_update_lods()
	apply_quality(GameSettings.get_value("quality"), GameSettings.get_value("quality") == "ultra")


func apply_quality(level: String, shadows: bool) -> void:
	material().set_shader_parameter("normal_strength", {"low": 0.22, "high": 0.35, "ultra": 0.45}[level])
	for batch: Dictionary in batches:
		for i in 3:
			batch.nodes[i].cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows and batch.kind == "tall" and i < 2 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_update_lods()


func _add_point(groups: Dictionary, rng: RandomNumberGenerator, kind: String, pos: Vector3) -> void:
	if counts[kind] >= LIMIT[kind]:
		return
	counts[kind] += 1
	var cell := Vector2i(floori(pos.x / CELL), floori(pos.z / CELL))
	var variant := rng.randi_range(0, 3)
	var key := "%s_%d_%d_%d" % [kind, variant, cell.x, cell.y]
	if not groups.has(key):
		groups[key] = {"kind": kind, "cell": cell, "variant": variant, "xf": [], "colors": []}
	var scale_ := rng.randf_range(0.9, 1.08)
	var basis := Basis(Vector3.UP, rng.randf()*TAU).scaled(Vector3(scale_, scale_, scale_))
	groups[key].xf.append(Transform3D(basis, pos))
	var shade := rng.randf_range(0.88, 1.0)
	groups[key].colors.append(Color(shade, shade, shade))


func _process(delta: float) -> void:
	_tick += delta
	if _tick >= 0.15:
		_tick = 0.0
		_update_lods()


func _update_lods() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var on := GameSettings.get_value("t_jungle") == "on"
	for batch: Dictionary in batches:
		var distance_ := camera.global_position.distance_to(batch.center)
		var lod := -1 if not on or distance_ > END[batch.kind] else (0 if distance_ < 36.0 else (1 if distance_ < 49.0 else 2))
		for i in 3:
			var node: MultiMeshInstance3D = batch.nodes[i]
			if node.visible != (i == lod):
				node.visible = i == lod
		batch.lod = lod


static func preview(kind: String, old := false) -> Node3D:
	var root := Node3D.new()
	root.name = "GrassPreview"
	var kinds: Array = KINDS if kind == "all" else [kind]
	for row in kinds.size():
		for variant in 4:
			var node := MeshInstance3D.new()
			node.mesh = Foliage.grass() if old else meshes(kinds[row])[variant]
			node.material_override = Foliage.material("grass") if old else material()
			if kinds.size() > 1:
				node.position = Vector3((row - 1)*2.0 + (variant % 2 - 0.5)*0.7, 0, (variant / 2 - 0.5)*0.85)
			else:
				node.position = Vector3((variant - 1.5)*0.85, 0, 0)
			root.add_child(node)
	return root
