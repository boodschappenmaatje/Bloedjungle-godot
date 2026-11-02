extends SceneTree
## v185: zuivere FIFO- en parkeerplaatscontrole, zonder zware speelwereld.
## godot --headless --path . --script tests/voorraad_verkeer_unit_test.gd

var fails := 0

func _check(label: String, pass: bool) -> void:
	print(("OK " if pass else "FOUT ") + label)
	if not pass:
		fails += 1

func _initialize() -> void:
	var supply := Voorraad.new()
	root.add_child(supply)
	var trucks: Array = []
	for i in 6:
		var t := VoorraadTruck.new()
		root.add_child(t)
		trucks.append(t)
	_check("eerste truck krijgt exclusieve weg", supply.traffic_request(trucks[0]))
	for i in range(1, trucks.size()):
		_check("truck %d netjes in wachtrij" % i, not supply.traffic_request(trucks[i]))
	for i in range(1, trucks.size()):
		supply.traffic_release(trucks[i - 1])
		_check("truck %d krijgt FIFO-voorrang" % i, supply.traffic_request(trucks[i]))
	supply.traffic_release(trucks[5])
	_check("weg vrij na de laatste truck", supply._traffic_owner == null and supply._traffic_queue.is_empty())
	var d := {"at": Vector3(13, 0, -17), "yaw": -PI / 2.0}
	var points: Array = []
	for i in 3:
		points.append(supply.parking_point(d, i))
	for i in 3:
		for j in range(i + 1, 3):
			_check("parkeerplaatsen %d/%d houden afstand" % [i, j], (points[i] as Vector2).distance_to(points[j]) >= 6.45)
	print("VERKEER_V185_UNIT_RESULT=", "PASS" if fails == 0 else "FAIL", " fouten=", fails)
	quit(1 if fails > 0 else 0)
