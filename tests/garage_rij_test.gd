extends SceneTree
## Garagerij (Generals-plan stap 2b): kopen zet een wagen in de rij, annuleren geeft de punten terug,
## in het bouwscherm blijft de rij staan en daarna rijdt de wagen uit.
## godot --headless --path . -s tests/garage_rij_test.gd --fixed-fps 60

var main: Node
var frames := 0
var fails := 0
var gar: Variant


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
		g.build_mode = true
		var p0: int = g.points
		b.buy_vehicle(gar, "jeep")
		b.buy_vehicle(gar, "tank")
		b.buy_vehicle(gar, "jeep")
		_check("tweede jeep mag, rij heeft 3 wagens", gar.order.size() == 3 and gar.order.count("jeep") == 2)
		_check("rij is vol bij 3 wagens", not b.can_buy_vehicle(gar, "truck"))
		b.cancel_order(gar, "tank")
		b.cancel_order(gar, "jeep")
		_check("annuleren laat een jeep over", gar.order == ["jeep"] and gar.has["tank"] == 0 and gar.has["jeep"] == 1)
		_check("punten kloppen na annuleren", g.points == p0 - 400)
		_check("rijbalk boven de garage", gar.rij != null)
	if frames == 8 + 120:
		_check("in het bouwscherm rijdt niets uit", gar.order.size() == 1 and gar.phase == "idle")
		root.get_node("Game").build_mode = false
	if frames == 8 + 120 + 90:
		_check("na het bouwscherm rijdt de jeep uit", gar.order.is_empty() and gar.phase != "idle")
		print("klaar, fouten: ", fails)
		quit(1 if fails > 0 else 0)
	return false
