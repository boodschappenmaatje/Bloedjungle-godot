extends SceneTree
## Vijandelijke basis van blokken (Generals-plan D2, stap 5a-1, scripts/vijand_basis.gd) en de grotere kaart (Data.WORLD_Z_N, level.gd).
## Controleert: de basis ligt op de grondplaat en binnen de speelgrens, de muur en het hoofdkwartier zijn massief, de poort is open,
## de gebouwen overlappen elkaar niet, de middenstraat is vrij, en de bestaande wereld (jouw basis, foliage-grens) is niet verschoven.
## godot --headless --path . --script tests/vijand_basis_test.gd --fixed-fps 60

var main: Node
var frames := 0
var fails := 0
var D = load("res://scripts/data.gd")
var VB = load("res://scripts/vijand_basis.gd")


func _initialize() -> void:
	root.size = Vector2i(932, 430)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FOUT ") + name)
	if not ok:
		fails += 1


func _process(_d: float) -> bool:
	frames += 1
	var g = root.get_node("Game")
	if frames == 2:
		main.get_node("Hud/Sticks").set_process(false)
	if frames == 4:
		main.begin()
		for m in get_nodes_in_group("menus"):
			m._show("")
	if frames > 4 and g.state == "prep":
		g.prep_t = 1e9
	if frames == 40:
		_constants()
		_structure()
		_physics()
		_layout()
		print("klaar, fouten: ", fails)
		quit(1 if fails > 0 else 0)
	return false


func _constants() -> void:
	var p: Vector3 = D.VIJAND_POS
	var h: Vector2 = D.VIJAND_HALF
	_check("kaart groeit: WORLD_Z_N 285", is_equal_approx(D.WORLD_Z_N, 285.0))
	_check("speelgrens laat de basis toe (noordmuur + 8 m marge binnen WORLD_Z_N)", p.z - h.y - 8.0 >= -D.WORLD_Z_N)
	_check("grondplaat reikt voorbij de noordmuur (+ 15 m marge)", p.z - h.y - 15.0 >= D.GROUND_Z_MIN)
	_check("basis blijft binnen de breedte van de kaart", p.x - h.x >= -D.WORLD_X and p.x + h.x <= D.WORLD_X)
	_check("foliage-grens ongewijzigd (200)", is_equal_approx(D.FOLIAGE_Z_N, 200.0))
	_check("basis ligt voorbij de foliage-strook en de stad", p.z + h.y < -D.FOLIAGE_Z_N - 10.0)
	_check("speler kan tot in de vijandbasis lopen (clamp_world laat z -250 toe)", is_equal_approx(D.clamp_world(Vector2(p.x, -250.0)).y, -250.0))
	_check("clamp_world houdt z -300 buiten de kaart", D.clamp_world(Vector2(0.0, -300.0)).y > -300.0)
	_check("contains: midden van de vijandbasis erin", VB.contains(p))
	_check("contains: jouw basis erbuiten", not VB.contains(Vector3.ZERO))
	_check("poort ligt aan de zuidkant (naar jouw basis toe)", VB.gate_outside().z > p.z + h.y)


func _structure() -> void:
	var lvl: Node = main.get_node("Level")
	var base: Node = lvl.get_node_or_null("VijandBasis")
	_check("knoop VijandBasis bestaat onder Level", base != null)
	if base == null:
		return
	_check("VijandBasis staat op VIJAND_POS", (base as Node3D).position.is_equal_approx(D.VIJAND_POS))
	_check("groep vijand_basis", base.is_in_group("vijand_basis"))
	_check("Muur en Poort aanwezig", base.get_node_or_null("Muur") != null and base.get_node_or_null("Poort") != null)
	_check("precies 1 hoofdkwartier", get_nodes_in_group("vijand_hk").size() == 1)
	_check("precies 4 torens", get_nodes_in_group("vijand_toren").size() == 4)
	_check("4 gebouwen + generator (vijand_gebouw)", get_nodes_in_group("vijand_gebouw").size() == 4)
	for naam in ["Kazerne", "Garage", "Depot", "Generator", "Hoofdkwartier"]:
		_check("onderdeel " + naam, base.find_child(naam, true, false) != null)
	_check("hk_pos ligt in de basis", VB.contains(VB.hk_pos()))
	# jouw eigen basis en bunker staan nog waar ze stonden
	var bunker := lvl.find_child("Bunker", true, false) as Node3D
	_check("bunker van de speler nog op het nulpunt", bunker != null and bunker.global_position.length() < 0.01)
	# de grondplaat is naar het noorden verlengd
	var ground := get_first_node_in_group("ground") as StaticBody3D
	var ok_ground := false
	if ground != null:
		for c in ground.get_children():
			if c is CollisionShape3D:
				var s := (c as CollisionShape3D).shape as BoxShape3D
				var cz := (c as CollisionShape3D).position.z
				var zmin := cz - s.size.z * 0.5
				var zmax := cz + s.size.z * 0.5
				ok_ground = absf(zmin - D.GROUND_Z_MIN) < 0.01 and absf(zmax - 220.0) < 0.01
	_check("grondplaat loopt van z -300 tot 220", ok_ground)


func _ray(from: Vector3, to: Vector3, mask: int) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, mask)
	return root.get_world_3d().direct_space_state.intersect_ray(q)


func _physics() -> void:
	var p: Vector3 = D.VIJAND_POS
	var h: Vector2 = D.VIJAND_HALF
	var wall_mask := 2   # Kit.LAYER_WALL
	var ground_mask := 1
	# grond onder de vijandbasis en aan de noordrand
	_check("grond onder het hoofdkwartier", not _ray(Vector3(p.x, 5, p.z - 13), Vector3(p.x, -2, p.z - 13), ground_mask).is_empty())
	_check("grond tot de noordrand (z -295)", not _ray(Vector3(0, 5, -295), Vector3(0, -2, -295), ground_mask).is_empty())
	_check("geen grond voorbij de noordrand (z -305)", _ray(Vector3(0, 5, -305), Vector3(0, -2, -305), ground_mask).is_empty())
	# massieve muren: noord, west en oost
	_check("noordmuur is massief", not _ray(Vector3(p.x + 10, 0.8, p.z - h.y - 3), Vector3(p.x + 10, 0.8, p.z - h.y + 3), wall_mask).is_empty())
	_check("westmuur is massief", not _ray(Vector3(p.x - h.x - 3, 0.8, p.z), Vector3(p.x - h.x + 3, 0.8, p.z), wall_mask).is_empty())
	_check("oostmuur is massief", not _ray(Vector3(p.x + h.x + 3, 0.8, p.z), Vector3(p.x + h.x - 3, 0.8, p.z), wall_mask).is_empty())
	# zuidmuur is massief naast de poort, maar de poort is open
	_check("zuidmuur massief naast de poort", not _ray(Vector3(p.x + 12, 0.8, p.z + h.y + 3), Vector3(p.x + 12, 0.8, p.z + h.y - 3), wall_mask).is_empty())
	_check("poortopening is vrij (links van het midden)", _ray(Vector3(p.x - 2.0, 0.8, p.z + h.y + 3), Vector3(p.x - 2.0, 0.8, p.z + h.y - 3), wall_mask).is_empty())
	_check("poortopening is vrij (rechts van het midden)", _ray(Vector3(p.x + 2.0, 0.8, p.z + h.y + 3), Vector3(p.x + 2.0, 0.8, p.z + h.y - 3), wall_mask).is_empty())
	# middenstraat: van net buiten de poort tot vlak voor het hoofdkwartier vrij; het hoofdkwartier zelf is massief
	var hk: Vector3 = VB.hk_pos()
	_check("middenstraat vrij tot voor het hoofdkwartier", _ray(Vector3(p.x, 0.8, p.z + h.y + 5), Vector3(p.x, 0.8, hk.z + 6.0), wall_mask).is_empty())
	var hit := _ray(Vector3(p.x, 0.8, p.z + h.y + 5), Vector3(p.x, 0.8, hk.z - 6.0), wall_mask)
	_check("hoofdkwartier is massief (voorkant ca. 4,5 m voor het midden)", not hit.is_empty() and absf((hit.position as Vector3).z - (hk.z + 4.5)) < 0.3)
	# gebouwen en torens zijn massief
	for naam in ["Kazerne", "Garage", "Depot", "Generator"]:
		var n := main.get_node("Level/VijandBasis").find_child(naam, true, false) as Node3D
		var c := n.global_position + Vector3(0, 1.0, 0)
		_check(naam + " is massief", not _ray(c + Vector3(0, 0, 8), c + Vector3(0, 0, -8), wall_mask).is_empty())
	for t in get_nodes_in_group("vijand_toren"):
		var c := (t as Node3D).global_position + Vector3(0, 1.5, 0)
		_check("toren is massief", not _ray(c + Vector3(4, 0, 0), c + Vector3(-4, 0, 0), wall_mask).is_empty())


## Grondvlakken van de blokken: niets overlapt, en de middenstraat (x -4..4) blijft leeg.
func _layout() -> void:
	var boxes: Array = []
	for grp in ["vijand_hk", "vijand_gebouw"]:
		for n in get_nodes_in_group(grp):
			var body: StaticBody3D = null
			for c in n.get_children():
				if c is StaticBody3D:
					body = c
					break
			if body == null:
				_check("%s heeft een botsblok" % n.name, false)
				continue
			var cs := body.get_child(0) as CollisionShape3D
			var sz := (cs.shape as BoxShape3D).size
			var c3 := (n as Node3D).global_position
			boxes.append({"n": n.name, "r": Rect2(c3.x - sz.x * 0.5, c3.z - sz.z * 0.5, sz.x, sz.z)})
	_check("5 botsblokken gevonden (HK, kazerne, garage, depot, generator)", boxes.size() == 5)
	var overlap := ""
	for i in boxes.size():
		for j in range(i + 1, boxes.size()):
			if (boxes[i].r as Rect2).grow(1.0).intersects(boxes[j].r):
				overlap += "%s/%s " % [boxes[i].n, boxes[j].n]
	_check("gebouwen overlappen elkaar niet (marge 1 m) " + overlap, overlap == "")
	var lane := Rect2(D.VIJAND_POS.x - 4.0, D.VIJAND_POS.z - D.VIJAND_HALF.y, 8.0, D.VIJAND_HALF.y * 2.0)
	var blocked := ""
	for b in boxes:
		if b.n != "Hoofdkwartier" and (b.r as Rect2).intersects(lane):
			blocked += str(b.n) + " "
	_check("middenstraat vrij van gebouwen (behalve het hoofdkwartier aan het eind) " + blocked, blocked == "")
	var inside := true
	for b in boxes:
		inside = inside and VB.contains(Vector3((b.r as Rect2).get_center().x, 0, (b.r as Rect2).get_center().y), -3.0)
	_check("alle gebouwen staan binnen de muur (marge 3 m)", inside)
