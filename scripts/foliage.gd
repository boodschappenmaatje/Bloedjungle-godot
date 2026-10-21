class_name Foliage
## Bomen, struiken, varens en rotsen, zelf opgebouwd uit driehoeken (geen losse modelbestanden).
## Kleuren zitten in de vertexkleuren; de alfa is hoe sterk iets in de wind beweegt (foliage.gdshader).

static var _mats := {}
static var _shadow_mats := {}  # soort -> nepschaduw-materiaal
const STRIP_EXTRA := {"palm": 190, "bush": 520, "fern": 560, "grass": 2200, "rock": 14}  # extra stuks in de strook tussen muur en rivier
## Hoeveel van de extra planten per gebied blijft staan: moeras = varens en gras, open plek = bijna kaal met rotsen, dicht = alles.
const STRIP_KEEP := {
	"dicht": {"palm": 1.0, "bush": 1.0, "fern": 1.0, "grass": 1.0, "rock": 0.5},
	"moeras": {"palm": 0.3, "bush": 0.35, "fern": 0.9, "grass": 1.0, "rock": 0.2},
	"open": {"palm": 0.06, "bush": 0.12, "fern": 0.3, "grass": 0.45, "rock": 1.0},
}
const SHADOW_KINDS := {"palm": [4.2, 2.6, 0.8], "bush": [1.1, 1.8, 0.7], "rock": [0.5, 1.2, 0.6]}  # hoogte, breedte, sterkte


## Wind-materiaal; met een bladtextuur (kind) of zonder (stam, rotsen).
static func material(kind := "") -> ShaderMaterial:
	if not _mats.has(kind):
		var m := ShaderMaterial.new()
		m.shader = preload("res://shaders/foliage.gdshader")
		m.set_shader_parameter("use_tex", kind != "")
		if kind != "":
			m.set_shader_parameter("tex", LeafTex.get_tex(kind))
			m.set_shader_parameter("nrm", LeafTex.get_normal(kind))
		if kind == "grass":
			m.set_shader_parameter("sway", 0.08)
			m.set_shader_parameter("cut", 0.35)
		m.set_shader_parameter("wind", 1.0 if GameSettings.get_value("wind") == "on" else 0.0)
		_mats[kind] = m
	return _mats[kind]


## Zet de wind in alle bladeren aan of uit.
static func set_wind(on: bool) -> void:
	for k in _mats:
		_mats[k].set_shader_parameter("wind", 1.0 if on else 0.0)


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


static func palm() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 10
	var sides := 7
	var rings: Array = []
	var top := Vector3.ZERO
	for i in segs + 1:
		var t := float(i) / segs
		var c := Vector3(0.9 * t * t, 5.4 * t, 0.35 * t * t)
		top = c
		var r := lerpf(0.27, 0.13, t) * (1.0 + 0.2 * (1.0 if i % 2 == 0 else 0.0))
		var ring: Array = []
		for j in sides:
			var a := TAU * j / sides
			ring.append([c + Vector3(cos(a) * r, 0, sin(a) * r), Vector3(cos(a), 0, sin(a))])
		rings.append(ring)
	for i in segs:
		var shade := 0.8 if i % 2 == 0 else 1.0
		var col := Color(0.5 * shade, 0.38 * shade, 0.26 * shade, 0.04 * i / segs)
		for j in sides:
			var p00: Array = rings[i][j]
			var p01: Array = rings[i][(j + 1) % sides]
			var p10: Array = rings[i + 1][j]
			var p11: Array = rings[i + 1][(j + 1) % sides]
			for tri in [[p00, p10, p11], [p00, p11, p01]]:
				for v in tri:
					st.set_color(col)
					st.set_normal(v[1])
					st.add_vertex(v[0])
	st.commit(mesh)
	mesh.surface_set_material(0, material())
	# kroon van takken met bladpunten
	var crown := SurfaceTool.new()
	crown.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var white := Color(0.78, 0.9, 0.7)
	var dark := Color(0.5, 0.64, 0.42)
	for k in 12:
		var yaw := TAU * k / 12.0 + rng.randf_range(-0.2, 0.2)
		_frond(crown, top + Vector3.UP * 0.05, yaw, rng.randf_range(2.6, 3.4), rng.randf_range(0.65, 0.85), rng.randf_range(0.9, 1.5), rng.randf_range(1.1, 1.9), dark, white, 7)
	for k in 6:
		_frond(crown, top + Vector3.UP * 0.1, TAU * k / 6.0 + 0.3, 1.5, 0.45, 1.3, 0.3, dark, white, 4)
	crown.commit(mesh)
	mesh.surface_set_material(1, material("palm"))
	return mesh


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


static func rock() -> Mesh:
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 0.8
	s.radial_segments = 7
	s.rings = 4
	return s


## Zet de hele jungle neer: buiten de muur, met het pad vanaf de poorten vrij.
static func plant(parent: Node3D, seed_ := 11) -> void:
	logs(parent)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var sets := {"palm": [190, 18.5, 90.0, 0.85, 1.6, 0.1], "bush": [320, 16.5, 80.0, 0.8, 1.8, 0.05], "fern": [300, 15.8, 70.0, 0.8, 1.7, 0.04], "grass": [1400, 15.2, 62.0, 0.8, 1.8, 0.0], "rock": [45, 18.0, 75.0, 0.7, 2.2, 0.15]}
	var meshes := {"palm": palm(), "bush": bush(), "fern": fern(), "grass": grass(), "rock": rock()}
	for kind in sets:
		var c: Array = sets[kind]
		var xf: Array = []
		var cols: Array = []
		_scatter(rng, c[0], c[1], c[2], xf, cols, c[3], c[4], c[5])
		_strip(rng, kind, xf.size() + STRIP_EXTRA[kind], xf, cols, c[3], c[4], c[5])
		if kind == "rock":
			var rm := Kit.rock().duplicate() as StandardMaterial3D
			rm.vertex_color_use_as_albedo = true
			var ri := Kit.scatter(parent, meshes[kind], rm, xf, cols)
			ri.add_to_group("foliage_rock")
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
				var inst := Kit.scatter(parent, meshes[kind], null, cells[key][0], cells[key][1], kind != "grass")
				inst.add_to_group("foliage_" + kind)  # de grafiekinstelling dunt gras en struiken uit
				if SHADOW_KINDS.has(kind):
					_blobs(parent, kind, [cells[key][0]])


## Vaste nepschaduwen (platte ovalen) voor één vak bomen.
static func _blobs(parent: Node3D, kind: String, lists: Array) -> void:
	var q := PlaneMesh.new()
	q.size = Vector2.ONE
	var inst := Kit.scatter(parent, q, _shadow_mat(kind), lists[0], [], false)
	inst.add_to_group("treeshadow")
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
	if d < 12.0 and (absf(p.x - Data.BRIDGE_X) < 4.2 or absf(p.x - Data.FORD_X) < 3.6):
		return true
	return false


static func _add(rng: RandomNumberGenerator, out: Array, cols: Array, p: Vector3, s_min: float, s_max: float, tilt: float) -> void:
	var s := rng.randf_range(s_min, s_max)
	var b := Basis.from_euler(Vector3(rng.randf_range(-tilt, tilt), rng.randf() * TAU, rng.randf_range(-tilt, tilt))).scaled(Vector3(s, s * rng.randf_range(0.85, 1.2), s))
	out.append(Transform3D(b, p))
	var v := rng.randf_range(0.78, 1.12)
	cols.append(Color(v, v * rng.randf_range(0.94, 1.08), v * 0.92))


## Dichte jungle in de strook tussen de basismuur en de rivier; het pad vanaf de poort naar de brug blijft vrij.
static func _strip(rng: RandomNumberGenerator, kind: String, count: int, out: Array, cols: Array, s_min: float, s_max: float, tilt: float) -> void:
	var tries := 0
	while out.size() < count and tries < count * 20:
		tries += 1
		var x := rng.randf_range(-Data.WORLD_R * 0.8, Data.WORLD_R * 0.8)
		var zr := Data.river_z(x)
		var z := rng.randf_range(zr + Data.RIVER_HALF + 1.2, -Data.COMPOUND - 2.0)
		var p := Vector3(x, 0, z)
		if absf(x) < 4.6 or _in_river(p) or Vector2(x, z).length() > Data.WORLD_R:
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
	parent.add_child(body)
	var tries := 0
	while xf.size() < 26 and tries < 600:
		tries += 1
		var x := rng.randf_range(-Data.WORLD_R * 0.75, Data.WORLD_R * 0.75)
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
