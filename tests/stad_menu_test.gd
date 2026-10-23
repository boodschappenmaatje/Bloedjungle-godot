extends SceneTree
## Test: de knop "Stadseditor" in het hoofdmenu start de wereld op en opent de editor meteen.
## Draaien: godot --headless --path . -s tests/stad_menu_test.gd --fixed-fps 60

var main: Node
var frames := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main


func _process(_d: float) -> bool:
	frames += 1
	var game := root.get_node("Game")
	if frames == 5:
		var menu = get_nodes_in_group("menus")[0]
		print("staat: ", game.state)
		menu._open_stad_editor()
	if frames == 60:
		print("editor open na menuknop: ", game.editing, " staat ", game.state)
		print("STAD MENU TEST KLAAR")
		quit()
		return true
	return false
