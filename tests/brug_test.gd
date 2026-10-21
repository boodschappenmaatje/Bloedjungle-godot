extends SceneTree
## Test: de ophaalbrug gaat omhoog en omlaag, sluit de rivier af als hij omhoog staat en vijanden nemen dan de ondiepte. Draaien: godot --headless --path . -s tests/brug_test.gd --fixed-fps 60

var main: Node
var frames := 0
var game: Node
var phase := 0
var sample := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	physics_frame.connect(func(): if frames > 3 and phase >= 1: game.move = Vector2(0, -1))


func _process(_d: float) -> bool:
	frames += 1
	game = root.get_node("Game")
	if frames == 3:
		main.begin()
		print("brug: ", game.bridge != null, " anim: ", game.bridge.anim != null, " klep-lampen ", game.bridge._lamp_g != null, game.bridge._lamp_r != null, " kastje ", game.bridge.box_pos())
		print("Klep rotatie bij start: ", game.bridge.model.find_child("Klep", true, false).rotation, " (verwacht x=0)")
		game.player.global_position = game.bridge.box_pos() + Vector3(0, 0, 1.0)
		print("dichtbij kastje: ", game.bridge.near_player())
		game.bridge.toggle()
		print("na toggle state ", game.bridge.state, " (1 = stijgt)")
	if frames == 3 + 60 * 5:
		print("na 5 s state ", game.bridge.state, " (2 = omhoog)")
		# loop naar de rivier toe bij de brug: moet geblokkeerd worden
		var z0: float = Data.river_z(0.0)
		game.player.global_position = Vector3(0.0, 0.0, z0 + 12.0)
		phase = 1
	if frames == 3 + 60 * 9:
		print("omhoog: speler z ", snappedf(game.player.global_position.z, 0.1), " rivier ", snappedf(Data.river_z(0.0), 0.1), " (geblokkeerd als z > rivier + 3)")
		var wp: Vector3 = Route.waypoint(Vector3(0, 0, Data.river_z(0.0) - 12.0), Vector3.ZERO)
		print("route vanuit het noorden bij brug omhoog: ", wp.snapped(Vector3(0.1, 0.1, 0.1)), " (x moet bij ondiepte ", Data.FORD_X, ")")
		phase = 0
		game.player.global_position = game.bridge.box_pos() + Vector3(0, 0, 1.0)
		game.bridge.toggle()
	if frames == 3 + 60 * 14:
		print("na omlaag state ", game.bridge.state, " (0 = omlaag)")
		var z0: float = Data.river_z(0.0)
		game.player.global_position = Vector3(0.0, 0.0, z0 + 12.0)
		phase = 1
	if frames == 3 + 60 * 18:
		print("omlaag: speler z ", snappedf(game.player.global_position.z, 0.1), " rivier ", snappedf(Data.river_z(0.0), 0.1), " (over de brug als z < rivier - 6)")
		quit()
	return false
