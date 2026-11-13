extends SceneTree
## Voor/na-foto's van de third-personcamera (v231, camerakaart 1A-9A) en draw calls per stand.
## TAG=na|voor (voor = tactisch bovenbeeld en de oude bouwhoogte), FOTO_DIR=/pad
## VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 932x430x24" godot --rendering-driver vulkan --resolution 932x430 --path . -s tests/camera_third_foto.gd --fixed-fps 60

var main: Node
var frames := 0
var game: Node
var cam: Camera3D
var tag := OS.get_environment("TAG") if OS.get_environment("TAG") != "" else "na"
var dir := OS.get_environment("FOTO_DIR") if OS.get_environment("FOTO_DIR") != "" else "/tmp"
var aim_hold := NAN
var move_hold := Vector2.ZERO
var veh: Node3D


func _initialize() -> void:
	GameSettings.set_value("weather", "clear")
	GameSettings.set_value("time", "day")
	GameSettings.set_value("camera_view", "tact" if tag == "voor" else "third")
	load("res://scripts/data.gd").set("mcv_autodeploy", true)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	physics_frame.connect(func():
		if frames > 3 and game != null:
			game.move = move_hold
			game.aim = aim_hold)


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("%s/%s_%s.png" % [dir, name, tag])
	print("foto ", name, " ", tag)


func _calls(name: String) -> void:
	var dc := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var pr := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	var vp := root.get_viewport()
	var zicht := vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
	var schaduw := vp.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
	print("METING %s %s draw_calls=%d (beeld %d, schaduw %d) primitives=%d" % [tag, name, dc, zicht, schaduw, pr])


func _vehicle(scene: String, at: Vector3) -> void:
	veh = load(scene).instantiate()
	game.player.get_parent().add_child(veh)
	veh.global_position = at
	veh.rotation.y = 0.0   # voorkant = -Z: rijdt naar het noorden


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
	var data = load("res://scripts/data.gd")
	match frames:
		60:
			game.player.global_position = Vector3(data.path_x(-52.0) + 2.5, 0.0, -52.0)
			game.player.face = PI
			cam.snap_to_player()
		160:
			_shot("spel")
			_calls("jungle")
			if OS.get_environment("MEET_ALLEEN") != "":
				return true
			aim_hold = PI - 0.35
		200:
			_shot("richten")
			aim_hold = NAN
			game.player.global_position = Vector3(1.5, 0, -97.0)
			game.player.face = PI
			cam.snap_to_player()
		300:
			_shot("stad")
			_calls("stad")
			game.player.global_position = Data.HOTEL_POS + Vector3(-1.0, 0, 9.5)
			game.player.face = 0.0
			cam.snap_to_player()
		390:
			_shot("muur")
			game.player.global_position = Vector3(data.path_x(-40.0) + 2.5, 0.0, -40.0)
			game.player.face = PI
			_vehicle("res://scenes/jeep.tscn", game.player.global_position + Vector3(3, 0, 0))
		400:
			veh.call("_toggle")
			move_hold = Vector2(0.15, -1.0)
		470:
			_shot("jeep")
			move_hold = Vector2.ZERO
			veh.call("_toggle")
		480:
			veh.queue_free()
			_vehicle("res://scenes/tank.tscn", game.player.global_position + Vector3(4, 0, 0))
		490:
			veh.call("_toggle")
			move_hold = Vector2(0.0, -1.0)
		570:
			_shot("tank")
			move_hold = Vector2.ZERO
			veh.call("_toggle")
		580:
			veh.queue_free()
			var hq := get_first_node_in_group("mcv_hq") as Node3D
			game.player.global_position = (hq.global_position if hq != null else Vector3.ZERO) + Vector3(0, 0, 14)
			game.player.face = PI
			cam.snap_to_player()
		650:
			_shot("bij_hk")
			get_first_node_in_group("build_mode")._enter()
		662:
			if tag == "na":
				_shot("bouwen_vlucht")
		760:
			if tag == "voor":
				game.bcam.z /= 1.6   # oude bouwhoogte (v228)
		860:
			_shot("bouwen")
			return true
	return false
