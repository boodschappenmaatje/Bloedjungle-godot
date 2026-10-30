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
	# afstand en hoek gelden voor het kijkpunt (speler + look-ahead + schuif naar achteren)
	var strategic_distance := camera.global_position.distance_to(camera.get("focus"))
	_check(absf(strategic_distance - 22.5) < 0.8, "strategische cameraafstand is %.2f i.p.v. 22,5 m" % strategic_distance)
	var screen_h := float(root.get_visible_rect().size.y)
	var player_y := camera.unproject_position(player.global_position + Vector3.UP).y
	_check(player_y > screen_h * 0.5 and player_y < screen_h * 0.7, "speler staat niet iets onder het schermmidden (y=%.0f van %.0f)" % [player_y, screen_h])
	var strategic_angle := rad_to_deg(atan2(camera.global_transform.basis.z.y, Vector2(camera.global_transform.basis.z.x, camera.global_transform.basis.z.z).length()))
	var saved_pitch := GameSettings.get_value("camera_pitch")
	var expected_pitch := clampf(float(saved_pitch), 35.0, 75.0)
	_check(absf(strategic_angle - expected_pitch) < 0.8, "strategische kijkhoek is %.2f° i.p.v. %.0f°" % [strategic_angle, expected_pitch])
	var pitch_slider := main.find_child("CameraPitchSlider", true, false) as HSlider
	_check(pitch_slider != null, "camerahoek-schuifregelaar ontbreekt in Instellingen")
	if pitch_slider != null:
		_check(pitch_slider.min_value == 35.0 and pitch_slider.max_value == 75.0 and pitch_slider.step == 1.0, "camerahoek-schuifregelaar heeft verkeerde grenzen of stappen")
	# Echte camera-test: wijzig live de opgeslagen instelling en meet de resulterende camerastand.
	for new_pitch in [40, 65, 53]:
		GameSettings.set_value("camera_pitch", str(new_pitch))
		await _settle_camera(camera, 90)
		var measured := rad_to_deg(atan2(camera.global_transform.basis.z.y, Vector2(camera.global_transform.basis.z.x, camera.global_transform.basis.z.z).length()))
		_check(absf(measured - float(new_pitch)) < 1.2, "hoek %d° geeft camerastand %.2f°" % [new_pitch, measured])
	GameSettings.set_value("camera_pitch", saved_pitch)
	await _settle_camera(camera, 90)
	camera.call("toggle_view")
	await _settle_camera(camera, 150)  # inzoomen gaat bewust langzaam (0,85/s)
	var combat_distance := camera.global_position.distance_to(camera.get("focus"))
	_check(bool(camera.get("combat_view")), "gevechtsstand schakelt niet in")
	_check(absf(combat_distance - 20.0) < 0.8, "gevechtscameraafstand is %.2f i.p.v. 20 m" % combat_distance)
	var combat_angle := rad_to_deg(atan2(camera.global_transform.basis.z.y, Vector2(camera.global_transform.basis.z.x, camera.global_transform.basis.z.z).length()))
	_check(absf(combat_angle - expected_pitch) < 0.8, "gevechtskijkhoek is %.2f° i.p.v. %.0f°" % [combat_angle, expected_pitch])
	_check(absf(camera.fov - 45.0) < 0.01, "camerafov is niet 45°")
	camera.call("toggle_view")
	await _settle_camera(camera)
	_check(not bool(camera.get("combat_view")), "camera wisselt niet terug naar strategisch")
	game.set("build_mode", true)
	var selected_view: bool = bool(camera.get("combat_view"))
	_check(not camera.has_method("zoom"), "handmatige gameplayzoom mag niet meer bestaan")
	_check(not camera.has_method("_unhandled_input"), "muiswielzoom mag niet meer bestaan")
	await _settle_camera(camera, 90)
	var build_pitch := rad_to_deg(asin(camera.global_transform.basis.z.y))
	_check(absf(build_pitch - 71.0) < 3.0, "bouwcamera kijkt onder %.1f° i.p.v. circa 70°" % build_pitch)
	_check(camera.global_position.y > 35.0, "bouwcamera hangt niet hoog boven de basis")
	game.set("build_mode", false)
	await _settle_camera(camera, 120)
	_check(bool(camera.get("combat_view")) == selected_view, "bouwmodus vergat de geselecteerde speelcamera")
	var after_distance := camera.global_position.distance_to(camera.get("focus"))
	_check(absf(after_distance - 22.5) < 1.0, "camera keert niet terug op de vaste speelafstand (%.2f m)" % after_distance)
	# Een nabije tank en twee teamleden mogen het kader tijdelijk verruimen, zonder handmatige zoom.
	var tank := load("res://scenes/tank.tscn").instantiate() as Node3D
	tank.position = player.position + Vector3(6.0, 0.0, 2.0)
	main.add_child(tank)
	for i in 2:
		var ally: Node3D = (load("res://scripts/ally.gd") as Script).new()
		ally.call("setup", 100.0, 16.0, i)
		ally.position = player.position + Vector3(-4.0 - i * 3.0, 0.0, -2.0)
		main.add_child(ally)
		ally.set_physics_process(false)
		game.allies.append(ally)
	await _settle_camera(camera, 90)
	_check(float(camera.get("_group_distance")) > 24.0, "teamcamera maakt geen ruimte voor tank en teamleden")
	_check(int(camera.get("zoom_step")) == 0, "vaste camera heeft onverwachte handmatige zoomstap")
	# Lopen naast de tank: de speler mag op het scherm niet periodiek verspringen (groepsscan elke 0,4 s).
	var jump := 0.0
	var last_screen := camera.unproject_position(player.global_position)
	for _i in 120:
		player.global_position += Vector3(0.0, 0.0, 3.5 / 60.0)
		camera.call("_process", 1.0 / 60.0)
		await process_frame
		var screen := camera.unproject_position(player.global_position)
		jump = maxf(jump, screen.distance_to(last_screen) / screen_h * 720.0)  # omgerekend naar een 720p-scherm
		last_screen = screen
	_check(jump < 4.0, "teamcamera verspringt tijdens lopen (%.1f px op 720p in één frame)" % jump)
	print("CAMERA TEST: grootste schermsprong speler per frame %.2f px op 720p" % jump)
	tank.queue_free()
	for ally in game.allies:
		ally.queue_free()
	game.allies.clear()
	var hud: Node = main.get_node("Hud")
	var extra: Node = hud.find_child("HudExtra", true, false)
	var radar: Control = hud.find_child("TacticalRadar", true, false)
	_check(extra != null and radar != null, "HUD-camera-controls of radar ontbreekt")
	if extra != null and radar != null:
		_check(radar.visible, "radar is niet zichtbaar tijdens prep")
		var marker: Vector2 = extra.call("_radar_point", Vector3.ZERO, Rect2(Vector2.ZERO, Vector2(100, 100)))
		var expected_y := 100.0 * Data.WORLD_Z_N / (Data.WORLD_Z_N + Data.WORLD_Z_S)
		_check(absf(marker.x - 50.0) < 0.1 and absf(marker.y - expected_y) < 0.2, "radar projecteert wereldcoördinaten verkeerd")
		var view_button: Button = hud.find_child("CameraViewButton", true, false)
		_check(view_button != null and view_button.is_in_group("hud_button"), "camera-knop blokkeert geen stick-touch")
		if view_button != null:
			var touch: Node = hud.get_node("Sticks")
			_check(touch.call("_on_button", view_button.get_global_rect().get_center()), "touchknop wordt als stickbeweging gelezen")
		# radar: alleen vijanden in zicht
		var far_enemy := Node3D.new()
		root.add_child(far_enemy)
		far_enemy.global_position = player.global_position + Vector3(220.0, 0.0, 0.0)
		var near_enemy := Node3D.new()
		root.add_child(near_enemy)
		near_enemy.global_position = player.global_position + Vector3(10.0, 0.0, 0.0)
		_check(float(extra.call("_enemy_vis", far_enemy)) == 0.0, "radar toont een vijand ver buiten elk zicht")
		_check(float(extra.call("_enemy_vis", near_enemy)) == 1.0, "radar mist een vijand vlak bij de speler")
		far_enemy.queue_free()
		near_enemy.queue_free()
		_check(hud.find_child("CameraZoomOutButton", true, false) == null and hud.find_child("CameraZoomInButton", true, false) == null, "handmatige camerazoomknoppen staan nog in de HUD")
		_check(not extra.has_method("_two_touch_distance"), "HUD heeft nog pinch-detectie")
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
		var build_radar: Control = main.get_node("Hud").find_child("TacticalRadar", true, false)
		game.set("build_mode", true)
		await process_frame
		await process_frame
		_check(build_radar.visible, "minimap verdwijnt in bouwmodus")
		game.set("build_mode", false)
	var materials := ["palm", "leaf", "fern"]
	foliage_script.call("update_visibility_focus", player.global_position, camera.global_position, 1.0, true, [player.global_position + Vector3(5, 0, 0)])
	for kind in materials:
		var mat: ShaderMaterial = foliage_script.call("material", kind)
		_check(bool(mat.get_shader_parameter("fade_sightline")), "foliage uniform ontbreekt voor " + kind)
		_check(float(mat.get_shader_parameter("fade_amount")) > 0.99, "foliage-fade loopt niet in voor " + kind)
		var e0: Vector4 = mat.get_shader_parameter("view_e0")
		_check(e0.w > 0.5, "vijandelijke zichtlijn is niet doorgegeven voor " + kind)
	# in de bouwmodus loopt de fade rustig uit (niet in één stap) en is daarna uit
	foliage_script.call("update_visibility_focus", player.global_position, camera.global_position, 0.1, false)
	var mid: ShaderMaterial = foliage_script.call("material", "palm")
	_check(bool(mid.get_shader_parameter("fade_sightline")) and float(mid.get_shader_parameter("fade_amount")) > 0.5, "foliage-fade valt abrupt weg in plaats van uit te lopen")
	foliage_script.call("update_visibility_focus", player.global_position, camera.global_position, 1.0, false)
	_check(not bool(mid.get_shader_parameter("fade_sightline")), "foliage-fade blijft aan buiten het speelbeeld")
	foliage_script.call("update_visibility_focus", player.global_position, camera.global_position, 1.0, true)
	_check(bool(mid.get_shader_parameter("fade_sightline")), "foliage-fade komt niet terug na de bouwmodus")
	main.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty():
		print("CAMERA TEST PASS: adjustable pitch, fixed zoom, build restore, HUD touch targets, radar projection, attack data and foliage uniforms")
		quit(0)
	else:
		quit(1)
