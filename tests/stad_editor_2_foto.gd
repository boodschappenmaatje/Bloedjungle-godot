extends SceneTree
## Echte Godot-opnamen, zonder instellingen of de eigen opgeslagen stad te wijzigen.
## DISPLAY=:91 godot --path . --rendering-method gl_compatibility --audio-driver Dummy \
##   --resolution 934x430 -s tests/stad_editor_2_foto.gd --fixed-fps 60

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var city = load("res://scripts/stad.gd")
	city.save_path = "user://stad_editor_2_foto.json"
	city.clear_saved()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for _i in 3:
		await process_frame
	root.content_scale_factor = 1.0
	root.size = Vector2i(934, 430)
	main.get_node("Hud/Sticks").set_process(false)
	await main.begin()
	for menu in get_nodes_in_group("menus"):
		menu._show("")
	for _i in 8:
		await process_frame
	var ed = get_first_node_in_group("stad_editor")
	ed.enter()
	# Schuif alleen de editorcamera naar een vrij bouwvlak boven de bestaande stad.
	root.get_node("Game").ecam = Vector3(6, -120, 1)
	for _i in 45:
		await process_frame
	ed._pick_kind("magazijn")
	# Kies een werkelijk vrije plek op de bestaande kaart voor de groene preview.
	var found := false
	var best_score := INF
	var best := Vector3.ZERO
	var camera := root.get_camera_3d()
	for z in range(-132, -95, 2):
		for x in range(-36, 53, 2):
			var candidate := {"k": "magazijn", "x": float(x), "z": float(z), "r": 0, "m": 0}
			var point := camera.unproject_position(Vector3(x, 0, z))
			var bounds := Rect2(point, Vector2.ZERO)
			for dx in [-6, 6]:
				for dz in [-4, 4]:
					bounds = bounds.expand(camera.unproject_position(Vector3(x + dx, 5.8, z + dz)))
			var score := point.distance_squared_to(Vector2(480, 188))
			if Rect2(100, 70, 766, 246).encloses(bounds) and city.problem(candidate, city.current.items) == "" and score < best_score:
				best_score = score
				best = Vector3(x, 0, z)
				found = true
	if not found:
		push_error("Geen vrije plek voor de magazijnfoto")
		quit(1)
		return
	ed._aim(best)
	for _i in 8:
		await process_frame
	var destination := OS.get_environment("BJ_EDITOR_CAPTURE_DIR")
	if destination == "":
		destination = "/tmp/city2-captures"
	DirAccess.make_dir_recursive_absolute(destination)
	for state in [1, 2, 0]:
		ed._set_library_state(state)
		for _i in 4:
			await process_frame
		if RenderingServer.is_render_loop_enabled():
			await RenderingServer.frame_post_draw
		else:
			RenderingServer.force_draw()
		var image := root.get_texture().get_image()
		var path := destination.path_join("editor-934x430-%s.png" % ["hidden", "compact", "expanded"][state])
		var result := image.save_png(path)
		print("CAPTURE ", path, " error=", result)
	root.size = Vector2i(1280, 720)
	ed._set_library_state(1)
	for _i in 6:
		await process_frame
	if RenderingServer.is_render_loop_enabled():
		await RenderingServer.frame_post_draw
	else:
		RenderingServer.force_draw()
	root.get_texture().get_image().save_png(destination.path_join("editor-1280x720.png"))
	ed.exit()
	city.clear_saved()
	main.queue_free()
	await process_frame
	quit()
