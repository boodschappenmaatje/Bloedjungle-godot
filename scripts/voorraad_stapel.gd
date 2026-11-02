class_name VoorraadStapel
extends Node3D
## Een voorraadstapel op de kaart (Generals-plan stap 4, A1): kisten op een pallet die leegraakt als de trucks er voorraad uit halen.
## De stapel is in drie standen te zien (vol, half, bijna leeg) en heeft een markering met teller die je vooral in de tactische stand ziet.
## 4a: eenvoudige blokken. Het echte model (4b) komt in drie versies in plaats van deze blokken.

const SIZE := Vector3(5.0, 0.0, 4.0)   # voetafdruk (m) van de pallet

var site: Dictionary = {}
var slot := 0
var left := 0
var full := 0
var _stand: Array[Node3D] = []   # per stand de kisten die erbij horen
var _label: Label3D
var _mark: MeshInstance3D
var _shown := -1
var _cam_check := 0.0


func setup(site_: Dictionary, slot_: int, amount: int) -> void:
	site = site_
	slot = slot_
	left = amount
	full = amount
	position = Vector3(site.pos.x, 0.0, site.pos.y)
	name = "Stapel%d" % (slot + 1)
	add_to_group("voorraadstapel")
	var olive := Kit.flat(Color("55603a"), 0.85)
	var dark := Kit.flat(Color("3a4128"), 0.9)
	var wood := Kit.flat(Color("6e5a3c"), 0.95)
	var gold := Kit.flat(Color("c9a227"), 0.7)
	Kit.box(self, Vector3(0, 0.1, 0), Vector3(SIZE.x, 0.2, SIZE.z), wood)   # pallet
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + slot
	# drie standen: 14 / 7 / 3 kisten; elke stand bevat alleen de kisten die erbij horen (stand 0 is de vollere, bevat ze allemaal)
	for i in 3:
		var holder := Node3D.new()
		holder.name = "Stand%d" % i
		add_child(holder)
		_stand.append(holder)
	var spots := []
	for layer in 3:
		for cx in 3:
			for cz in 2:
				spots.append(Vector3(-1.5 + cx * 1.5, 0.2 + layer * 0.78 + 0.35, -0.9 + cz * 1.8))
	var counts := [14, 7, 3]
	for i in 3:
		for k in counts[i]:
			var p: Vector3 = spots[k] + Vector3(rng.randf_range(-0.08, 0.08), 0.0, rng.randf_range(-0.08, 0.08))
			Kit.box(_stand[i], p, Vector3(1.25, 0.72, 1.5), olive if k % 3 != 1 else dark, rng.randf_range(-0.12, 0.12))
			if k % 4 == 0:
				Kit.box(_stand[i], p + Vector3(0, 0.37, 0), Vector3(1.0, 0.04, 0.4), gold)   # gele band op het deksel
	# markering: een gouden ruit boven de stapel, met de teller eronder
	_mark = MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(1.7, 1.7)
	_mark.mesh = qm
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.albedo_color = Color("e8b923")
	mm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mm.no_depth_test = true
	mm.render_priority = 5
	_mark.material_override = mm
	_mark.position = Vector3(0, 8.0, 0)
	_mark.rotation.z = PI / 4.0   # een vierkant dat op de punt staat
	add_child(_mark)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.fixed_size = false
	_label.pixel_size = 0.022
	_label.font_size = 40
	_label.outline_size = 14
	_label.modulate = Color("f2e6b8")
	_label.outline_modulate = Color(0.05, 0.06, 0.03, 0.95)
	_label.position = Vector3(0, 6.3, 0)
	add_child(_label)
	refresh()


## Haalt voorraad weg; geeft terug hoeveel er echt is.
func take(amount: int) -> int:
	var got := mini(amount, left)
	left -= got
	refresh()
	return got


func fraction() -> float:
	return float(left) / maxf(1.0, float(full))


func refresh() -> void:
	var f := fraction()
	var s := 0 if f > 0.66 else (1 if f > 0.33 else 2)
	if left <= 0:
		s = -1
	if s != _shown:
		_shown = s
		for i in 3:
			_stand[i].visible = (i == s)
	_label.text = "STAPEL %d · %s" % [slot + 1, UI.nl(left)]


func _process(delta: float) -> void:
	_cam_check -= delta
	if _cam_check > 0.0:
		return
	_cam_check = 0.25
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	# in de tactische stand (de ruimere camera) staat de teller altijd in beeld; in de gevechtsstand pas als je dichtbij komt
	var tactical: bool = cam.get("combat_view") != true
	var near: bool = cam.global_position.distance_to(global_position) < 42.0
	_label.visible = tactical or near
	_mark.visible = true


## De stapel is leeg: de kisten zijn weg, alleen de pallet blijft kort liggen.
func vanish() -> void:
	left = 0
	refresh()
	_mark.visible = false
	_label.visible = false
	set_process(false)
	remove_from_group("voorraadstapel")
	var tw := create_tween()
	tw.tween_interval(20.0)
	tw.tween_callback(queue_free)
