class_name McvKraan
extends Node3D
## De bouwkraan en het platenrek op de MCV-wagen (assets/mcv_kraan.glb, bron/mcv_meshy/stap7_kraan_vast.py). De kraan zit vast op het model: een kolomkraan met
## een 3-delige telescoopgiek achter de cabine (onderweg ligt de giek naar voren over het cabinedak) en vier stempels; de acht prefab-platen
## staan in een rek met spanbanden op het cabinedak. Godot stuurt de kraan: draaikrans (yaw), giek (hoek), twee telescoopdelen en de kabel, en de stempels.
## De kraan hijst de platen een voor een op het groeiende hoofdkwartier (zie McvOpbouw).

const PAD := "res://assets/mcv_kraan.glb"
const SCHAAL := 1.0
const BASIS_POS := Vector3(0.0, 1.41, -0.35)    # kraanvoet op de laadbak, vlak achter de cabine (wagen-lokaal)
const REK_POS := Vector3(0.0, 2.7, -2.4)        # platenrek op het cabinedak
const HAAK_NAAR_PLAAT := 0.7                     # m: de haak hangt zo ver boven het midden van de plaat (stroppen)
const PLAAT_VOLGORDE := [3, 7, 2, 6, 1, 5, 0, 4]   # index in platen: eerst de bovenste van elke stapel
const DEEL := 3.2                                # m: lengte van het laatste telescoopdeel (tot de katrol)
const GIEK_MIN := 3.8                            # m: de giek helemaal ingeschoven (hoogte van pivot tot katrol)
const SCHUIF_B := 3.0                            # m: zo ver schuift deel B uit
const SCHUIF_C := 2.8                            # m: zo ver schuift deel C uit
const POOT_LENGTE := 1.8                         # schaal van de stempelpoot: tot op de grond (laadbak 1,41 m + stempelkast)

var kraan: Node3D
var stapel: Node3D
var platen: Array[Node3D] = []
var _dr: Node3D
var _ga: Node3D
var _gb: Node3D
var _gc: Node3D
var _km: Node3D
var _kab: Node3D
var _haak: Node3D
var _lamp: Node3D
var _stempels: Array = []         # [{balk, poot, zij}]
var _banden: Array[Node3D] = []
var uitlijn := 0.0                # 0 = plaat ligt zoals op de stapel, 1 = uitgelijnd op het gebouw
var uitlijn_yaw := 0.0
var _vast: Array = []             # [plaat, index]: de plaat in de haak
var _lamp_aan := false
var _lamp_t := 0.0
var _zwaai: OmniLight3D
var _flood: SpotLight3D
var _stof_neer := false
var _swing := Vector2.ZERO        # kabelslinger (rad, wereldassen x en z)
var _swing_v := Vector2.ZERO
var _haak_vorig := Vector3.ZERO
var _haak_v := Vector3.ZERO
var _rust_t := 1.0


func _ready() -> void:
	name = "Kraan"
	var m: Node = (load(PAD) as PackedScene).instantiate()
	for ap in m.find_children("*", "AnimationPlayer", true, false):
		ap.free()   # de clip Kraan_uitklappen is voor de viewer: in het spel stuurt Godot de kraan
	kraan = m.find_child("Kraan", true, false) as Node3D
	stapel = m.find_child("Stapel", true, false) as Node3D
	_dr = m.find_child("Draaikrans", true, false) as Node3D
	_ga = m.find_child("GiekA", true, false) as Node3D
	_gb = m.find_child("GiekB", true, false) as Node3D
	_gc = m.find_child("GiekC", true, false) as Node3D
	_km = m.find_child("KabelMesh", true, false) as Node3D
	_kab = m.find_child("Kabel", true, false) as Node3D
	_haak = m.find_child("Haak", true, false) as Node3D
	_lamp = m.find_child("Zwaailamp", true, false) as Node3D
	for i in range(1, 9):
		platen.append(m.find_child("Plaat%d" % i, true, false) as Node3D)
	for st in m.find_children("Stempel_*", "Node3D", true, false):
		_stempels.append({"balk": st.get_child(0), "poot": st.get_child(1), "zij": -1.0 if String(st.name).begins_with("Stempel_L") else 1.0})
	for b in m.find_children("Band_*", "Node3D", true, false):
		_banden.append(b as Node3D)
	m.remove_child(kraan)
	m.remove_child(stapel)
	m.free()
	add_child(kraan)
	add_child(stapel)
	kraan.position = BASIS_POS
	stapel.position = REK_POS
	for mi in find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for n in [kraan.find_child("Cabine", true, false), kraan.find_child("Onderbouw", true, false)]:
		if n is MeshInstance3D:
			(n as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_zwaai = OmniLight3D.new()
	_zwaai.omni_range = 6.0
	_zwaai.light_color = Color(1.0, 0.55, 0.1)
	_zwaai.light_energy = 0.0
	_zwaai.shadow_enabled = false
	_lamp.add_child(_zwaai)
	_flood = SpotLight3D.new()
	_flood.spot_range = 14.0
	_flood.spot_angle = 50.0
	_flood.light_color = Color(1.0, 0.93, 0.78)
	_flood.light_energy = 0.0
	_flood.shadow_enabled = false
	_flood.rotation_degrees.x = -90.0
	_kab.add_child(_flood)
	transport()


## Transportstand: giek ingeschoven en naar voren over het cabinedak, stempels ingetrokken, kabel kort.
func transport() -> void:
	_dr.rotation.y = PI
	_ga.rotation.x = deg_to_rad(-2.0)
	_gb.position.z = 0.3
	_gc.position.z = 0.3
	stempels(0.0, 0.0)
	_kabel(0.35)


## Alleen de giek terug in transportstand (de stempels bewegen apart).
func transport_giek() -> void:
	_dr.rotation.y = PI
	_ga.rotation.x = deg_to_rad(-2.0)
	_gb.position.z = 0.3
	_gc.position.z = 0.3
	_kabel(0.35)


## De platen in het rek zijn losgemaakt: de spanbanden vallen weg.
func banden_af() -> void:
	for b in _banden:
		b.visible = false


## Stempels: uit = balken zijwaarts uit (0-1), neer = poten naar de grond (0-1).
func stempels(uit: float, neer: float) -> void:
	for s in _stempels:
		var balk: Node3D = s.balk
		var poot: Node3D = s.poot
		balk.scale.x = maxf(0.05, uit)
		poot.position.x = float(s.zij) * maxf(0.05, uit)
		poot.scale.z = maxf(0.05, neer * POOT_LENGTE)
	if neer >= 0.99 and not _stof_neer and is_inside_tree():
		_stof_neer = true
		Sfx.play("thud", 0.8)
		var host: Node = get_parent().get_parent() if get_parent() != null and get_parent().get_parent() != null else self
		var grond := global_position.y - BASIS_POS.y
		for s2 in _stempels:
			var at: Vector3 = (s2.poot as Node3D).global_position
			McvFx.puff(host, Vector3(at.x, grond + 0.15, at.z), 1.0, Color(0.6, 0.53, 0.42), 8, 0.9)
	elif neer < 0.5:
		_stof_neer = false


func _kabel(lengte: float) -> void:
	if _kab != null and _kab.is_inside_tree():
		_kab.global_basis = Basis.from_scale(Vector3.ONE * SCHAAL)   # de kabel hangt altijd recht omlaag, ook als de giek schuin staat
	_km.scale.y = lengte
	_km.position.y = -lengte * 0.5
	_haak.position.y = -lengte


## Zet de haak op een punt in de wereld (m): draait, hijst en schuift de giek uit. Geeft false als het punt buiten bereik valt (de kraan doet dan zijn best).
func haak_naar(doel: Vector3) -> bool:
	var p: Vector3 = kraan.to_local(doel) * SCHAAL   # kraanruimte in meters (zonder schaal)
	var voet := (_dr.position.y + _ga.position.y) * SCHAAL   # draaipunt van de giek boven de kraanvoet (m)
	var d := Vector2(p.x, p.z).length()
	_dr.rotation.y = atan2(p.x, p.z)
	var beste_a := deg_to_rad(40.0)
	var beste_l := 6.0
	var score := INF
	var max_l := GIEK_MIN + SCHUIF_B + SCHUIF_C
	var ok := false
	for graden in range(10, 82, 2):
		var a := deg_to_rad(float(graden))
		var l := d / SCHAAL / cos(a)
		if l < GIEK_MIN or l > max_l:
			continue
		# de haak hangt een stuk onder de giektop: kies de hoek waarbij de kabel ongeveer 1,3 m lang is
		var top := voet + l * sin(a) * SCHAAL
		var s := absf(top - 1.3 - p.y)
		if s < score:
			score = s
			beste_a = a
			beste_l = l
			ok = true
	if not ok:
		# buiten bereik: de haak komt zo dicht mogelijk bij het punt (horizontaal gelijk houden)
		beste_l = max_l if d / SCHAAL > GIEK_MIN * 0.9 else GIEK_MIN
		beste_a = acos(clampf(d / SCHAAL / beste_l, 0.1, 1.0))
	var top_y := voet + beste_l * sin(beste_a) * SCHAAL
	_ga.rotation.x = -beste_a
	var ext := beste_l - GIEK_MIN
	var s1 := minf(ext, SCHUIF_B)
	_gb.position.z = 0.3 + s1
	_gc.position.z = 0.3 + clampf(ext - s1, 0.0, SCHUIF_C)
	_kabel(maxf(0.3, (top_y - p.y) / SCHAAL))
	return ok


func haak_wereld() -> Vector3:
	return _haak.global_position


## De plaat (index in platen) hangt aan de haak.
func hang(i: int) -> void:
	var p := platen[i]
	if not p.top_level:
		p.top_level = true
	_vast = [p, i]


## Index van de plaat in de haak (-1 = niets).
func in_haak() -> int:
	return int(_vast[1]) if not _vast.is_empty() else -1


func laat_los() -> Node3D:
	var p: Node3D = _vast[0] if not _vast.is_empty() else null
	_vast = []
	return p


func plaat_wereld(i: int) -> Vector3:
	return platen[i].global_position


## Zwaailamp: knippert zolang de kraan werkt.
func lamp(aan: bool) -> void:
	_lamp_aan = aan


func _process(delta: float) -> void:
	if _lamp != null:
		_lamp_t += delta
		_lamp.visible = not _lamp_aan or fmod(_lamp_t, 0.8) < 0.4
	_slinger(delta)
	if not _vast.is_empty():
		var p: Node3D = _vast[0]
		p.global_position = _haak.global_position + Vector3(0.0, -HAAK_NAAR_PLAAT, 0.0)
		p.global_rotation = Vector3(0.0, lerp_angle(global_rotation.y, uitlijn_yaw, uitlijn), 0.0)


## Kabelslinger, werkverlichting en hydrauliekgeluid: reageren op de beweging van de haak.
func _slinger(delta: float) -> void:
	if delta <= 0.0 or _haak == null or not is_inside_tree():
		return
	var h := (_kab.global_position if _kab != null else _haak.global_position) + Vector3(0.0, _haak.position.y * SCHAAL, 0.0)   # zonder de slinger zelf
	var v := (h - _haak_vorig) / delta if _haak_vorig != Vector3.ZERO else Vector3.ZERO
	_haak_vorig = h
	var a := (v - _haak_v) / delta
	_haak_v = v
	var ah := Vector2(clampf(a.x, -12.0, 12.0), clampf(a.z, -12.0, 12.0))
	# gedempte slinger: de haak blijft een beetje achter bij het versnellen en veert uit
	_swing_v += (-9.0 * _swing - 1.6 * _swing_v - 0.012 * ah) * delta
	_swing += _swing_v * delta
	_swing = _swing.limit_length(0.06)
	if _kab != null:
		var r := Vector3(-_swing.y, 0.0, _swing.x)
		var rot := Basis(r.normalized(), r.length()) if r.length() > 0.00001 else Basis.IDENTITY
		_kab.global_basis = rot * Basis.from_scale(Vector3.ONE * SCHAAL)
	# verlichting en geluid
	var aan := _lamp_aan
	if _flood != null:
		_flood.light_energy = lerpf(_flood.light_energy, 2.5 if aan else 0.0, 1.0 - exp(-4.0 * delta))
	if _zwaai != null:
		_zwaai.light_energy = 1.8 if (aan and _lamp != null and _lamp.visible) else 0.0
	var snel := Vector2(v.x, v.z).length() + absf(v.y)
	if snel > 0.6:
		if _rust_t > 0.6 and aan:
			Sfx.play("spuit", 0.35)   # hydrauliek: de giek komt in beweging
		_rust_t = 0.0
	else:
		_rust_t += delta
