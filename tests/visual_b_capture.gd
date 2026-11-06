extends SceneTree
## Real main.tscn, unmodified camera rig; isolated reproducible render/benchmark.
## BJ_INSTANT=1 BJ_TOUCH=1 BJ_B_OUT=<dir> godot --path . -s tests/visual_b_capture.gd --resolution 1280x720
const SPOTS := {"bospad": Vector3(7,0,-57), "rivier": Vector3(14,0,-80), "kamp": Vector3(-20,0,-32)}
var game: Node
var main: Node3D
var out: String
var render_scale := 0.6
var reports: Array = []
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	game = root.get_node("Game")
	var settings: GDScript = load("res://scripts/game_settings.gd")
	var governor: GDScript = load("res://scripts/perf_governor.gd")
	var progress: GDScript = load("res://scripts/progress.gd")
	out = OS.get_environment("BJ_B_OUT")
	var scale_override := OS.get_environment("BJ_RENDER_SCALE")
	if not scale_override.is_empty(): render_scale = clampf(float(scale_override), 0.6, 1.0)
	if out.is_empty():
		quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(out) != OK:
		push_error("Cannot create capture directory: "+out)
		quit(1)
		return
	seed(20261106)
	settings.values = settings.DEFAULTS.duplicate()
	settings._loaded = true
	settings.values["sound"] = "off"
	settings.values["hz"] = "120"
	settings.values["fps"] = "on"
	var quality_override := OS.get_environment("BJ_CAPTURE_QUALITY")
	if quality_override in ["low","high","ultra"]: settings.values["quality"] = quality_override
	governor.paused = true
	progress.autostart = false
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	print("CAPTURE world built")
	await main.begin()
	print("CAPTURE begin returned")
	main.set_process(false)
	main.get_node("Hud/Sticks").set_process(false)
	game.prep_t = 163
	game.move = Vector2.ZERO
	game.fire = false
	for menu in get_nodes_in_group("menus"): menu._show("")
	var cam: Camera3D = main.get_node("Camera")
	root.scaling_3d_scale = render_scale
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var spots := SPOTS
	var spot_override := OS.get_environment("BJ_CAPTURE_SPOT")
	if SPOTS.has(spot_override): spots = {spot_override:SPOTS[spot_override]}
	for key in spots:
		game.player.global_position = spots[key]
		game.player.face = 0.0
		cam.snap_to_player()
		print("CAPTURE settle ",key)
		for i in 8: await process_frame
		root.scaling_3d_scale = render_scale
		print("CAPTURE ready ",key)
		cam.set_process(false)
		sync_foliage_focus(cam)
		await RenderingServer.frame_post_draw
		if not save_frame(key+".png"): return
		if OS.get_environment("BJ_CAPTURE_ONLY") == "1":
			print("VISUAL B CAPTURE PASS ",out)
			quit()
			return
		var data := {"spot":key,"focus":str(spots[key]),"camera":str(cam.global_transform),"fov":cam.fov,
			"scale":root.scaling_3d_scale,"msaa":root.msaa_3d,"quality":settings.values.duplicate(),
			"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"engine":Engine.get_version_info().string}
		print("CAPTURE saved ",key)
		data.merge(await measure(60))
		reports.append(data)
		if not save_metrics(): return
		if key == "bospad":
			# Fixed camera translate, no changing wind/pushers: small temporal sequence.
			for i in 12:
				cam.position.x += 0.025
				sync_foliage_focus(cam)
				await process_frame
				await RenderingServer.frame_post_draw
				if not save_frame("temporal_%02d.png" % i): return
		cam.set_process(true)
	# Large deterministic encounter uses real enemy setup/AI, not dummy meshes.
	game.player.global_position = Vector3(0,0,-44)
	game.player.hp = 100000.0
	cam.snap_to_player()
	for i in 80:
		var e: Node3D = load("res://scenes/enemy.tscn").instantiate()
		e.setup("rifle" if i % 3 == 0 else "knife", 1)
		main.add_child(e)
		e.global_position = Vector3(-18+(i%16)*2.3,0,-64-(i/16)*2.2)
	game.state = "play"
	for i in 12: await process_frame
	cam.set_process(false)
	sync_foliage_focus(cam)
	await RenderingServer.frame_post_draw
	if not save_frame("combat.png"): return
	var battle := {"spot":"combat_80","enemies_start":game.enemies.size(),"camera":str(cam.global_transform)}
	battle.merge(await measure(100))
	battle["enemies_end"] = game.enemies.size()
	reports.append(battle)
	if not save_metrics(): return
	print("VISUAL B CAPTURE PASS ",out)
	quit()

func sync_foliage_focus(cam: Camera3D) -> void:
	# Main's process is paused for repeatable static timing, so refresh the same
	# sightline and actor-push uniforms the live main loop normally updates.
	var extras: Array = []
	var nearest: Array[Node3D] = []
	for enemy: Node3D in game.enemies:
		if is_instance_valid(enemy): nearest.append(enemy)
	nearest.sort_custom(func(a: Node3D,b: Node3D) -> bool:
		return a.global_position.distance_squared_to(game.player.global_position) < b.global_position.distance_squared_to(game.player.global_position))
	for i in mini(3,nearest.size()): extras.append(nearest[i].global_position)
	# Resolve after the project autoloads are available; this harness starts as a SceneTree.
	var foliage: GDScript = load("res://scripts/foliage.gd")
	foliage.update_visibility_focus(game.player.global_position,cam.global_position,1.0,true,extras)
	foliage.update_pushers(game.player,self,true)

func save_metrics() -> bool:
	var file := FileAccess.open(out.path_join("metrics.json"),FileAccess.WRITE)
	if file == null:
		push_error("Cannot write metrics: "+error_string(FileAccess.get_open_error()))
		quit(1)
		return false
	file.store_string(JSON.stringify(reports,"\t"))
	file.flush()
	if file.get_error() != OK:
		push_error("Metrics write failed")
		quit(1)
		return false
	return true
func measure(n: int) -> Dictionary:
	var times: Array[float] = []
	var draws: Array[float] = []
	var primitives: Array[float] = []
	var last := Time.get_ticks_usec()
	for i in n:
		await process_frame
		var now := Time.get_ticks_usec()
		times.append((now-last)/1000.0)
		last = now
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	times.sort()
	var slow := times.slice(floori(n*0.99))
	return {"samples":n,"mean_ms":times.reduce(func(a,b):return a+b,0.0)/n,"p99_ms":times[mini(n-1,floori(n*0.99))],
		"one_percent_low_fps":1000.0/(slow.reduce(func(a,b):return a+b,0.0)/slow.size()),
		"draw_calls_mean":draws.reduce(func(a,b):return a+b,0.0)/n,"primitives_mean":primitives.reduce(func(a,b):return a+b,0.0)/n,"frame_ms_sorted":times}

func save_frame(name_: String) -> bool:
	var path := out.path_join(name_)
	var error := root.get_texture().get_image().save_png(path)
	if error != OK:
		push_error("Capture write failed: %s (%s)" % [path,error_string(error)])
		quit(1)
		return false
	return true
