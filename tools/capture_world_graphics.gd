extends SceneTree
## Identical real-world frames for lighting/terrain review. No saved settings are written.
## BJ_INSTANT=1 godot4 --path . -s tools/capture_world_graphics.gd --fixed-fps 60 -- --stage before

var main: Node3D
var game: Node
var stage := "before"
var weather := "clear"
var view_only := ""
var records: Array = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--stage"):
		stage = args[args.find("--stage") + 1]
	if args.has("--weather"):
		weather = args[args.find("--weather") + 1]
	if args.has("--view-only"):
		view_only = args[args.find("--view-only") + 1]
	call_deferred("_run")


func _run() -> void:
	seed(2702026)
	GameSettings._load()
	GameSettings.values = GameSettings.DEFAULTS.duplicate()
	GameSettings.values["sound"] = "off"
	GameSettings.values["wind"] = "off"
	GameSettings.values["weather"] = weather
	load("res://scripts/perf_governor.gd").set("paused", true)
	load("res://scripts/atmosphere.gd").set("tier", 0)
	Progress.autostart = false
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await main.begin()
	game = root.get_node("Game")
	main.set_process(false)
	game.prep_t = 3600.0
	for menu in get_nodes_in_group("menus"):
		menu._show("")
	for node in root.find_children("*", "", true, false):
		if node.get_script() and String(node.get_script().resource_path).ends_with("touch_sticks.gd"):
			node.set_process(false)
	var cam: Camera3D = main.get_node("Camera")
	cam.set_process(false)
	for node in cam.get_children():
		if node is GPUParticles3D:
			node.emitting = false
	var shots := {"base": Vector3(0, 0, 0), "jungle": Vector3(2, 0, -38), "jeep": Vector3(0, 0, 10), "combat": Vector3(0, 0, -8)}
	if view_only == "river":
		shots = {"river": Vector3(8, 0, -87)}
	elif not view_only.is_empty():
		shots = {view_only: shots[view_only]}
	var jeep: Node3D
	for name in shots:
		seed(2702026)
		var focus: Vector3 = shots[name]
		game.player.global_position = focus + Vector3(0, 0, 5)
		game.player.face = PI
		game.aim = PI
		game.fire = false
		game.move = Vector2.ZERO
		if name == "jeep":
			jeep = load("res://scenes/jeep.tscn").instantiate()
			jeep.position = focus
			jeep.rotation.y = 0.6
			main.add_child(jeep)
		if name == "combat":
			for i in 6:
				var enemy = load("res://scenes/enemy.tscn").instantiate()
				enemy.setup("rifle", 1)
				enemy.position = focus + Vector3(-5.0 + float(i) * 2.0, 0, -3.0 - float(i % 2) * 2.0)
				main.add_child(enemy)
				enemy.set_physics_process(false)
				enemy.set_process(false)
		cam.global_position = focus + Vector3(0, sin(deg_to_rad(58.0)), cos(deg_to_rad(58.0))) * 28.0
		cam.look_at(focus)
		for _f in 8:
			await process_frame
		if name == "combat":
			game.player.call("_shoot", game.wstat(game.player.weapon))
			await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		var dir := "res://docs/world_graphics/renders/"
		DirAccess.make_dir_recursive_absolute(dir)
		var path: String = dir + stage + "-" + name + ".png"
		var err := image.save_png(path)
		if err != OK:
			push_error("Capture failed: " + path)
			quit(1)
			return
		var atm: Node = get_first_node_in_group("atmosphere")
		records.append({"scene": name, "file": path, "seed": 2702026,
			"camera": {"position": var_to_str(cam.position), "rotation": var_to_str(cam.rotation), "fov": cam.fov},
			"sun_rotation": var_to_str(atm._sun.rotation_degrees), "sun_energy": atm._sun.light_energy,
			"exposure": atm._env.tonemap_exposure, "quality": "high", "weather": weather, "resolution_scale": root.scaling_3d_scale,
			"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"rendered_primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			"texture_memory_bytes": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),
			"renderer": RenderingServer.get_current_rendering_method(),
			"gpu": RenderingServer.get_video_adapter_name(),
			"fps": "Not measured: fixed-step capture on software renderer"})
		print("WORLD CAPTURE ", path)
		if jeep:
			jeep.queue_free()
			jeep = null
	var file := FileAccess.open("res://docs/world_graphics/" + stage + "-captures.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(records, "\t") + "\n")
	quit()
