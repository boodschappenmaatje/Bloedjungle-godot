extends SceneTree
## v185: test FIFO en parkeerplaatsen op de bestaande voorraadbeheerder.
## Godot: --headless --path . --script tests/voorraad_verkeer_unit_test.gd

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
	if frames == 2:
		main.get_node("Hud/Sticks").set_process(false)
	if frames == 10:
		_run()
		quit(1 if fails > 0 else 0)
	return false

func _run() -> void:
	var g = root.get_node("Game")
	var supply = g.supply
	_check("voorraadbeheer geladen uit de spelwereld", supply != null)
	if supply == null:
		return
	var truck_script = load("res://scripts/voorraad_truck.gd")
	_check("truckscript beschikbaar", truck_script != null)
	if truck_script == null:
		return
	var trucks: Array = []
	for i in 6:
		var t = truck_script.new()
		root.add_child(t)
		trucks.append(t)
	_check("eerste truck krijgt exclusieve weg", supply.traffic_request(trucks[0]))
	for i in range(1, trucks.size()):
		_check("truck %d netjes in wachtrij" % i, not supply.traffic_request(trucks[i]))
	for i in range(1, trucks.size()):
		supply.traffic_release(trucks[i - 1])
		_check("truck %d krijgt FIFO-voorrang" % i, supply.traffic_request(trucks[i]))
	supply.traffic_release(trucks[5])
	_check("weg vrij na laatste truck", supply._traffic_owner == null and supply._traffic_queue.is_empty())
	var depot := {"at": Vector3(13, 0, -17), "yaw": -PI / 2.0}
	var parking: Array = []
	for i in 3:
		parking.append(supply.parking_point(depot, i))
	for i in 3:
		for j in range(i + 1, 3):
			_check("parkeerplaats %d/%d heeft afstand" % [i, j], (parking[i] as Vector2).distance_to(parking[j]) >= 6.45)
	print("VERKEER_V185_UNIT_RESULT=", "PASS" if fails == 0 else "FAIL", " fouten=", fails)
