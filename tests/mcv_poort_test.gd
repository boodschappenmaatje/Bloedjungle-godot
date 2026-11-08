extends SceneTree
## Test van MCV stap 3b: een poort zelf in de muur zetten, de omheining blijft compleet, trucks rijden door de poort, vijanden worden door de dichte poort gestopt.
## godot --headless --path . --script tests/mcv_poort_test.gd --fixed-fps 60

var D: GDScript
var M: GDScript
var K: GDScript
var main: Node
var frames := 0
var fails := 0
var mcv: Node
var depot: Dictionary
var slot := -1
var points0 := 0
var gate_opened := false
var income_seen := false
var zrow := 19   # rij van de zuidmuur van de gekozen omheining


func _initialize() -> void:
	D = load("res://scripts/data.gd")
	M = load("res://scripts/mcv.gd")
	K = load("res://scripts/kampmuur.gd")
	D.set("mcv_autodeploy", false)
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
	if frames == 16:
		mcv.deploy_now()
	if frames == 20:
		_check("geen poorten van het oude kamp", g.gates.list.is_empty())
		# een omheining rond het hoofdkwartier: rooster (5,5)..(19,19) = x 17,5..66,5, z 17,5..66,5
		# (vaten en dergelijke in de weg kunnen een stuk blokkeren: kies de eerste omheining waarvan alle stukken kunnen)
		var rings := [[5, 5, 19, 19], [4, 5, 19, 19], [5, 4, 19, 19], [5, 5, 20, 19], [5, 5, 19, 20], [4, 4, 20, 20]]
		var path: Array = []
		var chosen := []
		for rg in rings:
			var cand: Array = [Vector2i(rg[0], rg[1])]
			for v in [Vector2i(rg[2], rg[1]), Vector2i(rg[2], rg[3]), Vector2i(rg[0], rg[3]), Vector2i(rg[0], rg[1])]:
				K.extend(cand, v)
			var pl: Dictionary = K.plan(cand)
			if int(pl.built) == K.path_edges(cand).size():
				path = cand
				chosen = rg
				break
		print("gekozen omheining: ", chosen)
		zrow = chosen[3] if not chosen.is_empty() else 19
		_check("een vrije omheining gevonden", not path.is_empty())
		var r: Dictionary = K.build(path)
		_check("omheining gebouwd %s" % str(r), int(r.skipped) == 0 and int(r.poor) == 0 and int(r.built) == K.path_edges(path).size())
		_check("de omheining is compleet", K.enclosed())
		# een voorraaddepot binnen de omheining, voorkant naar het oosten
		var b = g.builds.place("depot", Vector3(28.0, 0.0, 56.0), PI / 2.0, false)
		_check("depot binnen de omheining gezet", b != null)
		if b != null:
			depot = b
			for i in g.supply.stapels.size():
				if g.supply.stapels[i] != null and g.supply.stapels[i].site.id == "zuid":
					slot = i
			_check("stapel Zuidveld gevonden", slot >= 0)
			_check("zonder poort versperd de muur de weg (%s)" % g.supply.blocked_by(depot, slot), g.supply.blocked_by(depot, slot) == "een muur zonder poort")
	if frames == 24:
		# de poort: twee muurstukken in de zuidmuur (rooster-rij 19) naast elkaar
		var k = K.edge_key(Vector2i(11, zrow), Vector2i(12, zrow))
		var pair: Variant = K.gate_pair(k, K.vertex(Vector2i(12, zrow)))
		_check("twee muurstukken naast elkaar vormen een poort-paar", pair != null and pair[1] == K.edge_key(Vector2i(12, zrow), Vector2i(13, zrow)))
		var kc: int = K.count()
		var money: int = g.points + g.build_credit
		var res: Dictionary = K.place_gate(k, K.vertex(Vector2i(12, zrow)))
		_check("poort geplaatst (%s)" % str(res.reason), res.ok)
		_check("de poort kostte 100 en nam twee stukken in", money - (g.points + g.build_credit) == 100 and K.count() == kc - 2)
		_check("er is één poort, op het rooster", g.gates.list.size() == 1 and g.gates.list[0].at.distance_to(K.vertex(Vector2i(12, zrow))) < 0.01)
		_check("de omheining blijft compleet met de poort", K.enclosed())
		# een los muurstuk is geen poort-paar
		var lone = K.edge_key(Vector2i(5, 8), Vector2i(5, 9))
		var kc2: int = K.count()
		var res2: Dictionary = K.place_gate(K.edge_key(Vector2i(12, zrow), Vector2i(13, zrow)), K.vertex(Vector2i(13, zrow)))
		_check("een tweede poort over de eerste heen kan niet", not res2.ok and K.count() == kc2)
		_check("de weg naar de stapel loopt nu door de poort (%s)" % g.supply.blocked_by(depot, slot), g.supply.blocked_by(depot, slot) == "")
		var route: Array = g.supply.route(depot, slot)
		var gp := Vector2(g.gates.list[0].at.x, g.gates.list[0].at.z)
		var door := false
		for pt: Vector2 in route:
			if pt.distance_to(gp) < 1.0:
				door = true
		_check("de route heeft een punt op de poort", door)
		# vijanden: de dichte poort houdt ze tegen
		_check("een vijand voor de dichte poort wordt tegengehouden", g.gates.blocking(Vector3(42.0, 0.0, 68.0), Vector3(40, 0, 40)) != null)
		_check("een vijand naast de poort niet", g.gates.blocking(Vector3(55.0, 0.0, 68.0), Vector3(40, 0, 40)) == null)
		g.supply.set_dest(depot, slot)
		points0 = g.points
		depot.build_t = 0.0
	if frames > 24 and frames < 12000 and slot >= 0:
		for gt in g.gates.list:
			if float(gt.open) > 0.5:
				gate_opened = true
		if not income_seen and g.points > points0 + 50:
			income_seen = true
			print("rit door de poort af na ", frames, " beelden: +", g.points - points0)
	if frames == 12000:
		_check("de poort ging open voor de truck", gate_opened)
		_check("een rit door de poort levert geld op", income_seen)
		# poort verkopen: plek blijft open en de omheining is niet meer compleet
		var gt = g.gates.list[0]
		var credit0: int = g.build_credit
		K.sell_gate(gt)
		_check("poort verkocht: +50 tegoed en geen poort meer", g.build_credit == credit0 + 50 and g.gates.list.is_empty())
		_check("zonder poort is de omheining open", not K.enclosed())
		print("klaar, fouten: ", fails)
		quit(1 if fails > 0 else 0)
	return false
