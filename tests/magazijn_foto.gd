extends SceneTree
## Schermafbeeldingen van het magazijn in het spel (buiten, op de buitentrap, op het dak, binnen, bij de zijdeur, deuren dicht, na de sloop).
## xvfb-run -a -s "-screen 0 720x1280x24" godot --rendering-driver vulkan --path . -s tests/magazijn_foto.gd --fixed-fps 60

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
	img.save_png("/tmp/claude-0/magazijn_%s.png" % name)
	print("foto ", name)


func _to(lp: Vector3) -> void:
	game.player.global_position = huis.to_global(lp)
	game.player.position.y = huis.position.y + lp.y


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
		huis = get_nodes_in_group("magazijn")[0]
		_to(Vector3(3.0, 0.0, 10.0))
		game.player.face = PI
	if frames == 200:
		_shot("buiten")
		_to(Vector3(6.75, 2.6, 0.2))
	if frames == 280:
		_shot("trap")
		_to(Vector3(2.0, 5.3, -1.0))
	if frames == 360:
		_shot("dak")
		_to(Vector3(0.0, 0.21, 0.5))
	if frames == 440:
		_shot("binnen")
		_to(Vector3(-7.2, 0.0, 3.0))
	if frames == 520:
		_shot("zijdeur")
		_to(Vector3(-10.0, 0.0, 9.0))
	if frames == 580:
		_shot("dicht")
		_to(Vector3(0.0, 0.0, 12.0))
		for p in [Vector3(-5, 1.6, 4.2), Vector3(-3, 1.6, 4.2), Vector3(3, 1.6, 4.2), Vector3(5, 1.6, 4.2), Vector3(6.3, 1.6, 1.0)]:
			for k in 6:
				huis.blast(huis.to_global(p), 2.0, 200.0)
	if frames == 660:
		_shot("sloop")
		return true
	return false
