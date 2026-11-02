class_name VoorraadStapel
extends Node3D
## Een voorraadstapel op de kaart (Generals-plan stap 4, A1): kisten op een pallet die leegraakt als de trucks er voorraad uit halen.
## De stapel is in drie standen te zien (vol, half, bijna leeg) en heeft een markering met teller die je vooral in de tactische stand ziet.
## 4b: het echte model (bron/voorraad/maak_stapel.py): één glb met de drie standen naast elkaar (`Stapel_vol`, `Stapel_half`, `Stapel_leeg`);
## elke stand heeft een afhaalkist (`Afhaal`) op een klein pallet aan de voorkant (+Z): daar pakt de grijper van de truck hem. De stapel draait
## zijn voorkant naar de kant waar de trucks vandaan komen.

const SIZE := Vector3(5.0, 0.0, 4.0)   # voetafdruk (m) van de pallet
const MODEL := "res://assets/voorraadstapel.glb"
const STANDS := ["Stapel_vol", "Stapel_half", "Stapel_leeg"]
const PICKUP_Z := 2.8                  # m voor het midden van de stapel: de afhaalkist

var site: Dictionary = {}
var slot := 0
var left := 0
var full := 0
var _stand: Array[Node3D] = []   # per stand het model (Stapel_vol, Stapel_half, Stapel_leeg)
var _afhaal: Array[Node3D] = []  # per stand de afhaalkist
var _label: Label3D
var _mark: MeshInstance3D
var _shown := -1
var _cam_check := 0.0


## De afhaalkist-pivot van een stand. Blender maakt de namen uniek (Afhaal, Afhaal.001, Afhaal.002), Godot maakt daar Afhaal, Afhaal_001, Afhaal_002 van.
static func _find_afhaal(stand: Node) -> Node3D:
	for c in stand.get_children():
		var nm := String(c.name)
		if c is Node3D and (nm == "Afhaal" or (nm.begins_with("Afhaal_") and nm.substr(7).is_valid_int())):
			return c as Node3D
	return null


func setup(site_: Dictionary, slot_: int, amount: int, face := Vector2.ZERO) -> void:
	site = site_
	slot = slot_
	left = amount
	full = amount
	position = Vector3(site.pos.x, 0.0, site.pos.y)
	name = "Stapel%d" % (slot + 1)
	add_to_group("voorraadstapel")
	if face.length() > 0.01:
		rotation.y = atan2(face.x, face.y)   # lokale +Z wijst naar de kant van de trucks
	var m := VoorraadModellen.laad(MODEL, self)
	for n in STANDS:
		var st := m.find_child(n, true, false) as Node3D
		if st == null:
			continue
		st.position.x = 0.0      # in de glb staan de standen naast elkaar; hier staat er één op het midden
		_stand.append(st)
		var ah := _find_afhaal(st)
		if ah != null:
			_afhaal.append(ah)
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


## De truck heeft de afhaalkist gepakt (weg) of is weg (de kist ligt er weer).
func pickup_taken(taken: bool) -> void:
	for a in _afhaal:
		a.visible = not taken


func fraction() -> float:
	return float(left) / maxf(1.0, float(full))


func refresh() -> void:
	var f := fraction()
	var s := 0 if f > 0.66 else (1 if f > 0.33 else 2)
	if left <= 0:
		s = -1
	if s != _shown:
		_shown = s
		for i in _stand.size():
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
