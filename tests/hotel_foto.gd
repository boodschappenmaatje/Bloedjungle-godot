extends SceneTree
## Schermafbeeldingen van het hotel in het spel (buiten, lobby, kamer op verdieping 2, na de sloop).
## xvfb-run -a -s "-screen 0 720x1280x24" godot --rendering-driver vulkan --path . -s tests/hotel_foto.gd --fixed-fps 60

var main: Node
var frames := 0
var game: Node
var huis


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	physics_frame.connect(func(): if frames > 3: game.move = Vector2.ZERO)


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("/tmp/claude-0/hotel_%s.png" % name)
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
		game.player.global_position = Data.HOTEL_POS + Vector3(-1.0, 0, 12.0)
		game.player.face = PI
	if frames == 200:
		huis = get_nodes_in_group("hotel")[0]
		_shot("buiten")
		game.player.global_position = Data.HOTEL_POS + Vector3(1.0, 0.3, -1.5)
		game.player.position.y = 0.3
	if frames == 280:
		_shot("lobby")
		game.player.global_position = Data.HOTEL_POS + Vector3(1.0, 6.8, 1.5)
		game.player.position.y = 6.8
	if frames == 360:
		_shot("kamer")
		game.player.global_position = Data.HOTEL_POS + Vector3(-1.0, 0.0, 14.0)
		game.player.position.y = 0.0
		for p in [Vector3(-3.4, 8.3, 5.1), Vector3(0, 8.3, 5.1), Vector3(3.4, 8.3, 5.1), Vector3(-3.4, 8.3, -5.1), Vector3(5.1, 8.3, 0.0)]:
			for k in 5:
				huis.blast(Data.HOTEL_POS + p, 2.4, 160.0)
	if frames == 440:
		_shot("sloop")
		for p in [Vector3(-3.4, 1.6, 5.1), Vector3(0, 1.6, 5.1), Vector3(3.4, 1.6, 5.1), Vector3(5.1, 1.6, -2.5), Vector3(5.1, 1.6, 0), Vector3(-3.4, 1.6, -5.1), Vector3(0, 1.6, -5.1)]:
			for k in 5:
				huis.blast(Data.HOTEL_POS + p, 2.4, 160.0)
	if frames == 560:
		_shot("ruine")
		return true
	return false
