extends SceneTree
## Schermafbeeldingen van de auto's in de stad met de echte spelcamera: heel, beschadigd, brandend, ontploffing in stappen, wrak.
## xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --path . -s tests/bus_foto.gd --fixed-fps 60
## Uitvoer: OUT/auto_*.png (OUT = omgevingsvariabele BUS_OUT, standaard /tmp/busfoto)

var main: Node
var frames := 0
var game: Node
var Stad
var cars: Array = []
var out := "/tmp/busfoto"
var f0 := 0


func _initialize() -> void:
	Stad = load("res://scripts/stad.gd")
	if OS.get_environment("BUS_OUT") != "":
		out = OS.get_environment("BUS_OUT")
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	physics_frame.connect(func(): if frames > 3: game.move = Vector2.ZERO)


func _shot(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("%s/bus_%s.png" % [out, name])
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
		GameSettings.set_value("time", "day")
		for a in get_nodes_in_group("atmosphere"):
			a.apply_settings()
	if frames == 10:
		var lines: Array = [
			["weg_recht", 0, -96, 0, 0], ["weg_recht", 0, -102, 0, 0], ["weg_recht", 0, -108, 0, 0], ["weg_recht", 0, -114, 0, 0], ["weg_recht", 0, -120, 0, 0], ["weg_recht", 0, -126, 0, 0], ["weg_recht", 0, -132, 0, 0],
			["stoep", 6, -96, 0, 0], ["stoep", -6, -96, 0, 0], ["stoep", 6, -102, 0, 0], ["stoep", -6, -102, 0, 0], ["stoep", 6, -108, 0, 0], ["stoep", -6, -108, 0, 0],
			["stoep", 6, -114, 0, 0], ["stoep", -6, -114, 0, 0],
			["bus", -1.4, -104.0, 0, 0], ["bus", 1.4, -118.0, 0, 0], ["bus", -1.4, -132.0, 0, 0], ["buswrak", 1.4, -102.0, 0, 0],
			["lantaarn", 3.6, -99, 0, 0], ["lantaarn", -3.6, -109, 0, 0],
		]
		Stad.current.set_items(Stad.from_lines(lines))
		for d in Stad.current.items:
			if d.k.begins_with("bus"):
				cars.append(d.node)
	if frames == 60:
		var cam = main.get_node("Camera")
		cam.combat_view = false
		cam.zoom_step = 0
		for c in main.find_children("*", "CanvasLayer", true, false):
			c.visible = false     # zonder HUD
		game.player.global_position = Vector3(5.5, 0, -118.0)
		game.player.face = PI * 0.5
	if frames == 140:
		_shot("heel")
		cars[0].take(Bus_hp(cars[0], 0.42))    # beschadigd: ruiten, banden, deur
		cars[1].take(Bus_hp(cars[1], 0.24))    # brandend
		cars[1]._fuse = 999.0
	if frames == 220:
		_shot("fases")
	if frames == 240:
		cars[2].take(Bus_hp(cars[2], 0.66))
	if frames == 330:
		_shot("fases2")
		cars[1]._fuse = 0.0   # laat de brandende auto ontploffen
		f0 = frames
	if f0 > 0 and frames == f0 + 6:
		_shot("boem_a")
	if f0 > 0 and frames == f0 + 22:
		_shot("boem_b")
	if f0 > 0 and frames == f0 + 55:
		_shot("boem_c")
	if f0 > 0 and frames == f0 + 130:
		_shot("boem_d")
	if f0 > 0 and frames == f0 + 330:
		_shot("wrak")
		GameSettings.set_value("time", "night")
		for a in get_nodes_in_group("atmosphere"):
			a.apply_settings()
	if f0 > 0 and frames == f0 + 420:
		_shot("nacht")
		return true
	return false


func Bus_hp(a, frac: float) -> float:
	return a.hp - a.HP * frac
