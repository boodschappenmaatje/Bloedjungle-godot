class_name AirfieldHQ23
extends RefCounted
## Build-zone and purchase contract for the Airfield HQ 2.3 complex.
## The approved HQ 2.2 asset is instantiated read-only as the current fallback.

const BUILD_COST := 2800
const P47_COST := 1800
const AIRCRAFT_CAPACITY := 1
# BaseProps._wall() puts the outermost side-wall posts at ±(COMPOUND + .325)
# and end posts at ±(COMPOUND + .475), including their authored cap/paling sizes.
const BASE_GROUND_SIZE := Vector2(Data.COMPOUND * 2.0 + 0.65, Data.COMPOUND * 2.0 + 0.95)
const MAX_GROUND_AREA := 2.0 * BASE_GROUND_SIZE.x * BASE_GROUND_SIZE.y
# Bounds measured from the approved 2.2 Godot import. The original hangar and
# tower transforms stay intact; only pavement and aircraft route markers move.
const FOOTPRINT := Vector3(113.25, 18.0, 55.4)
const MAX_RUNWAY_LENGTH := 30.0
const RUNWAY_START_X := 20.0
const RUNWAY_END_X := RUNWAY_START_X + MAX_RUNWAY_LENGTH
const RUNWAY_CENTER_Z := 8.5
const APRON_CENTER := Vector2(18.0, -20.0)
const TAXI_ARC_CENTER := Vector2(30.5, -4.0)
const TAXI_ARC_RADIUS := 12.5
const COMPLEX_CENTER_OFFSET := Vector3(-24.125, 0.0, -0.3)
const SUGGESTED_CENTER := Vector3(100.0, 0.0, -150.0)
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
	# The whole footprint must remain walkable. Pavement modules provide ground
	# collision; a wall-layer footprint here would block the player and aircraft.
	slab_collision.disabled = true
	body.add_child(slab_collision)
	var complex := packed.instantiate()
	complex.name = "AirfieldHQ22ApprovedCore"
	complex.position = COMPLEX_CENTER_OFFSET
	body.add_child(complex)
	_compact_approved_core(complex)
	var paving := AirfieldPavementModules.new()
	paving.name = "AirfieldHQ23PavementModules"
	complex.add_child(paving)
	body.set_meta("complex", complex)
	return body

static func _compact_approved_core(complex: Node3D) -> void:
	# Reuse the approved 2.2 hangar, interior, tower, door and windsock unchanged.
	# Remove the 2.2 showcase landscape and long runway from the placed complex.
	var keep_prefixes := ["Hangar HQ 22", "Hangar sliding door", "USAAF blue insignia", "USAAF white star", "Hangar Service Props", "Control Tower 22", "Tower access door", "Tower wind sock"]
	for lod_name in ["Airfield_HQ_22_LOD0", "Airfield_HQ_22_LOD1", "Airfield_HQ_22_LOD2"]:
		var lod := complex.get_node_or_null(lod_name)
		if lod == null:
			continue
		for node in lod.find_children("*", "MeshInstance3D", true, false):
			var keep := false
			for prefix in keep_prefixes:
				if node.name.begins_with(prefix):
					keep = true
					break
			node.visible = keep
	for collider_name in ["RunwayCollision", "ApronCollision", "TaxiCollision"]:
		var collider := complex.get_node_or_null("GameplayCollisions/" + collider_name) as StaticBody3D
		if collider != null:
			collider.collision_layer = 0

static func footprint_area() -> float:
	return FOOTPRINT.x * FOOTPRINT.z

static func layout_point(x: float, z: float, y: float = 0.22) -> Vector3:
	# Layout coordinates are measured from the placed building origin; the
	# approved 2.2 visual core is translated only as a complete, unscaled scene.
	return Vector3(x - COMPLEX_CENTER_OFFSET.x, y, z - COMPLEX_CENTER_OFFSET.z)

static func area_limit_ok() -> bool:
	return footprint_area() <= MAX_GROUND_AREA

static func site_inside_world(at: Vector3, yaw: float) -> bool:
	var half := Vector2(FOOTPRINT.x, FOOTPRINT.z) * 0.5
	var corners := [Vector2(-half.x, -half.y), Vector2(-half.x, half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y)]
	for corner in corners:
		var rotated: Vector2 = corner.rotated(-yaw) + Vector2(at.x, at.z)
		if absf(rotated.x) > Data.WORLD_X - 1.0:
			return false
		if rotated.y < -Data.WORLD_Z_N + 1.0 or rotated.y > Data.WORLD_Z_S - 1.0:
			return false
	return true

static func site_clear_of_combat_spawns(at: Vector3, yaw: float) -> bool:
	var half := Vector2(FOOTPRINT.x, FOOTPRINT.z) * 0.5
	var from_center := Vector2(-at.x, -at.z).rotated(yaw)
	var closest_local := Vector2(clampf(from_center.x, -half.x, half.x), clampf(from_center.y, -half.y, half.y))
	var closest_world := Vector2(at.x, at.z) + closest_local.rotated(-yaw)
	return closest_world.length() >= Data.SPAWN_R + 2.0

static func site_clear_of_river(at: Vector3, yaw: float) -> bool:
	var half := Vector2(FOOTPRINT.x, FOOTPRINT.z) * 0.5
	var nx := ceili(FOOTPRINT.x / 10.0)
	var nz := ceili(FOOTPRINT.z / 10.0)
	for ix in range(nx + 1):
		for iz in range(nz + 1):
			var local := Vector2(lerpf(-half.x, half.x, float(ix) / nx), lerpf(-half.y, half.y, float(iz) / nz))
			var point := Vector2(at.x, at.z) + local.rotated(-yaw)
			if Data.river_off(point.x, point.y) < Data.RIVER_HALF + 2.0:
				return false
	return true

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
