extends SceneTree
## Test van MCV stap 3c: vier gratis wachttorens (daarna 100), alleen bij het hoofdkwartier, klimbaar. godot --headless --path . --script tests/mcv_toren_test.gd --fixed-fps 60

var D: GDScript
var M: GDScript
var main: Node
var frames := 0
var fails := 0
var mcv: Node
var towers: Array = []


func _initialize() -> void:
	D = load("res://scripts/data.gd")
	M = load("res://scripts/mcv.gd")
	D.set("mcv_mode", true)
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
	if frames > 4 and g.state == "prep" and g.mcv_deployed:
		g.prep_t = 1e9
	if frames == 12:
		mcv = get_nodes_in_group("mcv")[0]
		mcv.global_position = Vector3(40.0, 0.0, 40.0)
		mcv.rotation.y = 0.0
		_check("voor het uitklappen kan er geen toren staan", not g.builds.placement_status("wachttoren", Vector3(40, 0, 20), 0.0).valid)
	if frames == 16:
		mcv.deploy_now()
	if frames == 22:
		_check("vier gratis torens na het uitklappen", g.free_towers == 4 and g.builds.cost_of("wachttoren") == 0)
		var far: Dictionary = g.builds.placement_status("wachttoren", Vector3(40, 0, 100), 0.0)
		_check("een toren ver van het hoofdkwartier kan niet (%s)" % str(far.reason), not far.valid and far.reason == "Alleen bij het hoofdkwartier")
		var pts: int = g.points + g.build_credit
		# vier torens rond het hoofdkwartier (40, 40), de hoeken van een kamp
		for pos in [Vector3(24, 0, 24), Vector3(56, 0, 24), Vector3(24, 0, 56), Vector3(56, 0, 56)]:
			var b = g.builds.place("wachttoren", pos, 0.0 if pos.x < 40 else PI, true)
			if b != null:
				towers.append(b)
		_check("vier torens gebouwd", towers.size() == 4)
		_check("ze kostten niets", g.points + g.build_credit == pts and g.free_towers == 0)
		_check("de vijfde kost 100", g.builds.cost_of("wachttoren") == 100)
		var fifth = g.builds.place("wachttoren", Vector3(40, 0, 20), 0.0, true)
		_check("vijfde toren gebouwd voor 100", fifth != null and pts - (g.points + g.build_credit) == 100)
		if fifth != null:
			towers.append(fifth)
		_check("verkoopwaarde: gratis 0, betaald 50", g.builds.sell_value(towers[0]) == 0 and g.builds.sell_value(fifth) == 50)
		_check("de torens staan in de groep 'tower' (klimmen en radar)", get_nodes_in_group("tower").size() == 5)
		_check("een toren in aanbouw heeft steigers", Buildings_under(g, towers[0]))
		for t in towers:
			t.build_t = 0.05
	if frames == 40:
		# klimmen: loop tegen de trap (lokale +x) van de eerste toren aan
		var t0: Node3D = towers[0].node
		var foot: Vector3 = t0.to_global(Vector3(1.8, 0.0, 0.0))
		p.global_position = Vector3(foot.x, 0.0, foot.z)
		var dirw: Vector3 = t0.global_transform.basis * Vector3(-1.0, 0.0, 0.0)
		p._find_stairs(Vector2(dirw.x, dirw.z).normalized())
		_check("de speler kan op de trap van een zelf gebouwde toren stappen", p.tower == t0 and p.climb == 0.0)
		p.tower = null
		p.climb = -1.0
		p.collision_mask = p.get("_mask0")
		print("klaar, fouten: ", fails)
		quit(1 if fails > 0 else 0)
	return false


func Buildings_under(g, b) -> bool:
	return float(b.get("build_t", 0.0)) > 0.0
