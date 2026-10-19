class_name Foliage
## Bomen, struiken, varens en rotsen, zelf opgebouwd uit driehoeken (geen losse modelbestanden).
## Kleuren zitten in de vertexkleuren; de alfa is hoe sterk iets in de wind beweegt (foliage.gdshader).

static var _mat: ShaderMaterial


static func material() -> ShaderMaterial:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = preload("res://shaders/foliage.gdshader")
	return _mat


## Eén blad of palmtak: een gebogen strook met een licht gevouwen middenrib.
static func _frond(st: SurfaceTool, origin: Vector3, yaw: float, length: float, width: float, rise: float, droop: float, c0: Color, c1: Color, segs := 6) -> void:
	var d := Vector3(cos(yaw), 0.0, sin(yaw))
	var side := Vector3(-d.z, 0.0, d.x)
	var rows: Array = []
	for i in segs + 1:
		var t := float(i) / segs
		var c := origin + d * length * t + Vector3.UP * (sin(t * PI * 0.6) * rise - t * t * droop)
		var w := width * pow(sin(minf(t * 1.0, 1.0) * PI), 0.6) + 0.03
		var col := c0.lerp(c1, t)
		col.a = t
		var up := Vector3(0, 1, 0)
		var n := (up * 0.75 + d * 0.15).normalized()
		rows.append([[c - side * w + Vector3.DOWN * w * 0.25, col, n], [c + Vector3.UP * w * 0.12, col.lightened(0.08), n], [c + side * w + Vector3.DOWN * w * 0.25, col, n]])
	for i in segs:
		for k in 2:
			var a: Array = rows[i][k]
			var b: Array = rows[i][k + 1]
			var cc: Array = rows[i + 1][k]
			var dd: Array = rows[i + 1][k + 1]
			for tri in [[a, cc, b], [b, cc, dd]]:
				for v in tri:
					st.set_color(v[1])
					st.set_normal(v[2])
					st.add_vertex(v[0])


static func palm() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 9
	var sides := 7
	var rings: Array = []
	var top := Vector3.ZERO
	for i in segs + 1:
		var t := float(i) / segs
		var c := Vector3(0.9 * t * t, 5.2 * t, 0.35 * t * t)
		top = c
		var r := lerpf(0.27, 0.13, t) * (1.0 + 0.18 * (1.0 if i % 2 == 0 else 0.0))
		var ring: Array = []
		for j in sides:
			var a := TAU * j / sides
			ring.append([c + Vector3(cos(a) * r, 0, sin(a) * r), Vector3(cos(a), 0, sin(a))])
		rings.append(ring)
	for i in segs:
		var shade := 0.85 if i % 2 == 0 else 1.0
		var col := Color(0.42 * shade, 0.30 * shade, 0.19 * shade, 0.04 * i / segs)
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
	# kroon van takken
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for k in 10:
		var yaw := TAU * k / 10.0 + rng.randf_range(-0.2, 0.2)
		var len := rng.randf_range(2.3, 3.0)
		_frond(st, top + Vector3.UP * 0.05, yaw, len, rng.randf_range(0.5, 0.7), rng.randf_range(0.9, 1.4), rng.randf_range(1.0, 1.7), Color("1d4a14"), Color("5f9a32"), 7)
	for k in 5:  # jonge takken die recht omhoog staan
		_frond(st, top + Vector3.UP * 0.1, TAU * k / 5.0 + 0.3, 1.3, 0.3, 1.1, 0.3, Color("2d6a1c"), Color("8cc044"), 4)
	mesh = st.commit()
	return mesh


static func bush() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for k in 16:
		var yaw := TAU * k / 16.0 + rng.randf_range(-0.2, 0.2)
		var o := Vector3(cos(yaw), 0, sin(yaw)) * rng.randf_range(0.0, 0.25) + Vector3.UP * rng.randf_range(0.05, 0.35)
		_frond(st, o, yaw, rng.randf_range(0.8, 1.3), rng.randf_range(0.28, 0.4), rng.randf_range(0.5, 0.9), rng.randf_range(0.3, 0.7), Color("17400f"), Color("4f9030"), 4)
	return st.commit()


static func fern() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for k in 9:
		var yaw := TAU * k / 9.0 + rng.randf_range(-0.15, 0.15)
		_frond(st, Vector3(0, 0.05, 0), yaw, rng.randf_range(0.9, 1.3), 0.17, rng.randf_range(0.4, 0.8), rng.randf_range(0.5, 0.9), Color("1f4d12"), Color("6ca636"), 5)
	return st.commit()


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
	var palms: Array = []
	var palm_cols: Array = []
	var bushes: Array = []
	var bush_cols: Array = []
	var ferns: Array = []
	var fern_cols: Array = []
	var rocks: Array = []
	var rock_cols: Array = []
	_scatter(rng, 150, 18.5, 85.0, palms, palm_cols, 0.85, 1.55, 0.12, true)
	_scatter(rng, 300, 16.5, 80.0, bushes, bush_cols, 0.8, 1.7, 0.05, false)
	_scatter(rng, 260, 15.8, 70.0, ferns, fern_cols, 0.8, 1.6, 0.04, false)
	_scatter(rng, 45, 18.0, 75.0, rocks, rock_cols, 0.7, 2.2, 0.15, true)
	Kit.scatter(parent, palm(), material(), palms, palm_cols)
	Kit.scatter(parent, bush(), material(), bushes, bush_cols)
	Kit.scatter(parent, fern(), material(), ferns, fern_cols, false)
	var rm := Kit.rock().duplicate() as StandardMaterial3D
	rm.vertex_color_use_as_albedo = true
	Kit.scatter(parent, rock(), rm, rocks, rock_cols)


static func _scatter(rng: RandomNumberGenerator, count: int, r_min: float, r_max: float, out: Array, cols: Array, s_min: float, s_max: float, tilt: float, dense_far: bool) -> void:
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
		var v := rng.randf_range(0.78, 1.12)
		cols.append(Color(v, v * rng.randf_range(0.94, 1.08), v * 0.92))
