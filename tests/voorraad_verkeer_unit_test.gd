extends SceneTree
## v185: FIFO- en parkeercontract binnen de normale Godot-spelinitialisatie.
## Godot --headless --path . --script tests/voorraad_verkeer_unit_test.gd --fixed-fps 60
## Geen directe Voorraad.new()/VoorraadTruck.new() in scriptmode: die mist Game-autoload.

var main: Node
var frames := 0
var fails := 0

func _initialize() -> void:
	root.size = Vector2i(932, 430)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

func _check(label: String, ok: bool) -> void:
	print(("OK " if ok else "FOUT ") + label)
	if not ok:
		fails += 1

func _process(_delta: float) -> bool:
	frames += 1
	var g = root.get_node("Game")
	if frames == 2:
		main.get_node("Hud/Sticks").set_process(false)
	if frames == 4:
		main.begin()
		for menu in get_nodes_in_group("menus"):
			menu._show("")
	if frames > 4 and g.state == "prep":
		g.prep_t = 1e9
	if frames == 40:
		_run(g)
		print("VERKEER_V185_UNIT_RESULT=", "PASS" if fails == 0 else "FAIL", " fouten=", fails)
		quit(1 if fails > 0 else 0)
	return false

func _run(g) -> void:
	var supply = g.supply
	_check("voorraadbeheer bestaat", supply != null)
	if supply == null:
		return
	var depots: Array = supply.depots()
	_check("startdepot bestaat", not depots.is_empty())
	if depots.is_empty():
		return
	var depot: Dictionary = depots[0]
	for i in 2:
		supply._spawn_truck(depot)
	var trucks: Array = supply.trucks_of(depot)
	_check("drie trucks voor de FIFO-controle", trucks.size() == 3)
	if trucks.size() != 3:
		return
	for truck in trucks:
		supply.traffic_release(truck)
	_check("eerste truck krijgt exclusieve weg", supply.traffic_request(trucks[0]))
	for i in range(1, trucks.size()):
		_check("truck %d staat in wachtrij" % i, not supply.traffic_request(trucks[i]))
	for i in range(1, trucks.size()):
		supply.traffic_release(trucks[i - 1])
		_check("truck %d krijgt FIFO-voorrang" % i, supply.traffic_request(trucks[i]))
	supply.traffic_release(trucks[trucks.size() - 1])
	_check("weg vrij na de laatste truck", supply._traffic_owner == null and supply._traffic_queue.is_empty())
	var points: Array = []
	for i in 3:
		points.append(supply.parking_point(depot, i))
	for i in 3:
		for j in range(i + 1, 3):
			_check("parkeerplaatsen %d/%d houden afstand" % [i, j], (points[i] as Vector2).distance_to(points[j]) >= 6.45)
