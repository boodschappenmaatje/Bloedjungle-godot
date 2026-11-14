extends SceneTree
## Foto van de nieuwe vijandsoorten (v236): schild, granaatwerper met cirkel, flanker, gewone schutter.
## FOTO_DIR=/pad VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 932x430x24" godot --rendering-driver vulkan --resolution 932x430 --path . -s tests/vijandsoorten_foto.gd --fixed-fps 60
var main: Node
var frames := 0
var game: Node
var cam: Camera3D
var dir := OS.get_environment("FOTO_DIR") if OS.get_environment("FOTO_DIR") != "" else "/tmp"
var es := []


func _initialize() -> void:
	GameSettings.set_value("weather", "clear")
	GameSettings.set_value("time", "day")
	GameSettings.set_value("camera_view", "third")
	load("res://scripts/data.gd").set("mcv_autodeploy", true)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_d: float) -> bool:
	frames += 1
	game = root.get_node("Game")
	if frames == 3:
		main.begin()
		for m in get_nodes_in_group("menus"):
			m._show("")
		cam = root.get_viewport().get_camera_3d()
	if frames >= 4:
		for g in ["mcv_opbouw", "mcv", "mcv_wagen"]:
			for n in get_nodes_in_group(g):
				n.queue_free()
	if frames > 3 and game.state == "prep":
		game.prep_t = 1e9
	if frames == 60:
		var data = load("res://scripts/data.gd")
		var at := Vector3(data.path_x(-52.0) + 2.5, 0.0, -52.0)
		game.player.global_position = at
		game.player.face = PI
		cam.snap_to_player()
		var soorten := ["schild", "granaat", "", "flank"]
		for i in soorten.size():
			var e: Node3D = load("res://scenes/enemy.tscn").instantiate()
			e.setup("assault", 3)
			if soorten[i] == "schild" or soorten[i] == "granaat":
				e.set_soort(soorten[i])
			elif soorten[i] == "flank":
				e.soort = "flank"
			main.add_child(e)
			e.set_physics_process(false)
			e.global_position = at + Vector3(-6.0 + i * 4.0, 0.0, -11.0)
			e.face = PI
			e.rotation.y = PI
			es.append(e)
		es[1]._gooi_granaat(at + Vector3(0, 0, -6.0))
	if frames == 100:
		root.get_viewport().get_texture().get_image().save_png("%s/vijandsoorten.png" % dir)
		print("foto klaar")
		quit(0)
	return false
