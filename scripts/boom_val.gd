extends Node3D
## Een boom die omvalt (Foliage.fell): kantelt om zijn voet van de knal af, versnelt, slaat op de grond met stof, bladeren en
## een dreun, veert kort terug en blijft liggen. De stam wordt dan een lage botsing (dekking), de kroon ligt eroverheen.

const T_FALL := 1.5        # seconden tot de kroon de grond raakt (palm); bomen zijn hoger en vallen trager
const REBOUND := 0.45      # seconden terugveren na de klap
const BOUNCE := 6.0        # graden dat de kroon terugveert
const TRUNK_SHARE := 0.85  # deel van de modelhoogte dat stam is (de rest is kroon)

var _t := 0.0
var _dur := T_FALL
var _len := 5.0
var _lift := 0.3
var _dir := Vector3.RIGHT
var _axis := Vector3.RIGHT
var _landed := false
var _cracked := false
var _origin := Vector3.ZERO
var _solid := true       # false = door een voertuig geveld: de stam krijgt geen botsing


## mesh = de boom (uit jungle_mesh), xf = zijn plek en schaal, dir = richting waarin hij valt (vlak, lengte 1).
func start(mesh: Mesh, xf: Transform3D, dir: Vector3, boom: bool, col := Color.WHITE, solid := true) -> void:
	_solid = solid
	_origin = xf.origin
	_dir = dir
	_axis = Vector3.UP.cross(dir).normalized()
	var h := mesh.get_aabb().size.y * xf.basis.y.length()
	_len = h * TRUNK_SHARE
	_lift = 0.35 if boom else 0.28
	_dur = T_FALL * sqrt(maxf(h, 3.0) / 5.5)
	position = _origin
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = 1
	mm.set_instance_transform(0, Transform3D(xf.basis, Vector3.ZERO))
	mm.set_instance_color(0, col)
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	add_child(mi)
	_tilt(0.0)


## Hoek (graden) op tijdstip t: langzaam begin, dan versnellen tot de klap, daarna terugveren.
func _angle(t: float) -> float:
	if t < _dur:
		var u := t / _dur
		return 90.0 * pow(u, 2.3)
	var s := clampf((t - _dur) / REBOUND, 0.0, 1.0)
	return 90.0 - BOUNCE * sin(s * PI) * (1.0 - s)


func _tilt(deg: float) -> void:
	var a := deg_to_rad(deg)
	basis = Basis(_axis, a)
	position = _origin + Vector3.UP * _lift * sin(a)


func _process(delta: float) -> void:
	_t += delta
	_tilt(_angle(_t))
	if not _cracked and _t > 0.05:
		_cracked = true
		Sfx.play("thud", 0.6, _origin)   # krakende voet
		Fx.impact(get_parent(), _origin + Vector3.UP * 0.5, -_dir, "wood")
	if not _landed and _t >= _dur:
		_landed = true
		_land()
	if _t >= _dur + REBOUND:
		set_process(false)


func _land() -> void:
	var parent := get_parent()
	var tip := _origin + _dir * _len
	Fx.dust(parent, tip + Vector3.UP * 0.3)
	Fx._burst(parent, tip + Vector3.UP * 0.8, Vector3.UP, 16, Color(0.24, 0.42, 0.14), 0.12, 3.0, Vector3(0.12, 0.02, 0.12))
	Fx._burst(parent, _origin + _dir * (_len * 0.5) + Vector3.UP * 0.4, Vector3.UP, 8, Color(0.58, 0.52, 0.42), 0.07, 2.0)
	Sfx.play("boom", 0.28, tip)
	if not _solid:
		return
	# de liggende stam: een lage balk waar je niet doorheen loopt, maar die ook kogels opvangt (dekking)
	var body := StaticBody3D.new()
	body.collision_layer = Kit.LAYER_NATURE
	body.collision_mask = 0
	body.set_meta("impact_material", "wood")
	var shape := BoxShape3D.new()
	var half := 0.4
	shape.size = Vector3(_len, half * 2.0, _lift * 2.2)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	parent.add_child(body)
	body.global_transform = Transform3D(Basis(Vector3.UP, atan2(-_dir.z, _dir.x)), _origin + _dir * (_len * 0.5) + Vector3.UP * half)
