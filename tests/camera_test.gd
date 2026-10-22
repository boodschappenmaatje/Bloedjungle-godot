extends SceneTree
## Regressietest voor strategisch/gevechtszicht, zoom, bouwcamera-herstel, radar en touch-HUD.

var failures: Array[String] = []
var main: Node
var game: Node
var foliage_script: Script


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("CAMERA TEST: " + message)


func _settle_camera(camera: Camera3D, count := 60) -> void:
	for _i in count:
		camera.call("_process", 1.0 / 60.0)
		await process_frame


func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	game = root.get_node("Game")
	foliage_script = load("res://scripts/foliage.gd")
	for _i in 3:
		await process_frame
	await main.call("begin")
	for _i in 3:
		await process_frame
	var camera: Camera3D = main.get_node("Camera")
	var player: Node3D = game.get("player")
	_check(player != null, "main scène heeft geen speler")
	if player == null:
		quit(1)
		return
	_check(not bool(camera.get("combat_view")), "strategisch zicht is niet de standaard")
	await _settle_camera(camera)
	var strategic_distance := camera.global_position.distance_to(player.global_position)
	_check(absf(strategic_distance - 28.0) < 0.8, "strategische cameraafstand is %.2f i.p.v. 28 m" % strategic_distance)
	var strategic_angle := rad_to_deg(atan2(camera.global_transform.basis.z.y, Vector2(camera.global_transform.basis.z.x, camera.global_transform.basis.z.z).length()))
	_check(absf(strategic_angle - 58.0) < 0.8, "strategische kijkhoek is %.2f° i.p.v. 58°" % strategic_angle)
	camera.call("toggle_view")
	await _settle_camera(camera)
	var combat_distance := camera.global_position.distance_to(player.global_position)
	_check(bool(camera.get("combat_view")), "gevechtsstand schakelt niet in")
	_check(absf(combat_distance - 16.0) < 0.8, "gevechtscameraafstand is %.2f i.p.v. 16 m" % combat_distance)
	var combat_angle := rad_to_deg(atan2(camera.global_transform.basis.z.y, Vector2(camera.global_transform.basis.z.x, camera.global_transform.basis.z.z).length()))
	_check(absf(combat_angle - 48.0) < 0.8, "gevechtskijkhoek is %.2f° i.p.v. 48°" % combat_angle)
	_check(absf(camera.fov - 45.0) < 0.01, "camerafov is niet 45°")
	camera.call("toggle_view")
	await _settle_camera(camera)
	_check(not bool(camera.get("combat_view")), "camera wisselt niet terug naar strategisch")
	camera.call("zoom", -99)
	_check(int(camera.get("zoom_step")) == -3, "zoom-minimum is niet begrensd")
	camera.call("zoom", 99)
	_check(int(camera.get("zoom_step")) == 4, "zoom-maximum is niet begrensd")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	camera.call("_unhandled_input", wheel)
	_check(int(camera.get("zoom_step")) == 3, "muiswiel zoomt niet in")
	game.set("build_mode", true)
	camera.call("_unhandled_input", wheel)
	_check(int(camera.get("zoom_step")) == 3, "muiswiel verandert de bouwcamera")
	game.set("build_mode", true)
	var selected_view: bool = bool(camera.get("combat_view"))
	camera.call("_process", 1.0 / 60.0)
	game.set("build_mode", false)
	await _settle_camera(camera)
	_check(bool(camera.get("combat_view")) == selected_view, "bouwmodus vergat de geselecteerde speelcamera")
	var hud: Node = main.get_node("Hud")
	var extra: Node = hud.find_child("HudExtra", true, false)
	var radar: Control = hud.find_child("TacticalRadar", true, false)
	_check(extra != null and radar != null, "HUD-camera-controls of radar ontbreekt")
	if extra != null and radar != null:
		_check(radar.visible, "radar is niet zichtbaar tijdens prep")
		var marker: Vector2 = extra.call("_radar_point", Vector3.ZERO, Rect2(Vector2.ZERO, Vector2(100, 100)))
		_check(absf(marker.x - 50.0) < 0.1 and absf(marker.y - 61.54) < 0.2, "radar projecteert wereldcoördinaten verkeerd")
		var view_button: Button = hud.find_child("CameraViewButton", true, false)
		_check(view_button != null and view_button.is_in_group("hud_button"), "camera-knop blokkeert geen stick-touch")
		if view_button != null:
			var touch: Node = hud.get_node("Sticks")
			_check(touch.call("_on_button", view_button.get_global_rect().get_center()), "touchknop wordt als stickbeweging gelezen")
		var zoom_out: Button = hud.find_child("CameraZoomOutButton", true, false)
		var zoom_in: Button = hud.find_child("CameraZoomInButton", true, false)
		_check(zoom_out != null and zoom_in != null, "zoomknoppen ontbreken")
		if zoom_out != null and zoom_in != null:
			zoom_out.emit_signal("pressed")
			await process_frame
			_check(int(camera.get("zoom_step")) == 4 and zoom_out.disabled, "zoomknop − vergroot de afstand niet correct")
			zoom_in.emit_signal("pressed")
			await process_frame
			_check(int(camera.get("zoom_step")) == 3 and not zoom_in.disabled, "zoomknop + verkleint de afstand niet correct")
		var ray_start := player.global_position + Vector3.UP * 1.2
		var ray_end := ray_start + Vector3(0, 10, 10)
		var blocker := StaticBody3D.new()
		blocker.collision_layer = 2
		var blocker_shape := CollisionShape3D.new()
		var blocker_box := BoxShape3D.new()
		blocker_box.size = Vector3(4, 4, 4)
		blocker_shape.shape = blocker_box
		blocker.add_child(blocker_shape)
		blocker.position = ray_start.lerp(ray_end, 0.5)
		root.add_child(blocker)
		await physics_frame
		var safe_position: Vector3 = camera.call("_avoid_obstacles", ray_start, ray_end, player)
		_check(safe_position.distance_to(ray_end) > 0.5, "camera obstruction ray negeert gebouwen")
		blocker.queue_free()
		await physics_frame
		game.get("attack")["N"] = 2.0
		game.call("mark_attack", Vector3(0, 0, -20))
		_check(game.get("attack")["N"] > 0.0, "noordelijke aanvalsrichting mist radarbrondata")
		game.set("build_mode", true)
		await process_frame
		await process_frame
		_check(not radar.visible, "radar bedekt de bouwinterface")
		game.set("build_mode", false)
	var materials := ["palm", "leaf", "fern"]
	foliage_script.call("update_visibility_focus", player.global_position, camera.global_position)
	for kind in materials:
		var mat: ShaderMaterial = foliage_script.call("material", kind)
		_check(bool(mat.get_shader_parameter("fade_sightline")), "foliage uniform ontbreekt voor " + kind)
	main.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty():
		print("CAMERA TEST PASS: camera modes, zoom, build restore, HUD touch targets, radar projection, attack data and foliage uniforms")
		quit(0)
	else:
		quit(1)
