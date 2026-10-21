extends SceneTree
## Test: de speler kan over de brug en de ondiepte het noorden in, maar niet dwars door de rivier. Draaien: godot --headless --path . -s tests/rivier_test.gd

var main: Node
var frames := 0
var game: Node
var phase := 0
var start := Vector3.ZERO


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	physics_frame.connect(func(): if frames > 3: game.move = Vector2(0, -1))


func _process(_d: float) -> bool:
	frames += 1
	game = root.get_node("Game")
	if frames == 3:
		main.begin()
		_go(Vector3(0.0, 0.0, Data.river_z(0.0) + 14.0))
	if frames > 3 and frames % 240 == 0:
		var p: Vector3 = game.player.global_position
		var zr: float = Data.river_z(p.x)
		print("fase ", phase, " pos ", p.snapped(Vector3(0.1, 0.1, 0.1)), " rivier-z ", snappedf(zr, 0.1))
		phase += 1
		if phase == 1:
			_go(Vector3(10.0, 0.0, Data.river_z(10.0) + 14.0))      # dwars door de rivier zonder brug
		elif phase == 2:
			_go(Vector3(Data.FORD_X, 0.0, Data.river_z(Data.FORD_X) + 14.0))  # ondiepte
		elif phase == 3:
			quit()
	return false


func _go(p: Vector3) -> void:
	game.player.global_position = p
	game.player.velocity = Vector3.ZERO
