extends SceneTree
## Voor/na van de soldaatmarkeringen in de echte spelcamera, zelfde plek en licht: ZICHT_MODE=off (voor) of on (na).
## ZICHT_OUT = uitvoermap. Spelcamera's Gevecht en Tactisch na elkaar.
## ZICHT_MODE=on ZICHT_OUT=/tmp/zicht BJ_TOUCH=1 xvfb-run -a -s "-screen 0 1280x590x24" godot --rendering-driver vulkan --path . -s tests/zichtbaar_foto.gd --resolution 1280x590 --fixed-fps 60
var main: Node
var game: Node
var frames := 0
var out := "/tmp/zicht"
var mode := "on"
var cam: Camera3D


func _initialize() -> void:
	if OS.get_environment("ZICHT_OUT") != "":
		out = OS.get_environment("ZICHT_OUT")
	if OS.get_environment("ZICHT_MODE") != "":
		mode = OS.get_environment("ZICHT_MODE")
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_d: float) -> bool:
	frames += 1
	game = root.get_node("Game")
	if frames == 3:
		main.begin()
		for m in get_nodes_in_group("menus"):
			m._show("")
		for n in root.find_children("*", "", true, false):
			if n.get_script() and String(n.get_script().resource_path).ends_with("touch_sticks.gd"):
				n.set_process(false)
		for c in main.find_children("*", "CanvasLayer", true, false):
			c.visible = false
		GameSettings.set_value("time", "day")
		GameSettings.values["markeringen"] = mode
		game.prep_t = 9999.0
		cam = root.find_children("*", "Camera3D", true, false)[0]
	if frames == 10:
		var base: Vector3 = game.player.global_position
		var spots := [[Vector3(-5.5, 0, -8.0), "rifle", 0.4], [Vector3(4.5, 0, -9.0), "heavy", -0.3], [Vector3(8.0, 0, 2.0), "knife", 1.9]]
		for s in spots:
			var e: Node3D = main.ENEMY.instantiate()
			e.setup(s[1], 1)
			main.add_child(e)
			e.global_position = base + s[0]
			e.rotation.y = s[2]
			e.set_physics_process(false)
			e.model.play("lopen")
		var ally := Node3D.new()
		main.add_child(ally)
		ally.global_position = base + Vector3(-4.0, 0, 3.0)
		var am := SoldierModel.new()
		ally.add_child(am)
		am.setup(Color("5a6a36"), "thompson")
		am.scale = Vector3.ONE * Data.SOLDIER_SCALE
		am.play("stil")
	if frames == 30:
		cam.combat_view = true
	if frames == 200:
		root.get_viewport().get_texture().get_image().save_png(out + "/%s_gevecht.png" % mode)
	if frames == 201:
		cam.combat_view = false
	if frames == 380:
		root.get_viewport().get_texture().get_image().save_png(out + "/%s_tactisch.png" % mode)
	return frames > 382
