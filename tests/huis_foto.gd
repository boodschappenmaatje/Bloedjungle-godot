extends SceneTree
## Schermafbeeldingen van het woonhuis in het spel (buiten, binnen beneden, boven, na sloop).
## xvfb-run -a -s "-screen 0 720x1280x24" godot --rendering-driver vulkan --path . -s tests/huis_foto.gd --fixed-fps 60

var main: Node
var frames := 0
var game: Node
var huis
var shots := ["buiten", "binnen", "boven", "sloop"]


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	physics_frame.connect(func(): if frames > 3: game.move = Vector2.ZERO)


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("/tmp/claude-0/huis_%s.png" % name)
	print("foto ", name)


func _process(_d: float) -> bool:
	frames += 1
	game = root.get_node("Game")
	if frames == 3:
		main.begin()
		for n in root.find_children("*", "", true, false):
			if n.get_script() and String(n.get_script().resource_path).ends_with("touch_sticks.gd"):
				n.set_process(false)
		huis = get_nodes_in_group("huis")[0]
		for m in get_nodes_in_group("menus"):
			m._show("")
		game.player.global_position = Data.HUIS_POS + Vector3(1.0, 0, 6.5)
		game.player.face = PI
	if frames == 3 + 90:
		_shot("buiten")
		game.player.global_position = Data.HUIS_POS + Vector3(-0.5, 0.3, 1.5)
	if frames == 3 + 150:
		_shot("binnen")
		game.player.global_position = Data.HUIS_POS + Vector3(1.5, 3.2, -2.0)
		game.player.position.y = 3.2
	if frames == 3 + 210:
		_shot("boven")
		game.player.global_position = Data.HUIS_POS + Vector3(-2.0, 0, 8.0)
		game.player.position.y = 0.0
		for x in [-3.0, 1.0, 3.0]:
			huis.blast(Data.HUIS_POS + Vector3(x, 1.4, 4.2), 2.2, 160.0)
		huis.blast(Data.HUIS_POS + Vector3(-1.0, 4.5, 4.2), 2.2, 90.0)
		huis.blast(Data.HUIS_POS + Vector3(4.5, 4.5, -1.0), 2.2, 90.0)
	if frames == 3 + 330:
		_shot("sloop")
		return true
	return false
