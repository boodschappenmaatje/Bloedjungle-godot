class_name BaseProps
## De basis: Meshy-veldmuur, de bunker met zandzakken en antenne, vier wachttorens,
## (hutten en kratten zijn weg). Muren, bunker en torens houden kogels en mensen tegen.
## Maten van muur, poorten en bunker komen uit data.gd (zoals in de web-versie).

const C := Data.COMPOUND
const G := Data.GATE_GAP
const BUNKER_GAME_ASSET_PAD := "res://assets/tests/bunker/bloedjungle_bunker_hq.glb"  # zwaar OTA-bestand: pas laden als het nodig is (zie tests/ota_vroeg_test.gd)
const BUNKER_COLLISION_SIZE := Vector3(4.6, 2.0, 4.6)
const BASE_WALL_ASSET := "res://assets/base_wall_hq2.glb"
const WALL_MODULE_LENGTH := 3.5
const WALL_LOD_NAMES := ["Wall_LOD0", "Wall_LOD1", "Wall_LOD2"]
const WALL_LOD_BEGIN := [0.0, 28.0, 58.0]
const WALL_LOD_END := [0.0, 0.0, 0.0]
const WALL_LOD_HYSTERESIS := 1.5  # meters: voorkomt LOD-pingpong bij bewegende iOS-camera


static func build(root: Node3D) -> void:
	_wall(root)
	_gates(root)
	_bunker(root)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_tower(root, Vector3(sx * (C - 1.8), 0, sz * (C - 1.8)))
	Kit.sandbags(root, Vector3(-C + 0.7, 0, 3.0), Vector3(-C + 0.7, 0, 8.0), 2, 3)
	Kit.sandbags(root, Vector3(C - 0.7, 0, -3.0), Vector3(C - 0.7, 0, -8.0), 2, 4)
	_crates(root, Vector3(-C + 6.5, 0, -C + 5.5))  # voorraadhoek bij de noordwesthoek


## Build shared local transforms once; keep the placement math testable without GPU readback.
static func _wall_module_transforms(a: Vector3, b: Vector3, yaw: float) -> Array[Transform3D]:
	var direction := (b - a).normalized()
	var span_center := (a + b) * 0.5
	var count := roundi(a.distance_to(b) / WALL_MODULE_LENGTH)
	var transforms: Array[Transform3D] = []
	for i in count:
		var at := a + direction * (WALL_MODULE_LENGTH * (float(i) + 0.5))
		transforms.append(Transform3D(Basis(Vector3.UP, yaw), at - span_center))
	return transforms


## Gesloten Meshy-modules met afzonderlijke, doorlopende eenvoudige botsvormen.
static func _wall(root: Node3D) -> void:
	var packed := load(BASE_WALL_ASSET) as PackedScene
	if packed == null:
		push_error("BaseProps: optimized Meshy wall asset is missing: " + BASE_WALL_ASSET)
		return
	var template := packed.instantiate()
	var lod_meshes: Dictionary = {}
	for node in template.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		if WALL_LOD_NAMES.has(mesh_node.name):
			lod_meshes[mesh_node.name] = mesh_node.mesh
	template.free()
	# De 2K-normalmaps van de Meshy-muur schitteren op 70%-mobile renderresolutie.
	# Hergebruik dezelfde twee PBR-materialen voor alle LODs; alleen filter/sterkte aanpassen.
	var adjusted_materials: Array[StandardMaterial3D] = []
	for wall_mesh: Mesh in lod_meshes.values():
		for surface in wall_mesh.get_surface_count():
			var pbr := wall_mesh.surface_get_material(surface) as StandardMaterial3D
			if pbr != null and not adjusted_materials.has(pbr):
				adjusted_materials.append(pbr)
				pbr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
				pbr.normal_scale = minf(pbr.normal_scale, 0.5)
	for name in WALL_LOD_NAMES:
		if not lod_meshes.has(name):
			push_error("BaseProps: expected LOD node missing from Meshy wall asset: " + name)
			return

	var spans := [
		{"name": "north_west", "a": Vector3(-C, 0, -C), "b": Vector3(-G - 0.1, 0, -C), "yaw": PI, "along_x": true},
		{"name": "north_east", "a": Vector3(G + 0.1, 0, -C), "b": Vector3(C, 0, -C), "yaw": PI, "along_x": true},
		{"name": "south_west", "a": Vector3(-C, 0, C), "b": Vector3(-G - 0.1, 0, C), "yaw": 0.0, "along_x": true},
		{"name": "south_east", "a": Vector3(G + 0.1, 0, C), "b": Vector3(C, 0, C), "yaw": 0.0, "along_x": true},
		{"name": "west", "a": Vector3(-C, 0, -C), "b": Vector3(-C, 0, C), "yaw": -PI * 0.5, "along_x": false},
		{"name": "east", "a": Vector3(C, 0, -C), "b": Vector3(C, 0, C), "yaw": PI * 0.5, "along_x": false},
	]
	var collision := StaticBody3D.new()
	collision.name = "BaseHighWallCollision"
	collision.collision_layer = Kit.LAYER_WALL | Kit.LAYER_FORTIFICATION
	collision.collision_mask = 0
	collision.add_to_group("base_high_wall")
	collision.set_meta("wall_height", Data.BASE_WALL_H)
	root.add_child(collision)
	for span: Dictionary in spans:
		var a: Vector3 = span.a
		var b: Vector3 = span.b
		var length := a.distance_to(b)
		var span_center := (a + b) * 0.5
		var yaw: float = span.yaw
		var instance_transforms := _wall_module_transforms(a, b, yaw)
		# Visibility ranges use the AABB centre, not the node origin. All LODs must
		# sample the same distance, with bounds enclosing every authored detail level.
		var shared_bounds := AABB()
		var first_bound := true
		for wall_mesh: Mesh in lod_meshes.values():
			for transform: Transform3D in instance_transforms:
				var bounds := transform * wall_mesh.get_aabb()
				shared_bounds = bounds if first_bound else shared_bounds.merge(bounds)
				first_bound = false
		var count := instance_transforms.size()
		var is_x: bool = span.along_x
		var shape := BoxShape3D.new()
		shape.size = Vector3(length, Data.BASE_WALL_H, Data.WALL_T) if is_x else Vector3(Data.WALL_T, Data.BASE_WALL_H, length)
		var collider := CollisionShape3D.new()
		collider.name = "WallSpan_" + str(span.name)
		collider.shape = shape
		collider.position = (a + b) * 0.5 + Vector3.UP * (Data.BASE_WALL_H * 0.5)
		collision.add_child(collider)
		var span_lods: Array[MultiMeshInstance3D] = []
		for lod_index in WALL_LOD_NAMES.size():
			var multi := MultiMesh.new()
			multi.transform_format = MultiMesh.TRANSFORM_3D
			multi.mesh = lod_meshes[WALL_LOD_NAMES[lod_index]]
			multi.custom_aabb = shared_bounds
			multi.instance_count = count
			for i in count:
				multi.set_instance_transform(i, instance_transforms[i])
			var visual := MultiMeshInstance3D.new()
			visual.name = "Wall_%s_%s" % [span.name, WALL_LOD_NAMES[lod_index]]
			visual.add_to_group("base_wall_visual")
			visual.set_meta("wall_span", str(span.name))
			visual.set_meta("wall_start", a)
			visual.set_meta("wall_end", b)
			visual.set_meta("wall_yaw", yaw)
			visual.multimesh = multi
			visual.position = span_center
			visual.visibility_range_begin = WALL_LOD_BEGIN[lod_index]
			visual.visibility_range_end = WALL_LOD_END[lod_index]
			visual.visibility_range_begin_margin = WALL_LOD_HYSTERESIS if WALL_LOD_BEGIN[lod_index] > 0.0 else 0.0
			# One shared hysteresis decision per transition: the finer mesh renders
			# precisely when its coarser visibility parent is hidden by its begin range.
			# Independent begin/end margins can leave both meshes hidden on first view.
			visual.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			# Eén vaste goedkope schaduwvorm voorkomt dat bij LOD-wissels schaduwen flikkeren.
			visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(visual)
			span_lods.append(visual)
		# Resolve paths after all three siblings exist, including during editor builds.
		for lod_index in span_lods.size() - 1:
			span_lods[lod_index].visibility_parent = span_lods[lod_index].get_path_to(span_lods[lod_index + 1])
	_wall_shadow_proxies(root, spans)
	_wall_berm(root, spans)


## Stabiele schaduw van de muur, ongeacht welke detailversie de camera ziet.
## SHADOWS_ONLY: niet zichtbaar als extra muur en geen extra botsing/occlusie.
static func _wall_shadow_proxies(root: Node3D, spans: Array) -> void:
	for span: Dictionary in spans:
		var a: Vector3 = span.a
		var b: Vector3 = span.b
		var length := a.distance_to(b)
		var shadow_mesh := BoxMesh.new()
		shadow_mesh.size = Vector3(length, Data.BASE_WALL_H, Data.WALL_T) if span.along_x else Vector3(Data.WALL_T, Data.BASE_WALL_H, length)
		var shadow := MeshInstance3D.new()
		shadow.name = "BaseWallShadow_" + str(span.name)
		shadow.mesh = shadow_mesh
		shadow.position = (a + b) * 0.5 + Vector3.UP * (Data.BASE_WALL_H * 0.5)
		shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		shadow.add_to_group("base_wall_shadow")
		root.add_child(shadow)


## Shared, low-profile earth shoulders ground the mesh while staying outside the portals.
static func _wall_berm(root: Node3D, spans: Array) -> void:
	var mesh := _wall_berm_mesh()
	var earth := Kit.surface("base_wall_earth_berm", Color(0.09, 0.085, 0.055), Color(0.19, 0.17, 0.11), 0.98, 0.0, 0.04, 0.55)
	mesh.surface_set_material(0, earth)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = spans.size()
	for i in spans.size():
		var span: Dictionary = spans[i]
		var a: Vector3 = span.a
		var b: Vector3 = span.b
		var center := (a + b) * 0.5
		var outside := Vector3.ZERO
		if str(span.name).begins_with("north"):
			outside.z = -0.42
		elif str(span.name).begins_with("south"):
			outside.z = 0.42
		elif str(span.name) == "west":
			outside.x = -0.42
		else:
			outside.x = 0.42
		var direction := (b - a).normalized()
		var extend_start := 0.41 if absf(a.x) == C or absf(a.z) == C else 0.0
		var extend_end := 0.41 if absf(b.x) == C or absf(b.z) == C else 0.0
		var length := a.distance_to(b) + extend_start + extend_end
		center += direction * ((extend_end - extend_start) * 0.5)
		var basis := Basis(Vector3.UP, float(span.yaw)).scaled(Vector3(length, 1.0, 1.0))
		multi.set_instance_transform(i, Transform3D(basis, center + outside))
	var visual := MultiMeshInstance3D.new()
	visual.name = "BaseWallEarthBerm"
	visual.add_to_group("base_wall_berm")
	visual.multimesh = multi
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(visual)

	var corner_mesh := _wall_berm_corner_mesh()
	corner_mesh.surface_set_material(0, earth)
	var corners := MultiMesh.new()
	corners.transform_format = MultiMesh.TRANSFORM_3D
	corners.mesh = corner_mesh
	corners.instance_count = 4
	var index := 0
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			corners.set_instance_transform(index, Transform3D(Basis.IDENTITY, Vector3(sx * (C + 0.42), 0.0, sz * (C + 0.42))))
			index += 1
	var corner_visual := MultiMeshInstance3D.new()
	corner_visual.name = "BaseWallEarthBermCorners"
	corner_visual.add_to_group("base_wall_berm")
	corner_visual.multimesh = corners
	corner_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(corner_visual)


static func _wall_berm_mesh() -> ArrayMesh:
	var half_length := 0.5
	var half_base := 0.41
	var half_top := 0.23
	var height := 0.22
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_wall_berm_quad(st, Vector3(-half_length, 0, -half_base), Vector3(half_length, 0, -half_base), Vector3(half_length, 0, half_base), Vector3(-half_length, 0, half_base))
	_wall_berm_quad(st, Vector3(-half_length, height, -half_top), Vector3(-half_length, height, half_top), Vector3(half_length, height, half_top), Vector3(half_length, height, -half_top))
	_wall_berm_quad(st, Vector3(-half_length, 0, half_base), Vector3(half_length, 0, half_base), Vector3(half_length, height, half_top), Vector3(-half_length, height, half_top))
	_wall_berm_quad(st, Vector3(half_length, 0, -half_base), Vector3(-half_length, 0, -half_base), Vector3(-half_length, height, -half_top), Vector3(half_length, height, -half_top))
	_wall_berm_quad(st, Vector3(half_length, 0, half_base), Vector3(half_length, 0, -half_base), Vector3(half_length, height, -half_top), Vector3(half_length, height, half_top))
	_wall_berm_quad(st, Vector3(-half_length, 0, -half_base), Vector3(-half_length, 0, half_base), Vector3(-half_length, height, half_top), Vector3(-half_length, height, -half_top))
	st.generate_normals()
	return st.commit() as ArrayMesh


static func _wall_berm_corner_mesh() -> ArrayMesh:
	var base := 0.41
	var top := 0.23
	var height := 0.22
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_wall_berm_quad(st, Vector3(-base, 0, -base), Vector3(base, 0, -base), Vector3(base, 0, base), Vector3(-base, 0, base))
	_wall_berm_quad(st, Vector3(-top, height, -top), Vector3(-top, height, top), Vector3(top, height, top), Vector3(top, height, -top))
	_wall_berm_quad(st, Vector3(-base, 0, base), Vector3(base, 0, base), Vector3(top, height, top), Vector3(-top, height, top))
	_wall_berm_quad(st, Vector3(base, 0, -base), Vector3(-base, 0, -base), Vector3(-top, height, -top), Vector3(top, height, -top))
	_wall_berm_quad(st, Vector3(base, 0, base), Vector3(base, 0, -base), Vector3(top, height, -top), Vector3(top, height, top))
	_wall_berm_quad(st, Vector3(-base, 0, -base), Vector3(-base, 0, base), Vector3(-top, height, top), Vector3(-top, height, -top))
	st.generate_normals()
	return st.commit() as ArrayMesh


static func _wall_berm_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(d)


## Poortposten; de stalen schuifpoorten en de zwaailichten erop staan in gates.gd.
static func _gates(root: Node3D) -> void:
	for sz in [-1.0, 1.0]:
		for sx in [-1.0, 1.0]:
			var p := Vector3(sx * (G + 0.3), 0, sz * C)
			Kit.box(root, p, Vector3(0.7, Data.BASE_WALL_H, 0.7), Kit.concrete_dark(), 0.0, Kit.LAYER_WALL)
			Kit.box(root, p + Vector3.UP * Data.BASE_WALL_H, Vector3(0.9, 0.16, 0.9), Kit.concrete())
		# stalen bovenbalk met geel-zwarte rand
		Kit.box(root, Vector3(0, Data.BASE_WALL_H, sz * C), Vector3(G * 2.0 + 1.0, 0.18, 0.4), Kit.olive())
		for i in 10:
			var x := -G + 0.25 + i * (G * 2.0 / 9.0)
			Kit.box(root, Vector3(x, Data.BASE_WALL_H - 0.16, sz * C), Vector3(0.22, 0.16, 0.44), Kit.flat(Color("c9a227") if i % 2 == 0 else Color("1a1a18")))


static func _bunker(root: Node3D) -> void:
	# Keep the original gameplay body exactly: same layer, 4.6 × 2 × 4.6 m box,
	# position, damage script and FX anchors. Only the visual child is replaced.
	var b := StaticBody3D.new()
	b.name = "Bunker"
	b.collision_layer = Kit.LAYER_BUNKER
	b.collision_mask = 0
	b.set_script(preload("res://scripts/bunker.gd"))
	b.set_process(true)
	var collision := CollisionShape3D.new()
	collision.name = "BunkerCollision"
	var shape := BoxShape3D.new()
	shape.size = BUNKER_COLLISION_SIZE
	collision.shape = shape
	collision.position.y = BUNKER_COLLISION_SIZE.y / 2.0
	b.add_child(collision)
	# Het hoofdkwartier (assets/hoofdkwartier.glb) staat op de plek van de bunker; model 5,0 m x 0,92 = 4,6 m botsblok.
	var visual := Node3D.new()
	visual.name = "Hoofdkwartier"
	visual.set_script(preload("res://scripts/hoofdkwartier.gd"))
	b.add_child(visual)
	root.add_child(b)
	# zandzakkenring met een opening bij de deur
	var r := 3.6
	Kit.sandbags(root, Vector3(-r, 0, -r), Vector3(r, 0, -r), 2, 21)
	Kit.sandbags(root, Vector3(-r, 0, r), Vector3(-r, 0, -r), 2, 22)
	Kit.sandbags(root, Vector3(r, 0, -r), Vector3(r, 0, r), 2, 23)
	Kit.sandbags(root, Vector3(-r, 0, r), Vector3(0.1, 0, r), 2, 24)
	root.add_child(HqOmgeving.new())   # voorplein met belijning, lichtmasten, afzetblokken, vaten en kisten


## Houten wachttoren met platform, reling, ladder en golfplaten dak.
static func _tower(root: Node3D, pos: Vector3) -> void:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = 0.0 if pos.x < 0.0 else PI  # de trap loopt naar het midden van de basis
	root.add_child(holder)
	holder.add_to_group("tower")
	Kit.collider(holder, Vector3(0, 2.5, 0), Vector3(1.9, 5.0, 1.9), Kit.LAYER_WALL)
	var model: Node = (load("res://assets/wachttoren.glb") as PackedScene).instantiate()
	Kit.skin(model, "toren")
	holder.add_child(model)


static func _hut(root: Node3D, pos: Vector3, yaw: float) -> void:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = yaw
	holder.scale = Vector3.ONE * 1.15
	root.add_child(holder)
	Kit.box(holder, Vector3.ZERO, Vector3(3.6, 2.3, 2.8), Kit.photo("buildings/plywood", 2.0, Color(0.62, 0.64, 0.5)), 0.0, Kit.LAYER_WALL)
	Kit.box(holder, Vector3(0, 0, 0), Vector3(3.7, 0.3, 2.9), Kit.concrete_dark())
	Kit.gable(holder, Vector3(0, 2.3, 0), Vector3(4.4, 1.0, 3.6), Kit.roof())
	Kit.box(holder, Vector3(-0.6, 0, 1.41), Vector3(0.9, 1.7, 0.1), Kit.wood())
	Kit.box(holder, Vector3(0.9, 1.0, 1.41), Vector3(0.8, 0.7, 0.1), Kit.flat(Color("14130f"), 0.8))
	Kit.box(holder, Vector3(1.8, 0, 0.0), Vector3(0.12, 1.1, 2.6), Kit.canvas())


static func _crates(root: Node3D, pos: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pos.x * 10.0 + pos.z)
	for i in 5:
		var s := rng.randf_range(0.7, 1.0)
		var p := pos + Vector3(rng.randf_range(-1.0, 1.0), 0, rng.randf_range(-0.8, 0.8))
		var yaw := rng.randf() * PI
		Kit.prop(root, "Kist_Hout", p, s, yaw)
		Kit.collider(root, p + Vector3(0, s * 0.45, 0), Vector3(s, s * 0.9, s) * 1.1, Kit.LAYER_WALL)
		if i < 2:
			Kit.prop(root, "Kist_Hout", p + Vector3(0, s * 0.91, 0), s * 0.85, rng.randf() * PI)
		elif i == 2:
			Kit.prop(root, Kit.MUNITIEKIST, p + Vector3(0, s * 0.91, 0), 1.1, rng.randf() * PI)
	Kit.collider(root, pos + Vector3(0.15, 0.63, 1.5), Vector3(1.4, 1.26, 0.8), Kit.LAYER_WALL)
	Kit.prop(root, Kit.MUNITIEKIST, pos + Vector3(-0.3, 0, 1.4), 1.1, 0.4)
	Kit.prop(root, Kit.MUNITIEKIST, pos + Vector3(0.5, 0, 1.55), 1.1, -0.2)
	Kit.prop(root, Kit.MUNITIEKIST, pos + Vector3(0.5, 0.63, 1.55), 1.1, -0.1)
	Kit.collider(root, pos + Vector3(2.4, 0.45, 0.9), Vector3(2.0, 0.9, 0.7), Kit.LAYER_WALL)
	for i in 3:
		Kit.cylinder(root, pos + Vector3(1.7 + i * 0.7, 0, 0.9), 0.3, 0.9, Kit.olive() if i != 1 else Kit.rust(), 10)
