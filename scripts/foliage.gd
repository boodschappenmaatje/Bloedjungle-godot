class_name Foliage
## Bomen, struiken, varens en rotsen, zelf opgebouwd uit driehoeken (geen losse modelbestanden).
## Kleuren zitten in de vertexkleuren; de alfa is hoe sterk iets in de wind beweegt (foliage.gdshader).

static var _mats := {}
static var _shadow_mats := {}  # soort -> nepschaduw-materiaal
const STRIP_EXTRA := {"palm": 70, "bush": 230, "fern": 330, "grass": 1300, "rock": 26}  # extra stuks in de strook tussen muur en rivier
## Hoeveel van de extra planten per gebied blijft staan: moeras = varens en gras, open plek = bijna kaal met rotsen, dicht = alles.
const STRIP_KEEP := {
	"dicht": {"palm": 1.0, "bush": 1.0, "fern": 1.0, "grass": 1.0, "rock": 0.5},
	"moeras": {"palm": 0.3, "bush": 0.35, "fern": 0.9, "grass": 1.0, "rock": 0.2},
	"open": {"palm": 0.06, "bush": 0.12, "fern": 0.3, "grass": 0.45, "rock": 1.0},
}
## Afstand (m, vanaf de camera, gemeten tot het midden van een vak van 36 m) waarboven een soort niet meer getekend wordt.
const VIS_END := {"palm": 140.0, "bush": 95.0, "fern": 85.0, "grass": 55.0}
const PALM_NEAR := 62.0  # dichterbij: volledige palm; verder: de simpele palm
## Stam of rots waar je niet doorheen loopt: straal in meters bij schaal 1 (laag Kit.LAYER_NATURE: mensen, voertuigen, kogels en granaten).
const BOOM_COLLIDE_R := 0.8  # jungleboom: stam met plankwortels (bij schaal 1, voor de 0,75 van BOOM_SCALE)
const COLLIDE_R := {"palm": 0.32, "rock": 0.45}
const SHADOW_KINDS := {"palm": [4.2, 2.6, 0.5], "bush": [1.1, 1.8, 0.45], "rock": [0.5, 1.2, 0.4]}  # hoogte, breedte, sterkte


## Wind-materiaal; met een bladtextuur (kind) of zonder (stam, rotsen).
static func material(kind := "") -> ShaderMaterial:
	if not _mats.has(kind):
		var m := ShaderMaterial.new()
		m.shader = preload("res://shaders/foliage.gdshader")
		m.set_shader_parameter("use_tex", kind != "")
		if kind == "bark":
			m.set_shader_parameter("tex", load("res://assets/textures/nature/tree_bark/base_color.jpg"))
			m.set_shader_parameter("nrm", load("res://assets/textures/nature/tree_bark/normal_gl.jpg"))
			m.set_shader_parameter("tile", true)
			m.set_shader_parameter("cut", 0.0)
			m.set_shader_parameter("tint", Vector3(0.55, 0.45, 0.36))
		elif kind != "":
			m.set_shader_parameter("tex", LeafTex.get_tex(kind))
			m.set_shader_parameter("nrm", LeafTex.get_normal(kind))
		if kind == "grass":
			m.set_shader_parameter("sway", 0.08)
			m.set_shader_parameter("cut", 0.35)
		m.set_shader_parameter("wind", 1.0 if GameSettings.get_value("wind") == "on" else 0.0)
		_mats[kind] = m
	return _mats[kind]


static var _focus_mats: Array[ShaderMaterial] = []
static var _fade := 0.0  # 0..1, loopt zacht mee zodat bladeren niet ploffen


## Globale uniforms op gedeelde leaf-materialen, zonder per-palm drawcalls of raycasts.
## active = false (bouwmodus, menu): de zichtlijn-fade loopt rustig terug naar 0.
## extras = tot drie wereldposities (vijanden) die ook uit de bladeren moeten blijven.
static func update_visibility_focus(player_pos: Vector3, camera_pos: Vector3, delta := 1.0 / 60.0, active := true, extras: Array = []) -> void:
	GrassField.set_focus(player_pos, active)
	_fade = move_toward(_fade, 1.0 if active else 0.0, delta / 0.35)
	if _focus_mats.is_empty():
		for key in ["palm", "leaf", "fern"]:
			_focus_mats.append(material(key))
	var on := _fade > 0.001
	var e: Array[Vector4] = [Vector4.ZERO, Vector4.ZERO, Vector4.ZERO]
	for i in mini(extras.size(), 3):
		var pos: Vector3 = extras[i]
		e[i] = Vector4(pos.x, pos.y + 1.0, pos.z, 1.0)
	for mat in _focus_mats:
		mat.set_shader_parameter("fade_sightline", on)
		if not on:
			continue
		mat.set_shader_parameter("fade_amount", _fade)
		mat.set_shader_parameter("view_player", player_pos + Vector3.UP * 1.2)
		mat.set_shader_parameter("view_camera", camera_pos)
		mat.set_shader_parameter("view_e0", e[0])
		mat.set_shader_parameter("view_e1", e[1])
		mat.set_shader_parameter("view_e2", e[2])


const PUSH_MAX := 8
const PUSH_RANGE := 24.0   # verder dan dit van de speler (buiten beeld) hoeft niets te buigen
const PUSH_R_SOLDIER := 1.7
const PUSH_R_VEHICLE := 3.0
static var _push_busy := false
static var push_enabled := true   # uit = niets buigt (alleen voor tests en foto's)


## Wie er door de struiken, varens en het gras loopt: de speler en de PUSH_MAX dichtstbijzijnde soldaten, vijanden en
## voertuigen buigen het lage blad opzij (alleen een shader-effect, geen botsing). active = false: niets buigt (bouwmodus, menu).
static func update_pushers(player: Node3D, tree: SceneTree, active := true) -> void:
	var list := PackedVector4Array()
	list.resize(PUSH_MAX)
	if active and push_enabled and player != null:
		var c := player.global_position
		var found: Array = []   # [afstand², Vector4]
		var add := func(n, r: float) -> void:
			if not is_instance_valid(n) or not n is Node3D or n.get("dead") == true:
				return
			var pos: Vector3 = (n as Node3D).global_position
			var d2 := pos.distance_squared_to(c)
			if d2 < PUSH_RANGE * PUSH_RANGE:
				found.append([d2, Vector4(pos.x, pos.z, r, 1.0)])
		add.call(player, PUSH_R_SOLDIER)
		for e in Game.enemies:
			add.call(e, PUSH_R_SOLDIER)
		for a in Game.allies:
			add.call(a, PUSH_R_SOLDIER)
		for v in tree.get_nodes_in_group("voertuigen"):
			add.call(v, PUSH_R_VEHICLE)
		found.sort_custom(func(a, b): return a[0] < b[0])
		for i in mini(found.size(), PUSH_MAX):
			list[i] = found[i][1]
	var any := false
	for v in list:
		if v.w > 0.0:
			any = true
			break
	if not any and not _push_busy:
		return   # niets te buigen en de materialen staan al leeg
	_push_busy = any
	for k in _mats:
		if k != "bark":
			_mats[k].set_shader_parameter("pushers", list)
	GrassField.set_pushers(list)


## Zet de wind in alle bladeren aan of uit.
static func set_wind(on: bool) -> void:
	for k in _mats:
		_mats[k].set_shader_parameter("wind", 1.0 if on else 0.0)
	GrassField.set_wind(on)


## Richting en lengte van de nepschaduwen volgen de zon (dir = waarheen de schaduw valt, elev = zonhoogte in graden).
static func set_sun(dir: Vector2, elev: float) -> void:
	var reach := 1.0 / tan(deg_to_rad(clampf(elev, 8.0, 80.0)))
	for k in _shadow_mats:
		_shadow_mats[k].set_shader_parameter("sun_dir", dir)
		_shadow_mats[k].set_shader_parameter("reach", reach)


static func _shadow_mat(kind: String) -> ShaderMaterial:
	if not _shadow_mats.has(kind):
		var c: Array = SHADOW_KINDS[kind]
		var m := ShaderMaterial.new()
		m.shader = preload("res://shaders/treeshadow.gdshader")
		m.set_shader_parameter("height", c[0])
		m.set_shader_parameter("width", c[1])
		m.set_shader_parameter("strength", c[2])
		_shadow_mats[kind] = m
	return _shadow_mats[kind]


## Eén blad of palmtak: een gebogen strook met een licht gevouwen middenrib. De textuur loopt
## in de lengte (u) en over de breedte (v), met de nerf op v = 0,5.
static func _frond(st: SurfaceTool, origin: Vector3, yaw: float, length: float, width: float, rise: float, droop: float, c0: Color, c1: Color, segs := 6) -> void:
	var d := Vector3(cos(yaw), 0.0, sin(yaw))
	var side := Vector3(-d.z, 0.0, d.x)
	var rows: Array = []
	for i in segs + 1:
		var t := float(i) / segs
		var c := origin + d * length * t + Vector3.UP * (sin(t * PI * 0.6) * rise - t * t * droop)
		var col := c0.lerp(c1, t)
		col.a = t
		var n := (Vector3.UP * 0.75 + d * 0.15).normalized()
		rows.append([
			[c - side * width + Vector3.DOWN * width * 0.3, Vector2(t, 0.0), col, n],
			[c + Vector3.UP * width * 0.1, Vector2(t, 0.5), col, n],
			[c + side * width + Vector3.DOWN * width * 0.3, Vector2(t, 1.0), col, n]])
	for i in segs:
		for k in 2:
			var a: Array = rows[i][k]
			var b: Array = rows[i][k + 1]
			var cc: Array = rows[i + 1][k]
			var dd: Array = rows[i + 1][k + 1]
			for tri in [[a, cc, b], [b, cc, dd]]:
				for v in tri:
					st.set_uv(v[1])
					st.set_color(v[2])
					st.set_normal(v[3])
					st.add_vertex(v[0])


## Palmen en rotsen komen uit assets/jungle.glb (bron/jungle/maak_jungle.py): 3 palmen met een
## verre variant, 3 rotsen. Stam = schors, kroon = palmblad, rots = steen met mos in de vertexkleuren.
const PALMS := ["Palm1", "Palm2", "Palm3"]
## Wat er op een palmplek komt te staan: een op de vijf is een jungleboom (plankwortels, lianen), op 0,75 geschaald.
const PALM_POOL := ["Palm1", "Palm2", "Palm3", "Palm1", "Boom1", "Palm2", "Palm3", "Boom2", "Palm1", "Palm2"]
const BOOM_SCALE := 0.75
const ROCKS := ["Rots1", "Rots2", "Rots3"]
static var _jungle := {}


static func jungle_mesh(name: String) -> Mesh:
	if _jungle.is_empty():
		var root := (load("res://assets/jungle.glb") as PackedScene).instantiate()
		for mi in root.find_children("*", "MeshInstance3D", true, false):
			_jungle[String(mi.name)] = (mi as MeshInstance3D).mesh
		root.free()
	var m: Mesh = _jungle[name]
	for i in m.get_surface_count():
		var mn := m.surface_get_material(i).resource_name if m.surface_get_material(i) else ""
		if mn.begins_with("Palm_Stam") or mn.begins_with("Boom_Stam"):
			m.surface_set_material(i, material("bark"))
		elif mn.begins_with("Palm_Blad"):
			m.surface_set_material(i, material("palm"))
		elif mn.begins_with("Boom_Blad"):
			m.surface_set_material(i, material("leaf"))
		elif mn.begins_with("Boom_Liaan"):
			m.surface_set_material(i, material())
	return m


## Struik van brede bladeren.
static func bush() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for k in 22:
		var yaw := TAU * k / 22.0 + rng.randf_range(-0.2, 0.2)
		var o := Vector3(cos(yaw), 0, sin(yaw)) * rng.randf_range(0.0, 0.3) + Vector3.UP * rng.randf_range(0.05, 0.5)
		_frond(st, o, yaw, rng.randf_range(0.9, 1.5), rng.randf_range(0.4, 0.55), rng.randf_range(0.5, 1.0), rng.randf_range(0.3, 0.8), Color(0.6, 0.7, 0.55), Color(1.0, 1.0, 0.9), 3)
	var m := st.commit()
	m.surface_set_material(0, material("leaf"))
	return m


static func fern() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for k in 10:
		var yaw := TAU * k / 10.0 + rng.randf_range(-0.15, 0.15)
		_frond(st, Vector3(0, 0.05, 0), yaw, rng.randf_range(1.0, 1.5), 0.32, rng.randf_range(0.5, 0.9), rng.randf_range(0.6, 1.0), Color(0.6, 0.7, 0.55), Color(1.0, 1.0, 0.9), 4)
	var m := st.commit()
	m.surface_set_material(0, material("fern"))
	return m


## Pol gras: drie kruisende kaartjes.
static func grass() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 3:
		var a := PI * k / 3.0
		var d := Vector3(cos(a), 0, sin(a)) * 0.5
		var h := 0.75
		var q := [[-d, Vector2(0, 1), 0.0], [d, Vector2(1, 1), 0.0], [d + Vector3.UP * h, Vector2(1, 0), 1.0], [-d + Vector3.UP * h, Vector2(0, 0), 1.0]]
		for idx in [0, 1, 2, 0, 2, 3]:
			var v: Array = q[idx]
			st.set_uv(v[1])
			st.set_color(Color(0.85, 0.95, 0.75, v[2]))
			st.set_normal(Vector3.UP)
			st.add_vertex(v[0])
	var m := st.commit()
	m.surface_set_material(0, material("grass"))
	return m


## Zet de hele jungle neer: buiten de muur, met het pad vanaf de poorten vrij.
static var trees := PackedVector2Array()  # plekken van palmen en rotsen, voor de landing van de heli
static var _root: Node3D  # waar de jungle in hangt (de vallende bomen komen er ook in)
static var _reg := {}  # vak (36 m) -> palmen en bomen die nog kunnen omvallen (zie fell_near)
const VEG_CELL := 36.0
const BUILD_CLEAR_MARGIN := 0.75
const CLEARABLE_KINDS := ["palm", "bush", "fern", "grass"]
const SOUTH_COUNTS := {"palm": 150, "bush": 260, "fern": 220, "grass": 1100, "rock": 32}
static var _vegetation_cells := {}  # 36 m spatial index; each item points at one actual MultiMesh instance
static var _vegetation_serial := 0
static var _building_clearings := {}  # live placed building id -> regions reapplied after Level rebuild


static func collider_is_clearable(collider: Object) -> bool:
	return is_instance_valid(collider) and collider.has_meta("clearable_vegetation") and bool(collider.get_meta("clearable_vegetation"))


static func _register_vegetation(entry: Dictionary) -> Dictionary:
	var source_transform: Transform3D = entry.get("xf", Transform3D.IDENTITY)
	var local_position: Vector3 = entry.get("local_position", source_transform.origin)
	entry["local_position"] = local_position
	entry["world_position"] = _root.to_global(local_position) if is_instance_valid(_root) else local_position
	entry["vegetation_id"] = _vegetation_serial
	entry["cleared"] = false
	_vegetation_serial += 1
	var position: Vector3 = entry["world_position"]
	var cell := Vector2i(floori(position.x / VEG_CELL), floori(position.z / VEG_CELL))
	entry["vegetation_cell"] = cell
	if not _vegetation_cells.has(cell):
		_vegetation_cells[cell] = []
	_vegetation_cells[cell].append(entry)
	if entry.get("tracks_tree", false):
		entry["tree_local_position"] = Vector2(local_position.x, local_position.z)
		trees.append(entry["tree_local_position"])
	return entry


static func register_grass_instance(local_position: Vector3, slots: Array[Dictionary]) -> Dictionary:
	return _register_vegetation({"kind": "grass", "local_position": local_position, "slots": slots, "shapes": []})


static func _region_world_center(at: Vector3, yaw: float, region: Dictionary) -> Vector2:
	var center: Vector2 = region.center
	return Vector2(at.x, at.z) + _rotate_local(center, yaw)


static func _rotate_local(point: Vector2, yaw: float) -> Vector2:
	return point.rotated(-yaw)


static func _point_in_build_region(point: Vector3, at: Vector3, yaw: float, region: Dictionary, margin: float) -> bool:
	var local := Vector2(point.x - at.x, point.z - at.z).rotated(yaw)
	local -= region.center
	local = local.rotated(float(region.get("yaw", 0.0)))
	var half: Vector2 = region.size * 0.5 + Vector2.ONE * margin
	return absf(local.x) <= half.x and absf(local.y) <= half.y


static func _entries_for_build_regions(regions: Array, at: Vector3, yaw: float, margin: float) -> Array:
	var found := {}
	for region: Dictionary in regions:
		var half: Vector2 = region.size * 0.5 + Vector2.ONE * margin
		var angle := yaw + float(region.get("yaw", 0.0))
		var center := _region_world_center(at, yaw, region)
		var extent_x := absf(cos(angle)) * half.x + absf(sin(angle)) * half.y
		var extent_z := absf(sin(angle)) * half.x + absf(cos(angle)) * half.y
		var low := Vector2i(floori((center.x - extent_x) / VEG_CELL), floori((center.y - extent_z) / VEG_CELL))
		var high := Vector2i(floori((center.x + extent_x) / VEG_CELL), floori((center.y + extent_z) / VEG_CELL))
		for cx in range(low.x, high.x + 1):
			for cz in range(low.y, high.y + 1):
				for entry: Dictionary in _vegetation_cells.get(Vector2i(cx, cz), []):
					if entry.get("cleared", false):
						continue
					if not CLEARABLE_KINDS.has(entry.get("kind", "")):
						continue
					if _point_in_build_region(entry.world_position, at, yaw, region, margin):
						found[entry.vegetation_id] = entry
	return found.values()


static func count_clearable_in_regions(regions: Array, at: Vector3, yaw: float, margin := BUILD_CLEAR_MARGIN) -> int:
	return _entries_for_build_regions(regions, at, yaw, margin).size()


static func clear_for_building(building_id: int, regions: Array, at: Vector3, yaw: float, margin := BUILD_CLEAR_MARGIN) -> int:
	_building_clearings[building_id] = {"regions": regions.duplicate(true), "at": at, "yaw": yaw, "margin": margin}
	return _clear_regions_now(regions, at, yaw, margin)


static func release_building_clearance(building_id: int) -> void:
	_building_clearings.erase(building_id)


static func reapply_building_clearings() -> void:
	for building_id in _building_clearings.keys().duplicate():
		var live_object := instance_from_id(int(building_id))
		if not is_instance_valid(live_object):
			_building_clearings.erase(building_id)
			continue
		var clearing: Dictionary = _building_clearings[building_id]
		_clear_regions_now(clearing.regions, clearing.at, clearing.yaw, clearing.margin)


static func _clear_regions_now(regions: Array, at: Vector3, yaw: float, margin: float) -> int:
	var removed := 0
	for entry: Dictionary in _entries_for_build_regions(regions, at, yaw, margin):
		if _remove_vegetation_entry(entry):
			removed += 1
	return removed


static func _remove_vegetation_entry(entry: Dictionary) -> bool:
	if entry.get("cleared", false):
		return false
	entry["cleared"] = true
	entry["felled"] = true
	var hidden_slots := 0
	for slot: Dictionary in entry.get("slots", []):
		var multimesh: MultiMesh = slot.get("multimesh")
		var index: int = int(slot.get("index", -1))
		if multimesh != null and index >= 0 and index < multimesh.instance_count:
			var transform := multimesh.get_instance_transform(index)
			transform.origin = Vector3(0.0, -1000.0, 0.0)
			multimesh.set_instance_transform(index, transform)
			hidden_slots += 1
	entry["hidden_slot_count"] = hidden_slots
	for shape: CollisionShape3D in entry.get("shapes", []):
		if is_instance_valid(shape):
			shape.set_deferred("disabled", true)
	for name in ["stump_node", "fall_node"]:
		var leftover: Node = entry.get(name)
		if is_instance_valid(leftover):
			leftover.queue_free()
	if entry.get("tracks_tree", false):
		var tree_pos: Vector2 = entry.get("tree_local_position", Vector2.ZERO)
		for i in range(trees.size() - 1, -1, -1):
			if trees[i].is_equal_approx(tree_pos):
				trees.remove_at(i)
				break
	if entry.has("reg_key"):
		var reg_key: Vector2i = entry.reg_key
		var bucket: Array = _reg.get(reg_key, [])
		bucket.erase(entry)
		if bucket.is_empty():
			_reg.erase(reg_key)
	var cell: Vector2i = entry.get("vegetation_cell", Vector2i.ZERO)
	var vegetation_bucket: Array = _vegetation_cells.get(cell, [])
	vegetation_bucket.erase(entry)
	if vegetation_bucket.is_empty():
		_vegetation_cells.erase(cell)
	return true


static func has_tree_near(x: float, z: float, r: float) -> bool:
	var r2 := r * r
	for t in trees:
		if (t.x - x) * (t.x - x) + (t.y - z) * (t.y - z) < r2:
			return true
	return false


static func plant(parent: Node3D, seed_ := 11, step := Callable()) -> void:
	trees.clear()
	_reg.clear()
	_vegetation_cells.clear()
	_vegetation_serial = 0
	_root = parent
	logs(parent)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var south_rng := RandomNumberGenerator.new()
	south_rng.seed = seed_ + 1009
	var sets := {"palm": [190, 18.5, 90.0, 0.85, 1.6, 0.1], "bush": [320, 16.5, 80.0, 0.8, 1.8, 0.05], "fern": [300, 15.8, 70.0, 0.8, 1.7, 0.04], "grass": [1400, 15.2, 62.0, 0.8, 1.8, 0.0], "rock": [45, 18.0, 75.0, 0.7, 2.2, 0.15]}
	var meshes := {"bush": bush(), "fern": fern(), "grass": grass()}
	for kind in sets:
		if step.is_valid():
			await step.call(kind)
		var c: Array = sets[kind]
		var xf: Array = []
		var cols: Array = []
		_scatter(rng, c[0], c[1], c[2], xf, cols, c[3], c[4], c[5])
		_strip(rng, kind, xf.size() + STRIP_EXTRA[kind], xf, cols, c[3], c[4], c[5])
		_south_scatter(south_rng, kind, SOUTH_COUNTS[kind], xf, cols, c[3], c[4], c[5])
		if kind == "grass":
			# Keep the original RNG/placement sequence for palms, rocks and all gameplay.
			# Only grass is replaced by Blender tufts with separate geometric LODs.
			GrassField.spawn(parent, xf)
			continue
		if kind == "rock":
			var rock_shapes := _collide(parent, xf, COLLIDE_R[kind], "concrete", "rock")
			var rm := Kit.rock().duplicate() as StandardMaterial3D
			rm.vertex_color_use_as_albedo = true
			var shadow := _blobs(parent, kind, [xf])
			for v in ROCKS.size():
				var vx: Array = []
				var vc: Array = []
				for i in range(v, xf.size(), ROCKS.size()):
					vx.append(xf[i])
					vc.append(cols[i])
				var inst := Kit.scatter(parent, jungle_mesh(ROCKS[v]), rm, vx, vc)
				inst.add_to_group("foliage_rock")
				for k in vx.size():
					var source_index := v + k * ROCKS.size()
					_register_vegetation({"kind": "rock", "xf": xf[source_index], "tracks_tree": true,
						"slots": [{"multimesh": inst.multimesh, "index": k}, {"multimesh": shadow.multimesh, "index": source_index}],
						"shapes": [rock_shapes[source_index]]})
			continue
		# In vakken van 36 m zodat render-, schaduw- en collisiondata per instance vindbaar blijven.
		var cells := {}
		for i in xf.size():
			var o: Vector3 = xf[i].origin
			var key := Vector2i(floori(o.x / VEG_CELL), floori(o.z / VEG_CELL))
			if not cells.has(key):
				cells[key] = [[], []]
			cells[key][0].append(xf[i])
			cells[key][1].append(cols[i])
		for key in cells:
			# Palmen: elke plek krijgt een palm- of boomvorm; struiken/varens blijven per vak gegroepeerd.
			var groups := {}
			for i in cells[key][0].size():
				var vn: String = PALM_POOL[i % PALM_POOL.size()] if kind == "palm" else ""
				if not groups.has(vn):
					groups[vn] = [[], [], []]
				var xt: Transform3D = cells[key][0][i]
				if vn.begins_with("Boom"):
					xt.basis = xt.basis.scaled(Vector3.ONE * BOOM_SCALE)
				groups[vn][0].append(xt)
				groups[vn][1].append(cells[key][1][i])
				groups[vn][2].append(i)
			var blob: MultiMeshInstance3D = _blobs(parent, kind, [cells[key][0]]) if SHADOW_KINDS.has(kind) else null
			for vn in groups:
				var vx: Array = groups[vn][0]
				var vc: Array = groups[vn][1]
				var mesh: Mesh = jungle_mesh(vn) if kind == "palm" else meshes[kind]
				var shapes: Array = []
				if kind == "palm":
					shapes = _collide(parent, vx, BOOM_COLLIDE_R if vn.begins_with("Boom") else COLLIDE_R["palm"], "wood", "palm")
				var inst := Kit.scatter(parent, mesh, null, vx, vc)
				inst.add_to_group("foliage_" + kind)
				inst.visibility_range_end = VIS_END[kind]
				inst.visibility_range_end_margin = 16.0
				inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
				var far: MultiMeshInstance3D = null
				if kind == "palm":
					inst.visibility_range_end = PALM_NEAR
					far = Kit.scatter(parent, jungle_mesh(vn + "_far"), null, vx, vc, false)
					far.add_to_group("foliage_palm")
					far.visibility_range_begin = PALM_NEAR
					far.visibility_range_begin_margin = 16.0
					far.visibility_range_end = VIS_END["palm"]
					far.visibility_range_end_margin = 16.0
					far.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
				for k in vx.size():
					var source_index: int = groups[vn][2][k]
					var slots: Array[Dictionary] = [{"multimesh": inst.multimesh, "index": k}]
					if far != null:
						slots.append({"multimesh": far.multimesh, "index": k})
					if blob != null:
						slots.append({"multimesh": blob.multimesh, "index": source_index})
					var entry := {"kind": kind, "xf": vx[k], "slots": slots, "shapes": [shapes[k]] if kind == "palm" else [],
						"tracks_tree": kind == "palm", "felled": false}
					if kind == "palm":
						entry.merge({"vn": vn, "mm": inst.multimesh, "far": far.multimesh, "blob": blob.multimesh,
							"idx": k, "blob_idx": source_index, "shape": shapes[k], "col": vc[k], "reg_key": key}, true)
						if not _reg.has(key):
							_reg[key] = []
						_reg[key].append(entry)
					_register_vegetation(entry)
	reapply_building_clearings()


## Onzichtbare ronde zuilen op de plek van stammen en rotsen, per vak van 36 m één lichaam (goedkoop voor de natuurkunde).
static func _collide(parent: Node3D, xforms: Array, radius: float, impact: String, vegetation_kind: String) -> Array:
	var bodies := {}
	var shapes := {}
	var out: Array = []
	for xt: Transform3D in xforms:
		var key := Vector2i(floori(xt.origin.x / 36.0), floori(xt.origin.z / 36.0))
		if not bodies.has(key):
			var b := StaticBody3D.new()
			b.collision_layer = Kit.LAYER_NATURE
			b.set_meta("impact_material", impact)
			b.set_meta("vegetation_kind", vegetation_kind)
			b.set_meta("clearable_vegetation", vegetation_kind == "palm")
			b.collision_mask = 0
			parent.add_child(b)
			bodies[key] = b
		var r := snappedf(radius * xt.basis.x.length(), 0.05)
		if not shapes.has(r):
			var cyl := CylinderShape3D.new()
			cyl.radius = r
			cyl.height = 2.2
			shapes[r] = cyl
		var cs := CollisionShape3D.new()
		cs.shape = shapes[r]
		cs.position = Vector3(xt.origin.x, 1.1, xt.origin.z)
		cs.set_meta("vegetation_kind", vegetation_kind)
		bodies[key].add_child(cs)
		out.append(cs)
	return out


const FELL_MIN_R := 3.0    # kleinste ontploffing (straal in m) die een boom velt: tankgranaat, raket, granaat, vat, voertuig
const FELL_REACH := 0.55   # een boom valt als de ontploffing binnen dit deel van de straal (plus de stam) ligt
const FELL_MAX := 6        # zoveel bomen per ontploffing, zodat een grote knal geen haperingen geeft


## Ontploffing (Game.note_blast): bomen en palmen vlakbij vallen om, van de knal af. Een stronk blijft staan, de stam blijft
## als dekking liggen. Geeft het aantal gevelde bomen.
static func fell_near(at: Vector3, radius: float) -> int:
	if _reg.is_empty() or radius < FELL_MIN_R or not is_instance_valid(_root):
		return 0
	var reach := radius * FELL_REACH
	var lo := Vector2i(floori((at.x - reach - 1.0) / 36.0), floori((at.z - reach - 1.0) / 36.0))
	var hi := Vector2i(floori((at.x + reach + 1.0) / 36.0), floori((at.z + reach + 1.0) / 36.0))
	var n := 0
	for cx in range(lo.x, hi.x + 1):
		for cz in range(lo.y, hi.y + 1):
			for e: Dictionary in _reg.get(Vector2i(cx, cz), []):
				if e["felled"] or n >= FELL_MAX:
					continue
				var o: Vector3 = e["xf"].origin
				if Vector2(o.x - at.x, o.z - at.z).length() <= reach + (0.8 if String(e["vn"]).begins_with("Boom") else 0.3):
					fell(e, at)
					n += 1
	return n


## Voertuig dat tegen een stam rijdt (aanroepen direct na move_and_slide, met de snelheid van vóór de botsing). Gewichtsklassen:
## een voertuig velt een palm vanaf min_palm m/s en een jungleboom vanaf min_boom m/s (INF = nooit). Een jungleboom die te zwaar
## is houdt het voertuig tegen: het kaatst terug en raakt beschadigd (als het take() kent). Tank 1,5 / 2,5; bus 4 / 8; jeep 6 / nooit; auto 7 / nooit.
static func ram(body: CharacterBody3D, speed: float, min_palm: float, min_boom := INF) -> void:
	if speed < minf(min_palm, min_boom) or _reg.is_empty() or not is_instance_valid(_root):
		return
	for i in body.get_slide_collision_count():
		var hit := body.get_slide_collision(i).get_position()
		var key := Vector2i(floori(hit.x / 36.0), floori(hit.z / 36.0))
		var best: Dictionary = {}
		var best_d := 2.0   # een stam of plankwortel zit binnen ~1,5 m van het raakpunt
		for k in [key, key + Vector2i(1, 0), key + Vector2i(-1, 0), key + Vector2i(0, 1), key + Vector2i(0, -1)]:
			for e: Dictionary in _reg.get(k, []):
				if e["felled"]:
					continue
				var o: Vector3 = e["xf"].origin
				var d := Vector2(o.x - hit.x, o.z - hit.z).length()
				if d < best_d:
					best_d = d
					best = e
		if best.is_empty():
			continue
		var boom := String(best["vn"]).begins_with("Boom")
		if speed >= (min_boom if boom else min_palm):
			fell(best, body.global_position)
		elif boom and speed > 3.0:
			var cur = body.get("_speed")
			if cur != null:
				body.set("_speed", -signf(cur) * speed * 0.25)   # te zware boom: terugkaatsen
			if body.has_method("take"):
				body.call("take", speed * 1.5)
			Sfx.play("thud", 0.7, hit)


## Staat er een boom (nog overeind) echt in het rompvlak van dit voertuig? Voor draaien: de natuurkunde houdt draaien niet tegen,
## dus de aanroeper draait terug en velt de boom (hij botst eerst, dan valt hij). half = halve breedte en lengte van de romp.
static func hull_tree(body: Node3D, half: Vector2) -> Dictionary:
	if _reg.is_empty() or not is_instance_valid(_root):
		return {}
	var p := body.global_position
	var inv := body.global_transform.affine_inverse()
	var reach := half.length() + 2.0
	var lo := Vector2i(floori((p.x - reach) / 36.0), floori((p.z - reach) / 36.0))
	var hi := Vector2i(floori((p.x + reach) / 36.0), floori((p.z + reach) / 36.0))
	for cx in range(lo.x, hi.x + 1):
		for cz in range(lo.y, hi.y + 1):
			for e: Dictionary in _reg.get(Vector2i(cx, cz), []):
				if e["felled"]:
					continue
				var local: Vector3 = inv * (e["xf"].origin as Vector3)
				var m := 0.5 if String(e["vn"]).begins_with("Boom") else 0.24   # stamstraal min een rand, zodat alleen echt overlappen telt
				if absf(local.x) < half.x + m and absf(local.z) < half.y + m:
					return e
	return {}


## Eén boom omver: weg uit de MultiMesh (voet, ver-variant, nepschaduw) en uit de botsing, en een vallende boom ervoor in de plaats.
static func fell(e: Dictionary, from: Vector3, solid := true) -> void:
	if e.get("cleared", false) or e.get("felled", false):
		return
	var parent := _root
	e["felled"] = true
	var xf: Transform3D = e["xf"]
	var gone := Transform3D(Basis.from_scale(Vector3.ZERO), xf.origin)
	e["mm"].set_instance_transform(e["idx"], gone)
	e["far"].set_instance_transform(e["idx"], gone)
	e["blob"].set_instance_transform(e["blob_idx"], gone)
	var p: Vector2 = e.get("tree_local_position", Vector2(xf.origin.x, xf.origin.z))
	for i in trees.size():
		if trees[i].is_equal_approx(p):
			trees.remove_at(i)
			break
	var boom := String(e["vn"]).begins_with("Boom")
	# de hoge zuil van de staande boom wordt een lage zuil om de stronk
	var stump_col := CylinderShape3D.new()
	stump_col.radius = ((e["shape"] as CollisionShape3D).shape as CylinderShape3D).radius
	stump_col.height = 1.3 if boom else 0.8
	if solid:
		(e["shape"] as CollisionShape3D).set_deferred("shape", stump_col)
		(e["shape"] as CollisionShape3D).set_deferred("position", Vector3(xf.origin.x, stump_col.height * 0.5, xf.origin.z))
	else:   # door een voertuig geveld: stronk en stam worden platgereden, het voertuig blijft niet haken
		(e["shape"] as CollisionShape3D).set_deferred("disabled", true)
	# de stronk blijft op de plek (een klein stuk van de oude stam, met splinterrand)
	var stump := MeshInstance3D.new()
	stump.mesh = jungle_mesh("Stomp2" if boom else "Stomp1")
	stump.transform = Transform3D(xf.basis, xf.origin)
	parent.add_child(stump)
	e["stump_node"] = stump
	var away := Vector3(xf.origin.x - from.x, 0.0, xf.origin.z - from.z)
	if away.length() < 0.2:
		away = Vector3.RIGHT.rotated(Vector3.UP, randf() * TAU)
	var fall = load("res://scripts/boom_val.gd").new()
	parent.add_child(fall)
	fall.start(jungle_mesh(e["vn"]), xf, away.normalized(), boom, e["col"], solid)
	e["fall_node"] = fall


## Vaste nepschaduwen (platte ovalen) voor één vak bomen.
static func _blobs(parent: Node3D, kind: String, lists: Array) -> MultiMeshInstance3D:
	var q := PlaneMesh.new()
	q.size = Vector2.ONE
	var inst := Kit.scatter(parent, q, _shadow_mat(kind), lists[0], [], false)
	inst.add_to_group("treeshadow")
	inst.visibility_range_end = 100.0
	inst.extra_cull_margin = 30.0  # de schaduw valt tot ver buiten de boom
	return inst


static func _scatter(rng: RandomNumberGenerator, count: int, r_min: float, r_max: float, out: Array, cols: Array, s_min: float, s_max: float, tilt: float) -> void:
	var tries := 0
	while out.size() < count and tries < count * 20:
		tries += 1
		var r := sqrt(rng.randf_range(r_min * r_min, r_max * r_max))
		var a := rng.randf() * TAU
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		if maxf(absf(p.x), absf(p.z)) < Data.COMPOUND + 1.8:
			continue
		if absf(p.x) < 4.6 and absf(p.z) > Data.COMPOUND and absf(p.z) < 70.0:
			continue  # pad vanaf de poorten
		if p.x > Data.COMPOUND and p.x < Data.COMPOUND + 11.5 and absf(p.z) < 23.0:
			continue  # tankbaan langs de oostmuur
		if _in_river(p):
			continue
		_add(rng, out, cols, p, s_min, s_max, tilt)


## Added southern jungle on the already-rendered 440 m terrain plate. The gate exit stays clear.
static func _south_scatter(rng: RandomNumberGenerator, kind: String, count: int, out: Array, cols: Array, s_min: float, s_max: float, tilt: float) -> void:
	var added := 0
	var tries := 0
	var min_z := Data.COMPOUND + 48.0
	var max_z := Data.WORLD_Z_S - 9.0
	while added < count and tries < count * 50:
		tries += 1
		var p := Vector3(rng.randf_range(-Data.WORLD_X + 10.0, Data.WORLD_X - 10.0), 0.0, rng.randf_range(min_z, max_z))
		if absf(p.x) < Data.GATE_GAP + 3.0 or _in_river(p):
			continue
		if kind == "rock":
			var reserved := false
			for region in AirfieldHQ23.site_regions():
				if _point_in_build_region(p, AirfieldHQ23.SUGGESTED_CENTER, 0.0, region, 1.0):
					reserved = true
					break
			if reserved:
				continue
		if kind != "grass" and rng.randf() > 0.30 + 0.70 * _grove(p.x, p.z):
			continue
		_add(rng, out, cols, p, s_min, s_max, tilt)
		added += 1



## In de rivier, op de oevers en op de open paden naar brug en ondiepte.
static func _in_river(p: Vector3) -> bool:
	var d := absf(p.z - Data.river_z(p.x))
	if d < Data.RIVER_HALF + 1.0:
		return true
	if p.z < Data.FOREST_Z0 and p.z > Data.river_z(0.0) and absf(p.x - Data.path_x(p.z)) < 3.4:
		return true  # het pad door het bos blijft open
	if d < 12.0 and (absf(p.x - Data.BRIDGE_X) < 4.2 or absf(p.x - Data.FORD_X) < 3.6):
		return true
	if Stad.covers(p, 4.0):
		return true  # de stad met zijn wegen en gebouwen, en een strook eromheen
	return false


static func _add(rng: RandomNumberGenerator, out: Array, cols: Array, p: Vector3, s_min: float, s_max: float, tilt: float) -> void:
	var s := rng.randf_range(s_min, s_max)
	var b := Basis.from_euler(Vector3(rng.randf_range(-tilt, tilt), rng.randf() * TAU, rng.randf_range(-tilt, tilt))).scaled(Vector3(s, s * rng.randf_range(0.85, 1.2), s))
	out.append(Transform3D(b, p))
	var v := rng.randf_range(0.78, 1.12)
	cols.append(Color(v, v * rng.randf_range(0.94, 1.08), v * 0.92))


## Bos tussen de basismuur en de rivier en daarachter: bosjes en open plekken wisselen elkaar af (rustige sinus-ruis),
## dus je kunt tussen de bomen door lopen en kijken. Het pad van de poort naar de brug blijft vrij.
static func _grove(x: float, z: float) -> float:
	return 0.5 + 0.5 * sin(x * 0.075 + 1.3) * sin(z * 0.095 + 0.4)


static func _strip(rng: RandomNumberGenerator, kind: String, count: int, out: Array, cols: Array, s_min: float, s_max: float, tilt: float) -> void:
	var tries := 0
	while out.size() < count and tries < count * 30:
		tries += 1
		var x := rng.randf_range(-Data.WORLD_X + 2.0, Data.WORLD_X - 2.0)
		var north := rng.randf() < 0.3
		var zr := Data.river_z(x)
		var z := rng.randf_range(-Data.WORLD_Z_N + 3.0, zr - Data.RIVER_HALF - 1.2) if north else rng.randf_range(zr + Data.RIVER_HALF + 1.2, -Data.COMPOUND - 2.0)
		var p := Vector3(x, 0, z)
		if _in_river(p):
			continue
		if kind == "palm" and p.z < Data.FOREST_Z0 and absf(x - Data.path_x(z)) < 7.5:
			continue  # langs het pad geen kruinen die het zicht afsluiten
		if kind != "grass" and rng.randf() > 0.25 + 0.75 * _grove(x, z):
			continue
		if rng.randf() > STRIP_KEEP[Data.strip_zone(x)][kind]:
			continue
		_add(rng, out, cols, p, s_min, s_max, tilt)


## Omgevallen stammen in de strook tussen muur en rivier: dekking voor jou en de vijand.
static func logs(parent: Node3D, seed_ := 41) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.34
	cyl.bottom_radius = 0.4
	cyl.height = 1.0
	cyl.radial_segments = 8
	cyl.rings = 1
	var mat := Kit.photo("nature/tree_bark", 1.5, Color(0.7, 0.62, 0.52))
	var xf: Array = []
	var body := StaticBody3D.new()
	body.collision_layer = Kit.LAYER_WALL
	body.collision_mask = 0
	body.set_meta("impact_material", "wood")
	parent.add_child(body)
	var tries := 0
	while xf.size() < 30 and tries < 800:
		tries += 1
		var x := rng.randf_range(-Data.WORLD_X + 3.0, Data.WORLD_X - 3.0)
		var p := Vector3(x, 0.32, rng.randf_range(Data.river_z(x) + 5.0, -Data.COMPOUND - 3.0))
		if absf(x) < 6.0 or _in_river(p) or Data.strip_zone(x) == "moeras" and rng.randf() < 0.5:
			continue
		var len_ := rng.randf_range(3.5, 7.0)
		var yaw := rng.randf() * PI
		var b: Basis = Basis.from_euler(Vector3(0, yaw, 0)) * Basis.from_euler(Vector3(PI / 2.0, 0, 0)) * Basis.from_scale(Vector3(1, len_, 1))
		xf.append(Transform3D(b, p))
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(0.7, 0.64, len_)
		cs.shape = bs
		cs.transform = Transform3D(Basis.from_euler(Vector3(0, yaw, 0)), p)
		body.add_child(cs)
	Kit.scatter(parent, cyl, mat, xf, [], true)
