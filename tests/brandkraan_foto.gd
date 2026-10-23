extends SceneTree
## Schermafbeeldingen: brandkraan die opengaat (dag), en de straat met brandende lantaarns (nacht).
## xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --path . -s tests/brandkraan_foto.gd --fixed-fps 60

var main: Node
var frames := 0
var game: Node
var Stad
var kraan


func _initialize() -> void:
	Stad = load("res://scripts/stad.gd")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	physics_frame.connect(func(): if frames > 3: game.move = Vector2.ZERO)


func _shot(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("/tmp/claude-0/kraan_%s.png" % name)
	print("foto ", name)


func _process(_d: float) -> bool:
	frames += 1
	game = root.get_node("Game")
	if frames == 6:
		GameSettings.set_value("time", "day")
		for a in get_nodes_in_group("atmosphere"):
			a.apply_settings()
	if frames == 3:
		main.begin()
		for n in root.find_children("*", "", true, false):
			if n.get_script() and String(n.get_script().resource_path).ends_with("touch_sticks.gd"):
				n.set_process(false)
		for m in get_nodes_in_group("menus"):
			m._show("")
	if frames == 10:
		var lines: Array = [
			["weg_recht", 0, -96, 0, 0], ["weg_recht", 0, -102, 0, 0], ["weg_recht", 0, -108, 0, 0],
			["stoep", 6, -96, 0, 0], ["stoep", -6, -96, 0, 0], ["stoep", 6, -102, 0, 0], ["stoep", -6, -102, 0, 0], ["stoep", 6, -108, 0, 0], ["stoep", -6, -108, 0, 0],
			["lantaarn", 3.4, -97, 0, 0], ["lantaarn", -3.4, -103, 0, 0], ["lantaarn", 3.4, -109, 0, 0],
			["brandkraan", -3.6, -99, 0, 0], ["bankje", 5, -104, 1, 0], ["bushokje", -6.5, -106, 0, 0],
		]
		Stad.current.set_items(Stad.from_lines(lines))
		for d in Stad.current.items:
			if d.k == "brandkraan":
				kraan = d.node
	if frames == 100:
		game.player.global_position = Vector3(1.0, 0, -99.0)
		game.player.face = PI
	if frames == 160:
		_shot("dicht")
		kraan.burst()
	if frames == 190:
		_shot("spuit_a")   # 0,5 s: dop vliegt
	if frames == 260:
		_shot("spuit_b")   # 1,7 s
	if frames == 420:
		_shot("spuit_c")   # lus
		GameSettings.set_value("time", "night")
		for a in get_nodes_in_group("atmosphere"):
			a.apply_settings()
	if frames == 520:
		_shot("nacht")
		GameSettings.set_value("time", "day")
		return true
	return false
