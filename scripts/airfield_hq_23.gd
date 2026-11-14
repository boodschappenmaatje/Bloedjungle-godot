class_name AirfieldHQ23
extends RefCounted
## Construction, footprint, and deferred aircraft-store contract for Airfield HQ 2.3.
## The approved 2.2 hangar is instantiated read-only; the 2.3 tower is a separate asset.

const BUILD_COST := 2800
const P47_COST := 1800
const P47_PURCHASE_ENABLED := false # aircraft work resumes only after iPhone approval
const AIRCRAFT_CAPACITY := 2 # keuze 7B (14 nov 2026): twee toestellen naast elkaar in één hangar
const UNWANTED_WORKSHOP_LIGHT_PREFIX := "Warm workshop practical light"

# De grootte van het oude vaste kamp (56,65 x 56,95 m); sinds stap 4b alleen nog het oppervlaktebudget van het vliegveld (MAX_GROUND_AREA).
const BASE_GROUND_SIZE := Vector2(56.65, 56.95)
const MAX_GROUND_AREA := 2.0 * BASE_GROUND_SIZE.x * BASE_GROUND_SIZE.y

## Vliegveld op basismaat (keuzes Dennis 14 nov 2026: 1A 2A 3B 4B 5A 6A 7B 8A), stap 1 = proef met het bestaande model verkleind.
## Eén hangar (HQ2.3 x HANGAR_SCALE) voor twee toestellen van ~8,5 m, met de deuren op een korte betonstrook van 36 x 8 m
## (opstijgen na ~12 m rollen, landen + remmen in ~11 m), een lage toren van ~9 m ernaast en aan beide uiteinden van de strook
## een vrije aanvliegzone van 20 m waar je niets hoogs mag bouwen. Was 75 x 53 m, nu ongeveer 36 x 25 m.
const HANGAR_SCALE := 0.85    # 22 x 20 m HQ2.3-hangar -> 18,7 x 17 m, deuropening 12,75 m
const TOWER_SCALE := 0.4      # HQ2.3-toren 22,7 m -> ~9 m hoog
const FOOTPRINT := Vector3(36.0, 9.5, 25.2) # hangar + toren + strook (zonder aanvliegzones); voor camera en bouwkaart

const HANGAR_CENTER := Vector2(0.0, -4.05)
const HANGAR_SIZE := Vector2(19.4, 17.6) # 18,7 x 17 m hangar met een randje
const HANGAR_DOOR_Z := HANGAR_CENTER.y + 9.775 * HANGAR_SCALE # buitenkant van de deuren (vliegveldcoördinaten)
const TOWER_CENTER := Vector2(-12.6, -6.0)
const TOWER_SIZE := Vector2(4.6, 4.6)
const SLOT_X := [-3.3, 3.3]   # parkeerplekken in de hangar (x t.o.v. het midden van de hangar)

const RUNWAY_LENGTH_M := 36.0
const RUNWAY_WIDTH_M := 8.0
const RUNWAY_START_X := -18.0
const RUNWAY_END_X := RUNWAY_START_X + RUNWAY_LENGTH_M
const RUNWAY_CENTER_Z := HANGAR_DOOR_Z + 0.3 + RUNWAY_WIDTH_M * 0.5
const APPROACH_ZONE_M := 20.0   # keuze 5A: vrij verlengde aan beide uiteinden
const APPROACH_ZONE_WIDTH_M := 10.0
const APRON_CENTER := Vector2(0.0, RUNWAY_CENTER_Z) # de strook voor de deuren is ook het platform
const TAXIWAY_WIDTH_M := RUNWAY_WIDTH_M
const TAXI_START := Vector2(0.0, RUNWAY_CENTER_Z)
const TAXI_RUNWAY_END := Vector2(RUNWAY_END_X - 2.0, RUNWAY_CENTER_Z)
const TAXI_RUNWAY_HOLD := Vector2(0.0, RUNWAY_CENTER_Z)

# The derived compact hangar is centred at its authored floor origin.
const COMPLEX_CENTER_OFFSET := Vector3(0.0, 0.0, HANGAR_CENTER.y)
const SUGGESTED_CENTER := Vector3(70.0, 0.0, 115.0)
const P47_SCENE := "res://assets/p47_thunderbolt.glb"
const HQ22_ANIMATED_TOWER_SCENE := "res://assets/airfield_hq_v22/runtime/Bloedjungle_Airfield_HQ_2_2_LOD0.glb"
const AIRCRAFT := {
	"p47": {"name": "Republic P-47 Thunderbolt", "cost": P47_COST, "scene": P47_SCENE, "source_required": "original Meshy Pro GLB/FBX"},
}
const COMPLEX_SCENE := "res://scenes/airfield_hq_23_compact_showcase.tscn"
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
	# This coarse overall box is disabled: individual placement regions and solid
	# wall, door and stair colliders preserve playable access between components.
	var slab_collision := CollisionShape3D.new()
	var slab := BoxShape3D.new()
	slab.size = Vector3(FOOTPRINT.x, 0.5, FOOTPRINT.z)
	slab_collision.shape = slab
	slab_collision.position = Vector3(0, -0.25, 0)
	slab_collision.disabled = true
	body.add_child(slab_collision)
	# "complex" is een onverschaalde wortel op het midden van de hangar (metrisch, zoals vliegtuig.gd verwacht);
	# alleen de hangar zelf is verkleind (HANGAR_SCALE, gelijk in alle richtingen zodat botsing en deuren meeschalen).
	var complex := Node3D.new()
	complex.name = "AirfieldCompactRoot"
	complex.position = COMPLEX_CENTER_OFFSET
	body.add_child(complex)
	var hangar := packed.instantiate() as Node3D
	hangar.name = "AirfieldHQ23CompactCore"
	hangar.scale = Vector3.ONE * HANGAR_SCALE
	complex.add_child(hangar)
	complex.set_meta("hangar", hangar)
	_compact_approved_core(hangar)
	var flight := hangar.get_node_or_null("AirfieldFlightIntegration") as Node3D
	if flight != null:
		flight.scale = Vector3.ONE / HANGAR_SCALE   # markers in meters t.o.v. het hangarmidden
	_add_hq23_tower(complex)
	var paving := AirfieldPavementModules.new()
	paving.name = "AirfieldHQ23PavementModules"
	complex.add_child(paving)
	body.set_meta("complex", complex)
	return body

static func _compact_approved_core(complex: Node3D) -> void:
	# The protected 2.2 showcase stays untouched. This derived 2.3 scene keeps its
	# compact hangar, service interior and animated hangar doors; its old tower hides.
	var keep_prefixes := ["Hangar HQ 22", "Hangar sliding door", "USAAF blue insignia", "USAAF white star", "Hangar Service Props"]
	for lod_name in ["Airfield_HQ_23_Compact_LOD0", "Airfield_HQ_23_Compact_LOD1", "Airfield_HQ_23_Compact_LOD2"]:
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
	_disable_unwanted_workshop_lights(complex)
	for collider_name in ["RunwayCollision", "ApronCollision", "TaxiCollision", "TowerCollision", "TowerWestWall", "TowerEastWall", "TowerSouthWestPier", "TowerSouthEastPier", "TowerDoorCollision"]:
		var collider := complex.get_node_or_null("GameplayCollisions/" + collider_name) as StaticBody3D
		if collider != null:
			collider.collision_layer = 0

static func _disable_unwanted_workshop_lights(complex: Node3D) -> void:
	# The protected source remains byte-identical. The derived GLB carries five
	# bounded local workshop lights; keep them off in normal daylight and expose a
	# reversible toggle for matched lights-on/lights-off review captures.
	var lod0 := complex.get_node_or_null("Airfield_HQ_23_Compact_LOD0")
	if lod0 == null:
		return
	for node in lod0.find_children("*", "OmniLight3D", true, false):
		var light := node as OmniLight3D
		if light.name.begins_with(UNWANTED_WORKSHOP_LIGHT_PREFIX):
			light.visible = false

static func _add_hq23_tower(complex: Node3D) -> void:
	# Keuze 6A: een lage toren (~9 m) naast de hangar. In deze proef is het de HQ2.3-toren gelijkmatig verkleind,
	# dus niet beklimbaar (de trap zou 1 m hoge deuren krijgen); het nieuwe model in stap 2 krijgt weer een echte trap.
	var tower_root := Node3D.new()
	tower_root.name = "ControlTowerHQ23"
	tower_root.position = layout_point(TOWER_CENTER.x, TOWER_CENTER.y, 0.0)
	tower_root.scale = Vector3.ONE * TOWER_SCALE
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
		_strip_motion_source_lights(root)
		tower_root.add_child(root)
	var solid := StaticBody3D.new()
	solid.name = "Tower solid collision"
	solid.collision_layer = Kit.LAYER_WALL
	solid.collision_mask = 0
	solid.position = layout_point(TOWER_CENTER.x, TOWER_CENTER.y, 0.0)
	complex.add_child(solid)
	_add_box_collision(solid, Vector3(0.0, 4.6, 0.0), Vector3(TOWER_SIZE.x - 0.4, 9.2, TOWER_SIZE.y - 0.4))

static func _strip_motion_source_lights(motion_root: Node) -> void:
	# The full HQ2.2 LOD0 GLB is instanced only for the door and windsock clips.
	# Its glTF import carries the five workshop point lights WITHOUT their 6 m
	# range: Godot gives them energy ≈38,000 and range 4096 m, which floods the
	# whole airfield (white runway, clipped tower, hangar roof). The motion
	# details must add no light at all, so the instanced copies are removed;
	# the protected source GLB stays byte-identical.
	for node in motion_root.find_children("*", "Light3D", true, false):
		node.get_parent().remove_child(node)
		node.free()

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
	# Convert airport-local coordinates into the compact hangar-centered scene.
	return Vector3(x - COMPLEX_CENTER_OFFSET.x, y, z - COMPLEX_CENTER_OFFSET.z)

## Taxiroute: geen aparte taxibaan meer, de strook ligt direct voor de deuren.
static func taxi_centerline_points() -> Array[Vector2]:
	var points: Array[Vector2] = [TAXI_START, TAXI_RUNWAY_END]
	return points

static func slot_point(slot: int) -> Vector2:
	return Vector2(HANGAR_CENTER.x + float(SLOT_X[clampi(slot, 0, SLOT_X.size() - 1)]), HANGAR_CENTER.y)

## Hangar, toren en strook: wat echt gebouwd wordt (botsing, rivier, spawn, wegduwen).
static func site_regions() -> Array[Dictionary]:
	var regions: Array[Dictionary] = [
		{"name": "hangar", "center": HANGAR_CENTER, "size": HANGAR_SIZE, "yaw": 0.0},
		{"name": "tower", "center": TOWER_CENTER, "size": TOWER_SIZE, "yaw": 0.0},
		{"name": "runway", "center": Vector2((RUNWAY_START_X + RUNWAY_END_X) * 0.5, RUNWAY_CENTER_Z), "size": Vector2(RUNWAY_WIDTH_M, RUNWAY_LENGTH_M), "yaw": PI * 0.5},
	]
	return regions

## Keuze 5A: het verlengde van de strook blijft vrij (geen gebouw, toren of muur; zandzakken mogen). Bomen worden gekapt.
static func approach_zones() -> Array[Dictionary]:
	var zones: Array[Dictionary] = []
	for side in [-1.0, 1.0]:
		var edge: float = RUNWAY_END_X if side > 0.0 else RUNWAY_START_X
		zones.append({"name": "approach", "center": Vector2(edge + side * APPROACH_ZONE_M * 0.5, RUNWAY_CENTER_Z), "size": Vector2(APPROACH_ZONE_M, APPROACH_ZONE_WIDTH_M), "yaw": 0.0, "zone": true})
	return zones

static func site_and_zone_regions() -> Array[Dictionary]:
	var regions := site_regions()
	regions.append_array(approach_zones())
	return regions

static func preview_regions() -> Array[Dictionary]:
	return site_and_zone_regions()

## Raakt een gebouwvlak (wereld: midden, maat x/z, draaiing) de aanvliegzone van een gebouwd vliegveld?
static func blocks_approach(center: Vector3, size: Vector2, yaw: float) -> bool:
	for b in Game.buildings:
		if b.kind != "airfield" or b.get("down", false):
			continue
		var at: Vector3 = b.at
		var by: float = b.yaw
		for zone in approach_zones():
			var zc := Vector2(at.x, at.z) + _rotate_local(zone.center, by)
			if _rectangles_overlap(zc, zone.size, by + float(zone.yaw), Vector2(center.x, center.z), size, yaw):
				return true
	return false

static func _region_corners(region: Dictionary) -> Array[Vector2]:
	var half: Vector2 = region.size * 0.5
	var center: Vector2 = region.center
	var yaw: float = region.get("yaw", 0.0)
	var corners: Array[Vector2] = []
	for point in [Vector2(-half.x,-half.y),Vector2(-half.x,half.y),Vector2(half.x,-half.y),Vector2(half.x,half.y)]:
		corners.append(center + _rotate_local(point, yaw))
	return corners

static func footprint_area() -> float:
	return HANGAR_SIZE.x * HANGAR_SIZE.y + TOWER_SIZE.x * TOWER_SIZE.y + RUNWAY_LENGTH_M * RUNWAY_WIDTH_M

static func area_limit_ok() -> bool:
	return footprint_area() <= MAX_GROUND_AREA

static func site_inside_world(at: Vector3, yaw: float) -> bool:
	for region in site_and_zone_regions():
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

static func _rectangles_overlap(a_center: Vector2, a_size: Vector2, a_yaw: float, b_center: Vector2, b_size: Vector2, b_yaw: float) -> bool:
	var axes: Array[Vector2] = [
		Vector2(cos(a_yaw), -sin(a_yaw)), Vector2(sin(a_yaw), cos(a_yaw)),
		Vector2(cos(b_yaw), -sin(b_yaw)), Vector2(sin(b_yaw), cos(b_yaw)),
	]
	var a_x := axes[0]
	var a_z := axes[1]
	var b_x := axes[2]
	var b_z := axes[3]
	var delta := b_center - a_center
	for axis in axes:
		var ra := absf(axis.dot(a_x)) * a_size.x * 0.5 + absf(axis.dot(a_z)) * a_size.y * 0.5
		var rb := absf(axis.dot(b_x)) * b_size.x * 0.5 + absf(axis.dot(b_z)) * b_size.y * 0.5
		if absf(delta.dot(axis)) > ra + rb:
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
	var hangar: Node = complex.get_meta("hangar") if complex.has_meta("hangar") else complex
	var parking := hangar.get_node_or_null("AirfieldFlightIntegration/P47_Apron_Parking") as Node3D
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

## Testversie vliegen (stap 1): het vliegveld zet vanzelf een gratis toestel klaar (plaatsvervanger-model); na neerstorten komt
## er na RESPAWN_S een nieuw. Kopen met punten volgt samen met het Meshy-toestel.
const TEST_PLANE := true
const RESPAWN_S := 20.0
## Via preload i.p.v. de klassenaam: een klasse die pas via een OTA-patch bijkomt staat niet in de klassenlijst van de IPA.
const VLIEGTUIG := preload("res://scripts/vliegtuig.gd")

static func step(building: Dictionary, delta: float) -> void:
	if not TEST_PLANE or building.get("down", false) or building.get("hp", 1.0) <= 0.0:
		return
	var list: Array = building.aircraft
	for i in range(list.size() - 1, -1, -1):
		var n = list[i].get("node")
		if n == null or not is_instance_valid(n):
			list.remove_at(i)
	if list.size() >= AIRCRAFT_CAPACITY:
		return
	building["spawn_t"] = building.get("spawn_t", 1.0) - delta
	if building.spawn_t > 0.0:
		building["spawn_status"] = "toestel wordt klaargezet…"
		return
	if not building.node.has_meta("complex"):
		building["spawn_status"] = "geen toestel: vliegveldscène mist (complex)"
		return
	var slot := 0
	var used: Array[int] = []
	for a in list:
		used.append(int(a.get("slot", 0)))
	while used.has(slot):
		slot += 1
	var v = VLIEGTUIG.spawn(building, slot)
	if v == null:
		building["spawn_status"] = "geen toestel: spawn mislukt"
		building["spawn_t"] = RESPAWN_S
		return
	building["spawn_status"] = "toestel staat klaar" if v._model != null else "toestel staat klaar, maar het model laadt niet (%s)" % VLIEGTUIG.MODEL_PATH
	# het tweede toestel komt vlak na het eerste; na een crash duurt het RESPAWN_S
	building["spawn_t"] = 1.0 if list.size() + 1 < AIRCRAFT_CAPACITY and not building.get("had_planes", false) else RESPAWN_S
	if list.size() + 1 >= AIRCRAFT_CAPACITY:
		building["had_planes"] = true
	list.append({"kind": "test", "node": v, "state": "PARKED", "slot": slot, "health": 1.0})

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
