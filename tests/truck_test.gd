extends SceneTree
## Test: truck uit de garage, 8 soldaten klimmen erin, rijden, zeil dicht en open, en weer uitstappen.
## Draaien: godot --headless --path . -s tests/truck_test.gd --fixed-fps 60

var main: Node
var game: Node
var frames := 0
var truck: Node
const S := 60


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _states() -> String:
	var out := {}
	for a in truck._riders:
		var st: String = truck._riders[a].st
		out[st] = out.get(st, 0) + 1
	return str(out)


func _process(_d: float) -> bool:
	frames += 1
	game = root.get_node("Game")
	if frames == 3:
		main.begin()
		game.points = 9000
		game.build_credit = 9000 if "build_credit" in game else 0
		var r = game.builds.place("garage", Vector3(-8.6, 0, -6), 0.0)
		print("garage: ", r != null)
		var b: Dictionary = game.buildings.back()
		game.builds.buy_vehicle(b, "truck")
		for i in 8:
			var a = load("res://scripts/ally.gd").new()
			game.builds.add_child(a)
			a.global_position = Vector3(4 + i * 1.5, 0, 8)
			a.setup(100.0, 16.0, game.allies.size())
			game.allies.append(a)
		for n in main.find_children("*", "", true, false):
			if n is TouchSticks:
				n.set_process(false)
				n.set_physics_process(false)
	if frames == 3 + S * 8:
		for n in game.builds.get_children():
			if n.get_script() and String(n.get_script().resource_path).ends_with("vrachtwagen.gd"):
				truck = n
		print("truck: ", truck != null, " goals ", truck.goals.size() if truck else -1, " pos ", truck.global_position if truck else Vector3.ZERO)
		game.player.global_position = truck.global_position + Vector3(2, 0, 0)
		truck._toggle()
		print("bestuurd: ", truck.driven, " motor ", truck._engine, " riders ", truck._riders.size())
	if frames > 3 + S * 8 and frames % (S * 2) == 0 and frames < 3 + S * 30 and truck:
		print("t=", frames / S, " motor ", truck._engine, " klep ", truck._klep_open, " ", _states())
	if frames == 3 + S * 30:
		print("na laden: ", _states())
		game.move = Vector2(0, -1)
	if frames > 3 + S * 30 and frames < 3 + S * 36:
		game.move = Vector2(0.3, -1)
	if frames == 3 + S * 36:
		game.move = Vector2.ZERO
		print("gereden, snelheid ", truck._speed, " versnelling ", truck._gear, " pos ", truck.global_position)
		truck._zeil_button()
	if frames == 3 + S * 39:
		print("zeil dicht: ", truck._zeil_dicht, " dak schaal ", truck.get_node("Model/Vrachtwagen/Body/Zeil/ZeilDak").scale)
		truck._zeil_button()
		truck._toggle()
	if frames == 3 + S * 42:
		print("uitstappen bezig: ", _states())
	if frames == 3 + S * 52:
		print("na uitstappen: ", _states(), " riders ", truck._riders.size(), " motor ", truck._engine)
		var ok := 0
		for a in game.allies:
			if a.truck == null and a.position.y < 0.05:
				ok += 1
		print("weer op de grond: ", ok)
		quit()
	return false
