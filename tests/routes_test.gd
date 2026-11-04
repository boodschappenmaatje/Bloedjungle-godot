extends SceneTree
## Test: vaste aanvalsroutes (aanval_routes.gd). Elke route wordt afgelopen tot vlak bij de basis,
## de keuze per golf heeft altijd een stadsroute, en _spawn zet vijanden op hun route.
## Draaien: godot --headless --path . -s tests/routes_test.gd --fixed-fps 60

var main: Node
var routes_script: GDScript
var enemy_base_script: GDScript
var route_list: Dictionary
var frames := 0
var fails := 0
var finishing := false
var walkers := {}  # route-id -> vijand
var best := {}  # route-id -> [kleinste afstand tot elk routepunt]
var arrived := {}  # route-id -> seconden tot binnen 34 m van de bunker


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		push_error("ROUTES TEST: " + msg)


func _quit_with_result(exit_code: int) -> void:
	quit(exit_code)


func _initialize() -> void:
	call_deferred("_start")


func _start() -> void:
	# Direct --script execution parses its target before project autoloads are
	# ready. Defer main.tscn loading so scripts depending on Game compile after
	# autoload initialization, matching the real application startup order.
	await process_frame
	routes_script = load("res://scripts/aanval_routes.gd") as GDScript
	enemy_base_script = load("res://scripts/vijand_basis.gd") as GDScript
	route_list = routes_script.get("LIST")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_dt: float) -> bool:
	if finishing:
		return false
	frames += 1
	var game = root.get_node("Game")
	if frames == 3:
		main.begin()
		for n in main.get_children():   # de wachten van de basis zouden de wandelaars neerschieten voor ze aankomen
			if n.get_script() and String(n.get_script().resource_path).ends_with("patrouille.gd"):
				n.queue_free()
		game.player.global_position = Vector3(-150, 0, 60)  # ver weg, zodat niemand op de speler afgaat
		for n in range(1, 16):
			var ids: Array = routes_script.call("pick", n)
			_check(ids.size() >= 1 and ids.size() <= 3, "golf %d heeft %d routes" % [n, ids.size()])
			var city := false
			for id in ids:
				_check((routes_script.get("LIST") as Dictionary).has(id), "onbekende route " + str(id))
				city = city or (routes_script.get("LIST") as Dictionary)[id].stad
			_check(city, "golf %d heeft geen route door de stad" % n)
		_check(routes_script.call("pick", 1) == ["brug"], "golf 1 is niet de brug")
		# _spawn gebruikt de routes van de golf
		game.state = "play"
		game.routes = ["industrie"]
		main._spawn("knife")
		var e: Node = game.enemies[game.enemies.size() - 1]
		var spawned_path: Array = e.get("path")
		var base_origin: Vector3 = enemy_base_script.get("P")
		var half: Vector2 = enemy_base_script.get("HALF")
		var offset: Vector3 = e.global_position - base_origin
		_check(absf(offset.x) <= 1.8 and offset.z >= half.y - 12.0 and offset.z <= half.y - 5.0, "vijand begint op het binnenplein bij de zuidpoort")
		_check(spawned_path.size() == 3, "vijand heeft een poortuitgang en beide routepunten")
		if spawned_path.size() == 3:
			_check(Vector2(spawned_path[1].x - 72.0, spawned_path[1].z + 108.0).length() < 2.3, "industrie-route start bij het vastgelegde routepunt")
		e.queue_free()
		game.enemies.erase(e)
		for id in route_list:
			var w: Node = load("res://scenes/enemy.tscn").instantiate()
			w.call("setup", "knife", 1)
			w.set("gate_z", 0.0)
			w.set("path", routes_script.call("path_for", id))
			w.position = routes_script.call("spawn_at", w.get("path"))
			main.add_child(w)
			walkers[id] = w
			var d := []
			for q in route_list[id].pts:
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
			var pts: Array = route_list[id].pts
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
		if not finishing:
			finishing = true
			call_deferred("_quit_with_result", 1 if fails else 0)
	return false
