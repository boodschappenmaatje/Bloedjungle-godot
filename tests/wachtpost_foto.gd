extends SceneTree
## Slagboom en wachthuisje in de echte spelcamera: noordpoort dicht en open, en de zuidpoort heel en kapot. WACHTPOST_OUT = uitvoermap.
## BJ_TOUCH=1 xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver vulkan --path . -s tests/wachtpost_foto.gd --resolution 1280x590 --fixed-fps 60
var main: Node
var game: Node
var frames := 0
var out := "/tmp/wachtpost"


func _initialize() -> void:
	if OS.get_environment("WACHTPOST_OUT") != "":
		out = OS.get_environment("WACHTPOST_OUT")
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _shot(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(out + "/" + name + ".png")


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
		game.prep_t = 9999.0
	if frames >= 10 and game.player != null:
		var z := -(Data.COMPOUND - 6.0) if frames < 330 else (Data.COMPOUND - 6.0)
		game.player.global_position = Vector3(0, 0, z)
	if frames >= 130 and frames < 330:
		game.gates.list[0].open = 1.0
	if frames == 120:
		_shot("noord_dicht")
	if frames == 300:
		_shot("noord_open")
	if frames == 420:
		_shot("zuid_dicht")
	if frames == 440:   # de zuidpoort: huisje en slagboom kapot geschoten
		for n in main.get_children():
			if n.get_script() and String(n.get_script().resource_path).ends_with("wachtpost.gd"):
				n.damage(n.posts[1], "hut", 9999.0, "explosive")
				n.damage(n.posts[1], "boom", 9999.0, "explosive")
	if frames == 560:
		_shot("zuid_kapot")
	return frames > 565
