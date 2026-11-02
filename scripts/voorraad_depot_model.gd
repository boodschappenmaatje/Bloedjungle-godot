class_name VoorraadDepotModel
extends Node3D
## Het model van het voorraaddepot (stap 4b, bron/voorraad/maak_depot.py): schuur met rolpoort, laadperron en portaalkraan.
## De rolpoort (clip `Poort`) gaat open als er een truck van dit depot binnen OPEN_RANGE komt en dicht als hij weg is. De portaalkraan
## (clip `Kraan-lossen`) pakt de kist die de truck op de laadplaat zet en stapelt hem op het opslagpallet: `play_unload()`.
## Voorkant (waar de trucks komen) is +Z, de oorsprong is het midden van de voetafdruk (9 x 6,5 m).

const MODEL := "res://assets/voorraaddepot.glb"
const MODEL_LOD := "res://assets/voorraaddepot_lod1.glb"
const LOD_SWITCH := 80.0
const OPEN_RANGE := 14.0

var depot: Dictionary = {}      # het gebouw (Game.buildings); wordt uit de ouder (BuildingBody.ref) gehaald, leeg in de viewer/test
var _ap: AnimationPlayer        # Kraan-lossen
var _door: AnimationPlayer      # Poort (eigen speler, op pauze; we sturen de stand zelf)
var _door_len := 2.0
var _door_pos := 0.0
var _door_open := false
var _check := 0.0
var _hold := 0.0
var model: Node
var model_lod: Node


func _ready() -> void:
	model = VoorraadModellen.laad(MODEL, self, 0.0, LOD_SWITCH)
	model_lod = VoorraadModellen.laad(MODEL_LOD, self, LOD_SWITCH, 0.0)
	_ap = model.find_child("AnimationPlayer", true, false)
	_door = VoorraadModellen.eigen_speler(model, _ap, "Poort", "PoortSpeler")
	if _door != null:
		_door_len = _door.get_animation("Poort").length
		_door.play("Poort")
		_door.pause()
		_door.seek(0.0, true)
	set_process(true)


## De portaalkraan zet de kist van de laadplaat op het opslagpallet (4,5 s).
func play_unload() -> void:
	if _ap != null and _ap.has_animation("Kraan-lossen"):
		_ap.stop()
		_ap.play("Kraan-lossen")


func unload_length() -> float:
	return _ap.get_animation("Kraan-lossen").length if _ap != null and _ap.has_animation("Kraan-lossen") else 0.0


func is_open() -> bool:
	return _door_open


## Zet de poort open of dicht (zet ook de stand van het model; de poort loopt daarna door in _process).
func set_open(open: bool) -> void:
	_door_open = open


func door_fraction() -> float:
	return _door_pos / maxf(_door_len, 0.01)


func _process(delta: float) -> void:
	_check -= delta
	if depot.is_empty() and get_parent() is BuildingBody and not (get_parent() as BuildingBody).ref.is_empty():
		depot = (get_parent() as BuildingBody).ref
	if _check <= 0.0 and not depot.is_empty():
		_check = 0.25
		var near := false
		for t in get_tree().get_nodes_in_group("voorraadtruck"):
			if not is_instance_valid(t) or t.depot != depot or t.state == VoorraadTruck.S.WRAK:
				continue
			if global_position.distance_to(t.global_position) < OPEN_RANGE:
				near = true
				break
		if near:
			_hold = 2.0
		else:
			_hold -= 0.25
		_door_open = _hold > 0.0
	if _door == null:
		return
	var goal := _door_len if _door_open else 0.0
	if not is_equal_approx(_door_pos, goal):
		_door_pos = move_toward(_door_pos, goal, delta)
		_door.seek(_door_pos, true)
