class_name Buildings
extends Node3D
## Gebouwen en bouwstukken die je in de bouwmodus neerzet (BUILD_DEFS in 16d-base.js): de kazerne die
## rekruten opleidt, betonmuren en zandzakken. Verplaatsen, draaien, repareren en verkopen kan ook.
## De rekruten zelf zijn Ally (ally.gd); het bouwscherm staat in build_mode.gd.

const DEFS := {
	"depot": {"name": "Voorraaddepot", "cost": 800, "size": Vector3(9.0, 3.6, 6.5), "max": 3, "hp": 900.0},   # Generals-stap 4: trucks leveren hier voorraad af (voorraad.gd)
	"kazerne": {"name": "Kazerne", "cost": 1000, "size": Vector3(4.4, 2.2, 3.2), "max": 1, "hp": 600.0},
	"garage": {"name": "Garage", "cost": 800, "size": Vector3(7.7, 7.3, 8.0), "max": 1, "hp": 900.0},   # Meshy-motorpool (bron/garage_meshy), compact (keuze A), poort 3,7 x 4,4 m voor de truck
	"helipad": {"name": "Heliplatform", "cost": 1000, "size": Vector3(12.8, 2.0, 12.8), "max": 1, "hp": 1200.0},
	"airfield": {"name": "Vliegveld", "cost": AirfieldHQ23.BUILD_COST, "size": AirfieldHQ23.FOOTPRINT, "max": 1, "hp": 3000.0},
	"zandzak": {"name": "Zandzakken", "cost": 150, "size": Vector3(3.1, 0.95, 0.8), "max": 40, "hp": 380.0, "piece": true},
	"wachttoren": {"name": "Wachttoren", "cost": 100, "size": Vector3(1.9, 5.0, 1.9), "max": 40, "hp": 800.0},   # MCV-start: dezelfde klimbare toren als in het oude kamp (wachttoren.glb), alleen bij je hoofdkwartier
	"kampmuur": {"name": "Kampmuur", "cost": 50, "size": Vector3(3.5, 3.0, 0.7), "max": 800, "hp": 1500.0, "piece": true},   # MCV-start (kampmuur.gd): met je vinger getrokken, op een rooster van 3,5 m
}
# kaartjes die in de lijst staan maar nog geen model hebben (komen later)
const SOON := ["Ziekenboeg", "Munitiedepot", "Werkplaats", "Radiopost"]
const VEHICLES := {
	"jeep": {"name": "Jeep", "cost": 400, "scene": "res://scenes/jeep.tscn"},
	"tank": {"name": "Tank", "cost": 1200, "scene": "res://scenes/tank.tscn"},
	"truck": {"name": "Truck", "cost": 700, "scene": "res://scenes/vrachtwagen.tscn"},
}
const HELI_COST := 500
const GARAGE_RIJ_MAX := 3  # wagens die tegelijk in de garagerij mogen staan; van elk type mag je er zoveel kopen als je wilt
# Generals-plan stap 1 (docs/GENERALS_PLAN.md): bouwtijd in seconden en wat je eerst nodig hebt (techboom).
# Muren en zandzakken staan er meteen. Tests en code die place() zonder bouwtijd aanroepen bouwen direct.
const BUILD_TIME := {"wachttoren": 8.0, "depot": 12.0, "kazerne": 12.0, "garage": 15.0, "helipad": 20.0, "airfield": 30.0}
const REQUIRES := {"garage": "kazerne", "helipad": "garage", "airfield": "helipad"}
const PAD_T := 4.5  # seconden dat de luiken en de lift nodig hebben (de clips Open en Dicht)
const INFO := {
	"zandzak": "Lage dekking: kogels stoppen erop, jij schiet eroverheen.",
	"wachttoren": "Klim erop (loop tegen de trap) en schiet over de muur. Alleen bij je hoofdkwartier.",
	"kampmuur": "Hoge muur: niemand schiet of loopt erdoorheen. Vijanden schieten hem stuk; verkopen en repareren kan.",
}
# per niveau: soldaten tegelijk, seconden per rekruut, gezondheid, schade en wat het niveau kost
const LEVELS := [null,
	{"max": 2, "time": 10.0, "hp": 100.0, "dmg": 16.0},
	{"max": 4, "time": 7.0, "hp": 115.0, "dmg": 18.0, "cost": 1200},
	{"max": 6, "time": 5.0, "hp": 130.0, "dmg": 21.0, "cost": 1800}]
const TRAIN_COST := 250
const RIJ_MAX := 5  # soldaten tegelijk in de bouwrij van een kazerne (Generals-plan stap 2)
const DOOR := 2.5  # afstand van het midden tot het punt voor de deur
const TOWER_RANGE := 45.0  # m: een wachttoren mag alleen zo dicht bij het hoofdkwartier staan (Dennis: "alleen bij de basis")
const HQ_SPEEDUP := 0.75  # hoofdkwartier niveau 2: alle bouw- en opleidingstijden 25% korter (Generals-plan stap 3)
const DOOR_U := -0.04   # midden van de garagepoort (assets/garage.glb, poort 3,7 x 4,4 m)
const FRONT := 1.93     # afstand van het midden van de garage tot de voorkant van de poort
const GARAGE_LOD := 45.0  # vanaf hier (m) toont de garage Romp_LOD1 in plaats van Romp


var radio: Radio
var batch := false   # tijdens het bouwen van een hele muur: geen geluid en geen verversing per stuk (kampmuur.gd)


func _ready() -> void:
	radio = Radio.new()
	radio.name = "Radio"
	add_child(radio)
	add_to_group("buildings")
	add_child(GarageMenu.new())
	add_child(HqMenu.new())   # tik op het hoofdkwartier = upgradepaneel


## Tijdsfactor van het hoofdkwartier: 1.0 op niveau 1, 0,75 vanaf niveau 2 (bouwen en soldaten opleiden).
static func time_factor() -> float:
	return HQ_SPEEDUP if Game.hq_level >= 2 else 1.0


## Seconden per rekruut in deze kazerne, met de bonus van het hoofdkwartier.
static func train_time(b: Dictionary) -> float:
	return float(LEVELS[b.lv].time) * time_factor()


func count(kind: String) -> int:
	var n := 0
	for b in Game.buildings:
		if b.kind == kind:
			n += 1
	return n


func is_piece(kind: String) -> bool:
	return DEFS[kind].get("piece", false)


func full(kind: String) -> bool:
	return count(kind) >= DEFS[kind].max


# ---------------------------------------------------------------- neerzetten

## Wereldpunt van een plek (u, v) in het bouwstuk dat op `at` staat met draaiing `yaw`.
static func _pt(at: Vector3, yaw: float, u: float, v: float) -> Vector3:
	return at + Vector3(cos(yaw), 0, -sin(yaw)) * u + Vector3(sin(yaw), 0, cos(yaw)) * v


func _tower_feet() -> Array:
	var out: Array = []
	for t: Node3D in get_tree().get_nodes_in_group("tower"):
		out.append([t.to_global(Vector3(1.8, 0, 0)), t.global_position])
	return out


## Shared source of truth for the preview and the final transaction.
func placement_status(kind: String, at: Vector3, yaw: float, me: Variant = null) -> Dictionary:
	if kind == "airfield":
		if not AirfieldHQ23.complex_available() or not AirfieldHQ23.area_limit_ok():
			return _placement_result(false, "Vliegveldassets ontbreken", 0)
		if me == null and full(kind):
			return _placement_result(false, "Er is al een vliegveld gebouwd", 0)
		if not AirfieldHQ23.site_inside_world(at, yaw):
			return _placement_result(false, "Buiten speelbaar gebied", 0)
		if not AirfieldHQ23.site_clear_of_combat_spawns(at, yaw):
			return _placement_result(false, "Vijandelijke spawnzone", 0)
		if not AirfieldHQ23.site_clear_of_river(at, yaw):
			return _placement_result(false, "Kan niet in de rivier bouwen", 0)
		if not is_inside_tree():
			return _placement_result(true, "Bouwen mogelijk", 0)
		var exclusions: Array[RID] = []
		if me != null:
			exclusions.append(me.node.get_rid())
			for child in me.node.find_children("*", "CollisionObject3D", true, false):
				exclusions.append((child as CollisionObject3D).get_rid())
		for region in AirfieldHQ23.site_regions():
			var site_shape := BoxShape3D.new()
			site_shape.size = Vector3(region.size.x + 0.2, 1.4, region.size.y + 0.2)
			var site_query := PhysicsShapeQueryParameters3D.new()
			site_query.shape = site_shape
			site_query.collision_mask = Kit.LAYER_WALL | Kit.LAYER_BUNKER | Kit.LAYER_NATURE | Kit.LAYER_WATER
			site_query.exclude = exclusions
			site_query.transform = AirfieldHQ23.region_transform(at + Vector3(0.0, 0.7, 0.0), yaw, region)
			var blocker := _first_protected_overlap(site_query)
			if blocker != null:
				return _placement_result(false, _overlap_message(blocker), 0)
		var removable := Foliage.count_clearable_in_regions(_clearance_regions(kind), at, yaw)
		return _placement_result(true, "Bouwen mogelijk — begroeiing wordt verwijderd" if removable > 0 else "Bouwen mogelijk", removable)
	if kind == "kampmuur":
		return _kampmuur_status(at, yaw, me)
	if kind == "wachttoren":
		return _tower_status(at, yaw, me)
	var d: Dictionary = DEFS[kind]
	var sz: Vector3 = d.size
	var piece := is_piece(kind)
	# het kamp mag zo groot worden als je wilt, overal aan jouw kant van de rivier (geen vaste muur, geen vast kader)
	if not Game.mcv_deployed:
		return _placement_result(false, "Klap eerst je wagen uit", 0)
	if not Mcv.in_play_area(at, 4.0):
		return _placement_result(false, "Buiten speelbaar gebied", 0)
	if not Mcv.dry_side(at, 3.0):
		return _placement_result(false, "Kan niet in of voorbij de rivier bouwen", 0)
	var feet := _tower_feet()
	for iu in 3:
		for iv in 3:
			var p := _pt(at, yaw, (iu - 1) * sz.x * 0.5, (iv - 1) * sz.z * 0.5)
			if not Mcv.dry_side(p, 3.0):
				return _placement_result(false, "Kan niet in of voorbij de rivier bouwen", 0)
			for f in feet:
				if p.distance_to(f[0]) < 1.4 or p.distance_to(f[1]) < 1.9:
					return _placement_result(false, "Te dicht bij bestaande gebouwen", 0)
	var ex: Array[RID] = []
	if me != null:
		ex.append(me.node.get_rid())
	if _hits(Vector3(sz.x - 0.2, 1.0, sz.z - 0.2) if piece else Vector3(sz.x + 0.4, 1.0, sz.z + 0.4), at, yaw, ex):
		return _placement_result(false, "Te dicht bij bestaande gebouwen", 0)
	if piece or kind == "helipad":
		var removable_piece := Foliage.count_clearable_in_regions(_clearance_regions(kind), at, yaw) if is_inside_tree() else 0
		return _placement_result(true, "Bouwen mogelijk — begroeiing wordt verwijderd" if removable_piece > 0 else "Bouwen mogelijk", removable_piece)
	# de deur moet op vrij terrein uitkomen
	var door := _pt(at, yaw, 0.0, sz.z / 2.0 + 0.9)
	var q2 := PhysicsShapeQueryParameters3D.new()
	var s2 := SphereShape3D.new()
	s2.radius = 0.5
	q2.shape = s2
	q2.collision_mask = Kit.LAYER_WALL | Kit.LAYER_BUNKER
	q2.exclude = ex
	q2.transform = Transform3D(Basis.IDENTITY, door + Vector3(0, 0.8, 0))
	var door_blocker := _first_protected_overlap(q2)
	if door_blocker != null:
		return _placement_result(false, "Te dicht bij bestaande gebouwen", 0)
	var removable := Foliage.count_clearable_in_regions(_clearance_regions(kind), at, yaw) if is_inside_tree() else 0
	return _placement_result(true, "Bouwen mogelijk — begroeiing wordt verwijderd" if removable > 0 else "Bouwen mogelijk", removable)


## Een muurstuk van de MCV-start: aan jouw kant van de rivier, niet in iets massiefs (andere muurstukken raken elkaar bij de hoeken en tellen niet mee).
func _kampmuur_status(at: Vector3, yaw: float, me: Variant) -> Dictionary:
	if not Game.mcv_deployed:
		return _placement_result(false, "Klap eerst je wagen uit", 0)
	if full("kampmuur") and me == null:
		return _placement_result(false, "Je hebt het maximum aan muurstukken", 0)
	var sz: Vector3 = DEFS["kampmuur"].size
	for u in [-0.5, 0.0, 0.5]:
		var p := _pt(at, yaw, u * sz.x, 0.0)
		if not Mcv.in_play_area(p, 4.0):
			return _placement_result(false, "Buiten speelbaar gebied", 0)
		if not Mcv.dry_side(p, 3.0):
			return _placement_result(false, "Kan niet in of voorbij de rivier bouwen", 0)
	if not is_inside_tree():
		return _placement_result(true, "Bouwen mogelijk", 0)
	var ex: Array[RID] = []
	for b in Game.buildings:
		if b.kind == "kampmuur" and is_instance_valid(b.node):
			ex.append((b.node as CollisionObject3D).get_rid())
	if me != null and is_instance_valid(me.node):
		ex.append((me.node as CollisionObject3D).get_rid())
	# iets korter dan het stuk: de uiteinden raken de buurstukken
	if _hits(Vector3(sz.x - 0.9, 1.0, sz.z - 0.1), at, yaw, ex):
		return _placement_result(false, "Er staat iets in de weg", 0)
	var removable := Foliage.count_clearable_in_regions(_clearance_regions("kampmuur"), at, yaw)
	return _placement_result(true, "Bouwen mogelijk — begroeiing wordt verwijderd" if removable > 0 else "Bouwen mogelijk", removable)


## Een wachttoren van de MCV-start: aan jouw kant van de rivier, hooguit TOWER_RANGE van het hoofdkwartier, niet in iets massiefs, en de voet van de trap vrij.
func _tower_status(at: Vector3, yaw: float, me: Variant) -> Dictionary:
	if not Game.mcv_deployed:
		return _placement_result(false, "Klap eerst je wagen uit", 0)
	if full("wachttoren") and me == null:
		return _placement_result(false, "Je hebt het maximum aan torens", 0)
	if Vector2(at.x - Game.base_pos.x, at.z - Game.base_pos.z).length() > TOWER_RANGE:
		return _placement_result(false, "Alleen bij het hoofdkwartier", 0)
	if not Mcv.in_play_area(at, 4.0) or not Mcv.dry_side(at, 3.0):
		return _placement_result(false, "Kan niet in of voorbij de rivier bouwen", 0)
	if not is_inside_tree():
		return _placement_result(true, "Bouwen mogelijk", 0)
	var sz: Vector3 = DEFS["wachttoren"].size
	var ex: Array[RID] = []
	if me != null and is_instance_valid(me.node):
		ex.append((me.node as CollisionObject3D).get_rid())
	if _hits(Vector3(sz.x + 0.4, 1.0, sz.z + 0.4), at, yaw, ex):
		return _placement_result(false, "Er staat iets in de weg", 0)
	# de voet van de trap (aan de lokale +x-kant) moet vrij zijn, anders kom je er niet op
	var foot := at + Basis(Vector3.UP, yaw) * Vector3(1.8, 0.0, 0.0)
	if _hits(Vector3(1.4, 1.0, 1.4), foot, yaw, ex):
		return _placement_result(false, "De trap kan hier niet staan", 0)
	var removable := Foliage.count_clearable_in_regions(_clearance_regions("wachttoren"), at, yaw)
	return _placement_result(true, "Bouwen mogelijk — begroeiing wordt verwijderd" if removable > 0 else "Bouwen mogelijk", removable)


func can_place(kind: String, at: Vector3, yaw: float, me: Variant = null) -> bool:
	return bool(placement_status(kind, at, yaw, me).valid)


func _placement_result(valid: bool, reason: String, removable: int) -> Dictionary:
	return {"valid": valid, "reason": reason, "vegetation_count": removable}


func _clearance_regions(kind: String) -> Array:
	if kind == "airfield":
		return AirfieldHQ23.site_regions()
	var size: Vector3 = DEFS[kind].size
	return [{"name": kind, "center": Vector2.ZERO, "size": Vector2(size.x, size.z), "yaw": 0.0}]


func _overlap_message(collider: Object) -> String:
	if collider == null:
		return "Te dicht bij bestaande gebouwen"
	if collider is CollisionObject3D:
		var object := collider as CollisionObject3D
		if (object.collision_layer & Kit.LAYER_WATER) != 0:
			return "Kan niet in de rivier bouwen"
		if (object.collision_layer & Kit.LAYER_BUNKER) != 0:
			return "Te dicht bij bestaande gebouwen"
		if object.has_meta("protected_route") and bool(object.get_meta("protected_route")):
			return "Belangrijke route geblokkeerd"
		if object.has_meta("vegetation_kind") and String(object.get_meta("vegetation_kind")) == "rock":
			return "Beschermd terreinobject overlapt"
		if (object.collision_layer & Kit.LAYER_WALL) != 0:
			return "Te dicht bij bestaande gebouwen"
		return "Beschermd object overlapt"
	return "Beschermd object overlapt"


func _first_protected_overlap(query: PhysicsShapeQueryParameters3D) -> Object:
	var space := get_world_3d().direct_space_state
	var excluded := query.exclude.duplicate()
	while true:
		query.exclude = excluded
		var hits := space.intersect_shape(query, 256)
		if hits.is_empty():
			return null
		var found_clearable := false
		for hit: Dictionary in hits:
			var collider: Object = hit.get("collider")
			if Foliage.collider_is_clearable(collider):
				var rid: RID = hit.get("rid", RID())
				if rid.is_valid() and not excluded.has(rid):
					excluded.append(rid)
					found_clearable = true
				continue
			return collider
		if hits.size() < 256 or not found_clearable:
			return null
	return null


func _hits(size: Vector3, at: Vector3, yaw: float, ex: Array[RID]) -> bool:
	var shape := BoxShape3D.new()
	shape.size = size
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.collision_mask = Kit.LAYER_WALL | Kit.LAYER_BUNKER | Kit.LAYER_NATURE | Kit.LAYER_WATER
	q.exclude = ex
	q.transform = Transform3D(Basis(Vector3.UP, yaw), at + Vector3(0, 0.8, 0))
	return _first_protected_overlap(q) != null


## Het gebouw zelf: een StaticBody die kogels en mensen tegenhoudt, met het model eronder.
func make_node(kind: String) -> StaticBody3D:
	if kind == "airfield":
		return AirfieldHQ23.make_complex()
	var body := BuildingBody.new()
	body.collision_layer = Kit.LAYER_WALL
	body.collision_mask = 0
	body.set_meta("impact_material", {"zandzak": "dirt", "kazerne": "wood", "depot": "metal", "garage": "metal", "helipad": "concrete", "airfield": "concrete"}.get(kind, "concrete"))
	var sz: Vector3 = DEFS[kind].size
	if kind != "garage" and kind != "helipad":
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = sz
		cs.shape = bs
		cs.position = Vector3(0, sz.y / 2.0, 0)
		body.add_child(cs)
	match kind:
		"garage":
			_garage_node(body)
		"helipad":
			_pad_node(body)
		"depot":
			_depot_node(body, sz)
		"kazerne":
			var model: Node = (load("res://assets/kazerne.glb") as PackedScene).instantiate()
			Kit.skin(model, "kazerne")
			body.add_child(model)
		"wachttoren":
			body.add_to_group("tower")   # de speler klimt erop (player.gd), de radar tekent hem
			var tower_model: Node = (load("res://assets/wachttoren.glb") as PackedScene).instantiate()
			Kit.skin(tower_model, "toren")
			body.add_child(tower_model)
		"kampmuur":
			body.collision_layer = Kit.LAYER_WALL | Kit.LAYER_FORTIFICATION   # kogels van de grond en ontploffingen worden door hem tegengehouden (BaseWallRules)
			body.set_meta("nocam", true)   # de camera loopt er dwars doorheen in plaats van tegen de muur aan te schuiven
			Kampmuur.add_visual(body)
		"zandzak":
			_bags(body, sz)
	return body


## Voorraaddepot (4b): het echte model met schuur, rolpoort, laadperron en portaalkraan (scripts/voorraad_depot_model.gd).
## De voorkant (waar de trucks komen) is +Z; de voetafdruk is 9 x 6,5 m.
func _depot_node(root: Node3D, _sz: Vector3) -> void:
	var model := VoorraadDepotModel.new()
	model.name = "DepotModel"
	root.add_child(model)
	root.set_meta("depot_model", model)


func _bags(root: Node3D, sz: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(root.position.x * 13.0 + root.position.z * 7.0) + 11
	var mat: StandardMaterial3D = Kit.canvas()
	var bag := SphereMesh.new()
	bag.radius = 0.5
	bag.height = 1.0
	bag.radial_segments = 8
	bag.rings = 4
	for layer in 3:
		for i in 4 - (layer % 2):
			var mi := MeshInstance3D.new()
			mi.mesh = bag
			mi.material_override = mat
			mi.position = Vector3(-1.2 + i * 0.82 + (layer % 2) * 0.41, 0.17 + layer * 0.27, rng.randf_range(-0.04, 0.04))
			mi.scale = Vector3(0.88, 0.34, 0.52)
			mi.rotation.y = rng.randf_range(-0.1, 0.1)
			root.add_child(mi)


## Welk gebouw ontbreekt er nog voor dit gebouw? Leeg als je mag bouwen. Een gebouw in aanbouw of een wrak telt niet mee.
func missing(kind: String) -> String:
	var need: String = REQUIRES.get(kind, "")
	if need == "":
		return ""
	for b in Game.buildings:
		if b.kind == need and not b.down and not under_construction(b):
			return ""
	return need


static func under_construction(b: Dictionary) -> bool:
	return float(b.get("build_t", 0.0)) > 0.0


## with_time = true (bouwmodus): het gebouw groeit op in BUILD_TIME seconden met steigers en een voortgangsbalk.
## Wat een gebouw nu kost: het gratis eerste voorraaddepot van de MCV-start kost niets (Game.free_depot).
static func cost_of(kind: String) -> int:
	if kind == "depot" and Game.free_depot > 0:
		return 0
	if kind == "kampmuur":
		return Kampmuur.next_cost()
	if kind == "wachttoren" and Game.free_towers > 0:
		return 0
	return int(DEFS[kind].cost)


func place(kind: String, at: Vector3, yaw: float, with_time := false, free := false) -> Variant:
	var status := placement_status(kind, at, yaw)
	if full(kind) or not status.valid:
		return null
	if with_time and missing(kind) != "":
		return null
	var node: StaticBody3D = make_node(kind) if kind == "airfield" else null
	if kind == "airfield" and node == null:
		return null
	var gratis := not free and kind == "depot" and Game.free_depot > 0   # het gratis depot van de MCV-start (en daarmee de eerste truck gratis)
	var gratis_muur := not free and kind == "kampmuur" and Kampmuur.free_left() > 0   # een stuk van de gratis eerste omheining
	var gratis_toren := not free and kind == "wachttoren" and Game.free_towers > 0   # een van de vier gratis torens
	if not free and not gratis and not gratis_muur and not gratis_toren and not Game.pay_build(DEFS[kind].cost):
		if node != null:
			node.free()
		return null
	if node == null:
		node = make_node(kind)
	node.position = at
	node.rotation.y = yaw
	add_child(node)
	var b := {"kind": kind, "node": node, "at": at, "yaw": yaw, "lv": 1, "queue": 0, "train_t": 0.0,
		"hp": DEFS[kind].hp, "max_hp": DEFS[kind].hp, "down": false, "cracked": false, "fx": null, "bar": null,
		"rij": null, "rally": Vector3.ZERO, "has_rally": false, "rally_mode": "volgen", "flag": null}
	node.ref = b
	if gratis_toren:
		Game.free_towers -= 1
		b["gratis"] = true   # verkopen levert niets op
	if kind == "kazerne":
		b["wachten"] = []   # MCV-start: de wachten van deze kazerne (Wachten)
	if kind == "kampmuur":
		b["edge"] = Kampmuur.edge_of(at, yaw)
		if gratis_muur:
			b["gratis"] = true   # verkopen levert niets op
	if gratis:
		Game.free_depot -= 1
		b["gratis"] = true         # verkopen levert niets op
		b["gratis_truck"] = true   # Voorraad zet de eerste truck neer zodra het depot klaar is
	b.bar = HpBar.new()
	add_child(b.bar)
	if kind == "kazerne":
		b.rij = RijBalk.new()
		add_child(b.rij)
	if kind == "garage":
		b.rij = RijBalk.new()
		add_child(b.rij)
		b.merge({"has": {"jeep": 0, "tank": 0, "truck": 0}, "order": [], "fleet": [], "phase": "idle", "t": 0.0, "veh": null, "spin": 0.0, "sway": 0.0})
		_garage_init(b)
	elif kind == "airfield":
		b.merge({"aircraft": [], "aircraft_capacity": AirfieldHQ23.AIRCRAFT_CAPACITY, "runway_reserved_by": "", "complex": true})
	elif kind == "helipad":
		b.merge({"has_heli": false, "hs": "closed", "t": 0.0, "want": false, "heli": null, "spin": 0.0})
		_pad_init(b)
	if with_time and BUILD_TIME.has(kind):
		_site_start(b)
	Game.buildings.append(b)
	Foliage.clear_for_building(node.get_instance_id(), _clearance_regions(kind), at, yaw, Foliage.BUILD_CLEAR_MARGIN, true)
	_push_out(b)
	_cut_pad()
	if not batch:
		Sfx.play("thud")
		Game.changed.emit()
	return b


## Bouwplaats: steigers rond het gebouw en het gebouw zelf groeit omhoog (alleen het zichtbare deel, de botsvorm blijft).
func _site_start(b: Dictionary) -> void:
	b.build_total = BUILD_TIME[b.kind] * time_factor()
	b.build_t = b.build_total
	var node: Node3D = b.node
	var sz: Vector3 = DEFS[b.kind].size
	var site := Node3D.new()
	site.name = "Steiger"
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("8a6a3c")
	mat.roughness = 0.9
	var hx := sz.x * 0.5 + 0.2
	var hz := sz.z * 0.5 + 0.2
	for sx in [-1, 1]:
		for sz_ in [-1, 1]:
			site.add_child(_plank(Vector3(0.12, sz.y + 0.6, 0.12), Vector3(sx * hx, (sz.y + 0.6) * 0.5, sz_ * hz), mat))
	for lvl in [0.45, 0.95]:
		var y: float = sz.y * lvl
		for sx in [-1, 1]:
			site.add_child(_plank(Vector3(0.08, 0.08, hz * 2.0), Vector3(sx * hx, y, 0), mat))
		for sz_ in [-1, 1]:
			site.add_child(_plank(Vector3(hx * 2.0, 0.08, 0.08), Vector3(0, y, sz_ * hz), mat))
	node.add_child(site)
	b.site = site
	var vis: Array = []
	for c in node.get_children():
		if c is Node3D and not (c is CollisionShape3D) and c != site:
			vis.append(c)
	b.vis = vis
	_site_scale(b)


func _plank(size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _site_scale(b: Dictionary) -> void:
	var frac: float = 1.0 - float(b.build_t) / float(b.build_total)
	var k: float = lerpf(0.1, 1.0, smoothstep(0.0, 1.0, frac)) if b.build_t > 0.0 else 1.0
	for c in b.get("vis", []):
		if is_instance_valid(c):
			c.scale.y = k


func _site_done(b: Dictionary) -> void:
	b.build_t = 0.0
	_site_scale(b)
	if b.get("site") != null and is_instance_valid(b.site):
		b.site.queue_free()
	b.site = null
	b.vis = []
	Sfx.play("thud")
	Game.banner.emit("BOUW KLAAR", String(DEFS[b.kind].name).to_upper(), 1.4)
	radio.say("bouw_klaar")
	Game.changed.emit()


func move_to(b: Dictionary, at: Vector3, yaw: float) -> void:
	var status := placement_status(b.kind, at, yaw, b)
	if not status.valid:
		return
	b.at = at
	b.yaw = yaw
	b.node.position = at
	b.node.rotation.y = yaw
	Foliage.clear_for_building(b.node.get_instance_id(), _clearance_regions(b.kind), at, yaw)
	_push_out(b)
	_cut_pad()
	Sfx.play("thud", 0.6)


## Wie in het nieuwe bouwstuk staat, wordt er netjes naast gezet.
func _push_out(b: Dictionary) -> void:
	if b.kind == "airfield":
		_push_out_of_airfield(b)
		return
	var sz: Vector3 = DEFS[b.kind].size
	var who: Array = [Game.player]
	who.append_array(Game.allies)
	for w in who:
		if w == null or not is_instance_valid(w):
			continue
		var rel: Vector3 = w.global_position - b.at
		var u := rel.dot(Vector3(cos(b.yaw), 0, -sin(b.yaw)))
		var v := rel.dot(Vector3(sin(b.yaw), 0, cos(b.yaw)))
		var hu := sz.x / 2.0 + 0.7
		var hv := sz.z / 2.0 + 0.7
		if absf(u) < hu and absf(v) < hv:
			if hu - absf(u) < hv - absf(v):
				u = signf(u if u != 0.0 else 1.0) * hu
			else:
				v = signf(v if v != 0.0 else 1.0) * hv
			var p := _pt(b.at, b.yaw, u, v)
			w.global_position = Vector3(p.x, w.global_position.y, p.z)


func _push_out_of_airfield(b: Dictionary) -> void:
	var who: Array = [Game.player]
	who.append_array(Game.allies)
	for unit in who:
		if unit == null or not is_instance_valid(unit):
			continue
		var local := Vector2(unit.global_position.x - b.at.x, unit.global_position.z - b.at.z).rotated(b.yaw)
		for region in AirfieldHQ23.site_regions():
			var center: Vector2 = region.center
			var local_yaw: float = region.get("yaw", 0.0)
			var rel := (local - center).rotated(local_yaw)
			var half: Vector2 = region.size * 0.5
			if absf(rel.x) > half.x + 0.3 or absf(rel.y) > half.y + 0.3:
				continue
			if half.x - absf(rel.x) < half.y - absf(rel.y):
				rel.x = signf(rel.x if rel.x != 0.0 else 1.0) * (half.x + 0.7)
			else:
				rel.y = signf(rel.y if rel.y != 0.0 else 1.0) * (half.y + 0.7)
			var building_local := center + rel.rotated(-local_yaw)
			var world := Vector2(b.at.x, b.at.z) + building_local.rotated(-b.yaw)
			unit.global_position = Vector3(world.x, unit.global_position.y, world.y)
			break


func remove(b: Dictionary) -> void:
	Wachten.invalidate()   # de ronde van de wachten volgt muren en gebouwen
	for w in b.get("wachten", []):
		if is_instance_valid(w):
			w.queue_free()   # de wachten van een verkochte kazerne gaan mee
	_clear_fx(b)
	if b.kind == "airfield" or b.kind in DEFS:
		Foliage.release_building_clearance(b.node.get_instance_id())
	if b.bar != null:
		b.bar.queue_free()
	if b.get("rij") != null and is_instance_valid(b.rij):
		b.rij.queue_free()
	if b.get("flag") != null and is_instance_valid(b.flag):
		b.flag.queue_free()
	if b.kind == "airfield":
		AirfieldHQ23.cleanup(b)
	elif b.kind == "helipad":
		var player = Game.player
		if b.heli != null and is_instance_valid(b.heli):
			if b.heli.driven and player != null:
				b.heli._leave(player)
			b.heli.queue_free()
	b.node.queue_free()
	Game.buildings.erase(b)
	_cut_pad()
	Game.changed.emit()


# ---------------------------------------------------------------- schade (damageStructure in 16f-buildings.js)

## Schade aan een bouwstuk. Muren en zandzakken vallen uit elkaar, een gebouw wordt een rokend wrak dat je herbouwt.
func damage(b: Dictionary, dmg: float) -> void:
	if b.down or dmg <= 0.0 or (Game.state != "play" and Game.state != "prep") or not Game.buildings.has(b):
		return
	b.hp -= dmg
	if b.hp > 0.0 and not is_piece(b.kind):
		radio.say("basis_aanval")
	var node: Node3D = b.node
	if randf() < 0.5:
		Fx.dust(self, node.global_position + Vector3(randf_range(-1, 1), 0.8, randf_range(-1, 1)))
	if not b.cracked and b.hp > 0.0 and b.hp < b.max_hp * 0.5:
		b.cracked = true
		if is_piece(b.kind):
			node.scale.y = 0.75
		else:
			b.fx = Fx.burning(self, node.global_position, false)
			Game.banner.emit("%s BESCHADIGD" % DEFS[b.kind].name.to_upper(), "", 1.2)
	if b.hp <= 0.0:
		_break(b)
	Game.changed.emit()


func _break(b: Dictionary) -> void:
	var at: Vector3 = b.node.global_position
	if is_piece(b.kind):
		Fx.explosion(self, at + Vector3.UP * 0.4, 0.5)
		remove(b)
		return
	b.down = true
	b.hp = 0.0
	b.queue = 0
	b.node.scale = Vector3(1, 0.32, 1)
	b.node.collision_layer = 0
	_clear_fx(b)
	b.fx = Fx.burning(self, at, true)
	Fx.explosion(self, at + Vector3.UP * 1.0, 1.2)
	Game.banner.emit("%s VERWOEST" % DEFS[b.kind].name.to_upper(), "Herbouw hem in de bouwmodus.", 2.2)
	radio.say("gebouw_vernield")


func _clear_fx(b: Dictionary) -> void:
	if b.fx != null and is_instance_valid(b.fx):
		b.fx.queue_free()
	b.fx = null


## Ontploffing (explode() in 15-combat.js): muren en zandzakken de helft, een gebouw van een vijand de volle schade en van jezelf 15%.
func blast(at: Vector3, radius: float, dmg: float, own := false) -> void:
	for b in Game.buildings.duplicate():
		var sz: Vector3 = DEFS[b.kind].size
		var d: float = maxf(0.0, Vector2(b.at.x - at.x, b.at.z - at.z).length() - maxf(sz.x, sz.z) * 0.5)
		if d < radius:
			var mult := 0.5 if is_piece(b.kind) else (0.15 if own else 1.0)
			damage(b, dmg * mult * (1.0 - d / radius))
	Woonhuis.blast_all(at, radius, dmg)  # huizen in de stad gaan altijd stuk, ook door je eigen raketten


# ---------------------------------------------------------------- waarde en herstel

func fix_cost(b: Dictionary) -> int:
	if b.down:
		return roundi(DEFS[b.kind].cost / 2.0)
	if b.hp >= b.max_hp:
		return 0
	return roundi(DEFS[b.kind].cost * 0.4) if is_piece(b.kind) else 100


func repair(b: Dictionary) -> void:
	var c := fix_cost(b)
	if c > 0 and Game.pay_build(c):
		b.hp = b.max_hp
		b.cracked = false
		if b.down:
			b.down = false
			b.node.scale = Vector3.ONE
			b.node.collision_layer = Kit.LAYER_WALL
		_clear_fx(b)
		Sfx.play("reload")


## Verkopen geeft de helft van wat erin zit terug als bouwtegoed.
func sell_value(b: Dictionary) -> int:
	var spent: int = 0 if b.get("gratis", false) else int(DEFS[b.kind].cost)
	if b.kind == "kazerne":
		for l in range(2, b.lv + 1):
			spent += LEVELS[l].cost
	return roundi(spent * (0.25 if b.down else 0.5)) + b.queue * TRAIN_COST


func sell(b: Dictionary) -> void:
	Game.build_credit += sell_value(b)
	remove(b)
	Sfx.play("buy")


func turn(b: Dictionary) -> bool:
	var ny: float = fposmod(b.yaw + PI / 2.0, TAU)
	if not can_place(b.kind, b.at, ny, b):
		return false
	move_to(b, b.at, ny)
	return true


# ---------------------------------------------------------------- kazerne

func door_of(b: Dictionary) -> Vector3:
	return b.at + Vector3(sin(b.yaw), 0, cos(b.yaw)) * DOOR


func soldiers_alive() -> int:
	var n := 0
	for a in Game.allies:
		if is_instance_valid(a):
			n += 1
	return n


func queued() -> int:
	var n := 0
	for b in Game.buildings:
		n += b.queue
	return n


func room(b: Dictionary) -> int:
	return LEVELS[b.lv].max - soldiers_alive() - queued()


func recruit(b: Dictionary) -> void:
	if b.down or under_construction(b) or room(b) <= 0 or b.queue >= RIJ_MAX or not Game.pay_points(TRAIN_COST):
		return
	if b.queue == 0:
		b.train_t = train_time(b)
	b.queue += 1
	Game.changed.emit()


## MCV-start: de levende wachten van deze kazerne (Wachten): soldaten die zelf patrouilleren en niet bij je team horen.
func wachten_of(b: Dictionary) -> Array:
	var out: Array = []
	for w in b.get("wachten", []):
		if is_instance_valid(w):
			out.append(w)
	b["wachten"] = out
	return out


func can_buy_wacht(b: Dictionary) -> bool:
	return b.kind == "kazerne" and not b.down and not under_construction(b) and wachten_of(b).size() < Wachten.MAX_PER_KAZERNE and Game.points >= Wachten.COST


## Koopt een wacht (250): hij komt uit de deur van de kazerne en begint zijn ronde. Geeft de soldaat of null.
func buy_wacht(b: Dictionary) -> Variant:
	if not can_buy_wacht(b) or not Game.pay_points(Wachten.COST):
		return null
	var used := {}
	for w in wachten_of(b):
		used[w.wacht_slot] = true
	var slot := 0
	while used.has(slot):
		slot += 1
	var lv: Dictionary = LEVELS[b.lv]
	var a := Ally.new()
	a.guard = true
	a.wacht_slot = slot
	add_child(a)
	a.global_position = door_of(b)
	a.face = b.yaw
	a.setup(lv.hp, lv.dmg, 10 + slot)
	a.add_to_group("wacht")
	b["wachten"].append(a)
	Sfx.play("reload")
	Game.banner.emit("NIEUWE WACHT", "Hij loopt zelf langs de muur", 1.2)
	radio.say("eenheid_klaar")
	Game.changed.emit()
	return a


## Haal de laatste soldaat uit de rij en geef de punten terug.
func cancel_recruit(b: Dictionary) -> void:
	if b.queue <= 0:
		return
	b.queue -= 1
	Game.points += TRAIN_COST
	if b.queue == 0:
		b.train_t = 0.0
	Sfx.play("ping", 0.5)
	Game.changed.emit()


## Verzamelpunt: nieuwe soldaten lopen erheen als de stand op "vlag" staat.
func set_rally(b: Dictionary, at: Vector3) -> void:
	b.rally = Vector3(at.x, 0.0, at.z)
	b.has_rally = true
	b.rally_mode = "vlag"
	# soldaten die al klaar waren lopen ook naar het nieuwe verzamelpunt
	for a in Game.allies:
		if is_instance_valid(a):
			a.set_command("defend", b.rally)
	if b.flag == null or not is_instance_valid(b.flag):
		b.flag = _make_flag()
		add_child(b.flag)
	b.flag.position = b.rally
	_flag_visible(b)
	Game.changed.emit()


func toggle_rally_mode(b: Dictionary) -> void:
	b.rally_mode = "vlag" if b.rally_mode == "volgen" else "volgen"
	_flag_visible(b)
	Game.changed.emit()


func _flag_visible(b: Dictionary) -> void:
	if b.flag != null and is_instance_valid(b.flag):
		b.flag.visible = b.has_rally and (b.rally_mode == "vlag" or Game.build_mode)


func _make_flag() -> Node3D:
	var f := RallyFlag.new()
	f.setup(GameSettings.get_value("time") != "day")
	return f


func upgrade(b: Dictionary) -> void:
	if b.down or under_construction(b):
		return
	var nx: Variant = LEVELS[b.lv + 1] if b.lv + 1 < LEVELS.size() else null
	if nx == null or not Game.pay_build(nx.cost):
		return
	b.lv += 1
	for a in Game.allies:
		if is_instance_valid(a):
			a.set_level(nx.hp, nx.dmg)
	Sfx.play("reload")
	Game.changed.emit()


func _spawn(b: Dictionary) -> void:
	var lv: Dictionary = LEVELS[b.lv]
	var a := Ally.new()
	add_child(a)
	a.global_position = door_of(b)
	a.face = b.yaw
	a.setup(lv.hp, lv.dmg, Game.allies.size())
	Game.allies.append(a)
	if b.rally_mode == "vlag" and b.has_rally:
		a.set_command("defend", b.rally)
	Sfx.play("reload")
	Game.banner.emit("NIEUWE REKRUUT", "", 1.0)
	radio.say("eenheid_klaar")
	Game.changed.emit()


func _physics_process(delta: float) -> void:
	if Game.state != "play" and Game.state != "prep":
		return
	for b in Game.buildings:
		var bar: HpBar = b.bar
		if bar == null:
			continue
		if under_construction(b):
			b.build_t = maxf(0.0, float(b.build_t) - delta)
			bar.set_value(1.0 - float(b.build_t) / float(b.build_total), true)
			bar.global_position = b.at + Vector3(0, DEFS[b.kind].size.y + 1.0, 0)
			if b.build_t <= 0.0:
				_site_done(b)
			else:
				_site_scale(b)
			continue
		var hurt: bool = b.hp < b.max_hp
		bar.set_value(b.hp / b.max_hp, (hurt or Game.build_mode) and not b.down)
		bar.global_position = b.at + Vector3(0, DEFS[b.kind].size.y + 1.0, 0)
		if b.kind == "kazerne" and b.rij != null:
			var prog: float = 1.0 - clampf(float(b.train_t) / train_time(b), 0.0, 1.0) if b.queue > 0 else 0.0
			b.rij.set_value(b.queue, prog)
			b.rij.global_position = b.at + Vector3(0, DEFS[b.kind].size.y + 1.55, 0)
		if b.kind == "garage" and b.rij != null:
			b.rij.set_value(b.order.size(), -1.0)
			b.rij.global_position = b.at + Vector3(0, DEFS[b.kind].size.y + 1.55, 0)
		_flag_visible(b)
	for b in Game.buildings:
		if b.down or under_construction(b):
			continue  # een wrak of bouwplaats doet niets
		if b.kind == "garage":
			_garage_step(b, delta)
		elif b.kind == "airfield":
			AirfieldHQ23.step(b, delta)
		elif b.kind == "helipad":
			_pad_step(b, delta)
	# tijdens het bouwen staat de opleiding stil (updateStructures in 16d-base.js)
	if Game.build_mode:
		return
	for b in Game.buildings:
		if b.kind == "kazerne" and not b.down and not under_construction(b) and b.queue > 0:
			b.train_t -= delta
			if b.train_t <= 0.0:
				b.queue -= 1
				_spawn(b)
				b.train_t = train_time(b)


# ---------------------------------------------------------------- garage

## Gebouw van assets/garage.glb (Meshy-motorpool, bron/garage_meshy). Muren, luifels en spullen zijn losse kasten, zodat
## de poort open blijft; de poort is een kast die uitgaat als hij open is. Maten in meters, voorkant = +Z.
const GARAGE_KASTEN := [
	[Vector3(-3.04, 2.5, -0.50), Vector3(0.26, 5.0, 4.62)],   # linkerwand hal
	[Vector3(2.60, 2.5, -0.50), Vector3(0.26, 5.0, 4.62)],    # rechterwand hal
	[Vector3(-0.22, 2.5, -2.76), Vector3(5.90, 5.0, 0.26)],   # achterwand hal
	[Vector3(-2.53, 2.5, 1.81), Vector3(1.28, 5.0, 0.40)],    # voorgevel links van de poort
	[Vector3(2.27, 2.5, 1.81), Vector3(0.92, 5.0, 0.40)],     # voorgevel rechts van de poort
	[Vector3(-0.04, 4.7, 1.81), Vector3(3.78, 0.6, 0.40)],    # latei boven de poort
	[Vector3(-3.56, 1.0, -0.59), Vector3(0.79, 2.0, 3.69)],   # linkerluifel met kisten en banden
	[Vector3(3.17, 1.0, -0.59), Vector3(0.88, 2.0, 3.69)],    # rechterluifel met werkbank en vaten
	[Vector3(-0.22, 1.0, -3.44), Vector3(6.60, 2.0, 1.14)],   # achterluifel met kisten
	[Vector3(-2.90, 0.5, 2.56), Vector3(1.58, 1.0, 1.10)],    # zandzakken, vaten en jerrycans links voor
	[Vector3(2.51, 0.65, 2.51), Vector3(1.32, 1.3, 1.00)],    # kabelhaspel en kisten rechts voor
]


func _garage_node(body: StaticBody3D) -> void:
	var model: Node = (load("res://assets/garage.glb") as PackedScene).instantiate()
	body.add_child(model)
	body.set_meta("model", model)
	for pt in GARAGE_KASTEN:
		body.add_child(_box_shape(pt[0], pt[1]))
	var door := _box_shape(Vector3(DOOR_U, 2.2, 1.81), Vector3(3.7, 4.4, 0.35))
	door.name = "Poortkast"
	body.add_child(door)
	# dichtbij de volle romp, ver weg (tactische camera) de lichte LOD1 met dezelfde texturen
	var romp := model.find_child("Romp", true, false) as GeometryInstance3D
	var lod := model.find_child("Romp_LOD1", true, false) as GeometryInstance3D
	if romp and lod:
		romp.visibility_range_end = GARAGE_LOD
		lod.visibility_range_begin = GARAGE_LOD
	var ap: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	# Open en Dicht bewegen alleen de deuren (DeurL, DeurR)
	for clip in ["Open", "Dicht"]:
		var a := ap.get_animation(clip)
		for i in range(a.get_track_count() - 1, -1, -1):
			if not String(a.track_get_path(i)).get_slice(":", 0).get_file().begins_with("Deur"):
				a.remove_track(i)
	# lampen boven de poort en binnen: alleen bij Avond/Nacht, met een kort bereik (glTF-lampen hebben geen bereik)
	var night := GameSettings.get_value("time") != "day"
	for n in ["DeurLampL", "DeurLampM", "DeurLampR", "BinnenLamp"]:
		var l := model.find_child(n, true, false) as Light3D
		if l == null:
			continue
		l.visible = night
		l.shadow_enabled = false
		if l is SpotLight3D:
			(l as SpotLight3D).spot_range = 9.0
		elif l is OmniLight3D:
			(l as OmniLight3D).omni_range = 6.0


func _box_shape(pos: Vector3, size: Vector3) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = pos
	return cs


func _garage_init(b: Dictionary) -> void:
	var model: Node = b.node.get_meta("model")
	b.anim = model.find_child("AnimationPlayer", true, false)
	# de oude garage had een zwaailicht en een takel; de motorpool niet (dan blijven deze null)
	b.zwaai = model.find_child("Zwaai", true, false)
	b.light = model.find_child("ZwaaiLicht", true, false)
	b.arm = model.find_child("Arm", true, false)
	b.haak = model.find_child("Haak", true, false)
	b.door_shape = b.node.get_node("Poortkast")


func vehicle_cost(kind: String) -> int:
	return VEHICLES[kind].cost


func can_buy_vehicle(b: Dictionary, kind: String) -> bool:
	return b.kind == "garage" and not under_construction(b) and b.order.size() < GARAGE_RIJ_MAX and Game.points >= VEHICLES[kind].cost


## Koop een jeep of tank; hij rijdt uit zodra je het bouwscherm verlaat.
func buy_vehicle(b: Dictionary, kind: String) -> void:
	if not can_buy_vehicle(b, kind) or not Game.pay_points(VEHICLES[kind].cost):
		return
	b.has[kind] += 1
	b.order.append(kind)
	Sfx.play("buy")
	Game.changed.emit()


## Haal een gekochte wagen uit de rij zolang hij nog niet is uitgereden en geef de punten terug.
func cancel_order(b: Dictionary, kind: String) -> void:
	if b.kind != "garage" or not b.order.has(kind):
		return
	b.order.erase(kind)
	b.has[kind] = maxi(0, int(b.has[kind]) - 1)
	Game.points += VEHICLES[kind].cost
	Sfx.play("ping", 0.5)
	Game.changed.emit()


func _front(b: Dictionary) -> Vector3:
	return Vector3(sin(b.yaw), 0, cos(b.yaw))


## Hoeveel vrije meters er vóór de deur zijn (zonder bunker, muren of gebouwen).
func _free_run(b: Dictionary) -> float:
	var shape := SphereShape3D.new()
	shape.radius = 1.0
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.collision_mask = Kit.LAYER_WALL | Kit.LAYER_BUNKER
	var ex: Array[RID] = [b.node.get_rid()]
	q.exclude = ex
	var run := 0.0
	for i in range(1, 25):
		var d := i * 0.5
		var p := _pt(b.at, b.yaw, DOOR_U, FRONT + d)
		if not Mcv.in_play_area(p, 4.0):
			break
		q.transform = Transform3D(Basis.IDENTITY, p + Vector3(0, 1.0, 0))
		if not get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty():
			break
		run = d
	return run


func _spawn_vehicle(b: Dictionary, kind: String) -> void:
	var v: Node3D = (load(VEHICLES[kind].scene) as PackedScene).instantiate()
	add_child(v)
	# De hal is maar 4,7 m diep: de lange truck (8,5 m) staat met zijn neus 1,2 m buiten de open poort, de jeep en tank staan in de hal
	var inside := _pt(b.at, b.yaw, DOOR_U, FRONT + 1.2 - 4.25 if kind == "truck" else -0.4)
	v.global_transform = Transform3D(Basis(Vector3.UP, b.yaw + PI), Vector3(inside.x, 0.0, inside.z))
	var run := _free_run(b)
	var goals: Array = []
	# elke wagen krijgt een eigen parkeerplek naast de garage, zodat ze niet in elkaar staan
	var fleet: Array = b.fleet
	for i in range(fleet.size() - 1, -1, -1):
		if not is_instance_valid(fleet[i]):
			fleet.remove_at(i)
	var slot := fleet.size()
	fleet.append(v)
	radio.say("eenheid_klaar")
	# eerst kaarsrecht de poort uit tot de hele wagen buiten staat, dan pas opzij naar de parkeerplek
	if kind == "truck":
		# lange wagen: kaarsrecht naar buiten tot hij helemaal uit de poort is en dan stilstaan
		goals.append(_pt(b.at, b.yaw, DOOR_U, FRONT + clampf(run * 0.9, 5.0, 9.5)))
		# tot de achterkant (4,4 m achter het midden) voorbij de poort is, rijdt hij strak recht
		v.exit_lock = {"yaw": b.yaw + PI, "from": _pt(b.at, b.yaw, DOOR_U, 0.0), "dir": _front(b), "dist": FRONT + 4.6 + 0.8}
	else:
		var out := minf(6.0 if kind == "jeep" else 7.5, run * (0.7 if kind == "jeep" else 0.8))
		goals.append(_pt(b.at, b.yaw, DOOR_U, FRONT + out))
		goals.append(_park_spot(b, slot, run))
	v.goals = goals
	b.veh = v
	Sfx.play("thud", 0.8, v.global_position)


## Parkeerplek n naast de garage: om en om links en rechts van de poort, daarna een rij verder naar achteren.
func _park_spot(b: Dictionary, slot: int, run: float) -> Vector3:
	var side := -1.0 if slot % 2 == 0 else 1.0
	var col := slot / 2 % 3
	var row := slot / 6
	var u := DOOR_U + side * (3.3 + col * 3.1)
	var v := FRONT + minf(8.0, run * 0.9) + row * 4.2
	return _pt(b.at, b.yaw, u, v)


const DOOR_T := 1.0  # seconden dat de poort open of dicht gaat (de clip duurt 2 s en wordt sneller afgespeeld)


func _garage_step(b: Dictionary, delta: float) -> void:
	match b.phase:
		"idle":
			# in het bouwscherm wacht de rij: je kunt een wagen nog annuleren, hij rijdt uit als je terug het veld in gaat
			if not b.order.is_empty() and not Game.build_mode:
				b.phase = "opening"
				b.t = DOOR_T
				b.anim.speed_scale = 2.0 / DOOR_T
				b.anim.play("Open")
				if b.light:
					b.light.visible = true
				Sfx.play("thud", 0.5, b.node.global_position)
		"opening":
			b.t -= delta
			if b.t <= 0.0:
				b.door_shape.disabled = true
				_spawn_vehicle(b, b.order.pop_front())
				b.phase = "rolling"
		"rolling":
			# zodra de wagen buiten is en opzij draait, volgt de volgende of gaat de poort dicht
			var v: Node3D = b.veh
			# de truck rijdt maar één stuk recht vooruit: de poort gaat pas dicht als hij stilstaat
			var left := 0 if is_instance_valid(v) and v.has_method("ride_step") else 1
			if not is_instance_valid(v) or v.goals.size() <= left:
				if not b.order.is_empty():
					_spawn_vehicle(b, b.order.pop_front())
				else:
					b.phase = "closing"
					b.t = DOOR_T
					b.anim.play("Dicht")
		"closing":
			b.t -= delta
			if b.t <= 0.0:
				b.door_shape.disabled = false
				if b.light:
					b.light.visible = false
				b.phase = "idle"
	# zwaailicht draait zolang de poort in beweging is; de takel wiegt altijd een beetje
	var moving: bool = b.phase == "opening" or b.phase == "closing" or b.phase == "rolling"
	if moving and b.zwaai:
		b.spin += delta * 6.0
		b.zwaai.rotation.y = b.spin
	if b.arm == null or b.haak == null:
		return
	b.sway += delta
	b.arm.rotation.y = deg_to_rad(14.0) * sin(b.sway * TAU / 8.0)
	b.haak.rotation.x = deg_to_rad(4.0) * sin(b.sway * TAU / 2.0 + 1.0)
	b.haak.rotation.z = deg_to_rad(3.0) * sin(b.sway * TAU / 3.0)


# ---------------------------------------------------------------- helikopterplatform

## Platform uit assets/helipad.glb: betonplaat met een schacht van 9 x 9 m, twee luiken en een lift. De schacht
## is een kast (niemand loopt erin); Open en Dicht bewegen luiken, zuigers en lift, de zwaailampen doet de code.
func _pad_node(body: StaticBody3D) -> void:
	var model: Node = (load("res://assets/helipad.glb") as PackedScene).instantiate()
	model.position.y = 0.03  # net boven de grond, anders knippert de plaat
	body.add_child(model)
	body.set_meta("model", model)
	body.add_child(_box_shape(Vector3(0, 1.0, 0), Vector3(9.0, 2.0, 9.0)))
	var ap: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	for clip in ["Open", "Dicht"]:
		var a := ap.get_animation(clip)
		for i in range(a.get_track_count() - 1, -1, -1):
			if String(a.track_get_path(i)).contains("Zwaai"):
				a.remove_track(i)
	var night := GameSettings.get_value("time") != "day"
	for n in ["SchachtLicht0", "SchachtLicht1", "MastSchijnwerper"]:
		var l := model.find_child(n, true, false)
		if l:
			l.visible = night
	for n in ["ZwaaiALicht", "ZwaaiBLicht"]:
		var l := model.find_child(n, true, false)
		if l:
			l.visible = false


func _pad_init(b: Dictionary) -> void:
	var model: Node = b.node.get_meta("model")
	b.anim = model.find_child("AnimationPlayer", true, false)
	b.lift = model.find_child("Lift", true, false)
	b.zwa = model.find_child("ZwaaiA", true, false)
	b.zwb = model.find_child("ZwaaiB", true, false)
	b.lamps = [model.find_child("ZwaaiALicht", true, false), model.find_child("ZwaaiBLicht", true, false)]


## De schacht is echt uitgegraven: de grondschil krijgt een gat van 9 x 9 m op de plek van het platform.
func _cut_pad() -> void:
	var g := get_tree().get_first_node_in_group("ground")
	if g == null or not g.has_meta("mat"):
		return
	var mat: ShaderMaterial = g.get_meta("mat")
	mat.set_shader_parameter("pad_half", 0.0)
	for b in Game.buildings:
		if b.kind == "helipad":
			mat.set_shader_parameter("pad", Vector4(b.at.x, b.at.z, cos(b.yaw), sin(b.yaw)))
			mat.set_shader_parameter("pad_half", 4.5)


func can_buy_aircraft(b: Dictionary, kind: String) -> bool:
	return not under_construction(b) and AirfieldHQ23.can_buy(self, b, kind)

func buy_aircraft(b: Dictionary, kind: String) -> bool:
	return AirfieldHQ23.buy(self, b, kind)

func can_buy_heli(b: Dictionary) -> bool:
	return b.kind == "helipad" and not under_construction(b) and not b.has_heli and Game.points >= HELI_COST


## Koop de Apache: de luiken gaan open en de lift tilt hem omhoog.
func buy_heli(b: Dictionary) -> void:
	if not can_buy_heli(b) or not Game.pay_points(HELI_COST):
		return
	b.has_heli = true
	var h := Apache.new()
	h.setup(b)
	add_child(h)
	b.heli = h
	b.want = true
	Sfx.play("buy")
	Game.changed.emit()


## Zet de helikopter weer klaar als hij beneden staat.
func call_heli(b: Dictionary) -> void:
	if b.kind == "helipad" and b.has_heli and b.hs != "open":
		b.want = true
		Sfx.play("click")
		Game.changed.emit()


func _pad_play(b: Dictionary, clip: String, state: String) -> void:
	b.hs = state
	b.t = PAD_T
	b.anim.speed_scale = 1.0
	b.anim.play(clip)
	Sfx.play("gate", 0.9, b.node.global_position)


func _pad_step(b: Dictionary, delta: float) -> void:
	var heli = b.heli
	var player = Game.player
	match b.hs:
		"closed":
			if b.want and b.has_heli:
				b.want = false
				_pad_play(b, "Open", "opening")
		"opening":
			b.t -= delta
			if b.t <= 0.0:
				b.hs = "open"
		"open":
			if heli != null and is_instance_valid(heli):
				var d: float = Vector2(b.at.x - player.global_position.x, b.at.z - player.global_position.z).length() if player else 0.0
				var away: bool = heli.mode == Apache.Mode.LIFT and not heli.driven and d > 14.0
				var gone: bool = (heli.mode == Apache.Mode.FLY or heli.mode == Apache.Mode.GROUND) and Vector2(heli.global_position.x - b.at.x, heli.global_position.z - b.at.z).length() > 16.0
				if (away or gone) and not b.want:
					_pad_play(b, "Dicht", "closing")
		"closing":
			b.t -= delta
			if b.t <= 0.0:
				b.hs = "closed"
	var moving: bool = b.hs == "opening" or b.hs == "closing"
	if moving:
		b.spin += delta * 5.0
		b.zwa.rotation.y = b.spin
		b.zwb.rotation.y = -b.spin + 1.0
	for l in b.lamps:
		if l:
			l.visible = moving
