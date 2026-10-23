extends SceneTree
## Schermafbeeldingen van de straatset in het spel: een proefwijk met alle wegdelen (ook gedraaid en gespiegeld),
## gezien met de spelcamera en in de stadseditor recht van boven.
## xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver vulkan --path . -s tests/straat_foto.gd --fixed-fps 60

var main: Node
var frames := 0
var game: Node
var ed
var Stad


func _initialize() -> void:
	Stad = load("res://scripts/stad.gd")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	physics_frame.connect(func(): if frames > 3: game.move = Vector2.ZERO)


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("/tmp/claude-0/straat_%s.png" % name)
	print("foto ", name)


func _process(_d: float) -> bool:
	frames += 1
	game = root.get_node("Game")
	if frames == 3:
		main.begin()
		for n in root.find_children("*", "", true, false):
			if n.get_script() and String(n.get_script().resource_path).ends_with("touch_sticks.gd"):
				n.set_process(false)
		for m in get_nodes_in_group("menus"):
			m._show("")
	if frames == 10:
		# proefwijk: hoofdstraat met zebrapad en kruispunt, bocht, T, steeg, stoep en plein
		var lines: Array = [
			["weg_recht", 0, -96, 0, 0], ["weg_zebra", 0, -102, 0, 0], ["weg_kruis", 0, -108, 0, 0], ["weg_recht", 0, -114, 0, 0],
			["plein", 0, -123, 0, 0],
			["weg_recht", 6, -108, 1, 0], ["weg_t", 12, -108, 3, 0], ["weg_recht", 18, -108, 1, 0], ["weg_bocht", 24, -108, 2, 0],
			["weg_recht", 24, -102, 0, 0], ["weg_steeg", 12, -114, 0, 0], ["weg_bocht", 12, -120, 1, 1],
			["weg_recht", -6, -108, 1, 0], ["weg_bocht", -12, -108, 3, 0], ["weg_recht", -12, -102, 0, 0],
			["stoep", 6, -102, 0, 0], ["stoep", -6, -102, 0, 0], ["stoep", 6, -114, 0, 0],
			["lantaarn", 6, -102, 0, 0], ["bankje", -6, -102, 0, 0], ["auto", 1, -95, 0, 0],
		]
		Stad.current.set_items(Stad.from_lines(lines))
	if frames == 120:
		game.player.global_position = Vector3(1.5, 0, -100.0)
		game.player.face = PI
	if frames == 220:
		_shot("spel")
		game.player.global_position = Vector3(8.0, 0, -112.0)
	if frames == 300:
		_shot("spel2")
		ed = root.find_children("*", "Control", true, false).filter(func(n): return n.get_script() and String(n.get_script().resource_path).ends_with("stad_editor.gd"))[0]
		ed.enter()
		game.ecam = Vector3(6.0, -110.0, 1.4)
	if frames == 400:
		_shot("editor")
		var n := 0
		for s in Stad.current._roads.mesh.get_surface_count():
			n += Stad.current._roads.mesh.surface_get_array_len(s)
		print("wegen: ", Stad.current._roads.mesh.get_surface_count(), " vlakken, ", n, " hoekpunten")
		return true
	return false
