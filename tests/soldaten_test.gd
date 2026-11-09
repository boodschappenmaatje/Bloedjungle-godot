extends SceneTree
## Generals-plan C2/C3: soldatensoorten uit de kazerne (schutter, raketsoldaat, sluipschutter, hospik, ingenieur) en het steen-papier-schaar.
##  1. de counter-tabel en de schade tegen een lichte en een zware vijand
##  2. de bouwrij: per soort een prijs, een rij in volgorde, annuleren geeft de prijs van de laatste terug, het maximum blijft gedeeld
##  3. elke soort komt uit de kazerne met zijn eigen gezondheid
##  4. de hospik heelt jou en je soldaten, de ingenieur repareert een beschadigd gebouw, de raketsoldaat en de sluipschutter schieten op een vijand
## godot --headless --path . --script tests/soldaten_test.gd --fixed-fps 60
var main: Node
var frames := 0
var fails := 0
var kaz: Dictionary
var enemy_a
var enemy_h
var allies_by_kind := {}


func _initialize() -> void:
	root.size = Vector2i(932, 430)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FOUT ") + name)
	if not ok:
		fails += 1


func _enemy(kind: String, at: Vector3):
	var e = load("res://scenes/enemy.tscn").instantiate()
	e.setup(kind, 1)
	e.position = at
	main.add_child(e)
	e.set_physics_process(false)   # staat stil: alleen de schade telt
	return e


func _bm() -> Node:
	for c in main.get_node("Hud").get_children():
		if c.has_method("_enter") and c.has_method("_exit") and c.get("_ui") != null:
			return c
	return null


func _buttons(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is Button:
			out.append(c)
		_buttons(c, out)


func _process(_d: float) -> bool:
	frames += 1
	var g = root.get_node("Game")
	var D = load("res://scripts/data.gd")
	if frames == 2:
		main.get_node("Hud/Sticks").set_process(false)
	if frames == 4:
		main.begin()
	if frames > 4 and g.state == "prep":
		g.prep_t = 1e9
	if frames == 20:
		g.points = 9000
		g.build_credit = 9000
		# 1. counters
		_check("kogel tegen licht 1,0 en tegen zwaar 0,5", is_equal_approx(D.counter("kogel", "licht"), 1.0) and is_equal_approx(D.counter("kogel", "zwaar"), 0.5))
		_check("sluipschutter 2,2 tegen mensen en 0,8 tegen zwaar", is_equal_approx(D.counter("scherp", "licht"), 2.2) and is_equal_approx(D.counter("scherp", "zwaar"), 0.8))
		_check("raket 2,0 tegen zwaar en 0,7 tegen mensen", is_equal_approx(D.counter("raket", "zwaar"), 2.0) and is_equal_approx(D.counter("raket", "licht"), 0.7))
		_check("schade zonder soort blijft zoals hij was", is_equal_approx(D.counter("", "zwaar"), 1.0))
		enemy_a = _enemy("assault", Vector3(60, 0, 60))
		enemy_h = _enemy("heavy", Vector3(66, 0, 60))
		_check("een zware vijand heeft zwaar pantser, een gewone licht", enemy_h.armor == "zwaar" and enemy_a.armor == "licht")
		var ha: float = enemy_a.hp
		var hh: float = enemy_h.hp
		g.hit_class = "scherp"
		enemy_a.hit(20.0, Vector3.FORWARD, true)
		enemy_h.hit(20.0, Vector3.FORWARD, true)
		g.hit_class = ""
		_check("een sluipschutter doet 44 aan een mens (%.1f) en 16 aan een zware vijand (%.1f)" % [ha - enemy_a.hp, hh - enemy_h.hp], absf((ha - enemy_a.hp) - 44.0) < 0.01 and absf((hh - enemy_h.hp) - 16.0) < 0.01)
		ha = enemy_a.hp
		hh = enemy_h.hp
		g.hit_class = "raket"
		enemy_a.hit(20.0, Vector3.FORWARD, true)
		enemy_h.hit(20.0, Vector3.FORWARD, true)
		g.hit_class = ""
		_check("een raket doet 14 aan een mens en 40 aan een zware vijand (%.1f / %.1f)" % [ha - enemy_a.hp, hh - enemy_h.hp], absf((ha - enemy_a.hp) - 14.0) < 0.01 and absf((hh - enemy_h.hp) - 40.0) < 0.01)
		enemy_a.queue_free()
		enemy_h.queue_free()
		# 2. de bouwrij
		var spot := Vector3.ZERO
		for cs in [Vector3(-16, 0, 14), Vector3(16, 0, 16), Vector3(-18, 0, -14), Vector3(20, 0, -16)]:
			if g.builds.placement_status("kazerne", cs, 0.0).valid:
				spot = cs
				break
		var b = g.builds.place("kazerne", spot, 0.0, false, true)
		_check("kazerne staat", b != null)
		if b == null:
			quit(1)
			return false
		kaz = b
		g.builds.upgrade(kaz)
		g.builds.upgrade(kaz)
		var p0: int = g.points
		for k in ["raket", "sluip", "hospik", "ingenieur", "geweer"]:
			g.builds.recruit(kaz, k)
		var want := 400 + 450 + 300 + 350 + 250
		_check("vijf soorten in de rij kosten samen %d (%d)" % [want, p0 - g.points], p0 - g.points == want and kaz.queue == 5)
		_check("de rij houdt de volgorde bij", kaz.queue_kinds == ["raket", "sluip", "hospik", "ingenieur", "geweer"])
		_check("de eerste is een raketsoldaat: 1,5 keer de trainingstijd", absf(g.builds.train_time(kaz) - float(g.builds.LEVELS[kaz.lv].time) * g.builds.time_factor() * 1.5) < 0.001)
		var p1: int = g.points
		g.builds.cancel_recruit(kaz)
		_check("annuleren geeft de prijs van de laatste terug (250, nu %d)" % (g.points - p1), g.points - p1 == 250 and kaz.queue == 4 and kaz.queue_kinds.size() == 4)
		g.builds.recruit(kaz, "geweer")
		g.builds.recruit(kaz, "geweer")
		_check("de rij houdt 5 vast (nu %d)" % kaz.queue, kaz.queue == 5)
		kaz.train_t = 0.01
	if frames == 25:
		# het kazernepaneel heeft een knop per soort, met prijs
		var bm = _bm()
		bm._enter()
		bm._sel = kaz
		bm._fill_panel()
		var btns: Array = []
		_buttons(bm.get("_panel"), btns)
		var found := {}
		for bt in btns:
			for sk in D.SOLDIER_ORDER:
				if bt.text.begins_with(String(D.SOLDIER_TYPES[sk].short)):
					found[sk] = bt.text.replace("\n", " ")
		print("  knoppen: ", found)
		_check("het kazernepaneel heeft vijf soortenknoppen", found.size() == 5)
		var prijzen_ok := true
		for sk in found:
			if not String(found[sk]).contains("%d pt" % int(D.SOLDIER_TYPES[sk].cost)):
				prijzen_ok = false
		_check("elke knop toont zijn prijs", prijzen_ok)
		bm._exit()
	if frames > 20 and frames < 600 and kaz.queue > 0:
		kaz.train_t = minf(kaz.train_t, 0.01)   # snel door de rij heen
	if frames == 600:
		var order := []
		for a in g.allies:
			order.append(a.kind)
		print("  soldaten: ", order)
		_check("de soldaten kwamen in volgorde uit de kazerne", order == ["raket", "sluip", "hospik", "ingenieur", "geweer"])
		for a in g.allies:
			allies_by_kind[a.kind] = a
		var base_hp: float = float(g.builds.LEVELS[kaz.lv].hp)
		_check("een raketsoldaat heeft 0,9 en een sluipschutter 0,7 van de gezondheid", absf(allies_by_kind.raket.hp - base_hp * 0.9) < 0.01 and absf(allies_by_kind.sluip.hp - base_hp * 0.7) < 0.01)
		_check("een hospik en ingenieur schieten niet (schade 0)", allies_by_kind.hospik.dmg == 0.0 and allies_by_kind.ingenieur.dmg == 0.0)
		# 4a. hospik: jij gewond
		var pl = g.player
		pl.hp = 30.0
		allies_by_kind.sluip.hp = 20.0
		var med = allies_by_kind.hospik
		med.global_position = pl.global_position + Vector3(2.0, 0, 0)
		for k in ["raket", "sluip", "ingenieur", "geweer"]:
			allies_by_kind[k].global_position = pl.global_position + Vector3(-3.0, 0, 2.0)
		# 4b. ingenieur: een beschadigd gebouw
		var eng = allies_by_kind.ingenieur
		kaz.hp = float(kaz.max_hp) * 0.4
		eng.global_position = kaz.node.global_position + Vector3(0, 0, 4.0)
		# 4c. schieten
		enemy_a = _enemy("assault", Vector3(0, 0, 0))
		allies_by_kind["_hp_eng"] = kaz.hp
	if frames == 900:
		var pl = g.player
		_check("de hospik heelt jou (nu %.1f)" % pl.hp, pl.hp > 30.0 + 8.0)
		_check("de hospik heelt ook een gewonde soldaat (nu %.1f)" % allies_by_kind.sluip.hp, allies_by_kind.sluip.hp > 20.0 + 5.0)
		_check("de ingenieur repareert het gebouw (%.0f -> %.0f)" % [float(allies_by_kind["_hp_eng"]), float(kaz.hp)], float(kaz.hp) > float(allies_by_kind["_hp_eng"]) + 20.0)
		# 4c. de raketsoldaat tegen een zware vijand, de sluipschutter tegen een mens: ze vuren en raken
		enemy_a.queue_free()
		var far_pos: Vector3 = g.player.global_position + Vector3(0, 0, -20.0)
		enemy_h = _enemy("heavy", far_pos)
		enemy_a = _enemy("assault", far_pos + Vector3(8, 0, 0))
		var rs = allies_by_kind.raket
		var sn = allies_by_kind.sluip
		rs.global_position = far_pos + Vector3(0, 0, 12.0)
		sn.global_position = far_pos + Vector3(8, 0, 25.0)
		rs.command = "hold"
		sn.command = "hold"
		rs.command_hold_position = rs.global_position
		sn.command_hold_position = sn.global_position
		allies_by_kind["_h0"] = enemy_h.hp
		allies_by_kind["_a0"] = enemy_a.hp
	if frames == 1500:
		var dh: float = allies_by_kind["_h0"] - (enemy_h.hp if is_instance_valid(enemy_h) else 0.0)
		var da: float = allies_by_kind["_a0"] - (enemy_a.hp if is_instance_valid(enemy_a) else 0.0)
		_check("de raketsoldaat raakte de zware vijand (%.0f schade)" % dh, dh > 30.0)
		_check("de sluipschutter raakte de gewone vijand (%.0f schade)" % da, da > 30.0)
		print("klaar, fouten: ", fails)
		quit(1 if fails > 0 else 0)
	return false
