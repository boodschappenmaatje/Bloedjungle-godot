class_name HpBar
extends Node3D
## Levensbalkje boven een bouwwerk of poort: een klein balkje dat naar de camera kijkt en door muren heen zichtbaar is.

const W := 2.0
const H := 0.2

static var _mat_bg: StandardMaterial3D
static var _mat_fill := {}

var _fill: MeshInstance3D
var _last := -1.0


static func _mk(col: Color, prio: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.no_depth_test = true
	m.render_priority = prio
	m.albedo_color = col
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _init() -> void:
	if _mat_bg == null:
		_mat_bg = _mk(Color(0, 0, 0, 0.7), 10)
		_mat_bg.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	var bg := MeshInstance3D.new()
	bg.mesh = q
	bg.material_override = _mat_bg
	bg.scale = Vector3(W + 0.12, H + 0.12, 1)
	bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bg)
	_fill = MeshInstance3D.new()
	_fill.mesh = q
	_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_fill)
	visible = false


## frac 0..1; show = bar tonen
func set_value(frac: float, show: bool) -> void:
	if visible != show:
		visible = show
	if not show or is_equal_approx(frac, _last):
		return
	_last = frac
	var key := "g" if frac > 0.5 else ("o" if frac > 0.25 else "r")
	if not _mat_fill.has(key):
		_mat_fill[key] = _mk({"g": Color(0.45, 0.75, 0.25), "o": Color(0.95, 0.65, 0.15), "r": Color(0.85, 0.15, 0.1)}[key], 11)
	_fill.material_override = _mat_fill[key]
	var f := clampf(frac, 0.02, 1.0)
	_fill.scale = Vector3(W * f, H, 1)
	_fill.position.x = -W * 0.5 + W * f * 0.5
