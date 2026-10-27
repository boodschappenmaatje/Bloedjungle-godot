extends SceneTree
## Wachten op de basis in de echte spelcamera: patrouille in de pauze (links) en na het alarm bij hun post (rechts).
## PATROUILLE_OUT = uitvoermap.
## BJ_TOUCH=1 xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver vulkan --path . -s tests/patrouille_foto.gd --resolution 1280x590 --fixed-fps 60
var main: Node
var game: Node
var frames := 0
var out := "/tmp/patrouille"
var pat


func _initialize() -> void:
	if OS.get_environment("PATROUILLE_OUT") != "":
		out = OS.get_environment("PATROUILLE_OUT")
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
		game.prep_t = 9999.0
	if frames >= 20 and pat != null and pat.guards.size() > 0:
		game.player.global_position = (pat.guards[0] as Node3D).global_position + Vector3(0, 0, 4.5)   # de camera volgt de eerste wacht
	if frames == 20:
		for n in main.get_children():
			if n.get_script() and String(n.get_script().resource_path).ends_with("patrouille.gd"):
				pat = n
	if frames == 400 or frames == 520 or frames == 700:
		root.get_viewport().get_texture().get_image().save_png(out + "/patrouille_%d.png" % frames)
	if frames == 540:
		main.start_wave()
	if frames == 900:
		root.get_viewport().get_texture().get_image().save_png(out + "/alarm.png")
	return frames > 905
