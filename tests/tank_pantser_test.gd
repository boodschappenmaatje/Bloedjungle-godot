extends SceneTree
## Test: in de tank doen kogels en messen niets, een raket wel. Draaien: godot --headless --path . -s tests/tank_pantser_test.gd --fixed-fps 60

var main: Node
var frames := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_d: float) -> bool:
	frames += 1
	var game = root.get_node("Game")
	if frames == 3:
		main.begin()
		game.state = "play"
	if frames == 10:
		var p = game.player
		p.in_tank = true
		var hp0: float = p.hp
		p.hit(30.0, Vector3.FORWARD, false)
		print("na kogel: ", p.hp == hp0)
		p.hit(30.0, Vector3.FORWARD, false, true)
		print("na raket: ", p.hp < hp0)
		p.in_tank = false
		var hp1: float = p.hp
		p.hit(10.0, Vector3.FORWARD, false)
		print("te voet geraakt: ", p.hp < hp1)
		print("KLAAR")
		return true
	return false
