extends SceneTree
## Schermafbeeldingen van de Tiger in het spel met de echte spelcamera: stil, rijdend, koepel gedraaid, loop omhoog.
## xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --path . -s tests/tiger_foto.gd --fixed-fps 60
## Uitvoer: OUT/tiger_*.png (OUT = omgevingsvariabele TIGER_OUT, standaard /tmp/tigerfoto)

var main: Node
var frames := 0
var game: Node
var tank
var out := "/tmp/tigerfoto"


func _initialize() -> void:
	if OS.get_environment("TIGER_OUT") != "":
		out = OS.get_environment("TIGER_OUT")
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	physics_frame.connect(func(): if frames > 3: game.move = Vector2.ZERO)


func _shot(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("%s/tiger_%s.png" % [out, name])
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
		tank = (load("res://scenes/tank.tscn") as PackedScene).instantiate()
		main.add_child(tank)
		tank.global_position = Vector3(-6.0, 0, -4.0)
		game.player.global_position = Vector3(-6.0, 0, -4.0)
		game.player.face = PI
		var cam = main.get_node("Camera")
		cam.combat_view = false
		cam.zoom_step = int(OS.get_environment("TIGER_ZOOM")) if OS.get_environment("TIGER_ZOOM") != "" else 0
		for c in main.find_children("*", "CanvasLayer", true, false):
			if c != tank.get_child(-1):
				c.visible = false
	if frames == 120:
		_shot("stil")
		tank.goals = [tank.global_position + Vector3(8, 0, -6)]
	if frames == 200:
		_shot("rijdt")
		tank._toren.rotation.y = 1.1
		tank._loop.rotation.x = 0.18
	if frames == 260:
		_shot("toren_loop")
		return true
	return false
