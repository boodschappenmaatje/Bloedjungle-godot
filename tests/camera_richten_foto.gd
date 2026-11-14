extends SceneTree
## Foto's van de third-personcamera tijdens lopen, richten en schieten (v232): dezelfde plek, camera blijft op afstand.
## FOTO_DIR=/pad VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 932x430x24" godot --rendering-driver vulkan --resolution 932x430 --path . -s tests/camera_richten_foto.gd --fixed-fps 60

var main: Node
var frames := 0
var game: Node
var cam: Camera3D
var dir := OS.get_environment("FOTO_DIR") if OS.get_environment("FOTO_DIR") != "" else "/tmp"
var aim_hold := NAN
var fire_hold := false


func _initialize() -> void:
	GameSettings.set_value("weather", "clear")
	GameSettings.set_value("time", "day")
	GameSettings.set_value("camera_view", "third")
	load("res://scripts/data.gd").set("mcv_autodeploy", true)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	physics_frame.connect(func():
		if frames > 3 and game != null:
			game.move = Vector2.ZERO
			game.aim = aim_hold
			game.fire = fire_hold)


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [dir, name])
	var p: Node3D = game.player
	var d := Vector2(cam.global_position.x - p.global_position.x, cam.global_position.z - p.global_position.z).length()
	print("foto ", name, " afstand_camera_soldaat=%.2f hoogte_scherm=%.2f" % [d, cam.unproject_position(p.global_position + Vector3.UP).y / float(root.get_visible_rect().size.y)])


func _process(_d: float) -> bool:
	frames += 1
	game = root.get_node("Game")
	if frames == 2:
		for n in main.get_children():
			if n.get_script() and String(n.get_script().resource_path).ends_with("patrouille.gd"):
				n.queue_free()
	if frames == 3:
		main.begin()
		for n in root.find_children("*", "", true, false):
			if n.get_script() and String(n.get_script().resource_path).ends_with("touch_sticks.gd"):
				n.set_process(false)
		for m in get_nodes_in_group("menus"):
			m._show("")
		cam = root.get_viewport().get_camera_3d()
	if frames >= 4:
		for g in ["mcv_opbouw", "mcv", "mcv_wagen"]:
			for n in get_nodes_in_group(g):
				n.queue_free()
	if frames > 3 and game.state == "prep":
		game.prep_t = 1e9
	match frames:
		60:
			game.player.global_position = Vector3(1.5, 0, -97.0)   # de brug, de straat erachter ligt noordwaarts
			game.player.face = PI
			cam.snap_to_player()
		180:
			_shot("richten_lopen")
			aim_hold = PI + 0.25
		240:
			_shot("richten_richten")
			fire_hold = true
		250:
			_shot("richten_schieten")
		252:
			return true
	return false
