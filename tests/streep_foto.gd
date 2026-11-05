extends SceneTree
## Diagnose flikkerende streep: echte game, standaard instellingen (kwaliteit Hoog), speler loopt
## langs de westmuur en slaat een reeks frames op. STREEP_OUT = uitvoermap, STREEP_MODE = proefschakelaar.
## xvfb-run -a -s "-screen 0 1434x660x24" godot --rendering-driver vulkan --path . -s tests/streep_foto.gd --resolution 1434x660
var main: Node
var frames := 0
var out := "/tmp/streep"
var mode := ""
var shot := 0


func _initialize() -> void:
	if OS.get_environment("STREEP_OUT") != "":
		out = OS.get_environment("STREEP_OUT")
	mode = OS.get_environment("STREEP_MODE")
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _apply_mode() -> void:
	match mode:
		"noshadow":
			for n in root.find_children("*", "DirectionalLight3D", true, false):
				n.shadow_enabled = false
		"nowallshadow":
			for n in get_nodes_in_group("base_wall_shadow"):
				n.visible = false
		"nowall":
			for n in get_nodes_in_group("base_wall_shadow") + get_nodes_in_group("base_wall_visual"):
				n.visible = false
		"nossao":
			for n in root.find_children("*", "WorldEnvironment", true, false):
				n.environment.ssao_enabled = false


func _process(_d: float) -> bool:
	frames += 1
	var game: Node = root.get_node("Game")
	if frames == 3:
		main.begin()
		for m in get_nodes_in_group("menus"):
			m._show("")
		game.prep_t = 9999.0
	if frames == 20:
		_apply_mode()
	if frames >= 5 and game.player:
		var t := clampf((frames - 60) / 240.0, 0.0, 1.0)
		game.player.global_position = Vector3(-16.0, game.player.global_position.y, lerpf(14.0, -6.0, t))
	if frames >= 60 and frames % 6 == 0 and frames <= 300:
		root.get_viewport().get_texture().get_image().save_png(out + "/f_%03d.png" % shot)
		shot += 1
	return frames > 302
