extends SceneTree
## Test: vaste aanvalsroutes (aanval_routes.gd). Elke route wordt afgelopen tot vlak bij de basis,
## de keuze per golf heeft altijd een stadsroute, en _spawn zet vijanden op hun route.
## Draaien: godot --headless --path . -s tests/routes_test.gd --fixed-fps 60

var main: Node
var frames := 0
var fails := 0
var walkers := {}  # route-id -> vijand
var best := {}  # route-id -> [kleinste afstand tot elk routepunt]
var arrived := {}  # route-id -> seconden tot binnen 34 m van de bunker


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		push_error("ROUTES TEST: " + msg)


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_dt: float) -> bool:
	frames += 1
	var game = root.get_node("Game")
	if frames == 3:
		main.begin()
		for n in main.get_children():   # de wachten van de basis zouden de wandelaars neerschieten voor ze aankomen
			if n.get_script() and String(n.get_script().resource_path).ends_with("patrouille.gd"):
				n.queue_free()
		game.player.global_position = Vector3(-150, 0, 60)  # ver weg, zodat niemand op de speler afgaat
		for n in range(1, 16):
			var ids: Array = AanvalRoutes.pick(n)
			_check(ids.size() >= 1 and ids.size() <= 3, "golf %d heeft %d routes" % [n, ids.size()])
			var city := false
			for id in ids:
				_check(AanvalRoutes.LIST.has(id), "onbekende route " + str(id))
				city = city or AanvalRoutes.LIST[id].stad
			_check(city, "golf %d heeft geen route door de stad" % n)
		_check(AanvalRoutes.pick(1) == ["brug"], "golf 1 is niet de brug")
		# _spawn gebruikt de routes van de golf
		game.state = "play"
		game.routes = ["industrie"]
		main._spawn("knife")
		var e: Node = game.enemies[game.enemies.size() - 1]
		_check(e.global_position.distance_to(Vector3(72, 0, -108)) < 10.0, "spawn niet aan het begin van de route: %s" % e.global_position)
		_check(e.get("path").size() == 2, "vijand heeft geen route")
		e.queue_free()
		game.enemies.erase(e)
		for id in AanvalRoutes.LIST:
			var w: Node = load("res://scenes/enemy.tscn").instantiate()
			w.call("setup", "knife", 1)
			w.set("gate_z", 0.0)
			w.set("path", AanvalRoutes.path_for(id))
			w.position = AanvalRoutes.spawn_at(w.get("path"))
			main.add_child(w)
			walkers[id] = w
			var d := []
			for q in AanvalRoutes.LIST[id].pts:
				d.append(INF)
			best[id] = d
	if frames > 3:
		game.player.hp = 100000.0
		game.base_hp = game.base_max
		for id in walkers:
			var wv = walkers[id]   # niet getypeerd: een wandelaar kan al verwijderd zijn
			if not is_instance_valid(wv):
				continue
			var w: Node = wv
			var p: Vector3 = w.global_position
			var pts: Array = AanvalRoutes.LIST[id].pts
			for i in pts.size():
				best[id][i] = minf(best[id][i], Vector2(p.x - pts[i].x, p.z - pts[i].z).length())
			if not arrived.has(id) and Vector2(p.x, p.z).length() < 34.0:
				arrived[id] = (frames - 3) / 60.0
	if frames > 3 and frames % 300 == 0 and OS.has_environment("ROUTES_DEBUG"):
		var line := "t=%d" % ((frames - 3) / 60)
		for id in walkers:
			if is_instance_valid(walkers[id]):
				var w: Node = walkers[id]
				line += " %s(%.0f,%.0f i%d %s)" % [id, w.global_position.x, w.global_position.z, w.get("path_i"), w.get("_far")]
		print(line, " state=", game.state)
	if frames == 3 + 60 * 70:
		for id in walkers:
			_check(arrived.has(id), "route %s komt niet bij de basis (staat op %s)" % [id, walkers[id].global_position if is_instance_valid(walkers[id]) else "weg"])
			for i in best[id].size():
				_check(best[id][i] < 6.0, "route %s: punt %d niet gehaald (%.1f m)" % [id, i, best[id][i]])
			print("route %s: bij de basis na %s s" % [id, str(arrived.get(id, "-"))])
		print("ROUTES TEST: %s" % ("OK" if fails == 0 else "%d FOUT" % fails))
		quit(1 if fails else 0)
	return false
