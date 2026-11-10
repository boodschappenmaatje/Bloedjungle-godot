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
	set_process(mist or shadows or dust)


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
