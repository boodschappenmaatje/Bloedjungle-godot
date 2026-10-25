class_name GrenadeAim
extends MeshInstance3D
## Richthulp voor de handgranaat: stippellijn van de boog en een landingscirkel op de grond.
## Geel = vrije baan, rood = een muur of auto staat in de weg. Altijd zichtbaar door bladeren en daken heen.

const OK := Color(1.0, 0.82, 0.3, 0.95)
const BLOCKED := Color(0.95, 0.18, 0.12, 0.95)

var _im := ImmediateMesh.new()
var blocked := false
var land := Vector3.ZERO


func _init() -> void:
	mesh = _im
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.render_priority = 10
	material_override = m
	top_level = true


## Tekent de voorspelde baan van from naar target; blast = straal van de ontploffing.
func show_throw(from: Vector3, target: Vector3, blast: float) -> void:
	global_transform = Transform3D.IDENTITY
	var p := Grenade.predict(get_world_3d(), from, target)
	blocked = p.blocked
	land = p.land
	var col := BLOCKED if blocked else OK
	_im.clear_surfaces()
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: PackedVector3Array = p.points
	# om de andere stip: een gestippelde boog, plat zodat hij van boven goed leesbaar is
	for i in range(1, pts.size() - 1, 2):
		_disc(pts[i], 0.12, col, 6)
	var ground := Vector3(land.x, target.y + 0.06, land.z)
	_ring(ground, 0.55, 0.12, col)
	_disc(ground, 0.12, col, 8)
	_ring(ground, blast, 0.07, Color(col, 0.4))
	_im.surface_end()
	visible = true


func _disc(c: Vector3, r: float, col: Color, n: int) -> void:
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		_im.surface_set_color(col)
		_im.surface_add_vertex(c)
		_im.surface_add_vertex(c + Vector3(cos(a0), 0, sin(a0)) * r)
		_im.surface_add_vertex(c + Vector3(cos(a1), 0, sin(a1)) * r)


func _ring(c: Vector3, r: float, w: float, col: Color) -> void:
	var n := clampi(int(r * 10.0), 24, 64)
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		_im.surface_set_color(col)
		for v in [c + d0 * (r - w), c + d0 * (r + w), c + d1 * (r + w), c + d0 * (r - w), c + d1 * (r + w), c + d1 * (r - w)]:
			_im.surface_add_vertex(v)
