extends SceneTree
## v185 volledige-scene smoke: zes trucks, twee depots, 30 s bij 30 Hz.
## De aanvullende fastsim-test dekt 240 gesimuleerde seconden van de trucklogica.
## godot --headless --path . --script tests/voorraad_verkeer_test.gd --fixed-fps 30

var main: Node
var frames := 0
var fails := 0
var min_separation := INF
var overlaps := 0
var multi_active := 0
var max_travel := 0.0
var starts := {}
var first_depot: Dictionary = {}
var second_depot: Dictionary = {}

func _initialize() -> void:
	Engine.physics_ticks_per_second = 30
	root.size = Vector2i(932, 430)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

func _check(label: String, ok: bool) -> void:
	print(("OK   " if ok else "FOUT ") + label)
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
		g.prep_t = 1e9  # Geen vijandgolven tijdens verkeerproef.
	if frames == 40:
		_setup(g)
	if frames > 40 and frames % 6 == 0:
		_sample(g)
	if frames == 940:
		var sup: Voorraad = g.supply
		_check("één bewegende/ladende truck tegelijk (smalle wegen)", multi_active == 0)
		_check("geen truck-clipping in 240 s", overlaps == 0)
		_check("minimale afstand voertuigen %.2f m" % min_separation, min_separation >= 3.2)
		_check("vrachtwagen reed minimaal 5 meter (%.2f m)" % max_travel, max_travel >= 5.0)
		print("VERKEER_V185_LIVE_RESULT=", "PASS" if fails == 0 else "FAIL", " fouten=", fails, " ritten=", sup.trips)
		quit(1 if fails > 0 else 0)
	return false

func _setup(g) -> void:
	var sup: Voorraad = g.supply
	var depots := sup.depots()
	_check("startdepot bestaat", depots.size() > 0)
	if depots.is_empty():
		quit(1)
		return
	first_depot = depots[0]
	sup._spawn_truck(first_depot)
	sup._spawn_truck(first_depot)
	_check("drie trucks bij startdepot", sup.alive_trucks_of(first_depot) == 3)
	for i in range(1, sup.START_SPOTS.size()):
		var spot: Array = sup.START_SPOTS[i]
		var candidate = g.builds.place("depot", spot[0], spot[1], false, true)
		if candidate != null:
			second_depot = candidate
			break
	_check("tweede depot kan worden geplaatst", not second_depot.is_empty())
	if second_depot.is_empty():
		quit(1)
		return
	for i in 3:
		sup._spawn_truck(second_depot)
	_check("zes actieve trucks bij twee depots", sup.alive_trucks_of(first_depot) + sup.alive_trucks_of(second_depot) == 6)
	var all_trucks := get_nodes_in_group("voorraadtruck")
	for i in all_trucks.size():
		for j in range(i + 1, all_trucks.size()):
			var a = all_trucks[i] as VoorraadTruck
			var b = all_trucks[j] as VoorraadTruck
			_check("spawn zonder overlap %d/%d" % [i, j], a.global_position.distance_to(b.global_position) >= 3.2)
	for item in all_trucks:
		var truck := item as VoorraadTruck
		starts[truck.get_instance_id()] = Vector2(truck.global_position.x, truck.global_position.z)

func _sample(g) -> void:
	var sup: Voorraad = g.supply
	var trucks := get_nodes_in_group("voorraadtruck")
	var operating := 0
	for a in trucks:
		if a is VoorraadTruck:
			if a.state != VoorraadTruck.S.WACHT and a.state != VoorraadTruck.S.WRAK:
				operating += 1
			var orig: Vector2 = starts.get(a.get_instance_id(), Vector2(a.global_position.x, a.global_position.z))
			max_travel = maxf(max_travel, orig.distance_to(Vector2(a.global_position.x, a.global_position.z)))
	if operating > 1:
		multi_active += 1
	for i in trucks.size():
		for j in range(i + 1, trucks.size()):
			var a = trucks[i] as VoorraadTruck
			var b = trucks[j] as VoorraadTruck
			if a == null or b == null or a.state == VoorraadTruck.S.WRAK or b.state == VoorraadTruck.S.WRAK:
				continue
			var ap := Vector2(a.global_position.x, a.global_position.z)
			var bp := Vector2(b.global_position.x, b.global_position.z)
			var d := ap.distance_to(bp)
			min_separation = minf(min_separation, d)
			if d < 3.2:
				overlaps += 1
	# Lange leveringsvoortgang: tests/voorraad_verkeer_fastsim_test.gd.
