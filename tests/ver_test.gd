extends SceneTree
## Test: een vijand van voorbij de rivier loopt ver weg goedkoop (verborgen) en wordt weer gewoon vijand bij de basis. Draaien: godot --headless --path . -s tests/ver_test.gd --fixed-fps 60

var main: Node
var frames := 0
var e: Node


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_d: float) -> bool:
	frames += 1
	var game = root.get_node("Game")
	if frames == 3:
		main.begin()
	if frames == 10:
		e = load("res://scenes/enemy.tscn").instantiate()
		e.setup("rifle", 1)
		e.position = Vector3(0, 0, Data.river_z(0.0) - 14.0)
		main.add_child(e)
	if frames > 10 and frames % 300 == 0 and is_instance_valid(e):
		print("t ", (frames - 10) / 60, " pos ", e.position.snapped(Vector3(0.1, 0.1, 0.1)), " ver ", e._far, " zichtbaar ", e.model.visible)
	if frames > 3600:
		quit()
	return false
