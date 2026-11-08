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
var _fase := -1
var _stof_t := 0.0
var _vonk_t := 0.0
var _hamer_t := 0.0

## De vier bouwfasen: [begin (0-1), naam, ondertitel]
const FASEN := [
	[0.0, "FUNDERING", "Het voorplein wordt gelegd"],
	[0.25, "WANDEN", "De muren gaan omhoog"],
	[0.6, "DAK", "Het dak komt erop"],
	[0.85, "AFWERKING", "Deur, radar en zandzakken"],
]
## Hoogte van het gebouw (0-1) aan het begin van elke fase en aan het eind
const HOOGTE := [[0.0, 0.04], [0.25, 0.04], [0.6, 0.72], [0.85, 0.97], [1.0, 1.0]]


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


## Het punt waar de camera naar kijkt tijdens het wegrijden, uitklappen en bouwen: tussen hoofdkwartier en wagen.
func camera_focus() -> Vector3:
	var hq: Vector3 = (get_parent() as Node3D).global_position
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


func _hoogte(frac: float) -> float:
	for i in range(HOOGTE.size() - 1):
		var a: Array = HOOGTE[i]
		var b: Array = HOOGTE[i + 1]
		if frac <= b[0]:
			var u := clampf((frac - float(a[0])) / maxf(0.0001, float(b[0]) - float(a[0])), 0.0, 1.0)
			return lerpf(float(a[1]), float(b[1]), smoothstep(0.0, 1.0, u))
	return 1.0


func _apply(frac: float) -> void:
	# eerst het voorplein (0 tot 25%), daarna groeit het gebouw (15 tot 100%) en de steiger blijft er net boven
	var k := _hoogte(frac)
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
	_effecten(frac, delta)
	if frac > 0.85:
		for c in _ring:
			if is_instance_valid(c):
				(c as Node3D).visible = true
	if frac >= 1.0:
		_klaar()


func _effecten(frac: float, delta: float) -> void:
	var fase := 0
	for i in FASEN.size():
		if frac >= float((FASEN[i] as Array)[0]):
			fase = i
	if fase != _fase:
		_fase = fase
		var f: Array = FASEN[fase]
		Game.banner.emit(str(f[1]), str(f[2]), 2.2)
		Sfx.play("gate", 0.8)
		if fase == 0:
			Sfx.play("thud", 1.0)
	var hq := get_parent() as Node3D
	var half := Vector2(SIZE.x, SIZE.z) * 0.5
	var hoogte := SIZE.y * clampf(_hoogte(frac) + 0.05, 0.05, 1.0)
	# stof rond de bouwplaats, vooral bij de fundering
	_stof_t -= delta
	if _stof_t <= 0.0:
		_stof_t = 0.45 if fase == 0 else 1.2
		var hoek := randf() * TAU
		var r := (half.x + randf_range(0.5, 2.5)) if fase == 0 else (half.x + randf_range(0.3, 1.0))
		var plek := hq.global_position + hq.global_transform.basis * Vector3(cos(hoek) * r, 0.2, sin(hoek) * r)
		McvFx.puff(hq, plek, 1.4 if fase == 0 else 0.9, Color(0.6, 0.54, 0.43), 7, 1.0)
	# lasvonken op de steiger vanaf de wanden
	if fase >= 1:
		_vonk_t -= delta
		if _vonk_t <= 0.0:
			_vonk_t = randf_range(0.25, 0.6)
			var zijde := randi() % 4
			var y := randf_range(0.8, maxf(1.0, hoogte))
			var lok := Vector3(half.x * (1.0 if zijde == 0 else -1.0 if zijde == 1 else randf_range(-1.0, 1.0)), y, half.y * (1.0 if zijde == 2 else -1.0 if zijde == 3 else randf_range(-1.0, 1.0)))
			Fx.spark(hq, hq.global_position + hq.global_transform.basis * lok, Vector3.UP)
	# hamerslagen
	_hamer_t -= delta
	if _hamer_t <= 0.0 and frac < 1.0:
		_hamer_t = randf_range(0.9, 1.6)
		Sfx.play("thud", 0.55)
		if fase >= 1:
			Sfx.play("click", 0.9)


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
	Sfx.play("claxon", 0.8)   # toeter: klaar
	if wagen != null and is_instance_valid(wagen):
		wagen._model.set_baken(2)
	McvFx.puff(get_parent(), (get_parent() as Node3D).global_position + Vector3(0, 0.4, 0), 2.0, Color(0.7, 0.65, 0.55), 12, 1.3)
	Game.banner.emit("HOOFDKWARTIER KLAAR", "", 2.0)
	Game.changed.emit()
