extends SceneTree
## Schermafbeelding van de grote kaart met gebieden en een bevel.
## xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver vulkan --path . -s tests/stad_kaart_foto.gd --fixed-fps 60

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
	img.save_png("/tmp/claude-0/kaart_%s.png" % name)
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
	if frames == 100:
		game.player.global_position = Vector3(1.5, 0, -60.0)
		for i in 3:
			var a = load("res://scripts/ally.gd").new()
			main.add_child(a)
			a.global_position = Vector3(float(i) - 1.0, 0, -62)
			a.setup(100.0, 40.0, i)
			game.allies.append(a)
	if frames == 140:
		game.gebieden.state.kade.cleared = true
		game.set_order("woonwijk", "aanval")
		var k = main.get_node("Hud").find_children("*", "Kaart", true, false)[0]
		k.open()
		k.selected = "woonwijk"
		k._refresh()
	if frames == 200:
		_shot("kaart")
		return true
	return false
