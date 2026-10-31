class_name AirfieldHQ23
extends RefCounted
## Construction, footprint, and deferred aircraft-store contract for Airfield HQ 2.3.
## The approved 2.2 hangar is instantiated read-only; the 2.3 tower is a separate asset.

const BUILD_COST := 2800
const P47_COST := 1800
const P47_PURCHASE_ENABLED := false # aircraft work resumes only after iPhone approval
const AIRCRAFT_CAPACITY := 1

# BaseProps._wall() puts the outermost side-wall posts at ±(COMPOUND + .325)
# and end posts at ±(COMPOUND + .475), including their authored caps/paling sizes.
const BASE_GROUND_SIZE := Vector2(Data.COMPOUND * 2.0 + 0.65, Data.COMPOUND * 2.0 + 0.95)
const MAX_GROUND_AREA := 2.0 * BASE_GROUND_SIZE.x * BASE_GROUND_SIZE.y

# The actual construction footprint is a connected composition of the fixed
# hangar/tower and separate paving lobes. Its map-placement bounds include empty
# existing terrain between components; only the conservative surface sum below
# is charged against the 2× land-take limit.
const FOOTPRINT := Vector3(113.25, 23.0, 87.4) # symmetric bounds for build-camera framing only

const HANGAR_CENTER := Vector2(-24.125, -0.3)
const HANGAR_SIZE := Vector2(65.0, 42.46)
const TOWER_CENTER := Vector2(47.875, -20.3)
const TOWER_SIZE := Vector2(17.5, 14.8) # 2.2 reference envelope; 2.3 tower is contained

const RUNWAY_LENGTH_M := 75.0
const RUNWAY_WIDTH_M := 18.0
const RUNWAY_START_X := -56.5
const RUNWAY_END_X := RUNWAY_START_X + RUNWAY_LENGTH_M
const RUNWAY_CENTER_Z := -31.5
const APRON_CENTER := Vector2(28.0, -20.0)
const TAXI_ARC_CENTER := Vector2(16.0, -22.5)
const TAXI_ARC_RADIUS := 12.0
const TAXIWAY_WIDTH_M := 18.4
const TAXI_START := Vector2(28.0, -20.0)
const TAXI_ARC_START := Vector2(28.0, -22.5)
const TAXI_ARC_END := Vector2(16.0, -34.5)

# The unscaled approved core's original translation is retained.
const COMPLEX_CENTER_OFFSET := Vector3(-24.125, 0.0, -0.3)
const SUGGESTED_CENTER := Vector3(100.0, 0.0, -150.0)
const P47_SCENE := "res://assets/p47_thunderbolt.glb"
const AIRCRAFT := {
	"p47": {"name": "Republic P-47 Thunderbolt", "cost": P47_COST, "scene": P47_SCENE, "source_required": "original Meshy Pro GLB/FBX"},
}
const COMPLEX_SCENE := "res://scenes/airfield_hq_22_showcase.tscn"
const TOWER_LOD_SCENES := [
	"res://assets/airfield_hq_v23/tower/Control_Tower_HQ_23.glb",
	"res://assets/airfield_hq_v23/tower/Control_Tower_HQ_23_LOD1.glb",
	"res://assets/airfield_hq_v23/tower/Control_Tower_HQ_23_LOD2.glb",
]

static func complex_available() -> bool:
	if not ResourceLoader.exists(COMPLEX_SCENE):
		return false
	for path in TOWER_LOD_SCENES:
		if not ResourceLoader.exists(path):
			return false
	return true

static func make_complex() -> StaticBody3D:
	var packed := load(COMPLEX_SCENE) as PackedScene
	if packed == null:
		return null
	var body := BuildingBody.new()
	body.name = "AirfieldHQ23"
	body.collision_layer = Kit.LAYER_WALL
	body.collision_mask = 0
	body.set_meta("impact_material", "concrete")
	# This coarse overall box is disabled: individual construction-region checks
	# and the original building colliders preserve walkable gaps and playable access.
	var slab_collision := CollisionShape3D.new()
	var slab := BoxShape3D.new()
	slab.size = Vector3(FOOTPRINT.x, 0.5, FOOTPRINT.z)
	slab_collision.shape = slab
	slab_collision.position = Vector3(0, -0.25, 0)
	slab_collision.disabled = true
	body.add_child(slab_collision)
	var complex := packed.instantiate()
	complex.name = "AirfieldHQ22ApprovedCore"
	complex.position = COMPLEX_CENTER_OFFSET
	body.add_child(complex)
	_compact_approved_core(complex)
	_add_hq23_tower(complex)
	_add_tower_stair_collisions(complex)
	var paving := AirfieldPavementModules.new()
	paving.name = "AirfieldHQ23PavementModules"
	complex.add_child(paving)
	body.set_meta("complex", complex)
	return body

static func _compact_approved_core(complex: Node3D) -> void:
	# Only the approved 2.2 tower shell is hidden in this new 2.3 instance.
	# Hangar, interior, sliding doors, tower door and animated windsock remain byte-identical.
	var keep_prefixes := ["Hangar HQ 22", "Hangar sliding door", "USAAF blue insignia", "USAAF white star", "Hangar Service Props", "Tower access door", "Tower wind sock"]
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

static func _add_hq23_tower(complex: Node3D) -> void:
	var tower_root := Node3D.new()
	tower_root.name = "ControlTowerHQ23"
	tower_root.position = Vector3(72.0, 0.0, -20.0)
	complex.add_child(tower_root)
	for index in TOWER_LOD_SCENES.size():
		var path: String = TOWER_LOD_SCENES[index]
		var packed := load(path) as PackedScene
		if packed == null:
			push_error("Airfield HQ 2.3 tower LOD is missing: " + path)
			continue
		var root := packed.instantiate() as Node3D
		root.name = "Tower LOD%d" % index
		var begin_distance: float = [0.0, 65.0, 125.0][index]
		var end_distance: float = [65.0, 125.0, 0.0][index]
		for mesh in root.find_children("*", "MeshInstance3D", true, false):
			mesh.visibility_range_begin = begin_distance
			mesh.visibility_range_end = end_distance
			mesh.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		tower_root.add_child(root)

static func _add_tower_stair_collisions(complex: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "HQ23 Tower stair and level collisions"
	body.position = Vector3(72.0, 0.0, -20.0)
	body.collision_layer = Kit.LAYER_GROUND
	body.collision_mask = 0
	complex.add_child(body)
	var flight_xs := [5.10, 7.45, 5.10, 7.45]
	var flight_dirs := [1, -1, 1, -1]
	for flight_index in 4:
		var x: float = flight_xs[flight_index]
		var direction: int = flight_dirs[flight_index]
		var low := 0.45 + float(flight_index) * 3.03
		var y_start := -2.65 if direction > 0 else 2.65
		var y_end := y_start + direction * 5.30
		for step in 18:
			var t := (float(step) + 0.5) / 18.0
			var z := low + 3.03 * t
			var y := y_start + (y_end - y_start) * t
			_add_box_collision(body, Vector3(x, z, -y), Vector3(1.18, 0.12, 0.27))
	for level in range(1, 5):
		var high := 0.45 + float(level) * 3.03
		var x: float = flight_xs[level - 1]
		var y := -2.65 if level % 2 == 1 else 2.65
		_add_box_collision(body, Vector3((x + 4.55) * 0.5, high - 0.06, -y), Vector3(absf(x - 4.55) + 1.4, 0.14, 1.48))

static func _add_box_collision(parent: Node, at: Vector3, dimensions: Vector3) -> void:
	var node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	node.shape = shape
	node.position = at
	parent.add_child(node)

static func _rotate_local(point: Vector2, yaw: float) -> Vector2:
	return point.rotated(-yaw)

static func region_transform(at: Vector3, yaw: float, region: Dictionary) -> Transform3D:
	var center: Vector2 = region.center
	var local_yaw: float = region.get("yaw", 0.0)
	var world_center := at + (Basis(Vector3.UP, yaw) * Vector3(center.x, 0.0, center.y))
	return Transform3D(Basis(Vector3.UP, yaw + local_yaw), world_center)

static func layout_point(x: float, z: float, y: float = 0.22) -> Vector3:
	# Convert the declared airport-local layout coordinates into the translated
	# HQ2.2 source scene's child coordinate frame without scaling that core.
	return Vector3(x - COMPLEX_CENTER_OFFSET.x, y, z - COMPLEX_CENTER_OFFSET.z)

static func taxi_centerline_points() -> Array[Vector2]:
	var points: Array[Vector2] = [TAXI_START, TAXI_ARC_START]
	for i in range(1, 9):
		var angle := lerpf(0.0, -PI * 0.5, float(i) / 8.0)
		points.append(TAXI_ARC_CENTER + Vector2(cos(angle), sin(angle)) * TAXI_ARC_RADIUS)
	return points

static func _taxi_regions(step_m: float = 4.0) -> Array[Dictionary]:
	var points := taxi_centerline_points()
	var out: Array[Dictionary] = []
	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var delta := b - a
		var length := delta.length()
		if length < 0.01:
			continue
		var direction := delta / length
		var count := maxi(1, ceili(length / step_m))
		var section := length / count
		for j in count:
			var center := a + direction * (float(j) + 0.5) * section
			var heading := atan2(direction.x, direction.y)
			out.append({"name": "taxiway", "center": center, "size": Vector2(TAXIWAY_WIDTH_M, section + 0.5), "yaw": heading})
	return out

static func site_regions() -> Array[Dictionary]:
	var regions: Array[Dictionary] = [
		{"name": "hangar", "center": HANGAR_CENTER, "size": HANGAR_SIZE, "yaw": 0.0},
		{"name": "tower", "center": TOWER_CENTER, "size": TOWER_SIZE, "yaw": 0.0},
		{"name": "runway", "center": Vector2((RUNWAY_START_X + RUNWAY_END_X) * 0.5, RUNWAY_CENTER_Z), "size": Vector2(RUNWAY_WIDTH_M, RUNWAY_LENGTH_M), "yaw": PI * 0.5},
		{"name": "apron", "center": APRON_CENTER, "size": Vector2(18.0, 14.0), "yaw": 0.0},
	]
	regions.append_array(_taxi_regions())
	return regions

static func preview_regions() -> Array[Dictionary]:
	return site_regions()

static func _region_corners(region: Dictionary) -> Array[Vector2]:
	var half: Vector2 = region.size * 0.5
	var center: Vector2 = region.center
	var yaw: float = region.get("yaw", 0.0)
	var corners: Array[Vector2] = []
	for point in [Vector2(-half.x,-half.y),Vector2(-half.x,half.y),Vector2(half.x,-half.y),Vector2(half.x,half.y)]:
		corners.append(center + _rotate_local(point, yaw))
	return corners

static func footprint_area() -> float:
	var taxi_length := TAXI_START.distance_to(TAXI_ARC_START) + TAXI_ARC_RADIUS * PI * 0.5
	# A full 8 m of modular end coverage is added as a safe upper bound. Areas at
	# the apron, runway, and structure joints are intentionally counted twice.
	var taxi_with_endcaps := (taxi_length + 8.0) * TAXIWAY_WIDTH_M
	return HANGAR_SIZE.x * HANGAR_SIZE.y + TOWER_SIZE.x * TOWER_SIZE.y + RUNWAY_LENGTH_M * RUNWAY_WIDTH_M + 18.0 * 14.0 + taxi_with_endcaps

static func area_limit_ok() -> bool:
	return footprint_area() <= MAX_GROUND_AREA

static func site_inside_world(at: Vector3, yaw: float) -> bool:
	for region in site_regions():
		for corner in _region_corners(region):
			var world := Vector2(at.x, at.z) + _rotate_local(corner, yaw)
			if absf(world.x) > Data.WORLD_X - 1.0:
				return false
			if world.y < -Data.WORLD_Z_N + 1.0 or world.y > Data.WORLD_Z_S - 1.0:
				return false
	return true

static func _region_closest_to_spawn(region: Dictionary) -> Vector2:
	var local_spawn := Vector2(-region.center.x, -region.center.y).rotated(float(region.get("yaw", 0.0)))
	var half: Vector2 = region.size * 0.5
	var closest := Vector2(clampf(local_spawn.x, -half.x, half.x), clampf(local_spawn.y, -half.y, half.y))
	return Vector2(region.center.x, region.center.y) + _rotate_local(closest, float(region.get("yaw",0.0)))

static func site_clear_of_combat_spawns(at: Vector3, yaw: float) -> bool:
	for region in site_regions():
		var spawn_local := Vector2(-at.x, -at.z).rotated(yaw)
		var from_center := spawn_local - Vector2(region.center.x, region.center.y)
		from_center = from_center.rotated(float(region.get("yaw", 0.0)))
		var half: Vector2 = region.size * 0.5
		var closest := Vector2(clampf(from_center.x,-half.x,half.x),clampf(from_center.y,-half.y,half.y))
		if from_center.distance_to(closest) < Data.SPAWN_R + 2.0:
			return false
	return true

static func site_clear_of_river(at: Vector3, yaw: float) -> bool:
	for region in site_regions():
		var half: Vector2 = region.size * 0.5
		var nx := maxi(1, ceili(region.size.x / 8.0))
		var nz := maxi(1, ceili(region.size.y / 8.0))
		for ix in range(nx + 1):
			for iz in range(nz + 1):
				var local := Vector2(lerpf(-half.x,half.x,float(ix)/nx),lerpf(-half.y,half.y,float(iz)/nz))
				local = Vector2(region.center.x,region.center.y) + _rotate_local(local,float(region.get("yaw",0.0)))
				var world := Vector2(at.x,at.z) + _rotate_local(local,yaw)
				if Data.river_off(world.x,world.y) < Data.RIVER_HALF + 2.0:
					return false
	return true

static func can_buy(_buildings, building: Dictionary, kind: String) -> bool:
	# Aircraft integration is explicitly deferred until the owner accepts the native
	# airport test. Keep the existing store/catalog visible, but never charge now.
	if not P47_PURCHASE_ENABLED:
		return false
	if not AIRCRAFT.has(kind) or building.kind != "airfield" or building.down or building.hp <= 0.0:
		return false
	if building.aircraft.size() >= AIRCRAFT_CAPACITY:
		return false
	var scene_path: String = AIRCRAFT[kind].scene
	return ResourceLoader.exists(scene_path) and Game.points >= AIRCRAFT[kind].cost

static func buy(_buildings, building: Dictionary, kind: String) -> bool:
	if not can_buy(_buildings, building, kind):
		return false
	var def: Dictionary = AIRCRAFT[kind]
	var packed := load(def.scene) as PackedScene
	if packed == null:
		return false
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
	if not AIRCRAFT.has(kind):
		return "Onbekend vliegtuigtype"
	if not P47_PURCHASE_ENABLED:
		if not ResourceLoader.exists(AIRCRAFT[kind].scene):
			return "P-47-aankoop uitgesteld tot na de iPhone-vliegveldtest; origineel Meshy Pro-model ontbreekt"
		return "P-47-aankoop uitgesteld tot na de iPhone-vliegveldtest en goedkeuring"
	if not ResourceLoader.exists(AIRCRAFT[kind].scene):
		return "Niet beschikbaar: origineel Meshy Pro-vliegtuigmodel ontbreekt"
	return "Beschikbaar"
