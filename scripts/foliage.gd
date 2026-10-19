class_name Foliage
## Bomen, struiken, varens en rotsen, zelf opgebouwd uit driehoeken (geen losse modelbestanden).
## Kleuren zitten in de vertexkleuren; de alfa is hoe sterk iets in de wind beweegt (foliage.gdshader).

static var _mats := {}


## Wind-materiaal; met een bladtextuur (kind) of zonder (stam, rotsen).
static func material(kind := "") -> ShaderMaterial:
	if not _mats.has(kind):
		var m := ShaderMaterial.new()
		m.shader = preload("res://shaders/foliage.gdshader")
		m.set_shader_parameter("use_tex", kind != "")
		if kind != "":
			m.set_shader_parameter("tex", LeafTex.get_tex(kind))
		if kind == "grass":
			m.set_shader_parameter("sway", 0.08)
			m.set_shader_parameter("cut", 0.35)
		_mats[kind] = m
	return _mats[kind]


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


static func palm(seed_ := 5) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var segs := 10
	var sides := 7
	var rings: Array = []
	var top := Vector3.ZERO
	for i in segs + 1:
		var t := float(i) / segs
		var c := Vector3(0.9 * t * t, 5.0 + 0.4 * sin(float(seed_) * 0.7) * t, 0.35 * t * t)
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
	var white := Color(0.46, 0.56, 0.34)
	var dark := Color(0.23, 0.34, 0.20)
	for k in 12:
		var yaw := TAU * k / 12.0 + rng.randf_range(-0.2, 0.2)
		_frond(crown, top + Vector3.UP * 0.05, yaw, rng.randf_range(2.4, 3.6), rng.randf_range(0.55, 0.82), rng.randf_range(0.7, 1.35), rng.randf_range(1.15, 2.0), dark, white, 7)
	for k in 6:
		_frond(crown, top + Vector3.UP * 0.1, TAU * k / 6.0 + rng.randf_range(0.2, 0.4), rng.randf_range(1.2, 1.8), 0.4, rng.randf_range(1.0, 1.4), 0.3, dark, white, 4)
	crown.commit(mesh)
	mesh.surface_set_material(1, material("palm"))
	return mesh


## Struik van brede bladeren.
static func bush(seed_ := 9) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var leaf_count := rng.randi_range(18, 26)
	for k in leaf_count:
		var yaw := TAU * k / leaf_count + rng.randf_range(-0.28, 0.28)
		var o := Vector3(cos(yaw), 0, sin(yaw)) * rng.randf_range(0.0, 0.3) + Vector3.UP * rng.randf_range(0.05, 0.5)
		_frond(st, o, yaw, rng.randf_range(0.75, 1.45), rng.randf_range(0.34, 0.58), rng.randf_range(0.45, 0.95), rng.randf_range(0.3, 0.8), Color(0.30, 0.42, 0.27), Color(0.53, 0.61, 0.40), 3)
	var m := st.commit()
	m.surface_set_material(0, material("leaf"))
	return m


static func fern(seed_ := 3) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var frond_count := rng.randi_range(8, 12)
	for k in frond_count:
		var yaw := TAU * k / frond_count + rng.randf_range(-0.2, 0.2)
		_frond(st, Vector3(0, 0.05, 0), yaw, rng.randf_range(0.85, 1.55), rng.randf_range(0.24, 0.36), rng.randf_range(0.45, 0.95), rng.randf_range(0.55, 1.0), Color(0.28, 0.42, 0.25), Color(0.50, 0.61, 0.39), 4)
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
			st.set_color(Color(0.45, 0.56, 0.34, v[2]))
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
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var sets := {"palm": [126, 17.0, 91.0, 0.78, 1.7, 0.14], "bush": [420, 15.8, 84.0, 0.72, 1.9, 0.06], "fern": [370, 15.2, 74.0, 0.68, 1.8, 0.05], "grass": [1650, 14.8, 65.0, 0.68, 1.9, 0.0], "rock": [70, 16.5, 78.0, 0.65, 2.3, 0.15]}
	# A few silhouettes per plant type break up the repeated, evenly spaced crowns while keeping
	# each group instanced in a small number of draw calls.
	var meshes := {
		"palm": [palm(5), palm(17), palm(31)],
		"bush": [bush(9), bush(23), bush(41)],
		"fern": [fern(3), fern(19), fern(37)],
		"grass": [grass()],
		"rock": [rock()],
	}
	for kind in sets:
		var c: Array = sets[kind]
		var xf: Array = []
		var cols: Array = []
		_scatter(rng, c[0], c[1], c[2], xf, cols, c[3], c[4], c[5])
		for variant in meshes[kind].size():
			var variant_xf: Array = []
			var variant_cols: Array = []
			for i in xf.size():
				if i % meshes[kind].size() != variant:
					continue
				variant_xf.append(xf[i])
				variant_cols.append(cols[i])
			if kind == "rock":
				var rm := Kit.rock().duplicate() as StandardMaterial3D
				rm.vertex_color_use_as_albedo = true
				Kit.scatter(parent, meshes[kind][variant], rm, variant_xf, variant_cols)
			else:
				var cast_shadow := kind == "palm"
				Kit.scatter(parent, meshes[kind][variant], null, variant_xf, variant_cols, cast_shadow)


static func _scatter(rng: RandomNumberGenerator, count: int, r_min: float, r_max: float, out: Array, cols: Array, s_min: float, s_max: float, tilt: float) -> void:
	var tries := 0
	while out.size() < count and tries < count * 20:
		tries += 1
		var r := sqrt(rng.randf_range(r_min * r_min, r_max * r_max))
		var a := rng.randf() * TAU
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		if maxf(absf(p.x), absf(p.z)) < Data.COMPOUND + 1.8:
			continue
		if absf(p.x) < 4.6 and absf(p.z) > Data.COMPOUND and absf(p.z) < 50.0:
			continue  # pad vanaf de poorten
		var s := rng.randf_range(s_min, s_max)
		var b := Basis.from_euler(Vector3(rng.randf_range(-tilt, tilt), rng.randf() * TAU, rng.randf_range(-tilt, tilt))).scaled(Vector3(s, s * rng.randf_range(0.85, 1.2), s))
		out.append(Transform3D(b, p))
		var v := rng.randf_range(0.68, 1.08)
		# Canopy and understory stay in muted olive/forest hues rather than bright lime green.
		cols.append(Color(v * rng.randf_range(0.94, 1.04), v, v * rng.randf_range(0.82, 0.96)))
