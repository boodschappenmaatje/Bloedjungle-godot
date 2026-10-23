extends SceneTree
## Schermafbeeldingen van het benzinestation in het spel (buiten, onder de luifel, in de winkel, na de kettingreactie).
## xvfb-run -a -s "-screen 0 720x1280x24" godot --rendering-driver vulkan --path . -s tests/benzine_foto.gd --fixed-fps 60

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
	img.save_png("/tmp/claude-0/benzine_%s.png" % name)
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
		game.player.global_position = Data.BENZINE_POS + Vector3(-1.0, 0, 11.0)
		game.player.face = PI
	if frames == 200:
		huis = get_nodes_in_group("benzine")[0]   # in het spel wordt de wereld in stappen gebouwd
		_shot("buiten")
		game.player.global_position = Data.BENZINE_POS + Vector3(0.0, 0, 2.8)
	if frames == 260:
		_shot("luifel")
		game.player.global_position = Data.BENZINE_POS + Vector3(0.8, 0.2, -1.0)
		game.player.position.y = 0.2
	if frames == 320:
		_shot("binnen")
		game.player.global_position = Data.BENZINE_POS + Vector3(-1.0, 0, 13.0)
		game.player.position.y = 0.0
		var p = huis.pumps.filter(func(x): return String(x.get_parent().name).begins_with("XPomp"))[0]
		p.hit(100.0, Vector3(1, 0, 0), true)
	if frames == 345:
		_shot("boem")
	if frames == 420:
		_shot("brand")
	if frames == 700:
		_shot("ruine")
		return true
	return false
