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


static func has_tree_near(x: float, z: float, r: float) -> bool:
	var r2 := r * r
	for t in trees:
		if (t.x - x) * (t.x - x) + (t.y - z) * (t.y - z) < r2:
			return true
	return false


static func plant(parent: Node3D, seed_ := 11, step := Callable()) -> void:
	trees.clear()
	logs(parent)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
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
		if kind == "grass":
			# Keep the original RNG/placement sequence for palms, rocks and all gameplay.
			# Only grass is replaced by Blender tufts with separate geometric LODs.
			GrassField.spawn(parent, xf)
			continue
		if kind == "palm" or kind == "rock":
			for t in xf:
				trees.append(Vector2(t.origin.x, t.origin.z))
		if kind == "rock":
			_collide(parent, xf, COLLIDE_R[kind], "concrete")
		if kind == "rock":
			var rm := Kit.rock().duplicate() as StandardMaterial3D
			rm.vertex_color_use_as_albedo = true
			for v in ROCKS.size():
				var vx: Array = []
				var vc: Array = []
				for i in range(v, xf.size(), ROCKS.size()):
					vx.append(xf[i])
					vc.append(cols[i])
				Kit.scatter(parent, jungle_mesh(ROCKS[v]), rm, vx, vc).add_to_group("foliage_rock")
			_blobs(parent, kind, [xf])
		else:
			# in vakken van 36 m, zodat de camera alleen tekent en laat schaduwen wat in beeld is
			var cells := {}
			for i in xf.size():
				var o: Vector3 = xf[i].origin
				var key := Vector2i(floori(o.x / 36.0), floori(o.z / 36.0))
				if not cells.has(key):
					cells[key] = [[], []]
				cells[key][0].append(xf[i])
				cells[key][1].append(cols[i])
			for key in cells:
				# palmen: elke plek een van de vormen uit PALM_POOL (palmen en jungleboom)
				var groups := {}  # vorm -> [transforms, kleuren]
				for i in cells[key][0].size():
					var vn: String = PALM_POOL[i % PALM_POOL.size()] if kind == "palm" else ""
					if not groups.has(vn):
						groups[vn] = [[], []]
					var xt: Transform3D = cells[key][0][i]
					if vn.begins_with("Boom"):
						xt.basis = xt.basis.scaled(Vector3.ONE * BOOM_SCALE)
					groups[vn][0].append(xt)
					groups[vn][1].append(cells[key][1][i])
				for vn in groups:
					var vx: Array = groups[vn][0]
					var vc: Array = groups[vn][1]
					var mesh: Mesh = jungle_mesh(vn) if kind == "palm" else meshes[kind]
					if kind == "palm":
						_collide(parent, vx, BOOM_COLLIDE_R if vn.begins_with("Boom") else COLLIDE_R["palm"], "wood")
					var inst := Kit.scatter(parent, mesh, null, vx, vc, kind != "grass")
					inst.add_to_group("foliage_" + kind)  # de grafiekinstelling dunt gras en struiken uit
					# vakken die ver weg liggen worden niet meer getekend; ver weg staan palmen als simpeler model
					inst.visibility_range_end = VIS_END[kind]
					inst.visibility_range_end_margin = 16.0
					inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF  # zacht in- en uitdoven i.p.v. ploffen
					if kind == "palm":
						inst.visibility_range_end = PALM_NEAR
						var far := Kit.scatter(parent, jungle_mesh(vn + "_far"), null, vx, vc, false)
						far.add_to_group("foliage_palm")
						far.visibility_range_begin = PALM_NEAR
						far.visibility_range_begin_margin = 16.0
						far.visibility_range_end = VIS_END["palm"]
						far.visibility_range_end_margin = 16.0
						far.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
				if SHADOW_KINDS.has(kind):
					_blobs(parent, kind, [cells[key][0]])


## Onzichtbare ronde zuilen op de plek van stammen en rotsen, per vak van 36 m één lichaam (goedkoop voor de natuurkunde).
static func _collide(parent: Node3D, xforms: Array, radius: float, impact: String) -> void:
	var bodies := {}
	var shapes := {}
	for xt: Transform3D in xforms:
		var key := Vector2i(floori(xt.origin.x / 36.0), floori(xt.origin.z / 36.0))
		if not bodies.has(key):
			var b := StaticBody3D.new()
			b.collision_layer = Kit.LAYER_NATURE
			b.set_meta("impact_material", impact)
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
		bodies[key].add_child(cs)


## Vaste nepschaduwen (platte ovalen) voor één vak bomen.
static func _blobs(parent: Node3D, kind: String, lists: Array) -> void:
	var q := PlaneMesh.new()
	q.size = Vector2.ONE
	var inst := Kit.scatter(parent, q, _shadow_mat(kind), lists[0], [], false)
	inst.add_to_group("treeshadow")
	inst.visibility_range_end = 100.0
	inst.extra_cull_margin = 30.0  # de schaduw valt tot ver buiten de boom


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
