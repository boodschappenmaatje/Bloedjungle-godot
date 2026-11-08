class_name McvOpbouw
extends Node3D
## Het hoofdkwartier van de MCV-start wordt gebouwd (Dennis, 8 november 2026): na het wegrijden van de wagen staan er steigers rond de bunker en het
## gebouw groeit in 20 s omhoog; de zandzakkenring komt als laatste. Alleen het zichtbare deel groeit, de botsvorm en de basisgezondheid blijven
## zoals ze waren. Zelfde look als de bouwplaatsen van de andere gebouwen (Buildings._site_start).

const BOUWTIJD := 20.0
const PLEIN_DIEP := 7.0         # m: het voorplein komt omhoog uit de grond (eerste kwart van de bouw)
const SIZE := Vector3(5.4, 6.4, 5.4)   # steiger: m (x, hoogte, z)

var _vis: Node3D
var _vis_scale := Vector3.ONE
var _ring: Array[Node] = []
var _site: Node3D
var _plein: Node3D
var wagen: Node3D               # de geparkeerde bouwwagen (voor de camera)
var begonnen := false           # de bouw begint pas als de wagen is uitgeklapt
var _t := 0.0
var _last_thud := -10.0
var klaar := false


func start(holder: Node3D) -> void:
	holder.add_child(self)
	name = "Opbouw"
	add_to_group("mcv_opbouw")
	var bunker := holder.get_node_or_null("Bunker")
	if bunker != null:
		_vis = bunker.get_node_or_null("Hoofdkwartier") as Node3D
	if _vis != null:
		_vis_scale = _vis.scale
	for c in holder.get_children():
		if c is HqOmgeving:
			_plein = c
		elif c is Node3D and c != self and c.name != "Bunker":
			_ring.append(c)   # de zandzakken
			(c as Node3D).visible = false
	if _vis != null:
		_vis.visible = false
	if _plein != null:
		_plein.visible = false
		_plein.position.y = -PLEIN_DIEP
	_build_site()
	_site.visible = false
	_apply(0.0)


## De wagen is uitgeklapt: nu wordt gebouwd.
func begin() -> void:
	if begonnen:
		return
	begonnen = true
	if _vis != null:
		_vis.visible = true
	if _plein != null:
		_plein.visible = true
	_site.visible = true
	Game.banner.emit("HOOFDKWARTIER WORDT GEBOUWD", "", 2.5)


## Het punt waar de camera naar kijkt tijdens het wegrijden, uitklappen en bouwen: tussen hoofdkwartier en wagen.
func camera_focus() -> Vector3:
	var hq := get_parent().global_position
	if wagen != null and is_instance_valid(wagen):
		return (hq + wagen.global_position) * 0.5
	return hq


func _build_site() -> void:
	_site = Node3D.new()
	_site.name = "Steiger"
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("8a6a3c")
	mat.roughness = 0.9
	var hx := SIZE.x * 0.5
	var hz := SIZE.z * 0.5
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_site.add_child(_plank(Vector3(0.14, SIZE.y, 0.14), Vector3(sx * hx, SIZE.y * 0.5, sz * hz), mat))
	for lvl in [0.28, 0.56, 0.84]:
		var y: float = SIZE.y * lvl
		for sx in [-1, 1]:
			_site.add_child(_plank(Vector3(0.1, 0.1, hz * 2.0), Vector3(sx * hx, y, 0), mat))
		for sz in [-1, 1]:
			_site.add_child(_plank(Vector3(hx * 2.0, 0.1, 0.1), Vector3(0, y, sz * hz), mat))
		# een plankenvloer per verdieping aan de voorkant (deurzijde)
		_site.add_child(_plank(Vector3(hx * 2.0, 0.08, 0.7), Vector3(0, y, hz + 0.2), mat))
	add_child(_site)


func _plank(size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _apply(frac: float) -> void:
	# eerst het voorplein (0 tot 25%), daarna groeit het gebouw (15 tot 100%) en de steiger blijft er net boven
	var k := lerpf(0.04, 1.0, smoothstep(0.0, 1.0, clampf((frac - 0.15) / 0.85, 0.0, 1.0)))
	if _vis != null:
		_vis.scale = Vector3(_vis_scale.x, _vis_scale.y * k, _vis_scale.z)
	if _plein != null:
		_plein.position.y = -PLEIN_DIEP * (1.0 - smoothstep(0.0, 1.0, clampf(frac / 0.25, 0.0, 1.0)))
	if _site != null:
		_site.scale.y = clampf(k + 0.3, 0.3, 1.0)


func _process(delta: float) -> void:
	if klaar:
		return
	if not begonnen:
		return
	_t += delta
	var frac := clampf(_t / BOUWTIJD, 0.0, 1.0)
	_apply(frac)
	if _t - _last_thud > 4.0 and frac < 1.0:
		_last_thud = _t
		Sfx.play("thud", 0.7)
	if frac > 0.85:
		for c in _ring:
			if is_instance_valid(c):
				(c as Node3D).visible = true
	if frac >= 1.0:
		_klaar()


## Voor tests: meteen klaar.
func maak_klaar() -> void:
	begin()
	_t = BOUWTIJD
	_klaar()


func _klaar() -> void:
	if klaar:
		return
	klaar = true
	remove_from_group("mcv_opbouw")
	if _vis != null:
		_vis.visible = true
		_vis.scale = _vis_scale
	if _plein != null:
		_plein.visible = true
		_plein.position.y = 0.0
	for c in _ring:
		if is_instance_valid(c):
			(c as Node3D).visible = true
	if _site != null:
		_site.queue_free()
	Sfx.play("buy")
	Game.banner.emit("HOOFDKWARTIER KLAAR", "", 2.0)
	Game.changed.emit()
