class_name Graphics2Wereld
extends Node3D
## Graphics 2.0, de onderdelen die in de wereld staan (Atmosphere maakt deze knoop en zet hem aan of uit):
## - nevel: één vlak met laaghangende slierten dat met de camera meeschuift (diepte);
## - contactschaduw: een zachte donkere vlek onder elke soldaat en elk voertuig dichtbij, zodat niets zweeft
##   (de mobiele renderer heeft geen SSAO); één MultiMesh, dus één tekenopdracht;
## - stof achter rijdende voertuigen.

const MIST_HALF := 80.0
const MIST_Y := 1.25
const SHADOW_MAX := 56
const SHADOW_RANGE := 46.0
const DUST_MAX := 6
const DUST_SPEED := 2.2   # m/s: daaronder geen stof
const VEHICLE_GROUPS := ["voertuigen", "vijand_voertuig", "voorraadtruck"]
# halve breedte en halve lengte van de vlek per voertuigscript; de rest krijgt de jeepmaat
const FOOTPRINT := {"tank": Vector2(2.1, 3.9), "vijand_tank": Vector2(2.1, 3.9), "bus": Vector2(1.7, 5.8), "vrachtwagen": Vector2(1.7, 4.3),
	"voorraad_truck": Vector2(1.7, 4.3), "mcv": Vector2(1.9, 4.8)}
const FOOT_DEFAULT := Vector2(1.35, 2.5)

const BEAM_MAX := 26
const BEAM_CELL := 8.0      # m: per vak van het raster hooguit één bundel
const BEAM_RANGE := 5       # vakken rond de speler
const PLANT_GROUP := "g2_begroeiing"

var beams_on := false
var _beams: MultiMeshInstance3D
var _beam_mat: ShaderMaterial
var _beam_cell := Vector2i(99999, 99999)
var _clear := Vector3.ZERO
var _plants_built := false
var mist_on := false
var shadow_on := false
var dust_on := false

var _mist: MeshInstance3D
var _mist_mat: ShaderMaterial
var _shadows: MultiMeshInstance3D
var _scan := 0.0
var _vehicles: Array = []
var _last := {}        # voertuig-id -> vorige positie
var _dust_live := 0


func _ready() -> void:
	add_to_group("graphics2_wereld")
	top_level = true


## Atmosphere roept dit aan bij elke wijziging van de instellingen. tint/strength: kleur en dichtheid van de nevel.
func apply(mist: bool, shadows: bool, dust: bool, tint := Color(0.72, 0.78, 0.7), strength := 0.3) -> void:
	mist_on = mist
	shadow_on = shadows
	dust_on = dust
	if mist and _mist == null:
		_build_mist()
	if _mist != null:
		_mist.visible = mist
		_mist_mat.set_shader_parameter("tint", tint)
		_mist_mat.set_shader_parameter("strength", strength)
	if shadows and _shadows == null:
		_build_shadows()
	if _shadows != null:
		_shadows.visible = shadows
	if not dust:
		for v in _vehicles:
			if is_instance_valid(v):
				var p := v.get_node_or_null("G2Stof") as CPUParticles3D
				if p != null:
					p.emitting = false
	set_process(mist or shadows or dust or beams_on)


## Lichtbundels tussen de bomen (alleen overdag en bij avond): sun_dir = richting waarin het zonlicht reist.
func apply_beams(on: bool, sun_dir := Vector3(0.5, -0.5, 0.5), tint := Color(1.0, 0.82, 0.5), strength := 0.2) -> void:
	beams_on = on
	if on and _beams == null:
		_build_beams()
	if _beams != null:
		_beams.visible = on
		_beam_mat.set_shader_parameter("sun_dir", sun_dir.normalized())
		_beam_mat.set_shader_parameter("tint", tint)
		_beam_mat.set_shader_parameter("strength", strength)
		_beam_cell = Vector2i(99999, 99999)   # opnieuw neerzetten
	set_process(mist_on or shadow_on or dust_on or beams_on)


## Bloemen, bladplanten, varens en keien langs het pad door het bos (keuze 3B). Eenmalig gebouwd, daarna aan of uit.
func apply_plants(on: bool) -> void:
	if on and not _plants_built:
		_plants_built = true
		_build_plants()
	for n in get_tree().get_nodes_in_group(PLANT_GROUP):
		(n as Node3D).visible = on


func _build_beams() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := [Vector3(-0.5, 0, 0), Vector3(0.5, 0, 0), Vector3(0.5, 1, 0), Vector3(-0.5, 1, 0)]
	var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_uv(uvs[i])
		st.add_vertex(pts[i])
	var mesh := st.commit()
	_beam_mat = ShaderMaterial.new()
	_beam_mat.shader = preload("res://shaders/g2_lichtbundel.gdshader")
	_beam_mat.set_shader_parameter("noise", Kit.noise_tex(0.045, 8))
	_beam_mat.render_priority = 3
	mesh.surface_set_material(0, _beam_mat)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = BEAM_MAX
	mm.visible_instance_count = 0
	_beams = MultiMeshInstance3D.new()
	_beams.multimesh = mm
	_beams.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beams.custom_aabb = AABB(Vector3(-4000, -50, -4000), Vector3(8000, 200, 8000))
	add_child(_beams)


static func _hash(x: int, z: int, salt: int) -> float:
	var h := (x * 73856093) ^ (z * 19349663) ^ (salt * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	return float((h ^ (h >> 16)) & 0xffff) / 65535.0


## De bundels staan op vaste plekken in de wereld (een raster met toeval per vak), dus ze verspringen niet als je loopt;
## alleen de vakken rond de speler worden gevuld. Niet in het kamp en niet op het water.
func _place_beams(focus: Vector3) -> void:
	var cell := Vector2i(floori(focus.x / BEAM_CELL), floori(focus.z / BEAM_CELL))
	if cell == _beam_cell:
		return
	_beam_cell = cell
	var mm := _beams.multimesh
	var i := 0
	for dz in range(-BEAM_RANGE, BEAM_RANGE + 1):
		for dx in range(-BEAM_RANGE, BEAM_RANGE + 1):
			if i >= BEAM_MAX:
				break
			var cx := cell.x + dx
			var cz := cell.y + dz
			if _hash(cx, cz, 1) < 0.72:
				continue
			var x := (cx + _hash(cx, cz, 2)) * BEAM_CELL
			var z := (cz + _hash(cx, cz, 3)) * BEAM_CELL
			if absf(x - _clear.x) < 26.0 and absf(z - _clear.z) < 26.0:
				continue
			if absf(z - Data.river_z(x)) < 5.0:
				continue
			mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(x, 0.0, z)))
			mm.set_instance_custom_data(i, Color(2.2 + 2.6 * _hash(cx, cz, 4), 17.0 + 8.0 * _hash(cx, cz, 5), _hash(cx, cz, 6), 0.0))
			i += 1
	mm.visible_instance_count = i


func _build_plants() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2051
	var lists := {"bloem": [], "struik": [], "varen": [], "kei": []}
	var z := Data.FOREST_Z0 - 3.0
	while z > Data.RIVER_Z0 + 6.0:
		for side in [-1.0, 1.0]:
			if rng.randf() < 0.3:
				continue
			var x: float = Data.path_x(z) + side * rng.randf_range(2.7, 6.5)
			var pz := z + rng.randf_range(-0.9, 0.9)
			if Foliage.has_tree_near(x, pz, 1.1):
				continue
			var r := rng.randf()
			var kind := "bloem" if r < 0.36 else ("struik" if r < 0.64 else ("varen" if r < 0.85 else "kei"))
			var sc := rng.randf_range(0.75, 1.15)
			if kind == "kei":
				sc = rng.randf_range(0.28, 0.5)   # kniehoog: je loopt eroverheen, de grote rotsen van de jungle blokkeren wel
			elif kind == "struik":
				sc = rng.randf_range(0.6, 0.95)
			var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc, sc))
			lists[kind].append(Transform3D(b, Vector3(x, 0.0, pz)))
		z -= 2.3
	var meshes := {"bloem": _flower_mesh(), "struik": Foliage.bush(), "varen": Foliage.fern(), "kei": Foliage.jungle_mesh("Rots1")}
	for kind in lists:
		var xf: Array = lists[kind]
		if xf.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = meshes[kind]
		mm.instance_count = xf.size()
		for i in xf.size():
			mm.set_instance_transform(i, xf[i])
		var inst := MultiMeshInstance3D.new()
		inst.multimesh = mm
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if kind == "kei":
			inst.material_override = Kit.rock()
		inst.add_to_group(PLANT_GROUP)
		add_child(inst)


## Jungleplant met rode bloeiwijzen (heliconia-achtig): brede groene bladeren en een paar rode pluimen die omhoog steken.
static func _flower_mesh() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var leaves := SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 9:
		var yaw := TAU * k / 9.0 + rng.randf_range(-0.25, 0.25)
		Foliage._frond(leaves, Vector3(0, 0.04, 0), yaw, rng.randf_range(0.75, 1.15), rng.randf_range(0.3, 0.42), rng.randf_range(0.55, 1.0), rng.randf_range(0.3, 0.7), Color(0.55, 0.7, 0.5), Color(1.0, 1.0, 0.9), 3)
	var mesh := leaves.commit()
	mesh.surface_set_material(0, Foliage.material("leaf"))
	var red := SurfaceTool.new()
	red.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 8:
		var yaw := TAU * k / 8.0 + rng.randf_range(-0.4, 0.4)
		var o := Vector3(cos(yaw), 0, sin(yaw)) * rng.randf_range(0.1, 0.32) + Vector3.UP * rng.randf_range(0.3, 0.55)
		Foliage._frond(red, o, yaw, rng.randf_range(0.15, 0.23), 0.085, rng.randf_range(0.8, 1.3), 0.25, Color(0.26, 0.01, 0.01), Color(0.56, 0.035, 0.025), 2)
	red.commit(mesh)
	var rm := StandardMaterial3D.new()
	rm.vertex_color_use_as_albedo = true
	rm.cull_mode = BaseMaterial3D.CULL_DISABLED
	rm.roughness = 0.7
	mesh.surface_set_material(1, rm)
	return mesh


func _build_mist() -> void:
	_mist = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(MIST_HALF * 2.0, MIST_HALF * 2.0)
	_mist.mesh = plane
	_mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mist.extra_cull_margin = 4.0
	_mist_mat = ShaderMaterial.new()
	_mist_mat.shader = preload("res://shaders/g2_nevel.gdshader")
	_mist_mat.set_shader_parameter("noise", Kit.noise_tex(0.02, 3))
	_mist_mat.set_shader_parameter("half_size", MIST_HALF)
	_mist_mat.render_priority = 2
	_mist.material_override = _mist_mat
	add_child(_mist)


func _build_shadows() -> void:
	var q := PlaneMesh.new()
	q.size = Vector2(2.0, 2.0)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	grad.colors = PackedColorArray([Color(0, 0, 0, 1.0), Color(0, 0, 0, 0.75), Color(0, 0, 0, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = tex
	m.albedo_color = Color(0.02, 0.03, 0.02, 0.5)
	m.disable_fog = true
	m.render_priority = 1
	q.material = m
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = q
	mm.instance_count = SHADOW_MAX
	mm.visible_instance_count = 0
	_shadows = MultiMeshInstance3D.new()
	_shadows.multimesh = mm
	_shadows.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shadows.custom_aabb = AABB(Vector3(-4000, -50, -4000), Vector3(8000, 100, 8000))
	add_child(_shadows)


func _process(delta: float) -> void:
	var p = Game.player
	if p == null or not is_instance_valid(p):
		return
	var focus: Vector3 = p.global_position
	if mist_on and _mist != null:
		_mist.global_position = Vector3(focus.x, MIST_Y, focus.z)
	_scan -= delta
	if _scan <= 0.0:
		_scan = 1.0
		_rescan()
	if shadow_on and _shadows != null:
		_update_shadows(focus)
	if dust_on:
		_update_dust(focus, delta)
	if beams_on and _beams != null:
		_place_beams(focus)


func _rescan() -> void:
	_vehicles.clear()
	for g in VEHICLE_GROUPS:
		for n in get_tree().get_nodes_in_group(g):
			if n is Node3D and not _vehicles.has(n):
				_vehicles.append(n)
	for key in _last.keys():
		if not is_instance_id_valid(key):
			_last.erase(key)
	if _mist_mat != null:
		# geen nevel in het kamp: rond het hoofdkwartier (of het midden van de kaart zolang het er niet staat)
		var c := Vector3.ZERO
		var hq := get_tree().get_first_node_in_group("mcv_hq") as Node3D
		if hq != null:
			c = hq.global_position
		_mist_mat.set_shader_parameter("clear_zone", Vector4(c.x, c.z, 24.0, 24.0))
	var hq2 := get_tree().get_first_node_in_group("mcv_hq") as Node3D
	var c2 := hq2.global_position if hq2 != null else Vector3.ZERO
	if c2.distance_to(_clear) > 1.0:
		_clear = c2
		_beam_cell = Vector2i(99999, 99999)


static func footprint(n: Node) -> Vector2:
	var s: Script = n.get_script()
	if s == null:
		return FOOT_DEFAULT
	return FOOTPRINT.get(s.resource_path.get_file().get_basename(), FOOT_DEFAULT)


func _update_shadows(focus: Vector3) -> void:
	var mm := _shadows.multimesh
	var i := 0
	var soldiers: Array = [Game.player]
	soldiers.append_array(Game.allies)
	soldiers.append_array(Game.enemies)
	for s in soldiers:
		if i >= SHADOW_MAX:
			break
		if not is_instance_valid(s) or not (s is Node3D) or not s.is_inside_tree() or not s.visible or _vehicles.has(s):
			continue
		var pos: Vector3 = s.global_position
		if absf(pos.x - focus.x) > SHADOW_RANGE or absf(pos.z - focus.z) > SHADOW_RANGE:
			continue
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(0.62, 1.0, 0.62)), Vector3(pos.x, pos.y + 0.045, pos.z)))
		i += 1
	for v in _vehicles:
		if i >= SHADOW_MAX:
			break
		if not is_instance_valid(v) or not v.is_inside_tree() or not v.visible:
			continue
		var pos: Vector3 = v.global_position
		if absf(pos.x - focus.x) > SHADOW_RANGE or absf(pos.z - focus.z) > SHADOW_RANGE or pos.y > 1.5:
			continue
		var f := footprint(v)
		var b := Basis(Vector3.UP, v.global_rotation.y) * Basis.from_scale(Vector3(f.x * 1.25, 1.0, f.y * 1.2))
		mm.set_instance_transform(i, Transform3D(b, Vector3(pos.x, 0.05, pos.z)))
		i += 1
	mm.visible_instance_count = i


func _update_dust(focus: Vector3, delta: float) -> void:
	if delta <= 0.0:
		return
	for v in _vehicles:
		if not is_instance_valid(v) or not v.is_inside_tree():
			continue
		var id: int = v.get_instance_id()
		var pos: Vector3 = v.global_position
		var prev: Vector3 = _last.get(id, pos)
		_last[id] = pos
		var speed := Vector2(pos.x - prev.x, pos.z - prev.z).length() / delta
		var dust := v.get_node_or_null("G2Stof") as CPUParticles3D
		var near: bool = absf(pos.x - focus.x) < 55.0 and absf(pos.z - focus.z) < 55.0
		var want: bool = near and v.visible and pos.y < 1.5 and speed > DUST_SPEED and speed < 60.0
		if dust == null:
			if not want or _dust_live >= DUST_MAX:
				continue
			dust = _make_dust(footprint(v))
			v.add_child(dust)
			_dust_live += 1
			dust.tree_exiting.connect(func(): _dust_live = maxi(0, _dust_live - 1))
		dust.emitting = want


static func _make_dust(f: Vector2) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "G2Stof"
	p.amount = 18
	p.lifetime = 1.7
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(f.x * 0.8, 0.1, f.y * 0.8)
	p.position = Vector3(0, 0.3, 0)
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 1.1
	p.gravity = Vector3(0, 0.35, 0)
	p.scale_amount_min = 1.7
	p.scale_amount_max = 2.7
	var c := Curve.new()
	c.add_point(Vector2(0, 0.35))
	c.add_point(Vector2(1, 1.0))
	p.scale_amount_curve = c
	p.angle_min = -180.0
	p.angle_max = 180.0
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.15, 1.0])
	g.colors = PackedColorArray([Color(0.74, 0.66, 0.52, 0.0), Color(0.74, 0.66, 0.52, 0.7), Color(0.78, 0.71, 0.6, 0.0)])
	p.color_ramp = g
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	q.material = Fx.g2_particle_mat()
	p.mesh = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emitting = false
	return p
