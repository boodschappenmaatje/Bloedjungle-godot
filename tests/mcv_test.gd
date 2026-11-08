extends SceneTree
## Test van de MCV-start (Generals-plan "Stap MCV", stap 1): bouwwagen rijden, plek kiezen, uitklappen, hoofdkwartier, bomen weg,
## klok van 10 minuten, vijand en terugkomen bij het nieuwe hoofdkwartier.
## godot --headless --path . --script tests/mcv_test.gd --fixed-fps 60

var D: GDScript
var M: GDScript
var F: GDScript
var R: GDScript
var main: Node
var frames := 0
var fails := 0
var mcv: Node
var hq_at := Vector3.ZERO


func _initialize() -> void:
	D = load("res://scripts/data.gd")
	M = load("res://scripts/mcv.gd")
	F = load("res://scripts/foliage.gd")
	R = load("res://scripts/route.gd")
	D.set("mcv_mode", true)   # vóór het laden van de wereld: zonder vast kamp
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FOUT ") + name)
	if not ok:
		fails += 1


func _process(_d: float) -> bool:
	frames += 1
	var g = root.get_node("Game")
	var p = g.player
	if frames == 2:
		main.get_node("Hud/Sticks").set_process(false)
	if frames == 4:
		main.begin()
	if frames == 10:
		mcv = get_first_node("mcv")
		_check("de wagen staat er", mcv != null)
		_check("geen vast kamp: geen bunker", main.find_child("Bunker", true, false) == null)
		_check("geen vaste muur: geen poorten", g.gates.list.is_empty())
		_check("speler zit in de wagen", p.driving and not p.visible)
		_check("de wagen staat niet op een laag die de camera tegenhoudt", (mcv.collision_layer & (2 | 16)) == 0)
		# precies wat de camera doet (camera_rig._avoid_obstacles): een straal van de speler naar achteren/boven, muur + bunker, ook van binnenuit
		var ray := PhysicsRayQueryParameters3D.create(mcv.global_position + Vector3(0, 1, 0), mcv.global_position + Vector3(0, 20, 15.5), 2 | 16)
		ray.hit_from_inside = true
		_check("de camerastraal blijft vrij van de wagen", mcv.get_world_3d().direct_space_state.intersect_ray(ray).is_empty())
		_check("klok staat stil voor het uitklappen", is_equal_approx(g.prep_t, 600.0))
		_check("oud spel: bouwen kan nog niet", not main.get_node("Level").get_parent().get_node("Level").is_queued_for_deletion())
		var b: Variant = g.builds.placement_status("kazerne", Vector3(0, 0, 20), 0.0)
		_check("bouwen kan pas na het uitklappen", not b.valid)
		# rijden: stick naar het zuiden (+z = naar de camera toe) draait en rijdt de wagen
		var z0: float = mcv.global_position.z
		g.move = Vector2(0, 1)
	if frames == 150:
		g.move = Vector2.ZERO
		_check("de wagen rijdt", absf(mcv.global_position.z - 6.0) > 3.0 or absf(mcv.global_position.x) > 3.0)
		_check("speler volgt de wagen", p.global_position.distance_to(Vector3(mcv.global_position.x, 0, mcv.global_position.z)) < 0.01)
		# naar een plek bij de rivier: verboden
		mcv.global_position = Vector3(0, 0, D.river_z(0.0) + 5.0)
	if frames == 154:
		var st: Dictionary = M.site_status(mcv.global_position, mcv.rotation.y)
		_check("bij het water mag niet", not st.valid)
		var st2: Dictionary = M.site_status(Vector3(0, 0, D.river_z(0.0) - 5.0), 0.0)
		_check("aan de overkant van de rivier mag niet", not st2.valid)
		_check("kaartrand mag niet", not M.site_status(Vector3(D.WORLD_X - 5.0, 0, 100.0), 0.0).valid)
		# de plek met de meeste begroeiing (boven de kale startplek): daar moet het uitklappen echt iets weghalen
		var best := Vector3(70.0, 0.0, 60.0)
		var best_n := -1
		var scan_ex: Array[RID] = [mcv.get_rid()]
		for gx in range(-150, 151, 10):
			for gz in range(40, 161, 10):
				var cand := Vector3(gx, 0.0, gz)
				var cs: Dictionary = M.site_status(cand, 0.4, mcv.get_world_3d(), scan_ex)
				if cs.valid and int(cs.vegetation) > best_n:
					best_n = int(cs.vegetation)
					best = cand
		print("drukste plek: ", best, " met ", best_n, " planten")
		_check("er staat begroeiing op de gekozen plek", best_n > 20)
		mcv.global_position = best
		mcv.rotation.y = 0.4
	if frames == 158:
		var ex: Array[RID] = [mcv.get_rid()]
		var st3: Dictionary = M.site_status(mcv.global_position, mcv.rotation.y, mcv.get_world_3d(), ex)
		_check("open plek mag (%s)" % str(st3.reason), st3.valid)
		var veg_before: int = F.count_clearable_in_regions(M.footprint_regions(), mcv.global_position, mcv.rotation.y)
		print("planten in de voetafdruk: ", veg_before)
		hq_at = mcv.global_position
		mcv.deploy_now()
	if frames == 164:
		_check("hoofdkwartier staat", g.mcv_deployed and g.base_pos.distance_to(hq_at) < 0.01)
		_check("de wagen is weg", get_first_node("mcv") == null)
		var bunker := main.find_child("Bunker", true, false) as StaticBody3D
		_check("bunker/hoofdkwartier op de wagenplek", bunker != null and bunker.global_position.distance_to(hq_at) < 0.01)
		_check("planten in de voetafdruk zijn weg", F.count_clearable_in_regions(M.footprint_regions(), hq_at, g.base_yaw) == 0)
		_check("klok is 10 minuten", g.prep_t > 598.0 and g.prep_t <= 600.0)
		_check("speler staat uit de wagen", p.visible and not p.driving)
		_check("terugkomplek is bij het hoofdkwartier", p.home.distance_to(g.base_home()) < 0.01 and p.home.distance_to(hq_at) < 6.0)
		var b2: Variant = g.builds.placement_status("kazerne", g.base_point(Vector3(14, 0, 4)), 0.0)
		_check("bouwen kan nu, ook buiten het oude kamp (%s)" % str(b2.reason), b2.valid)
		var b3: Variant = g.builds.placement_status("kazerne", Vector3(0, 0, D.river_z(0.0) - 8.0), 0.0)
		_check("bouwen voorbij de rivier kan niet", not b3.valid)
		# de klok loopt nu
		g.prep_t = 600.0
	if frames == 224:
		_check("klok loopt na het uitklappen", g.prep_t < 599.5)
		# sneuvelen: terug bij het hoofdkwartier na 8 s
		g.state = "play"
		p.global_position = Vector3(5, 0, 80)
		p.hit(99999.0, Vector3.FORWARD, false)
		_check("speler is dood", p.dead)
		p.respawn_t = 0.05
	if frames == 232:
		_check("terug bij het nieuwe hoofdkwartier", not p.dead and p.global_position.distance_to(g.base_home()) < 0.01)
		# een vijand loopt naar het hoofdkwartier en niet naar de oorsprong
		var e: Node = load("res://scenes/enemy.tscn").instantiate()
		e.setup("knife", 1)
		main.add_child(e)
		e.global_position = hq_at + Vector3(0, 0, 25)
		g.player.global_position = hq_at + Vector3(0, 0, -60)   # ver van de speler: de vijand mikt op het hoofdkwartier
		_check("vijand meet afstand tot het gedraaide hoofdkwartier", absf(e._bunker_dist() - (25.0 * cos(g.base_yaw) - D.BUNKER_HALF)) < 0.3)
		var wp: Vector3 = R.waypoint(e.global_position, g.base_pos)
		_check("route naar het hoofdkwartier is rechtdoor (geen vierkante muur)", wp.distance_to(g.base_pos) < 0.01)
		# een groep valt het HK aan: het HK verliest sterkte en bij 0 is het spel voorbij
		var hp0: float = g.base_hp
		g.damage_base(100.0)
		_check("schade aan het hoofdkwartier", g.base_hp < hp0)
		g.damage_base(99999.0)
		_check("hoofdkwartier vernield = spel voorbij", g.state == "over")
		print("klaar, fouten: ", fails)
		quit(1 if fails > 0 else 0)
	return false


func get_first_node(group: String) -> Node:
	var l := get_nodes_in_group(group)
	return null if l.is_empty() else l[0]
