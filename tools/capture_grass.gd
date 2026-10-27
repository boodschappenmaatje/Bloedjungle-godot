extends SceneTree
## Actual game-world grass evidence; same production camera/light, no generated mockups.

var main: Node3D
var game: Node
var manifest: Array = []
var grass: GDScript
var foliage: GDScript


func _initialize() -> void:
	call_deferred("_run")


func _frames(count: int) -> void:
	for _i in count:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "res://docs/grass/renders/" + name + ".png"
	var error := root.get_texture().get_image().save_png(path)
	assert(error == OK)
	var cam: Camera3D = main.get_node("Camera")
	var field: Node = get_first_node_in_group("grass_fields")
	manifest.append({"file": path, "sha256": FileAccess.get_sha256(path),
		"camera_position": var_to_str(cam.global_position), "camera_rotation": var_to_str(cam.global_rotation), "fov": cam.fov,
		"renderer": RenderingServer.get_current_rendering_method(), "adapter": RenderingServer.get_video_adapter_name(),
		"grass_counts": field.counts, "batch_groups": field.batches.size(),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"texture_memory_bytes": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),
		"fps": "Not measured: fixed-step software renderer capture"})
	print("GRASS CAPTURE ", name)


func _run() -> void:
	grass = load("res://scripts/grass_field.gd")
	foliage = load("res://scripts/foliage.gd")
	seed(27102026)
	GameSettings._load()
	GameSettings.values = GameSettings.DEFAULTS.duplicate()
	GameSettings.values["sound"] = "off"
	GameSettings.values["quality"] = "high"
	GameSettings.values["wind"] = "off"
	load("res://scripts/perf_governor.gd").set("paused", true)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await main.begin()
	main.set_process(false)
	game = root.get_node("Game")
	game.prep_t = 3600.0
	game.fire = false
	game.move = Vector2.ZERO
	for menu in get_nodes_in_group("menus"):
		menu._show("")
	main.get_node("Hud/Sticks").set_process(false)
	var camera: Camera3D = main.get_node("Camera")
	camera.set_process(false)
	# Same real ground and camera/light, isolated 12-tuft plot for silhouette/material review.
	var anchor := Vector3(0, 0, 52)
	game.player.global_position = anchor + Vector3(-3.3, 0, 0.4)
	game.player.face = PI
	var plot: Node3D = grass.preview("all")
	plot.position = anchor
	main.add_child(plot)
	for revision in ["old", "new"]:
		if revision == "old":
			main.remove_child(plot)
			plot.free()
			plot = grass.preview("all", true)
			plot.position = anchor
			main.add_child(plot)
		else:
			plot.free()
			plot = grass.preview("all")
			plot.position = anchor
			main.add_child(plot)
		var focus := anchor + Vector3(0, 0.45, 0)
		camera.global_position = focus + Vector3(0, 4.4, 6.5)
		camera.look_at(focus)
		await _frames(6)
		await _shot("grass-plot-" + revision)
		focus = anchor
		camera.global_position = focus + Vector3(0, sin(deg_to_rad(58.0)), cos(deg_to_rad(58.0)))*28.0
		camera.look_at(focus)
		await _frames(4)
		await _shot("grass-gamecamera-" + revision)
	plot.queue_free()
	# Normal jungle route, including a defined tall zone. Player remains visible above it.
	var focus := Vector3(-12, 0, -42)
	game.player.global_position = focus
	game.player.face = PI
	camera.global_position = focus + Vector3(0, sin(deg_to_rad(58.0)), cos(deg_to_rad(58.0)))*28.0
	camera.look_at(focus)
	foliage.update_visibility_focus(game.player.global_position, camera.global_position, 1.0, true)
	await _frames(8)
	await _shot("grass-jungle-gamecamera")
	camera.global_position = focus + Vector3(0, sin(deg_to_rad(48.0)), cos(deg_to_rad(48.0)))*16.0
	camera.look_at(focus)
	foliage.update_visibility_focus(game.player.global_position, camera.global_position, 1.0, true)
	await _frames(6)
	await _shot("grass-jungle-combatcamera")
	GameSettings.values["wind"] = "on"
	foliage.set_wind(true)
	await _frames(8)
	await _shot("grass-wind-a")
	await _frames(24)
	await _shot("grass-wind-b")
	var file := FileAccess.open("res://docs/grass/godot-captures.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "\t")+"\n")
	quit()
