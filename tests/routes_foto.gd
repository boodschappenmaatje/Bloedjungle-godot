extends SceneTree
## Schermafbeeldingen van de rode routepijlen in de pauze en tijdens de golf.
## xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver vulkan --path . -s tests/stad_routes_foto.gd --fixed-fps 60

var main: Node
var frames := 0
var game: Node
var ed


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	physics_frame.connect(func(): if frames > 3: game.move = Vector2.ZERO)


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("/tmp/claude-0/routes_%s.png" % name)
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
	if frames == 120:
		game.player.global_position = Vector3(1.5, 0, -90.0)
		game.player.face = PI
		game.routes = ["brug", "wijk"]
	if frames == 220:
		_shot("brug")
		game.player.global_position = Vector3(0.0, 0, -20.0)
		game.routes = ["brug", "kade", "moeras"]
	if frames == 320:
		_shot("basis")
		return true
	return false
