class_name RijBalk
extends Node3D
## Bouwrij boven een kazerne: vijf kleine vakjes die naar de camera kijken. Gevulde vakjes zijn soldaten in de rij,
## het eerste vakje vult zich naarmate de soldaat klaar komt. Verborgen als de rij leeg is.

const SLOTS := 5
const STEP := 0.46
const SIZE := 0.36

static var _mat_bg: StandardMaterial3D
static var _mat_full: StandardMaterial3D
static var _mat_prog: StandardMaterial3D

var _full: Array[MeshInstance3D] = []
var _prog: MeshInstance3D


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
		_mat_bg = _mk(Color(0, 0, 0, 0.6), 10)
		_mat_bg.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat_full = _mk(Color(0.82, 0.68, 0.24), 11)
		_mat_prog = _mk(Color(0.95, 0.9, 0.55), 12)
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	var x0 := -STEP * (SLOTS - 1) * 0.5
	for i in SLOTS:
		var bg := MeshInstance3D.new()
		bg.mesh = q
		bg.material_override = _mat_bg
		bg.scale = Vector3(SIZE + 0.08, SIZE + 0.08, 1)
		bg.position.x = x0 + i * STEP
		bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(bg)
		var f := MeshInstance3D.new()
		f.mesh = q
		f.material_override = _mat_full
		f.scale = Vector3(SIZE, SIZE, 1)
		f.position.x = x0 + i * STEP
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		f.visible = false
		add_child(f)
		_full.append(f)
	# voortgang van het eerste vakje: een lichtere balk onderin
	_prog = MeshInstance3D.new()
	_prog.mesh = q
	_prog.material_override = _mat_prog
	_prog.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_prog.visible = false
	add_child(_prog)
	visible = false


## count = eenheden in de rij (0..5), progress = 0..1 van de eenheid die nu klaar komt; progress < 0 = geen voortgangsbalk (garage)
func set_value(count: int, progress: float) -> void:
	var show := count > 0
	if visible != show:
		visible = show
	if not show:
		return
	var x0 := -STEP * (SLOTS - 1) * 0.5
	for i in SLOTS:
		_full[i].visible = i < count and (i > 0 or progress < 0.0)
	var p := clampf(progress, 0.0, 1.0)
	# het eerste vakje: balk die van links naar rechts vult
	_prog.visible = progress >= 0.0
	_prog.scale = Vector3(maxf(0.02, SIZE * p), SIZE, 1)
	_prog.position.x = x0 - SIZE * 0.5 + SIZE * p * 0.5
