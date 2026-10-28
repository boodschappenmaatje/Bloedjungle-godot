extends SceneTree
## Regression for vehicle factories called while building the city and for opening its editor.

var main: Node
var frames := 0
var failures: Array[String] = []


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error("STAD VEHICLE FACTORY TEST: " + message)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 3:
		main.begin()
	if frames == 10:
		var menus := get_nodes_in_group("menus")
		_check(not menus.is_empty(), "main menu was not created")
		if menus.is_empty():
			quit(1)
			return true
		menus[0]._open_stad_editor()
		var stad_script = load("res://scripts/stad.gd")
		var stad = stad_script.current
		_check(stad != null, "opening the editor did not retain the active city")
		_check(bool(root.get_node("Game").get("editing")), "opening the editor did not enable editor mode")
		if stad != null:
			var items: Array = stad_script.from_lines([
				["auto", 0, -96, 0, 0],
				["autowrak", 16, -96, 0, 0],
				["bus", 32, -96, 0, 0],
				["buswrak", 48, -96, 0, 0],
			])
			stad.set_items(items)
			_check(items.size() == 4, "vehicle test items were filtered out")
			for item in items:
				var expected_script = load("res://scripts/auto.gd") if String(item.k).begins_with("auto") else load("res://scripts/bus.gd")
				_check(item.node != null and item.node.is_inside_tree(), "%s factory returned no in-tree node" % item.k)
				_check(item.node != null and item.node.get_script() == expected_script, "%s factory returned the wrong vehicle class" % item.k)
		if failures.is_empty():
			print("STAD VEHICLE FACTORY TEST PASS: Auto.make, Bus.make and stadseditor")
		quit(1 if not failures.is_empty() else 0)
		return true
	return false
