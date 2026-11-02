extends SceneTree
## Generals stap 4a (en het gameplaycontract voor 4b): voorraadstapels, depot en trucks (scripts/voorraad*.gd). Eerste depot met gratis truck, vier stapels met een vrije weg,
## een truck die haalt en brengt (geld komt binnen), een wrak, een lege stapel die een nieuwe plek krijgt, kills zonder geld,
## poorten die voor trucks opengaan, het depotpaneel en een tweede depot bouwen.
## godot --headless --path . --script tests/voorraad_test.gd --fixed-fps 60

var main: Node
var frames := 0
var fails := 0
var depot: Dictionary
var truck
var points0 := 0
var left0 := 0
var cycle_done := false


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
	if frames < 60:
		root.size = Vector2i(932, 430)
	if frames == 2:
		main.get_node("Hud/Sticks").set_process(false)
	if frames == 4:
		main.begin()
		for m in get_nodes_in_group("menus"):
			m._show("")
	if frames > 4 and g.state == "prep":
		g.prep_t = 1e9   # geen golf tijdens deze test
	if frames == 40:
		_check_start(g)
	if frames > 40 and frames < 5000 and not cycle_done:
		_watch_cycle(g)
	if frames == 5000:
		_check("een volledige rit is binnen 83 s gebeurd", cycle_done)
	if frames == 5002:
		_check_rest(g)
	if frames == 5100:
		_check_gate(g)
	if frames == 5200:
		_check_panel(g)
		print("klaar, fouten: ", fails)
		quit(1 if fails > 0 else 0)
	return false


func _check_start(g) -> void:
	var sup = g.supply
	_check("voorraadbeheer bestaat en is gestart", sup != null and sup.started)
	var n := 0
	for s in sup.stapels:
		if s != null and s.left == 2500:
			n += 1
	_check("vier voorraadstapels van 2.500", n == 4)
	var ok_afhaal := true
	for s in sup.stapels:
		# elke stapel heeft drie standen met elk een afhaalkist (4b); pickup_taken verbergt ze alle drie
		if s._afhaal.size() != 3:
			ok_afhaal = false
		s.pickup_taken(true)
		for a in s._afhaal:
			if a.visible:
				ok_afhaal = false
		s.pickup_taken(false)
	_check("elke stapel heeft drie afhaalkisten (vol, half, leeg) die verdwijnen als de truck ze pakt", ok_afhaal)
	var depots: Array = sup.depots()
	_check("eerste depot staat er vanaf het begin", depots.size() == 1)
	if depots.is_empty():
		return
	depot = depots[0]
	print("depot op ", depot.at, " yaw ", depot.yaw, " dock ", sup.dock_point(depot))
	var trucks: Array = sup.trucks_of(depot)
	_check("één gratis truck bij het begin", trucks.size() == 1)
	truck = trucks[0]
	_check("kills geven geen geld meer (add_score)", _kill_test(g))
	_check("enemy.gd geeft geen geld meer voor een kill", not FileAccess.get_file_as_string("res://scripts/enemy.gd").contains("Game.add_points(t.pts)"))
	# wegen
	var cleared_total := 0
	for s in sup.stapels:
		var r: Array = sup.route(depot, s.slot)
		_check("route naar stapel %d heeft wegpunten" % (s.slot + 1), r.size() >= 3)
		var len: float = sup.route_length(depot, s.slot)
		var val: int = sup.trip_value(depot, s.slot)
		print("  stapel %d %s: route %.0f m, rit %d punten" % [s.slot + 1, s.site.name, len, val])
		_check("rit van stapel %d levert 100 tot 400 op" % (s.slot + 1), val >= 100 and val <= 400)
		var left_in_road: int = load("res://scripts/foliage.gd")._entries_for_build_regions(sup.road_regions(s.site), Vector3.ZERO, 0.0, 0.5, true).size()
		_check("geen bomen of rotsen meer op de weg naar stapel %d" % (s.slot + 1), left_in_road == 0)
		cleared_total += int(sup._roads[s.site.id].get_meta("cleared", 0))
	print("  weggehaald: ", cleared_total)
	_check("er zijn bomen of rotsen weggehaald langs de wegen", cleared_total > 0)
	points0 = g.points
	g.points = 2000
	points0 = 2000


func _kill_test(g) -> bool:
	var p0: int = g.points
	var s0: int = g.score
	g.add_score(60)
	var ok: bool = g.points == p0 and g.score > s0
	g.score = s0
	return ok


func _watch_cycle(g) -> void:
	if truck == null or not is_instance_valid(truck):
		return
	var sup = g.supply
	if truck.state == 2 and left0 == 0:   # LADEN: onthoud wat er op de stapel lag
		left0 = sup.stapels[truck.slot].left + 1   # (+1 zodat 0 niet "niet gezien" betekent)
	if sup.trips >= 1 and not cycle_done:
		cycle_done = true
		print("  eerste rit afgeleverd na %.1f s spelertijd" % (float(frames - 40) / 60.0))
		_check("de truck heeft één rit afgeleverd", sup.trips == 1)
		_check("het geld kwam binnen (%d punten)" % sup.income_total, g.points == points0 + sup.income_total and sup.income_total >= 100)
		_check("de stapel is leger geworden", left0 > 0 and sup.stapels[truck.slot].left < left0 - 1 + 1 and sup.stapels[truck.slot].left == 2500 - sup.income_total)


func _check_rest(g) -> void:
	var sup = g.supply
	# wrak
	truck.take(10000.0)
	_check("truck kapot = wrak", truck.state == 5 and truck.cargo == 0)
	_check("wrak telt niet mee voor het maximum", sup.alive_trucks_of(depot) == 0)
	g.points = 2000
	var bought := 0
	for i in 5:
		if sup.buy_truck(depot):
			bought += 1
	_check("nieuwe trucks kopen: maximaal 3 per depot (kocht %d)" % bought, bought == 3 and g.points == 2000 - 3 * 600)
	# lege stapel krijgt een nieuwe plek, verder weg
	var first_site: String = sup.stapels[0].site.id
	var before: int = sup.stapels[0].left
	var got: int = sup.take(0, first_site, 99999)
	_check("een stapel haal je leeg (kreeg %d van %d)" % [got, before], got == before and before > 0)
	_check("daarna ligt er een nieuwe stapel verder weg", sup.stapels[0] != null and sup.stapels[0].site.id != first_site and sup.stapels[0].left == 2500 and sup.stapels[0].site.pos.length() > 64.0)
	print("  nieuwe plek: ", sup.stapels[0].site.name)
	# tweede depot bouwen (bouwtijd, geld)
	g.points = 3000
	var spot: Array = sup.START_SPOTS[1]
	var second = g.builds.place("depot", spot[0], spot[1], true)
	if second == null:
		spot = sup.START_SPOTS[2]
		second = g.builds.place("depot", spot[0], spot[1], true)
	_check("een tweede depot kun je bouwen", second != null and g.builds.count("depot") == 2)
	if second != null:
		_check("het tweede depot heeft bouwtijd en nog geen gratis truck", g.builds.under_construction(second) and sup.trucks_of(second).is_empty())
		g.builds.remove(second)
	# truck naar de noordpoort zetten: de poort gaat open
	var t0 = sup.trucks_of(depot)[1]
	t0.state = 0
	t0.global_position = Vector3(0, 0, -23.0)
	t0.path.clear()
	truck = t0


func _check_gate(g) -> void:
	var gate: Dictionary = g.gates.list[0]
	var other: Dictionary = g.gates.list[1]
	var best: float = maxf(float(gate.open), float(other.open))
	print("  poortstand: ", gate.open, " / ", other.open, " (trucks naast de poort)")
	_check("de poort schuift open voor een truck", best > 0.4)


func _check_panel(g) -> void:
	var gm = g.builds.find_children("*", "GarageMenu", true, false)[0]
	gm._sel = depot
	g.points = 2000
	gm._refresh()
	_check("het depotpaneel gaat open", gm._panel.visible)
	var kopen: Button = null
	var stapels := 0
	for b in gm._box.find_children("*", "Button", true, false):
		var t: String = (b as Button).text
		if t.begins_with("Truck") and not b.is_queued_for_deletion():
			kopen = b
		if t.begins_with("Stapel"):
			stapels += 1
	_check("het paneel toont een truckknop en de stapels", kopen != null and stapels >= 1)
	if kopen != null:
		_check("de truckknop is uit (maximum bereikt)", kopen.disabled)
	for b in gm._box.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with("Stapel 2"):
			b.pressed.emit()
			break
	_check("een stapel kiezen als bestemming", int(depot.get("dest", -1)) == 1)
