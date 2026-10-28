extends SceneTree
## HUD 3.0 in de echte game: prep (BOUW/TEAM + plaatsingsbalk) en gevecht, liggend en staand. HUD3_OUT = uitvoermap, HUD3_TAG = naam.
## BJ_TOUCH=1 xvfb-run -a -s "-screen 0 932x430x24" godot --rendering-driver vulkan --path . -s tests/hud3_foto.gd --resolution 932x430 --fixed-fps 60
var main: Node
var game: Node
var frames := 0
var out := "/tmp/hud3"
var tag := "hud"


func _initialize() -> void:
	if OS.get_environment("HUD3_OUT") != "":
		out = OS.get_environment("HUD3_OUT")
	if OS.get_environment("HUD3_TAG") != "":
		tag = OS.get_environment("HUD3_TAG")
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
		GameSettings.set_value("time", "day")
		game.prep_t = 9999.0
		game.inv = {"bags": 3, "trench": 2, "mine": 2, "wire": 1, "sentry": 0}
		game.changed.emit()
	if frames == 120:
		root.get_viewport().get_texture().get_image().save_png(out + "/%s_prep.png" % tag)
	if frames == 121:
		main.start_wave()
	if frames == 260:
		root.get_viewport().get_texture().get_image().save_png(out + "/%s_gevecht.png" % tag)
	return frames > 262
