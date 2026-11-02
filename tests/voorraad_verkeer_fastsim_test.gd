extends SceneTree
## Deterministische 240 s verkeersproef met echte VoorraadTruck._physics_process.
## Simuleert trucklogica zonder 7200 zware wereld/renderframes.
## Godot: --headless --path . --script tests/voorraad_verkeer_fastsim_test.gd

const HZ := 30
const SIM_SECONDS := 240
const DT := 1.0 / float(HZ)

var main: Node
var frames := 0
var fails := 0
var overlaps := 0
var simultaneous := 0
var closest := INF
var last_delivery_step := 0

func _check(label: String, ok: bool) -> void:
	print(("OK " if ok else "FOUT ") + label)
	if not ok:
		fails += 1

func _initialize() -> void:
	root.size = Vector2i(932, 430)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

func _process(_delta: float) -> bool:
	frames += 1
	var g = root.get_node("Game")
	if frames == 2:
		main.get_node("Hud/Sticks").set_process(false)
	if frames == 4:
		main.begin()
		for m in get_nodes_in_group("menus"):
			m._show("")
	if frames > 4 and g.state == "prep":
		g.prep_t = 1e9
	if frames >= 40 and g.supply != null and g.supply.started:
		_run(g)
		quit(1 if fails > 0 else 0)
	elif frames > 1200:
		_check("voorraadbeheer niet actief binnen 1200 frames", false)
		quit(1)
	return false

func _run(g) -> void:
	if g.supply == null or not is_instance_valid(g.supply):
		_check("Game.supply ontbreekt voor fastsim", false)
		return
	var sup = g.supply
	var depots: Array = sup.depots()
	_check("startdepot bestaat", depots.size() > 0)
	if depots.is_empty():
		return
	var first: Dictionary = depots[0]
	for i in 2:
		sup._spawn_truck(first)
	_check("drie trucks in eerste depot", sup.alive_trucks_of(first) == 3)
	var second: Dictionary = {}
	for i in range(1, sup.START_SPOTS.size()):
		var spot: Array = sup.START_SPOTS[i]
		var found = g.builds.place("depot", spot[0], spot[1], false, true)
		if found != null:
			second = found
			break
	_check("tweede depot gevonden", not second.is_empty())
	if second.is_empty():
		return
	for i in 3:
		sup._spawn_truck(second)
	var trucks: Array = get_nodes_in_group("voorraadtruck")
	_check("zes trucks actief", trucks.size() == 6)
	if trucks.size() != 6:
		return
	var delivered: int = sup.trips
	for tick in range(SIM_SECONDS * HZ):
		for item in trucks:
			var t = item
			if is_instance_valid(t) and t.state != 5:
				t._physics_process(DT)
		if tick % 3 != 0:
			continue
		var moving := 0
		for item in trucks:
			var truck = item
			if truck.state != 0 and truck.state != 5:
				moving += 1
		if moving > 1:
			simultaneous += 1
		for i in trucks.size():
			for j in range(i + 1, trucks.size()):
				var a = trucks[i]
				var b = trucks[j]
				if a.state == 5 or b.state == 5:
					continue
				var av := Vector2(a.global_position.x, a.global_position.z)
				var bv := Vector2(b.global_position.x, b.global_position.z)
				var d := av.distance_to(bv)
				closest = minf(closest, d)
				if d < 3.2:
					overlaps += 1
		if sup.trips != delivered:
			delivered = sup.trips
			last_delivery_step = tick
	_check("geen dubbele verkeersreservering", simultaneous == 0)
	_check("geen voertuigen op elkaar (overlapmonsters: %d)" % overlaps, overlaps == 0)
	_check("veilige minimale afstand %.2f m" % closest, closest >= 3.2)
	_check("voorraad afgeleverd: %d ritten" % sup.trips, sup.trips >= 2)
	_check("geen stilstand >120 s na laatste levering", SIM_SECONDS * HZ - last_delivery_step < 120 * HZ)
	print("VERKEER_V185_FASTSIM_RESULT=", "PASS" if fails == 0 else "FAIL", " fouten=", fails, " ritten=", sup.trips)
