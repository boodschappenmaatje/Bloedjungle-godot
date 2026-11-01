extends SceneTree
## Drie jeeps uit de garage staan niet in elkaar, en "In aanbouw" in het bouwpaneel telt live af.
## godot --headless --path . -s tests/parkeren_test.gd --fixed-fps 60

var main: Node
var frames := 0
var fails := 0
var gar: Variant
var kz: Variant
var bm: Node
var t0 := ""
var vehicles: Array = []


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FOUT ") + name)
	if not ok:
		fails += 1


func _process(_d: float) -> bool:
	frames += 1
	var g = root.get_node("Game")
	if frames == 2:
		main.get_node("Hud/Sticks").set_process(false)
	if frames == 4:
		main.begin()
		g.player.global_position = Vector3(-6, 0, -9)
	if frames == 8:
		var b = g.builds
		g.points = 100000
		g.build_credit = 100000
		b.place("kazerne", Vector3(-6, 0, -8), PI)
		gar = b.place("garage", Vector3(8, 0, -8), 0.0)
		for i in 3:
			b.buy_vehicle(gar, "jeep")
		var _build_mode = load("res://scripts/build_mode.gd")
		bm = main.get_node("Hud").get_children().filter(func(n): return n.get_script() == _build_mode)[0]
		bm._enter()
		kz = b.place("helipad", Vector3(-18, 0, 4), 0.0, true)
		bm._sel = kz
		bm._fill_panel()
		t0 = bm._build_info.text if bm._build_info != null else "geen label"
		_check("aanbouwlabel bestaat en toont tijd", bm._build_info != null and t0.begins_with("In aanbouw: nog "))
	if frames == 8 + 120:
		var t1: String = bm._build_info.text if bm._build_info != null else "geen label"
		_check("aanbouwlabel telt af (" + t0 + " -> " + t1 + ")", t1 != t0)
	if frames == 8 + 60 * 22:
		_check("paneel springt om als het gebouw klaar is", bm._build_b == null and not g.builds.under_construction(kz))
		g.build_mode = false
	if frames == 8 + 60 * 60:
		vehicles = gar.fleet.filter(func(v): return is_instance_valid(v))
		print("fleet ", gar.fleet.size(), " order ", gar.order.size(), " fase ", gar.phase)
		_check("drie jeeps zijn uitgereden", vehicles.size() == 3)
		var min_d := 99.0
		for i in vehicles.size():
			for j in range(i + 1, vehicles.size()):
				min_d = minf(min_d, vehicles[i].global_position.distance_to(vehicles[j].global_position))
		print("kleinste afstand tussen jeeps: ", snappedf(min_d, 0.1))
		_check("jeeps staan niet in elkaar (afstand > 2 m)", min_d > 2.0)
		print("klaar, fouten: ", fails)
		quit(1 if fails > 0 else 0)
	return false
