extends SceneTree
## Schermafbeeldingen van de stadseditor (gebouwenpalet, wegen trekken).
## xvfb-run -a -s "-screen 0 1800x830x24" godot --rendering-driver vulkan --path . -s tests/stad_editor_foto.gd --fixed-fps 60

var main: Node
var frames := 0
var ed


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _shot(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("/tmp/claude-0/editor_%s.png" % name)
	print("foto ", name)


func _cells(list: Array) -> Array:
	var out: Array = []
	for c in list:
		out.append(Vector2i(c[0], c[1]))
	return out


func _process(_d: float) -> bool:
	frames += 1
	if frames == 3:
		main.begin()
		for n in root.find_children("*", "", true, false):
			if n.get_script() and String(n.get_script().resource_path).ends_with("touch_sticks.gd"):
				n.set_process(false)
		for m in get_nodes_in_group("menus"):
			m._show("")
	if frames == 150:
		ed = root.find_children("*", "Control", true, false).filter(func(n): return n.get_script() and String(n.get_script().resource_path).ends_with("stad_editor.gd"))[0]
		ed.enter()
		ed._pick_tab("gebouw")
	if frames == 230:
		_shot("gebouwen")
		ed._pick_tab("weg")
		ed._pick_kind("lijn")
		ed._line_cells = _cells([[5, -17], [6, -17], [7, -17], [7, -18]])
		ed._line_update()
	if frames == 330:
		_shot("lijn")
		return true
	return false
