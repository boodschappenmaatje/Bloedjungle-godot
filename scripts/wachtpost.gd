class_name Wachtpost
extends Node3D
## Bij elke poort een slagboom en een wachthuisje (assets/wachtpost.glb, bron/wachtpost). De slagboom ligt 2,6 m binnen de muur dwars over de
## weg, gaat omhoog als de stalen poort open staat of kapot is (de arm volgt `Gates.list[i].open`) en zakt weer als de poort dicht gaat.
## Het wachthuisje heeft botsing, zodat je er niet doorheen loopt; de wacht van Patrouille staat er voor.

const C := Data.COMPOUND
const G := Data.GATE_GAP
const BARRIER_Z := 2.6    # slagboom ligt zoveel meter binnen de muur
const HUT_Z := 5.0        # wachthuisje staat zoveel meter binnen de muur
const HUT_X := 6.3        # en zoveel meter naast het midden van de poort
const LIFT_FROM := 0.35   # de arm begint omhoog te gaan als de poort zo ver open is (0..1)

var _gates: Array = []   # per poort: {ap, len}
var _spawned := false


## Plek van het huisje en de richting waarheen het raam kijkt: noord staat links (-X), zuid rechts (+X); het raam kijkt naar de weg.
static func hut_pos(sz: float) -> Vector3:
	return Vector3(HUT_X if sz > 0.0 else -HUT_X, 0.0, sz * (C - HUT_Z))


static func hut_yaw(sz: float) -> float:
	return PI / 2.0 if sz > 0.0 else -PI / 2.0


## Waar de wacht voor het huisje staat (aan de wegkant, tussen huisje en slagboomkast).
static func guard_spot(sz: float) -> Vector3:
	var h := hut_pos(sz)
	return Vector3(h.x + (-1.0 if sz > 0.0 else 1.0) * 1.85, 0.0, h.z)


func _process(_delta: float) -> void:
	if not _spawned and (Game.state == "prep" or Game.state == "play") and Game.gates != null:
		_spawned = true
		_spawn()


func _spawn() -> void:
	var parent: Node = get_parent().get_node_or_null("Level")
	if parent == null:
		parent = get_parent()
	var scene := load("res://assets/wachtpost.glb") as PackedScene
	for i in Game.gates.list.size():
		var sz: float = Game.gates.list[i].sz
		var barrier := _piece(scene, "Wachthuis")
		barrier.position = Vector3(0, 0, sz * (C - BARRIER_Z))
		parent.add_child(barrier)
		var ap: AnimationPlayer = barrier.find_child("AnimationPlayer", true, false)
		ap.play("Open")
		ap.pause()
		ap.seek(0.0, true)
		_gates.append({"ap": ap, "len": ap.get_animation("Open").length})
		_solid(barrier, Vector3(-G - 0.55, 0.65, 0), Vector3(0.6, 1.3, 0.5))   # kast
		var hut := _piece(scene, "Slagboom")
		hut.position = hut_pos(sz)
		hut.rotation.y = hut_yaw(sz)
		parent.add_child(hut)
		_solid(hut, Vector3(0, 1.25, 0), Vector3(2.4, 2.5, 2.4))


## Een kopie van de glb zonder het onderdeel dat hier niet bij hoort; het blijft op de glb-oorsprong staan.
static func _piece(scene: PackedScene, drop: String) -> Node3D:
	var root := Node3D.new()
	var model: Node3D = scene.instantiate()
	root.add_child(model)
	var other: Node = model.find_child(drop, true, false)
	if other:
		other.get_parent().remove_child(other)
		other.free()
	var keep: Node3D = model.find_child("Wachthuis" if drop == "Slagboom" else "Slagboom", true, false)
	if keep:
		keep.position = Vector3.ZERO
	return root


static func _solid(on: Node3D, at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Kit.LAYER_WALL
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = at
	body.add_child(cs)
	on.add_child(body)


func _physics_process(_delta: float) -> void:
	if _gates.is_empty() or Game.gates == null:
		return
	for i in mini(_gates.size(), Game.gates.list.size()):
		var g: Dictionary = Game.gates.list[i]
		var up := 1.0 if g.broken else clampf((float(g.open) - LIFT_FROM) / (1.0 - LIFT_FROM), 0.0, 1.0)
		var d: Dictionary = _gates[i]
		(d.ap as AnimationPlayer).seek(up * float(d.len), true)
