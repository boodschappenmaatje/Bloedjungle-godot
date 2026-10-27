extends SceneTree
## Generator in de echte spelcamera: heel, rokend, brandend, explosie en wrak. GENERATOR_OUT = uitvoermap.
## BJ_TOUCH=1 xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver vulkan --path . -s tests/generator_foto.gd --resolution 1280x590 --fixed-fps 60
var main: Node
var game: Node
var frames := 0
var out := "/tmp/generator"


func _initialize() -> void:
	if OS.get_environment("GENERATOR_OUT") != "":
		out = OS.get_environment("GENERATOR_OUT")
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
		game.player.global_position = Vector3(-17.0, 0, -10.0)
	var gen: Node
	for n in main.get_children():
		if n.get_script() and String(n.get_script().resource_path).ends_with("generator.gd"):
			gen = n
	if frames == 120:
		_shot("gen_heel")
	if frames == 150:
		gen.damage(gen.HP * 0.45, "explosive")   # rook
	if frames == 240:
		_shot("gen_rook")
	if frames == 250:
		gen.damage(gen.HP * 0.3, "explosive")    # vuur
	if frames == 340:
		_shot("gen_vuur")
	if frames == 350:
		gen.damage(9999.0, "explosive")
	if frames == 362:
		_shot("gen_explosie")
	if frames == 520:
		_shot("gen_wrak")
	return frames > 525
