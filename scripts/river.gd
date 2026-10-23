class_name River
## De rivier over het noorden van de kaart met de houten brug en de doorwaadbare plek (07b-river.js van de web-versie).
## De bedding ligt onder de grond (de grondshader snijdt de rivier eruit), modderige oevers lopen schuin naar beneden naar
## een donkere bodem onder stromend water. Je steekt over op de brug (noord) of bij de ondiepte met stenen (oost).
## Onzichtbare oevers houden mensen tegen; kogels vliegen erover. Brug en ford blijven open.

const W := Data.RIVER_HALF
const BEDDING := [[-1.0, 0.0, 0.0], [-0.73, -0.5, 0.45], [-0.5, -0.85, 0.85], [0.5, -0.85, 0.85], [0.73, -0.5, 0.45], [1.0, 0.0, 0.0]]  # dwarsprofiel: factor van W, hoogte, modder -> bodem
const WATER_Y := -0.2
const X_MAX := 210.0
const BRIDGE_HALF := 2.5


static func build(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "Rivier"
	parent.add_child(root)
	_trough(root)
	_water(root)
	_banks(root)
	_bridge(root)
	_ford(root)
	_reeds(root)


## Hoogte-factor: bij de doorwaadbare plek is de bedding ondiep (1 = volle diepte).
static func _depth(x: float) -> float:
	return 1.0 - 0.65 * (1.0 - smoothstep(2.0, 4.0, absf(x - Data.FORD_X)))


static func _pt(x: float, off: float, y: float) -> Vector3:
	return Vector3(x, y * _depth(x), Data.river_z(x) + off)


static func _trough(root: Node3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bank := Color("4a3a24")
	var bed := Color("16120c")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var x := -X_MAX
	while x < X_MAX:
		var xs := [x, x + 1.0]
		for k in BEDDING.size() - 1:
			var a: Array = BEDDING[k]
			var b: Array = BEDDING[k + 1]
			var q := [_pt(xs[0], a[0] * W, a[1]), _pt(xs[1], a[0] * W, a[1]), _pt(xs[1], b[0] * W, b[1]), _pt(xs[0], b[0] * W, b[1])]
			var n: Vector3 = (q[1] - q[0]).cross(q[3] - q[0]).normalized()
			if n.y < 0.0:
				n = -n
			var shade := 0.85 + 0.3 * rng.randf()
			var ca := bank.lerp(bed, a[2]) * shade
			var cb := bank.lerp(bed, b[2]) * shade
			ca.a = 1.0
			cb.a = 1.0
			for i in [0, 2, 1, 0, 3, 2]:
				st.set_normal(n)
				st.set_color(ca if i < 2 else cb)
				st.add_vertex(q[i])
		x += 1.0
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.75
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


static func _water(root: Node3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var x := -X_MAX
	var hw := W - 0.1
	while x < X_MAX:
		var xs := [x, x + 2.0]
		var q := [Vector3(xs[0], WATER_Y, Data.river_z(xs[0]) - hw), Vector3(xs[1], WATER_Y, Data.river_z(xs[1]) - hw), Vector3(xs[1], WATER_Y, Data.river_z(xs[1]) + hw), Vector3(xs[0], WATER_Y, Data.river_z(xs[0]) + hw)]
		for i in [0, 2, 1, 0, 3, 2]:
			st.set_normal(Vector3.UP)
			st.add_vertex(q[i])
		x += 2.0
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/water.gdshader")
	m.set_shader_parameter("noise", Kit.noise_tex(0.05, 17))
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	root.add_child(mi)


## Onzichtbare oevers: blokken langs de hele rivier, behalve bij de brug en de doorwaadbare plek.
static func _banks(root: Node3D) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Kit.LAYER_WATER
	body.collision_mask = 0
	root.add_child(body)
	var x := -X_MAX
	while x < X_MAX:
		var cx := x + 0.75
		x += 1.5
		if absf(cx - Data.BRIDGE_X) < 3.0 or absf(cx - Data.FORD_X) < 2.4:
			continue
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(2.0, 3.0, 2.0 * (W + 0.7))
		cs.shape = bs
		cs.position = Vector3(cx, 1.5, Data.river_z(cx))
		body.add_child(cs)


# ---------------------------------------------------------------- brug

static func _bridge(root: Node3D) -> void:
	var br := Bridge.new()
	br.name = "Brug"
	br.position = Vector3(Data.BRIDGE_X, 0, Data.river_z(Data.BRIDGE_X))
	root.add_child(br)
	if not Engine.is_editor_hint():
		Game.bridge = br


# ---------------------------------------------------------------- ford en riet

static func _ford(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var xf: Array = []
	var cols: Array = []
	for k in range(-3, 4):
		var z := Data.river_z(Data.FORD_X) + k * 0.8
		for pass_ in 2:
			var px := Data.FORD_X + (rng.randf_range(-0.5, 0.5) if pass_ == 0 else rng.randf_range(1.0, 1.6) * (1.0 if k % 2 else -1.0))
			var pz := z + (0.0 if pass_ == 0 else 0.3)
			var r := rng.randf_range(0.35, 0.5) if pass_ == 0 else rng.randf_range(0.3, 0.42)
			var b := Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3(r * 2.0, r * 1.2, r * 2.0))
			xf.append(Transform3D(b, Vector3(px, -0.3 + r * 0.25, pz)))
			var v := rng.randf_range(0.8, 1.1)
			cols.append(Color(v, v, v))
	var sph := SphereMesh.new()
	sph.radius = 0.5
	sph.height = 1.0
	sph.radial_segments = 8
	sph.rings = 4
	var rm := Kit.rock().duplicate() as StandardMaterial3D
	rm.vertex_color_use_as_albedo = true
	Kit.scatter(root, sph, rm, xf, cols, false)


static func _reeds(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	var xf: Array = []
	var cols: Array = []
	var tries := 0
	while xf.size() < 520 and tries < 6000:
		tries += 1
		var x := rng.randf_range(-Data.WORLD_R + 2.0, Data.WORLD_R - 2.0)
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var z := Data.river_z(x) + side * (W + rng.randf_range(-0.2, 0.6))
		if absf(x - Data.BRIDGE_X) < 4.0 or absf(x - Data.FORD_X) < 3.0:
			continue
		var h := rng.randf_range(0.9, 2.0)
		var b := Basis.from_euler(Vector3(rng.randf_range(-0.15, 0.15), 0, rng.randf_range(-0.15, 0.15))).scaled(Vector3(1, h, 1))
		xf.append(Transform3D(b, Vector3(x, h * 0.5, z)))
		cols.append(Color.from_hsv(rng.randf_range(0.17, 0.25), 0.55, rng.randf_range(0.18, 0.32)))
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.012
	cyl.bottom_radius = 0.03
	cyl.height = 1.0
	cyl.radial_segments = 4
	cyl.rings = 1
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.8
	Kit.scatter(root, cyl, m, xf, cols, false)
