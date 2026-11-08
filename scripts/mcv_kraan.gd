class_name McvKraan
extends Node3D
## De bouwkraan en de platenstapels op de laadbak van de MCV-wagen (assets/mcv_kraan.glb, bron/mcv_meshy/stap6_kraan.py).
## Godot stuurt de kraan: draaikrans (yaw), giek (hoek), uitschuifdeel (lengte) en kabel (lengte). De kraan hijst de acht prefab-platen een voor een
## van de stapel op het groeiende hoofdkwartier (zie McvOpbouw). Het hoofd van de kraan staat op de laadbak, 3,3 m achter het midden van de wagen.

const PAD := "res://assets/mcv_kraan.glb"
const SCHAAL := 1.5               # de kraan is groter dan het model: de giek moet over het hele gebouw reiken
const BASIS_Z := 3.3              # m: plek van de kraanvoet op de laadbak (lokaal)
const LAADBAK_Y := 1.41
const HAAK_NAAR_PLAAT := 0.8      # m: de haak hangt zo ver boven het midden van de plaat (stroppen)
const PLAAT_VOLGORDE := [3, 7, 2, 6, 1, 5, 0, 4]   # index in platen: eerst de bovenste van elke stapel

var kraan: Node3D
var stapel: Node3D
var platen: Array[Node3D] = []
var _dr: Node3D
var _ga: Node3D
var _gb: Node3D
var _km: Node3D
var _haak: Node3D
var _lamp: Node3D
var _lamp_t := 0.0
var _gb_rust: Vector3
var _vast: Array = []             # [plaat, wereldtransform]: platen in de haak


func _ready() -> void:
	name = "Kraan"
	position = Vector3(0.0, LAADBAK_Y, 0.0)
	var m: Node = (load(PAD) as PackedScene).instantiate()
	for ap in m.find_children("*", "AnimationPlayer", true, false):
		ap.free()   # de clip Werken is voor de viewer: in het spel stuurt Godot de kraan
	kraan = m.find_child("Kraan", true, false) as Node3D
	stapel = m.find_child("Stapel", true, false) as Node3D
	_dr = m.find_child("Draaikrans", true, false) as Node3D
	_ga = m.find_child("GiekA", true, false) as Node3D
	_gb = m.find_child("GiekB", true, false) as Node3D
	_km = m.find_child("KabelMesh", true, false) as Node3D
	_haak = m.find_child("Haak", true, false) as Node3D
	_lamp = m.find_child("Zwaailamp", true, false) as Node3D
	for i in range(1, 9):
		platen.append(m.find_child("Plaat%d" % i, true, false) as Node3D)
	m.remove_child(kraan)
	m.remove_child(stapel)
	m.free()
	add_child(kraan)
	add_child(stapel)
	kraan.position = Vector3(0.0, 0.0, BASIS_Z)
	kraan.scale = Vector3.ONE * SCHAAL
	stapel.position = Vector3.ZERO
	_gb_rust = _gb.position
	for mi in find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for n in [kraan.find_child("Cabine", true, false), kraan.find_child("Onderbouw", true, false)]:
		if n is MeshInstance3D:
			(n as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	rust()


## Giek omlaag en ingetrokken, kabel kort: de transportstand.
func rust() -> void:
	_dr.rotation.y = 0.0
	_ga.rotation.x = deg_to_rad(-12.0)
	_gb.position = _gb_rust
	_kabel(1.0)


func _kabel(lengte: float) -> void:
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
	var beste_l := 5.0
	var score := INF
	var schuif0 := _gb_rust.z
	var min_l := schuif0 + 3.0
	var max_l := schuif0 + 2.0 + 3.0
	var ok := false
	for graden in range(10, 76, 2):
		var a := deg_to_rad(float(graden))
		var l := d / SCHAAL / cos(a)
		if l < min_l or l > max_l:
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
		beste_a = deg_to_rad(35.0)
		beste_l = clampf(d / SCHAAL / cos(beste_a), min_l, max_l)
	var top_y := voet + beste_l * sin(beste_a) * SCHAAL
	_ga.rotation.x = -beste_a
	_gb.position = Vector3(_gb_rust.x, _gb_rust.y, beste_l - 3.0)
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


func _process(delta: float) -> void:
	_lamp_t += delta
	if not _vast.is_empty():
		var p: Node3D = _vast[0]
		p.global_position = _haak.global_position + Vector3(0.0, -HAAK_NAAR_PLAAT, 0.0)
		p.global_rotation = Vector3(0.0, _dr.global_rotation.y, 0.0)
