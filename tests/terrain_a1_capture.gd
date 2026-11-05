extends SceneTree
## Reproducible A1 ground captures from the real level and a fixed game-camera angle.
## TERRAIN_A1_OUT=/tmp/terrain-a1/before DISPLAY=:99 godot --rendering-driver opengl3 --path . -s tests/terrain_a1_capture.gd --resolution 1280x720 --fixed-fps 60

const SPOTS := {
	"kamp": Vector3(0.0, 0.0, -18.0),
	"bospad": Vector3(0.0, 0.0, -58.0),
	"rivier": Vector3(0.0, 0.0, -91.0),
}


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var out := OS.get_environment("TERRAIN_A1_OUT")
	if out.is_empty():
		push_error("TERRAIN_A1_OUT ontbreekt")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	seed(20261105)
	GameSettings.values = GameSettings.DEFAULTS.duplicate()
	GameSettings.values["quality"] = "high"
	GameSettings.values["time"] = "day"
	GameSettings.values["weather"] = "clear"
	GameSettings.values["wind"] = "off"
	GameSettings.values["sound"] = "off"
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await main.begin()
	var game: Node = root.get_node("Game")
	game.prep_t = 3600.0
	game.fire = false
	game.move = Vector2.ZERO
	main.set_process(false)
	main.get_node("Hud/Sticks").set_process(false)
	for menu in get_nodes_in_group("menus"):
		menu._show("")
	for layer in main.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	var camera: Camera3D = main.get_node("Camera")
	camera.set_process(false)
	for key in SPOTS:
		var focus: Vector3 = SPOTS[key]
		game.player.global_position = focus
		camera.global_position = focus + Vector3(0.0, sin(deg_to_rad(53.0)), cos(deg_to_rad(53.0))) * 28.0
		camera.look_at(focus)
		for _frame in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		var path := out.path_join(key + ".png")
		var error := root.get_texture().get_image().save_png(path)
		if error != OK:
			push_error("Capture mislukt: %s (%d)" % [path, error])
			quit(1)
			return
		print("TERRAIN A1 CAPTURE ", path, " sha256=", FileAccess.get_sha256(path))
	quit()
