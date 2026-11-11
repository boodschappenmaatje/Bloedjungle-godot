extends SceneTree
## Voor-en-na-beelden van Graphics 2.0 vanuit de spelcamera op 40 graden: basis, junglerand, explosie en rook.
## G2=on|off FOTO_DIR=/pad BJ_TOUCH=1 VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1280x590x24" \
##   godot --rendering-driver vulkan --path . -s tests/graphics2_foto.gd --fixed-fps 60

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
	img.save_png("%s/g2_%s_%s.png" % [dir, name, tag])
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
	if frames == 5:
		# het model vroeg laden (software-Vulkan houdt niet van modellen laden midden in het spel) en stilzetten
		jeep = load("res://scripts/vijand_jeep.gd").new()
		jeep.route = []
		jeep.position = Vector3(200, 0, 200)
		main.add_child(jeep)
		jeep.set_physics_process(false)
		jeep.set_process(false)   # de eigen voertuigen rijden sinds v214 per beeld
	if frames > 332 and is_instance_valid(jeep):
		# de jeep rijdt dwars door het beeld: stof achter de wielen en een donkere vlek eronder
		jeep.rotation.y = -PI * 0.5
		jeep.global_position = Vector3(-9.0 + (frames - 332) * 0.14, 0.0, -36.0)
	if frames == 90:
		_shot("open_veld")
		var fz := float(OS.get_environment("G2_Z")) if OS.get_environment("G2_Z") != "" else -30.0
		game.player.global_position = Vector3(load("res://scripts/data.gd").path_x(fz) + 2.5, 0.0, fz)   # naast het pad naar de brug, jungle rondom
		game.player.face = PI
	if frames == 170:
		_shot("jungle")
		spot = game.player.global_position + Vector3(2.5, 0.0, -6.0)
		load("res://scripts/fx.gd").explosion(game.player.get_parent(), spot, 1.0)
	if frames == 176:
		_shot("explosie_flits")
	if frames == 200:
		_shot("explosie_vuurbal")
	if frames == 330:
		_shot("explosie_rook")
	if frames == 420:
		_shot("jeep_stof")
	return frames > (172 if OS.get_environment("G2_KORT") != "" else 422)
