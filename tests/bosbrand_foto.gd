extends SceneTree
## Beelden van de bosbrand (scripts/bosbrand.gd) vanuit de spelcamera: aansteken, brandrand, doven en verschroeid gebied.
## G2=on|off FOTO_DIR=/pad BJ_TOUCH=1 VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1280x590x24" \
##   godot --rendering-driver vulkan --path . -s tests/bosbrand_foto.gd --fixed-fps 60

var main: Node
var frames := 0
var game: Node
var dir := OS.get_environment("FOTO_DIR") if OS.get_environment("FOTO_DIR") != "" else "/tmp"
var tag := "na" if OS.get_environment("G2") != "off" else "voor"
var spot := Vector3.ZERO
var jeep: Node3D


func _initialize() -> void:
	GameSettings.set_value("g2", "off" if tag == "voor" else "on")
	GameSettings.set_value("camera_pitch", "40")
	GameSettings.set_value("time", OS.get_environment("G2_TIJD") if OS.get_environment("G2_TIJD") != "" else "day")
	GameSettings.set_value("weather", "clear")
	load("res://scripts/data.gd").set("mcv_autodeploy", true)   # niet in de bouwwagen beginnen: het hoofdkwartier staat meteen
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	physics_frame.connect(func(): if frames > 3 and game != null: game.move = Vector2.ZERO)


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("%s/brand_%s_%s.png" % [dir, name, tag])
	print("foto ", name, " ", tag)


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
	if frames >= 4:
		# de bouwwagen en de opbouw houden de camera bij het hoofdkwartier: weg ermee, de camera volgt dan de speler
		for n in get_nodes_in_group("mcv_opbouw"):
			n.queue_free()
		for g in ["mcv", "mcv_wagen"]:
			for n in get_nodes_in_group(g):
				n.queue_free()
		if OS.get_environment("G2_HUD") == "":
			for n in root.find_children("*", "CanvasLayer", true, false):
				if (n as CanvasLayer).layer >= 0:
					(n as CanvasLayer).visible = false
		var cam := root.get_viewport().get_camera_3d()
		if cam != null:
			cam.set("_opbouw_weight", 0.0)
	if frames > 3 and game.state == "prep":
		game.prep_t = 1e9
	if frames == 90:
		var fz := float(OS.get_environment("G2_Z")) if OS.get_environment("G2_Z") != "" else -52.0
		game.player.global_position = Vector3(load("res://scripts/data.gd").path_x(fz) + 2.5, 0.0, fz)
		game.player.face = PI
	if frames == 170:
		_shot("0_voor")
		spot = game.player.global_position + Vector3(8.0, 0.0, -3.0)
		load("res://scripts/fx.gd").explosion(game.player.get_parent(), spot, 1.0)
		game.note_blast(spot, 4.0)
		Engine.time_scale = 10.0   # software-Vulkan is traag: het vuur loopt hier tien keer zo snel als in het spel
	if frames == 170 + 36:
		_shot("1_aangestoken")   # 6 s
	if frames == 170 + 84:
		_shot("2_brandrand")     # 14 s
	if frames == 170 + 150:
		_shot("3_groot")         # 25 s
	if frames == 170 + 400:
		_shot("4_na")            # ruim een minuut: gedoofd
	return frames > 170 + 402
