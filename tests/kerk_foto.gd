extends SceneTree
## Schermafbeeldingen van de kerk met flat in het spel (buiten, in de kerk, flat 2, helemaal ingestort).
## xvfb-run -a -s "-screen 0 720x1280x24" godot --rendering-driver vulkan --path . -s tests/kerk_foto.gd --fixed-fps 60

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
	img.save_png("/tmp/claude-0/kerk_%s.png" % name)
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
		game.player.global_position = Data.KERK_POS + Vector3(1.0, 0, 18.0)
		game.player.face = PI
	if frames == 200:
		huis = get_nodes_in_group("kerk")[0]   # in het spel wordt de wereld in stappen gebouwd
		_shot("buiten")
		game.player.global_position = Data.KERK_POS + Vector3(-1.48, 0.3, 8.9)
	if frames == 260:
		_shot("binnen")
		game.player.global_position = Data.KERK_POS + Vector3(0.0, 11.1, 7.0)
		game.player.position.y = 11.1
	if frames == 320:
		_shot("boven")
		game.player.global_position = Data.KERK_POS + Vector3(-2.0, 0, 18.0)
		game.player.position.y = 0.0
		for z in [2.4, -0.9, -4.1]:
			for x in [-5.3, 5.3]:
				for k in 3:
					huis.blast(Data.KERK_POS + Vector3(x, 3.0, z), 2.2, 120.0)
		for k in 3:
			huis.blast(Data.KERK_POS + Vector3(0, 9.3, 10.1), 2.2, 120.0)
			huis.blast(Data.KERK_POS + Vector3(-3.1, 9.3, 7.0), 2.2, 120.0)
	if frames == 440:
		_shot("sloop")
		return true
	return false
