extends SceneTree
## Voor/na-foto's van de vliegcamera (14 nov 2026): boven de stad en boven de jungle, met de echte spelcamera.
## Draaien: FOTO_DIR=/pad TAG=voor|na xvfb-run -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 -s tests/vliegen_camera_foto.gd

var out := ""
var tag := ""
var game
var V


func _initialize() -> void:
	V = load("res://scripts/vliegtuig.gd")
	root.size = Vector2i(1280, 720)
	call_deferred("_run")


func _frames(n: int) -> void:
	for _i in n:
		await process_frame


func _save(file: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(tag + "_" + file))
	print("FOTO ", out.path_join(tag + "_" + file))


func _fly(plane, at: Vector3, heading: float, file: String) -> void:
	plane.global_position = Vector3(at.x, 20.0, at.z)
	plane.rotation.y = heading
	plane.alt = 20.0
	plane.speed = 30.0
	plane.mode = V.Mode.AIR
	game.player.global_position = Vector3(at.x, 0.0, at.z)
	await _frames(90)
	var cam := root.get_viewport().get_camera_3d()
	print(file, " cam-modus ", cam.get("_mode"), " state ", game.state, " speler ", game.player.global_position, " build ", game.build_mode, " editing ", game.editing)
	print(file, " cam-pad ", cam.get_path(), " verwerkt ", cam.is_processing(), " ppos ", cam.get("_ppos"), " look ", cam.get("_look"), " fly_w ", cam.get("_fly_w"))
	print(file, " camera-script ", cam.get_script().resource_path if cam.get_script() else "geen")
	print(file, " camera ", cam.global_position, " toestel ", plane.global_position, " afstand ", cam.global_position.distance_to(plane.global_position), " hoogte_cam ", cam.global_position.y)
	var on_screen := cam.unproject_position(plane.global_position)
	print(file, " toestel in beeld op ", on_screen, " (midden 640,360)")
	await _save(file)


func _run() -> void:
	out = OS.get_environment("FOTO_DIR")
	tag = OS.get_environment("TAG")
	if out.is_empty():
		out = ProjectSettings.globalize_path("user://vliegen_camera")
	if tag.is_empty():
		tag = "na"
	DirAccess.make_dir_recursive_absolute(out)
	load("res://scripts/data.gd").mcv_autodeploy = true
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	game = root.get_node("Game")
	await _frames(3)
	await main.call("begin")
	var menu := get_first_node_in_group("menus")
	if menu != null:
		menu.call("_show", "")
	await _frames(30)
	game.state = "prep"
	game.points = 100000
	game.build_credit = 100000
	game.mcv_deployed = true
	var b = game.builds.place("airfield", Vector3(70.0, 0.0, 115.0), 0.0)
	for x in game.buildings:
		x["build_t"] = 0.0
	for _i in 600:
		await process_frame
		if b.aircraft.size() >= 1:
			break
	# eerst het HK laten afbouwen: tijdens de opbouw kijkt de camera naar de bouwplek
	for _i in 3000:
		if get_first_node_in_group("mcv_opbouw") == null:
			break
		await process_frame
	print("opbouw klaar: ", get_first_node_in_group("mcv_opbouw") == null)
	var plane = b.aircraft[0].node
	game.player.global_position = plane.global_position + Vector3(3, 0, 3)
	await _frames(5)
	plane._board(game.player)
	game.build_mode = false
	game.state = "play"
	print("bestuurd: ", V.driven_plane == plane, " bouwmodus ", game.build_mode)
	await _frames(5)
	for c in root.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	var huis: Node3D = null
	for n in root.find_children("*", "StaticBody3D", true, false):
		if n.get_script() != null and String(n.get_script().resource_path).ends_with("house_body.gd"):
			huis = n
			break
	var stad := huis.global_position if huis != null else Vector3(0.0, 0.0, -110.0)
	print("stad bij ", stad)
	# zo starten dat het toestel na 90 beelden (~45 m) boven de huizen vliegt
	await _fly(plane, stad + Vector3(0.0, 0.0, 40.0), 0.0, "01_boven_de_stad.png")
	await _fly(plane, Vector3(60.0, 0.0, 30.0), 0.0, "02_boven_de_jungle.png")
	print("KLAAR")
	quit(0)
