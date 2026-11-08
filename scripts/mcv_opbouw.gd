class_name McvOpbouw
extends Node3D
## Het hoofdkwartier van de MCV-start wordt gebouwd (Dennis, 8 november 2026). De wagen laat de container achter op de bouwplek en rijdt weg; de
## container klapt open (clip Uitklappen). Daarna hijst de kraan op de wagen acht prefab-platen een voor een op het groeiende gebouw terwijl
## soldaten kisten dragen. Als het gebouw staat zakt de container weg en lopen de bouwers het hoofdkwartier in. Alleen het zichtbare deel groeit:
## de botsvorm en de basisgezondheid blijven zoals ze waren.

const T_VOOR := 5.0             # s: het voorplein komt omhoog en de kraan richt zich op
const CYCLE := 3.4              # s per plaat: pakken, zwenken, plaatsen en terugzwenken
const T_LAND := 3.25            # s in de cyclus: de plaat zit op het gebouw
const T_GROEI := 1.0            # s: het gebouw groeit een laag na het plaatsen
const T_AF := 3.2               # s: afwerking na de laatste plaat
const BOUWTIJD := T_VOOR + 8.0 * CYCLE + T_AF
const PLEIN_DIEP := 7.0         # m: het voorplein komt omhoog uit de grond
const GRONDLAAG := 0.04         # deel van de hoogte dat er staat voor de eerste plaat
const WEG_WACHT := 1.6          # s: groen baken, dan zakt de container weg
const WEG_ZAK := 1.8            # s: de container zakt in de grond
const DEUR := Vector3(0.0, 0.0, -3.0)   # de ingang van het hoofdkwartier (lokaal): daar lopen de bouwers naar binnen

var _vis: Node3D
var _vis_scale := Vector3.ONE
var _hoogte := 5.5              # m: hoogte van het gebouw
var _ring: Array[Node] = []
var _plein: Node3D
var wagen: Node3D               # de geparkeerde bouwwagen (voor de camera)
var begonnen := false           # de bouw begint pas als de wagen is uitgeklapt
var _t := 0.0
var klaar := false
var _fase := -1
var _stof_t := 0.0
var _kraan: McvKraan
var _cycle := -1
var _start_haak := Vector3.ZERO
var _plaat := -1                # index van de plaat in de haak (-1 = geen)
var _geland := -1               # aantal geplaatste platen - 1
var _werkers: Array = []
var _na_t := -1.0               # s sinds het gebouw klaar is (container weg, bouwers naar binnen)
var _weg := false

## De bouwfasen: [begin (s), naam, ondertitel]
const FASEN := [
	[0.0, "FUNDERING", "Het voorplein wordt gelegd"],
	[T_VOOR, "WANDEN", "De kraan hijst de platen"],
	[T_VOOR + 5.0 * CYCLE, "DAK", "Het dak komt erop"],
	[T_VOOR + 8.0 * CYCLE, "AFWERKING", "Deur, radar en zandzakken"],
]


func start(holder: Node3D) -> void:
	holder.add_child(self)
	name = "Opbouw"
	add_to_group("mcv_opbouw")
	var bunker := holder.get_node_or_null("Bunker")
	if bunker != null:
		_vis = bunker.get_node_or_null("Hoofdkwartier") as Node3D
	if _vis != null:
		_vis_scale = _vis.scale
		var bb := AABB()
		var eerste := true
		for mi in _vis.find_children("*", "MeshInstance3D", true, false):
			var g := mi as MeshInstance3D
			var box: AABB = (_vis.global_transform.affine_inverse() * g.global_transform) * g.get_aabb()
			bb = box if eerste else bb.merge(box)
			eerste = false
		if not eerste and bb.size.y > 1.0:
			_hoogte = bb.size.y * _vis_scale.y
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
	_apply(0.0)


## De container staat open: nu wordt gebouwd.
func begin() -> void:
	if begonnen:
		return
	begonnen = true
	if _vis != null:
		_vis.visible = true
	if _plein != null:
		_plein.visible = true
	if wagen != null and is_instance_valid(wagen):
		_kraan = McvKraan.new()
		wagen.add_child(_kraan)
	_maak_werkers()


## Het punt waar de camera naar kijkt tijdens het wegrijden, uitklappen en bouwen: tussen hoofdkwartier en wagen.
func camera_focus() -> Vector3:
	var hq: Vector3 = (get_parent() as Node3D).global_position
	if wagen != null and is_instance_valid(wagen):
		return (hq + wagen.global_position) * 0.5
	return hq


## Hoogte van het gebouw (0-1) op tijdstip t: een laag erbij na elke geplaatste plaat.
func _k(t: float) -> float:
	var t0 := T_VOOR + T_LAND
	if t < t0:
		return GRONDLAAG
	var i := mini(int((t - t0) / CYCLE), 7)
	var u := clampf((t - t0 - float(i) * CYCLE) / T_GROEI, 0.0, 1.0)
	return GRONDLAAG + (1.0 - GRONDLAAG) * (float(i) + smoothstep(0.0, 1.0, u)) / 8.0


func _apply(t: float) -> void:
	var k := _k(t)
	if _vis != null:
		_vis.scale = Vector3(_vis_scale.x, _vis_scale.y * k, _vis_scale.z)
	if _plein != null:
		_plein.position.y = -PLEIN_DIEP * (1.0 - smoothstep(0.0, 1.0, clampf(t / T_VOOR, 0.0, 1.0)))


func _process(delta: float) -> void:
	if not begonnen:
		return
	_t += delta
	if klaar:
		_na(delta)
		return
	_apply(_t)
	_kraan_werk(delta)
	_werkers_stap(delta)
	_effecten(delta)
	if _t > BOUWTIJD - T_AF + 0.6:
		for c in _ring:
			if is_instance_valid(c):
				(c as Node3D).visible = true
	if _t >= BOUWTIJD:
		_klaar()


# ---------------------------------------------------------------- kraan

## Wereldpunt boven het gebouw waar plaat i neerkomt (de haak hangt HAAK_NAAR_PLAAT boven het midden van de plaat).
func _drop(i: int) -> Vector3:
	var hq := get_parent() as Node3D
	var top := _hoogte * (GRONDLAAG + (1.0 - GRONDLAAG) * float(i) / 8.0)
	var lokaal := Vector3(-1.0 + 2.0 * float(i % 2), top + 0.1 + McvKraan.HAAK_NAAR_PLAAT, -1.2)
	return hq.global_transform * lokaal


func _kraan_werk(delta: float) -> void:
	if _kraan == null or not is_instance_valid(_kraan):
		return
	# de kraan komt tot leven: de laadbak is leeg, de stapels en de kraan rijzen uit de bak
	var op := smoothstep(0.0, 1.0, clampf(_t / 1.6, 0.0, 1.0))
	_kraan.position.y = McvKraan.LAADBAK_Y - 1.7 * (1.0 - op)
	_kraan.visible = _t > 0.05
	if _t < T_VOOR:
		return
	var c := mini(int((_t - T_VOOR) / CYCLE), 7)
	var tc := _t - T_VOOR - float(c) * CYCLE
	if c != _cycle:
		_cycle = c
		_start_haak = _kraan.haak_wereld()
		_plaat = McvKraan.PLAAT_VOLGORDE[c]
	var plek := _plaat_pos0(_plaat)
	var haak := McvKraan.HAAK_NAAR_PLAAT
	var w: Array = [
		[0.0, _start_haak],
		[0.95, plek + Vector3(0.0, haak + 1.1, 0.0)],
		[1.3, plek + Vector3(0.0, haak, 0.0)],
		[1.6, plek + Vector3(0.0, haak, 0.0)],
		[1.95, plek + Vector3(0.0, 2.3, 0.0)],
		[2.9, _drop(c) + Vector3(0.0, 1.2, 0.0)],
		[T_LAND, _drop(c)],
		[CYCLE, _drop(c) + Vector3(0.0, 1.0, 0.0)],
	]
	var doel := _drop(c)
	for j in range(w.size() - 1):
		var a: Array = w[j]
		var b: Array = w[j + 1]
		if tc <= float(b[0]):
			var u := clampf((tc - float(a[0])) / maxf(0.001, float(b[0]) - float(a[0])), 0.0, 1.0)
			doel = (a[1] as Vector3).lerp(b[1] as Vector3, smoothstep(0.0, 1.0, u))
			break
	_kraan.haak_naar(doel)
	if tc >= 1.6 and _kraan.in_haak() != _plaat and tc < T_LAND:
		_kraan.hang(_plaat)
		Sfx.play("click", 0.8)
	if tc >= T_LAND and _geland < c:
		_geland = c
		_plaat_geland(c)


## Waar plaat i op de stapel lag (wereld): de plaat is nog niet gepakt, dus gewoon haar eigen plek; daarna blijft de beginplek bewaard.
var _plek0: Dictionary = {}


func _plaat_pos0(i: int) -> Vector3:
	if not _plek0.has(i):
		_plek0[i] = _kraan.plaat_wereld(i)
	return _plek0[i]


func _plaat_geland(i: int) -> void:
	var p := _kraan.laat_los()
	if p != null:
		p.visible = false
	var hq := get_parent() as Node3D
	var top := _hoogte * (GRONDLAAG + (1.0 - GRONDLAAG) * float(i) / 8.0)
	var at := hq.global_transform * Vector3(-1.0 + 2.0 * float(i % 2), top + 0.1, -1.2)
	Sfx.play("thud", 0.9)
	Sfx.play("click", 1.0)
	for k in 3:
		Fx.spark(hq, at + Vector3(randf_range(-0.6, 0.6), 0.1, randf_range(-0.5, 0.5)), Vector3.UP)
	McvFx.puff(hq, at, 1.0, Color(0.6, 0.57, 0.5), 7, 0.8)


func _effecten(delta: float) -> void:
	var fase := 0
	for i in FASEN.size():
		if _t >= float((FASEN[i] as Array)[0]):
			fase = i
	if fase != _fase:
		_fase = fase
		var f: Array = FASEN[fase]
		Game.banner.emit(str(f[1]), str(f[2]), 2.2)
		Sfx.play("gate", 0.8)
		if fase == 0:
			Sfx.play("thud", 1.0)
	var hq := get_parent() as Node3D
	# stof rond de bouwplaats, vooral bij de fundering
	_stof_t -= delta
	if _stof_t <= 0.0:
		_stof_t = 0.45 if fase == 0 else 1.4
		var hoek := randf() * TAU
		var r := randf_range(2.8, 5.0) if fase == 0 else randf_range(2.6, 3.6)
		var plek := hq.global_position + hq.global_transform.basis * Vector3(cos(hoek) * r, 0.2, sin(hoek) * r)
		McvFx.puff(hq, plek, 1.4 if fase == 0 else 0.9, Color(0.6, 0.54, 0.43), 7, 1.0)


# ---------------------------------------------------------------- bouwers

func _maak_werkers() -> void:
	var hq := get_parent() as Node3D
	# [begin, eind, draagt een kist, wacht (s)]
	var routes: Array = [
		[Vector3(3.2, 0.0, -2.4), Vector3(-1.6, 0.0, -4.6), true],
		[Vector3(3.9, 0.0, 0.8), Vector3(3.9, 0.0, -3.6), true],
		[Vector3(-3.4, 0.0, -2.6), Vector3(-3.4, 0.0, -2.6), false],
	]
	for r in routes:
		var n := Node3D.new()
		n.name = "Bouwer"
		n.add_to_group("mcv_bouwer")
		hq.add_child(n)
		n.position = r[0]
		var m := SoldierModel.new()
		n.add_child(m)
		m.setup(Color("5a6a36"), "thompson")
		m.scale = Vector3.ONE * Data.SOLDIER_SCALE
		var kist: MeshInstance3D = null
		if r[2]:
			kist = MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.5, 0.3, 0.34)
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color("6b5535")
			mat.roughness = 0.85
			bm.material = mat
			kist.mesh = bm
			kist.position = Vector3(0.0, 0.95, -0.38)
			n.add_child(kist)
		_werkers.append({"n": n, "m": m, "a": r[0], "b": r[1], "kist": kist, "naar_b": true, "wacht": randf_range(0.0, 1.2), "binnen": false})


func _werkers_stap(delta: float) -> void:
	for w in _werkers:
		var n: Node3D = w.n
		var m: SoldierModel = w.m
		if w.binnen:
			continue
		if w.wacht > 0.0:
			w.wacht -= delta
			m.play("stil")
			if w.a == w.b and _kraan != null and is_instance_valid(_kraan):
				_kijk(n, _kraan.haak_wereld())   # de voorman volgt de last met zijn blik
			continue
		var doel: Vector3 = w.b if w.naar_b else w.a
		var d := doel - n.position
		d.y = 0.0
		if d.length() < 0.12:
			w.naar_b = not w.naar_b
			w.wacht = randf_range(0.6, 1.6)
			if w.kist != null:
				(w.kist as MeshInstance3D).visible = not w.naar_b   # bij het stapelen is de kist leeg
			continue
		m.play("lopen")
		n.position += d.normalized() * 1.5 * delta
		n.rotation.y = lerp_angle(n.rotation.y, atan2(-d.x, -d.z), 8.0 * delta)


func _kijk(n: Node3D, wereld: Vector3) -> void:
	var l := n.to_local(wereld)
	n.rotation.y = lerp_angle(n.rotation.y, n.rotation.y + atan2(-l.x, -l.z), 0.1)


# ---------------------------------------------------------------- klaar

## Voor tests: meteen klaar.
func maak_klaar() -> void:
	begin()
	_t = BOUWTIJD
	_klaar()


func _klaar() -> void:
	if klaar:
		return
	klaar = true
	_na_t = 0.0
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
	if _kraan != null and is_instance_valid(_kraan):
		_kraan.rust()
	for w in _werkers:
		if w.kist != null:
			(w.kist as MeshInstance3D).visible = false
		w.a = Vector3.ZERO
		w.b = DEUR
		w.naar_b = true
		w.wacht = 0.0
	Sfx.play("buy")
	Sfx.play("claxon", 0.8)   # toeter: klaar
	if wagen != null and is_instance_valid(wagen):
		wagen._model.set_baken(2)
	McvFx.puff(get_parent(), (get_parent() as Node3D).global_position + Vector3(0, 0.4, 0), 2.0, Color(0.7, 0.65, 0.55), 12, 1.3)
	Game.banner.emit("HOOFDKWARTIER KLAAR", "", 2.0)
	Game.changed.emit()


## Na de bouw: de bouwers lopen naar binnen, het baken is groen en de container zakt weg.
func _na(delta: float) -> void:
	_na_t += delta
	for w in _werkers:
		if w.binnen:
			continue
		var n: Node3D = w.n
		var d: Vector3 = DEUR - n.position
		d.y = 0.0
		if d.length() < 0.2:
			w.binnen = true
			n.visible = false
			continue
		(w.m as SoldierModel).play("lopen")
		n.position += d.normalized() * 1.7 * delta
		n.rotation.y = lerp_angle(n.rotation.y, atan2(-d.x, -d.z), 8.0 * delta)
	if _weg or wagen == null or not is_instance_valid(wagen):
		return
	if _na_t > WEG_WACHT:
		var u := clampf((_na_t - WEG_WACHT) / WEG_ZAK, 0.0, 1.0)
		wagen._model.zet_lift(-McvModel.BAK_HOOGTE - 2.4 * smoothstep(0.0, 1.0, u))
		if u >= 1.0:
			_weg = true
			wagen._model.container_weg()
			Sfx.play("thud", 0.7)
			McvFx.puff(get_parent(), wagen._model.container_pos() + Vector3(0, 0.2, 0), 1.6, Color(0.6, 0.54, 0.43), 10, 1.0)
			for w in _werkers:
				if is_instance_valid(w.n):
					(w.n as Node3D).queue_free()
			_werkers.clear()
