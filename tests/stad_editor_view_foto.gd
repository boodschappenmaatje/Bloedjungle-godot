extends SceneTree
## Echte vergelijkingsopnamen van dezelfde bestaande lantaarn in BOVEN/SCHUIN.
## BJ_INSTANT=1 godot --path . --windowed --audio-driver Dummy --disable-render-loop \
##   -s tests/stad_editor_view_foto.gd --fixed-fps 60


func _initialize() -> void:
	call_deferred("_run")


func _frames(n := 10) -> void:
	for _i in n:
		await process_frame


func _shot(path: String) -> void:
	if RenderingServer.is_render_loop_enabled():
		await RenderingServer.frame_post_draw
	else:
		# Laat nieuw aangevraagde fontglyphs eerst naar de atlas uploaden.
		RenderingServer.force_draw()
		await process_frame
		RenderingServer.force_draw()
	var result := root.get_texture().get_image().save_png(path)
	if result != OK:
		push_error("Opname mislukt: " + path)
		quit(1)
	print("CAPTURE ", path, " error=", result)


func _run() -> void:
	var city = load("res://scripts/stad.gd")
	city.save_path = "user://stad_editor_view_foto.json"
	city.clear_saved()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	root.content_scale_factor = 1
	root.size = Vector2i(934, 430)
	main.get_node("Hud/Sticks").set_process(false)
	await main.begin()
	for menu in get_nodes_in_group("menus"):
		menu._show("")
	var ed = get_first_node_in_group("stad_editor")
	var game = root.get_node("Game")
	var camera := root.get_camera_3d()
	ed.enter()
	game.ecam = Vector3(4, -103, 0.65)
	ed._pick_tab("straat")
	await _frames(70)
	var pole: Dictionary = city.current.items.filter(func(d): return d.k == "lantaarn" and d.z == -99)[0]
	ed._sel = pole
	ed._refresh_hl()
	var directory := OS.get_environment("BJ_EDITOR_CAPTURE_DIR")
	if directory == "":
		directory = "/tmp/city86-captures"
	DirAccess.make_dir_recursive_absolute(directory)
	for mode in [true, false]:
		camera.editor_oblique = mode
		ed._sync_camera_button()
		await _frames(90)
		await _shot(directory.path_join("editor-%s-934x430.png" % ("schuin" if mode else "boven")))
	camera.editor_oblique = true
	ed._sync_camera_button()
	ed._pick_tab("gebouw")
	ed._set_library_state(2)
	game.ecam = Vector3(6, -115, 1)
	await _frames(90)
	await _shot(directory.path_join("editor-bibliotheek-934x430.png"))
	root.size = Vector2i(1280, 720)
	ed._set_library_state(1)
	await _frames(12)
	await _shot(directory.path_join("editor-desktop-1280x720.png"))
	ed.exit()
	city.clear_saved()
	main.queue_free()
	await _frames(2)
	quit()
