extends SceneTree
## Schermafbeelding van de fps-teller tijdens een golf (instelling "FPS-teller" aan).
## BJ_TOUCH=1 xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --path . -s tests/fps_foto.gd --resolution 932x430 --fixed-fps 60

var main: Node
var frames := 0


func _initialize() -> void:
	GameSettings.set_value("fps", "on")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_d: float) -> bool:
	frames += 1
	if frames == 3:
		main.begin()
		for m in get_nodes_in_group("menus"):
			m._show("")
	if frames == 60:
		main.start_wave()
	if frames == 200:
		root.get_viewport().get_texture().get_image().save_png("/tmp/claude-0/fps_spel.png")
		print("foto fps_spel")
		GameSettings.set_value("fps", "off")
		return true
	return false
