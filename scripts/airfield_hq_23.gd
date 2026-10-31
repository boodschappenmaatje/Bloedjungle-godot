class_name AirfieldHQ23
extends RefCounted
## Build-zone and purchase contract for the Airfield HQ 2.3 complex.
## The approved HQ 2.2 asset is instantiated read-only as the current fallback.

const BUILD_COST := 2800
const P47_COST := 1800
const AIRCRAFT_CAPACITY := 1
const ANCHOR := Vector3(1000.0, 0.0, 0.0)
const FOOTPRINT := Vector3(840.0, 18.0, 1140.0)
const P47_SCENE := "res://assets/p47_thunderbolt.glb"
const AIRCRAFT := {
	"p47": {"name": "Republic P-47 Thunderbolt", "cost": P47_COST, "scene": P47_SCENE, "source_required": "original Meshy Pro GLB/FBX"},
}
const COMPLEX_SCENE := "res://scenes/airfield_hq_22_showcase.tscn"

static func complex_available() -> bool:
	return ResourceLoader.exists(COMPLEX_SCENE)

static func make_complex() -> StaticBody3D:
	var packed := load(COMPLEX_SCENE) as PackedScene
	if packed == null:
		return null
	var body := BuildingBody.new()
	body.name = "AirfieldHQ23"
	body.collision_layer = Kit.LAYER_WALL
	body.collision_mask = 0
	body.set_meta("impact_material", "concrete")
	var slab_collision := CollisionShape3D.new()
	var slab := BoxShape3D.new()
	slab.size = Vector3(FOOTPRINT.x, 0.5, FOOTPRINT.z)
	slab_collision.shape = slab
	slab_collision.position = Vector3(0, -0.25, 0)
	body.add_child(slab_collision)
	var complex := packed.instantiate()
	complex.name = "AirfieldHQ22ApprovedCore"
	body.add_child(complex)
	var paving := AirfieldPavementModules.new()
	paving.name = "AirfieldHQ23PavementModules"
	complex.add_child(paving)
	body.set_meta("complex", complex)
	return body

static func can_buy(_buildings, building: Dictionary, kind: String) -> bool:
	if not AIRCRAFT.has(kind) or building.kind != "airfield" or building.down or building.hp <= 0.0:
		return false
	if building.aircraft.size() >= AIRCRAFT_CAPACITY:
		return false
	# Never charge for a missing or placeholder aircraft asset.
	var scene_path: String = AIRCRAFT[kind].scene
	return ResourceLoader.exists(scene_path) and Game.points >= AIRCRAFT[kind].cost

static func buy(_buildings, building: Dictionary, kind: String) -> bool:
	if not can_buy(_buildings, building, kind):
		return false
	var def: Dictionary = AIRCRAFT[kind]
	var packed := load(def.scene) as PackedScene
	if packed == null:
		return false
	# Recheck and commit without yielding, so rapid taps cannot double-charge.
	if building.aircraft.size() >= AIRCRAFT_CAPACITY or building.down or not Game.pay_points(def.cost):
		return false
	var aircraft := packed.instantiate() as Node3D
	if aircraft == null:
		Game.points += def.cost
		Game.changed.emit()
		return false
	var complex: Node3D = building.node.get_meta("complex")
	if complex == null:
		Game.points += def.cost
		Game.changed.emit()
		aircraft.free()
		return false
	var parking := complex.get_node_or_null("AirfieldFlightIntegration/P47_Apron_Parking") as Node3D
	if parking == null:
		Game.points += def.cost
		Game.changed.emit()
		aircraft.free()
		return false
	complex.add_child(aircraft)
	aircraft.global_transform = parking.global_transform
	building.aircraft.append({"kind": kind, "node": aircraft, "state": "PARKED", "slot": building.aircraft.size(), "health": 1.0})
	Game.changed.emit()
	return true

static func step(_building: Dictionary, _delta: float) -> void:
	pass

static func cleanup(building: Dictionary) -> void:
	for aircraft in building.get("aircraft", []):
		var node: Node = aircraft.get("node")
		if is_instance_valid(node):
			node.queue_free()
	building.aircraft.clear()
	building.runway_reserved_by = ""

static func shop_status(kind: String) -> String:
	var def: Dictionary = AIRCRAFT.get(kind, {})
	if def.is_empty():
		return "Onbekend vliegtuigtype"
	if not ResourceLoader.exists(def.scene):
		return "Niet beschikbaar: origineel Meshy Pro-vliegtuigmodel ontbreekt"
	return "Beschikbaar"
