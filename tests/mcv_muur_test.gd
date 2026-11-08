extends SceneTree
## Test van MCV stap 3a: muren trekken (rooster van 3,5 m), kosten (eerste complete omheining gratis, daarna 50 per stuk), plekcontrole en vijanden die een muur
## kapot slaan. godot --headless --path . --script tests/mcv_muur_test.gd --fixed-fps 60

var D: GDScript
var M: GDScript
var K: GDScript
var main: Node
var frames := 0
var fails := 0
var mcv: Node
var hp0 := 0.0
var enemy: Node


func _initialize() -> void:
	D = load("res://scripts/data.gd")
	M = load("res://scripts/mcv.gd")
	K = load("res://scripts/kampmuur.gd")
	D.set("mcv_mode", true)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FOUT ") + name)
	if not ok:
		fails += 1


func _total_hp(g) -> float:
	var s := 0.0
	for b in g.buildings:
		if b.kind == "kampmuur":
			s += float(b.hp)
	return s


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
	if frames == 16:
		_check("muren kunnen nog niet voor het uitklappen", not g.builds.placement_status("kampmuur", Vector3(0, 0, 20), 0.0).valid)
		mcv.deploy_now()
	if frames == 20:
		# rooster en paden
		var k = K.edge_key(Vector2i(3, 2), Vector2i(2, 2))
		_check("rand is onafhankelijk van de volgorde", k == K.edge_key(Vector2i(2, 2), Vector2i(3, 2)))
		_check("rand -> middelpunt -> rand klopt (x-as)", K.edge_of(K.edge_center(k), K.edge_yaw(k)) == k)
		var k2 = K.edge_key(Vector2i(5, -4), Vector2i(5, -3))
		_check("rand -> middelpunt -> rand klopt (z-as)", K.edge_of(K.edge_center(k2), K.edge_yaw(k2)) == k2)
		var path: Array = [Vector2i(0, 0)]
		K.extend(path, Vector2i(3, 0))
		_check("pad trekken vult tussenpunten aan", path.size() == 4)
		K.extend(path, Vector2i(1, 0))
		_check("teruggaan haalt het laatste stukje weg", path.size() == 2 and path[1] == Vector2i(1, 0))
		var diag: Array = [Vector2i(0, 0)]
		K.extend(diag, Vector2i(2, 2))
		_check("een schuine veeg wordt een trap (alleen rechte stukken)", diag.size() == 5)
		# plekcontrole
		var hq_edge = K.edge_key(Vector2i(11, 11), Vector2i(12, 11))   # dwars door het hoofdkwartier (40, 40)
		_check("een muur dwars door het hoofdkwartier kan niet", not g.builds.placement_status("kampmuur", K.edge_center(hq_edge), K.edge_yaw(hq_edge)).valid)
		var river_edge = K.edge_key(Vector2i(0, -26), Vector2i(1, -26))
		_check("een muur in de rivier kan niet", not g.builds.placement_status("kampmuur", K.edge_center(river_edge), K.edge_yaw(river_edge)).valid)
		_check("eerste stuk kost niets", K.next_cost() == 0 and g.builds.cost_of("kampmuur") == 0)
	if frames == 24:
		# drie zijden van een omheining rond het hoofdkwartier (40, 40): rooster (7,7)..(17,17) = x 24,5..59,5
		var pts0: int = g.points
		var cr0: int = g.build_credit
		var path: Array = [Vector2i(7, 7)]
		for v in [Vector2i(17, 7), Vector2i(17, 17), Vector2i(7, 17)]:
			K.extend(path, v)
		var plan: Dictionary = K.plan(path)
		_check("voorbeeld: 30 stukken, gratis", int(plan.built) == 30 and int(plan.cost) == 0)
		var r: Dictionary = K.build(path)
		_check("drie zijden gebouwd (%s)" % str(r), int(r.built) == 30 and int(r.skipped) == 0 and int(r.poor) == 0)
		_check("het kostte niets", g.points == pts0 and g.build_credit == cr0)
		_check("nog geen complete omheining: de laatste zijde ontbreekt", K.enclosed() == false and g.free_wall == true)
		var plan2: Dictionary = K.plan(path)
		var bestaand := 0
		for e in plan2.edges:
			if e.state == "bestaat":
				bestaand += 1
		_check("een pad over bestaande muren wordt niet nog eens gebouwd", bestaand == 30)
		var r2: Dictionary = K.build(path)
		_check("tweede keer bouwt niets", int(r2.built) == 0)
	if frames == 28:
		var pts0: int = g.points
		var path: Array = [Vector2i(7, 17)]
		K.extend(path, Vector2i(7, 7))
		var r: Dictionary = K.build(path)
		_check("vierde zijde gebouwd", int(r.built) == 10)
		_check("de omheining is compleet", K.enclosed() == true)
		_check("daarmee is het gratis tegoed op (de rest kost 50)", g.free_wall == false and K.next_cost() == 50)
		_check("alles bleef gratis", g.points == pts0)
		_check("40 stukken, allemaal gratis gemerkt", K.count() == 40 and K.count_free() == 40)
		# verkopen van een gratis stuk levert niets
		var any = null
		for b in g.buildings:
			if b.kind == "kampmuur":
				any = b
		_check("verkoopwaarde van een gratis stuk is 0", any != null and g.builds.sell_value(any) == 0)
	if frames == 32:
		# een stuk naar buiten kost nu 50 per stuk (bouwtegoed gaat eerst)
		var total0: int = g.points + g.build_credit
		var path: Array = [Vector2i(17, 17)]
		K.extend(path, Vector2i(20, 17))
		var plan: Dictionary = K.plan(path)
		_check("voorbeeld: 3 stukken voor 150", int(plan.built) == 3 and int(plan.cost) == 150)
		var r: Dictionary = K.build(path)
		_check("drie stukken gebouwd", int(r.built) == 3)
		_check("ze kostten 50 per stuk", total0 - (g.points + g.build_credit) == 150)
		var paid = null
		for b in g.buildings:
			if b.kind == "kampmuur" and not b.get("gratis", false):
				paid = b
		_check("verkoopwaarde van een betaald stuk is 25", paid != null and g.builds.sell_value(paid) == 25)
		# te weinig punten
		var credit: int = g.build_credit
		g.build_credit = 0
		g.points = 70
		var path2: Array = [Vector2i(20, 17)]
		K.extend(path2, Vector2i(24, 17))
		var plan3: Dictionary = K.plan(path2)
		_check("bij 70 punten kunnen er maar 1 van de 4 stukken bij", int(plan3.built) == 1)
		var r3: Dictionary = K.build(path2)
		_check("bouwt er één en meldt de rest als te duur", int(r3.built) == 1 and int(r3.poor) == 3)
		g.points = 5000
		g.build_credit = credit
	if frames == 36:
		# een vijand buiten de zuidmuur (z = 59,5) op weg naar het hoofdkwartier slaat de muur kapot
		g.state = "play"
		hp0 = _total_hp(g)
		enemy = load("res://scenes/enemy.tscn").instantiate()
		enemy.setup("knife", 1)
		main.add_child(enemy)
		enemy.global_position = Vector3(40.0, 0.0, 64.0)
		p.global_position = Vector3(40.0, 0.0, 40.0)   # de speler staat binnen het kamp, de vijand wil naar het hoofdkwartier
	if frames == 330:
		var hp1 := _total_hp(g)
		_check("de vijand heeft de muur beschadigd (%.0f -> %.0f)" % [hp0, hp1], hp1 < hp0)
		_check("de muur hield hem tegen (hij staat nog buiten)", is_instance_valid(enemy) and enemy.global_position.z > 59.0)
		print("klaar, fouten: ", fails)
		quit(1 if fails > 0 else 0)
	return false
