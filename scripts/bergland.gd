class_name Bergland
## Diepte rond de kaart (dambreuk-plan, stap 1, keuze 2A/3B): het speelveld blijft de vlakke grondplaat op hoogte 0,
## maar daarbuiten loopt het land op naar beboste heuvels en, in het noorden, hoge bergen. De rivier loopt in een eigen
## dal door de heuvels verder naar oost en west, en achter de vijandbasis snijdt een kloof de bergen in: daar komen in
## stap 2 de dam en het stuwmeer (Dennis koos 1A). Alleen beeld: niemand komt hier (Data.clamp_world), dus geen botsing.
##
## Data.ground_y(x, z) geeft overal de hoogte; op de grondplaat is die precies 0, zodat alle bestaande gameplay gelijk blijft.

# grondplaat (level.gd): x -220..220, z Data.GROUND_Z_MIN (-300) .. 220
const PLATE_X := 220.0
const PLATE_Z_N := -300.0
const PLATE_Z_S := 220.0
const EXTENT_X := 760.0          # tot hier loopt het bergland (oost/west)
const EXTENT_Z_N := -860.0
const EXTENT_Z_S := 620.0
const CELL := 10.0               # rastermaat van de berg-mesh in meters
const RIVER_FLOOR := -1.0        # bodem van het rivierdal buiten de plaat (water op RIVER_WATER_Y erboven)
const RIVER_X_MAX := 210.0       # = River.X_MAX (hier herhaald: River hangt aan Game, Data en tests moeten zonder kunnen)
const RIVER_WATER_Y := -0.2      # = River.WATER_Y

# kloof en stuwmeer (stap 2): de kloof loopt vanaf de noordrand van de plaat recht boven de vijandbasis de bergen in
const GORGE_X := -36.0
const DAM_Z := -336.0
const DAM_FLOOR := 2.0           # hoogte van de kloofbodem bij de dam
const BASIN := Vector2(-48.0, -470.0)   # midden van het (nu nog droge) stuwmeerbekken
const BASIN_R := 120.0
const BASIN_FLOOR := 3.0
const LAKE_Y := 14.0             # waterpeil van het toekomstige stuwmeer (12 m boven het dal + bodem)

static var _noise: FastNoiseLite
static var _detail: FastNoiseLite


static func _init_noise() -> void:
	if _noise != null:
		return
	_noise = FastNoiseLite.new()
	_noise.seed = 4711                     # vast: de bergen en de kloof liggen elk spel op dezelfde plek (keuze 13A)
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.0042
	_noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_noise.fractal_octaves = 4
	_detail = FastNoiseLite.new()
	_detail.seed = 977
	_detail.frequency = 0.021
	_detail.fractal_octaves = 2


## Afstand (m) van een punt tot de grondplaat; 0 erop.
static func plate_dist(x: float, z: float) -> float:
	var dx := maxf(absf(x) - PLATE_X, 0.0)
	var dz := maxf(maxf(PLATE_Z_N - z, z - PLATE_Z_S), 0.0)
	return sqrt(dx * dx + dz * dz)


## Midden van de kloof op diepte z (licht kronkelend).
static func gorge_x(z: float) -> float:
	return GORGE_X + 7.0 * sin(z * 0.021 + 0.6)


## Hoogte van het land. Op de grondplaat altijd 0.
static func height(x: float, z: float) -> float:
	var d := plate_dist(x, z)
	if d <= 0.0:
		return 0.0
	_init_noise()
	var ridge := _noise.get_noise_2d(x, z) * 0.5 + 0.5          # 0..1, ruggen
	var det := _detail.get_noise_2d(x, z)                      # -1..1, kleine bulten (boomkruinen, kopjes)
	# noorden: hoge bergen; zuiden, oost en west: beboste heuvels
	var north := smoothstep(PLATE_Z_N + 40.0, PLATE_Z_N - 120.0, z)
	var peak := lerpf(26.0, 62.0, north)
	# voet: de eerste 40 m blijven lage heuvels (vliegtuigen op 12 m beginnen tot 90 m buiten de kaart)
	# behalve recht ten noorden van de plaat: daar staan de kloofwanden meteen steil omhoog (de dam ligt 36 m buiten de plaat)
	var wall := smoothstep(PLATE_Z_N + 2.0, PLATE_Z_N - 20.0, z) * (1.0 - smoothstep(PLATE_X - 40.0, PLATE_X + 30.0, absf(x)))
	var foot := 4.0 * smoothstep(0.0, 40.0, d)
	var big := smoothstep(lerpf(45.0, 4.0, wall), lerpf(170.0, 60.0, wall), d)
	var h := foot + big * (8.0 + wall * 14.0 + peak * ridge * ridge) + det * 2.0 * smoothstep(0.0, 30.0, d)

	# rivierdal: de rivier loopt oost en west door de heuvels verder in een eigen dal
	if absf(x) > PLATE_X - 30.0:
		var rz := Data.river_z(clampf(x, -RIVER_X_MAX, RIVER_X_MAX))
		var w := 13.0 + 0.08 * maxf(absf(x) - PLATE_X, 0.0)   # breder dan de rivier zelf: het raster is 10 m grof
		var v := exp(-pow((z - rz) / w, 4.0))
		var bank := exp(-pow((z - rz) / (w * 2.2), 2.0))
		h = lerpf(h, h * 0.5, bank)
		h = lerpf(h, RIVER_FLOOR, v)

	# kloof van de plaat naar het stuwmeer, daarachter het bekken
	if z < PLATE_Z_N + 10.0:
		var t := clampf((PLATE_Z_N - z) / (PLATE_Z_N - DAM_Z), 0.0, 1.0)
		var floor_y := lerpf(0.0, DAM_FLOOR, t)
		var w2 := lerpf(26.0, 30.0, t)
		var g := exp(-pow((x - gorge_x(z)) / w2, 4.0)) * smoothstep(PLATE_Z_N + 10.0, PLATE_Z_N - 4.0, z)
		if z < DAM_Z:   # achter de dam: kloof loopt over in het bekken
			g *= smoothstep(DAM_Z - 70.0, DAM_Z - 10.0, z)
		h = lerpf(h, floor_y + det * 0.4, g)
		var b := smoothstep(BASIN_R, BASIN_R * 0.62, Vector2(x, z).distance_to(BASIN))
		h = lerpf(h, BASIN_FLOOR + det * 0.6, b)
	return h


static func normal_at(x: float, z: float) -> Vector3:
	var e := 2.0
	var hx := height(x + e, z) - height(x - e, z)
	var hz := height(x, z + e) - height(x, z - e)
	return Vector3(-hx, 2.0 * e, -hz).normalized()


## Bouwt de berg-mesh rond de grondplaat (één tekenopdracht) en het rivierwater door de dalen.
static func build(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "Bergland"
	parent.add_child(root)
	var mi := MeshInstance3D.new()
	mi.name = "Bergen"
	mi.mesh = build_mesh()
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/bergland.gdshader")
	m.set_shader_parameter("noise", Kit.noise_tex(0.05, 23))
	m.set_shader_parameter("canopy_tex", load("res://assets/textures/terrain/jungle_ground/base_color.jpg"))
	m.set_shader_parameter("rock_tex", load("res://assets/textures/terrain/gravel_rock/base_color.jpg"))
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # schaduw zit in de belichting van de hellingen
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mi.extra_cull_margin = 4.0
	root.add_child(mi)
	_river_out(root)


## Raster over het hele gebied; cellen die helemaal op de grondplaat liggen worden overgeslagen (die tekent level.gd).
static func build_mesh() -> ArrayMesh:
	_init_noise()
	var nx := int((EXTENT_X * 2.0) / CELL) + 1
	var nz := int((EXTENT_Z_S - EXTENT_Z_N) / CELL) + 1
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	verts.resize(nx * nz)
	norms.resize(nx * nz)
	cols.resize(nx * nz)
	var hs := PackedFloat32Array()
	hs.resize(nx * nz)
	for j in nz:
		var z := EXTENT_Z_N + j * CELL
		for i in nx:
			var x := -EXTENT_X + i * CELL
			var y := height(x, z)
			hs[j * nx + i] = y
			verts[j * nx + i] = Vector3(x, y, z)
	for j in nz:
		for i in nx:
			var k := j * nx + i
			var l := hs[k - 1] if i > 0 else hs[k]
			var r := hs[k + 1] if i < nx - 1 else hs[k]
			var u := hs[k - nx] if j > 0 else hs[k]
			var dn := hs[k + nx] if j < nz - 1 else hs[k]
			var n := Vector3(l - r, 2.0 * CELL, u - dn).normalized()
			norms[k] = n
			# r = holte (dalen donkerder, een goedkope occlusie), g = rand van de plaat (daar overvloeien in de grondkleur)
			var cav := clampf(((l + r + u + dn) * 0.25 - hs[k]) * 0.12 + 0.5, 0.0, 1.0)
			var d := plate_dist(verts[k].x, verts[k].z)
			cols[k] = Color(cav, clampf(d / 40.0, 0.0, 1.0), 0.0, 1.0)
	var idx := PackedInt32Array()
	for j in nz - 1:
		for i in nx - 1:
			var a := j * nx + i
			var b := a + 1
			var c := a + nx
			var e := c + 1
			# cel helemaal op de plaat (alle hoeken op hoogte 0 en binnen de plaat): overslaan
			if plate_dist(verts[a].x, verts[a].z) <= 0.0 and plate_dist(verts[e].x, verts[e].z) <= 0.0 \
					and plate_dist(verts[b].x, verts[b].z) <= 0.0 and plate_dist(verts[c].x, verts[c].z) <= 0.0:
				continue
			idx.append_array([a, b, c, b, e, c])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


## Het rivierwater loopt buiten de plaat door het dal verder (zelfde watershader als River).
static func _river_out(root: Node3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: float in [-1.0, 1.0]:
		var x := RIVER_X_MAX - 4.0
		while x < EXTENT_X:
			var x0 := side * x
			var x1 := side * (x + 4.0)
			var w0 := 2.9 + 0.03 * maxf(x - PLATE_X, 0.0)
			var w1 := 2.9 + 0.03 * maxf(x + 4.0 - PLATE_X, 0.0)
			var z0 := Data.river_z(clampf(x0, -RIVER_X_MAX, RIVER_X_MAX))
			var z1 := Data.river_z(clampf(x1, -RIVER_X_MAX, RIVER_X_MAX))
			var q := [Vector3(x0, RIVER_WATER_Y, z0 - w0), Vector3(x1, RIVER_WATER_Y, z1 - w1), Vector3(x1, RIVER_WATER_Y, z1 + w1), Vector3(x0, RIVER_WATER_Y, z0 + w0)]
			var order := [0, 2, 1, 0, 3, 2] if side > 0.0 else [0, 1, 2, 0, 2, 3]
			for i in order:
				st.set_normal(Vector3.UP)
				st.add_vertex(q[i])
			x += 4.0
	var mi := MeshInstance3D.new()
	mi.name = "RivierBuiten"
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.09, 0.22, 0.2)
	m.roughness = 0.35
	m.metallic_specular = 0.35
	m.cull_mode = BaseMaterial3D.CULL_DISABLED   # vult ook het gat tussen het einde van de rivierbedding (x 210) en de plaatrand (220)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
