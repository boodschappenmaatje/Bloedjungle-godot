extends SceneTree
## Tankschot: opnames van het schot van de vijandelijke tank en van jouw Tiger, met identieke camera en seed.
## BJ_TANKFX=nieuw|klassiek, BJ_OUT=/map (standaard /tmp/tankfx)
## xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver vulkan --path . -s tests/tankschot_foto.gd --fixed-fps 60

var main: Node
var game: Node
var frames := 0
var out := "/tmp/tankfx"
var stand := "nieuw"
var tank_vijand: Node
var tank_eigen: Node
const T_V := 60     # frame waarop de vijandelijke tank schiet
const T_E := 300    # frame waarop jouw Tiger schiet
const NA := [3, 6, 10, 16, 30, 60, 110]


func _initialize() -> void:
	OS.set_environment("BJ_TOUCH", "1")
	OS.set_environment("BJ_INSTANT", "1")
	out = OS.get_environment("BJ_OUT") if OS.get_environment("BJ_OUT") != "" else out
	stand = OS.get_environment("BJ_TANKFX") if OS.get_environment("BJ_TANKFX") != "" else stand
	DirAccess.make_dir_recursive_absolute(out)
	GameSettings.set_value("wapenfx", stand)
	GameSettings.set_value("time", "day")
	GameSettings.set_value("weather", "clear")
	load("res://scripts/data.gd").set("mcv_autodeploy", true)
	seed(1943)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	physics_frame.connect(func(): if frames > 3 and game != null: game.move = Vector2.ZERO)


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	var s := img.get_size()
	var crop := img.get_region(Rect2i(int(s.x * 0.12), int(s.y * 0.12), int(s.x * 0.76), int(s.y * 0.76)))
	crop.save_png("%s/%s_%s.png" % [out, stand, name])
	print("foto ", stand, " ", name)


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
	if frames >= 4 and frames < 400:
		for g in ["mcv_opbouw", "mcv", "mcv_wagen"]:
			for n in get_nodes_in_group(g):
				n.queue_free()
		var cam := root.get_viewport().get_camera_3d()
		if cam != null:
			cam.set("_opbouw_weight", 0.0)
		for n in root.find_children("*", "CanvasLayer", true, false):
			n.visible = false
	if frames > 3 and game.state == "prep":
		game.prep_t = 1e9
	if frames == 5:
		var cls: GDScript = load("res://scripts/vijand_tank.gd")
		tank_vijand = cls.new()
		tank_vijand.route = []
		tank_vijand.position = Vector3(200, 0, 200)
		main.add_child(tank_vijand)
		tank_vijand.set_physics_process(false)
		tank_vijand.set_process(false)
		var tscn: PackedScene = load("res://scenes/tank.tscn")
		tank_eigen = tscn.instantiate()
		main.add_child(tank_eigen)
		tank_eigen.global_position = Vector3(300, 0, 300)
		tank_eigen.set_physics_process(false)
		tank_eigen.set_process(false)
	if frames == 30:
		game.player.global_position = Vector3(0, 0, -30)
		game.player.face = PI
		tank_vijand.global_position = Vector3(-3, 0, -62)
		tank_vijand.rotation.y = 0.0   # kijkt naar +Z, de speler
	if frames > 30 and frames < 600:
		var cam2 := root.get_viewport().get_camera_3d()
		var tgt: Node = tank_vijand if frames < T_E - 20 else tank_eigen
		var d: Vector3 = tgt.global_position - game.player.global_position
		cam2.set("_lead", Vector3(d.x, 0.0, d.z) * 1.12)
	if frames == T_V:
		print("vijand schiet")
		tank_vijand._shoot(game.player.global_position)
	for k in NA:
		if frames == T_V + k:
			_shot("vijand_%02d" % k)
	if frames == T_E - 40:
		tank_eigen.global_position = Vector3(6, 0, -48)
		tank_eigen.rotation.y = 0.0   # kijkt naar -Z, weg van de speler
		tank_eigen.set_physics_process(true)
		tank_eigen.set_process(false)
	if frames == T_E:
		print("Tiger schiet")
		tank_eigen._shoot(Vector3(6, 0, -85))
	for k in NA:
		if frames == T_E + k:
			_shot("tiger_%02d" % k)
	return frames > T_E + 90
