class_name McvOpbouw
extends Node3D
## Het hoofdkwartier van de MCV-start wordt gebouwd (Dennis, 8 november 2026): na het wegrijden van de wagen staan er steigers rond de bunker en het
## gebouw groeit in 20 s omhoog; de zandzakkenring komt als laatste. Alleen het zichtbare deel groeit, de botsvorm en de basisgezondheid blijven
## zoals ze waren. Zelfde look als de bouwplaatsen van de andere gebouwen (Buildings._site_start).

const BOUWTIJD := 20.0
const WACHT := 3.5              # s: de wagen rijdt eerst weg
const SIZE := Vector3(5.4, 6.4, 5.4)   # steiger: m (x, hoogte, z)

var _vis: Node3D
var _vis_scale := Vector3.ONE
var _ring: Array[Node] = []
var _site: Node3D
var _t := 0.0
var _last_thud := -10.0
var klaar := false


func start(holder: Node3D) -> void:
	holder.add_child(self)
	name = "Opbouw"
	var bunker := holder.get_node_or_null("Bunker")
	if bunker != null:
		_vis = bunker.get_node_or_null("Hoofdkwartier") as Node3D
	if _vis != null:
		_vis_scale = _vis.scale
	for c in holder.get_children():
		if c is Node3D and c != self and c.name != "Bunker" and not (c is HqOmgeving):
			_ring.append(c)   # de zandzakken
			(c as Node3D).visible = false
	_build_site()
	_apply(0.0)


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
	var k := lerpf(0.04, 1.0, smoothstep(0.0, 1.0, frac))
	if _vis != null:
		_vis.scale = Vector3(_vis_scale.x, _vis_scale.y * k, _vis_scale.z)


func _process(delta: float) -> void:
	if klaar:
		return
	_t += delta
	var bouw := maxf(0.0, _t - WACHT)
	var frac := clampf(bouw / BOUWTIJD, 0.0, 1.0)
	_apply(frac)
	if _site != null:
		_site.visible = _t >= WACHT
	if _t >= WACHT and _t - _last_thud > 4.0 and frac < 1.0:
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
	_t = WACHT + BOUWTIJD
	_klaar()


func _klaar() -> void:
	if klaar:
		return
	klaar = true
	if _vis != null:
		_vis.scale = _vis_scale
	for c in _ring:
		if is_instance_valid(c):
			(c as Node3D).visible = true
	if _site != null:
		_site.queue_free()
	Sfx.play("buy")
	Game.banner.emit("HOOFDKWARTIER KLAAR", "", 2.0)
	Game.changed.emit()
