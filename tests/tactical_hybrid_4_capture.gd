extends SceneTree
## TH4_OUT=/tmp/th4 godot --path . --rendering-driver opengl3 -s tests/tactical_hybrid_4_capture.gd

var scene: Node3D
var frames := 0
var out := "/tmp/th4"
var samples: Array[float] = []


func _initialize() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	if OS.get_environment("TH4_OUT") != "":
		out = OS.get_environment("TH4_OUT")
	DirAccess.make_dir_recursive_absolute(out)
	scene = load("res://tests/tactical_hybrid_4.tscn").instantiate()
	root.add_child.call_deferred(scene)


func _process(_delta: float) -> bool:
	frames += 1
	if OS.has_environment("BJ_CAPTURE_MOVE") and frames >= 80 and frames <= 135:
		var game_for_move := root.get_node_or_null("Game")
		var moving_player: Variant = game_for_move.get("player") if game_for_move != null else null
		if moving_player != null:
			# De testopname verplaatst de echte speler langs de camera; touch wordt apart getest.
			moving_player.global_position.x += 0.08
	if OS.has_environment("BJ_CAPTURE_FIRE") and frames in [59, 119, 149]:
		var game := root.get_node_or_null("Game")
		var player: Variant = game.get("player") if game != null else null
		if player != null:
			var w: Dictionary = game.call("wstat", player.weapon)
			player.model.set_shoot_pose(true, player.weapon, w.rate)
			player._shoot(w)
	if frames >= 60 and frames <= 150:
		samples.append(Performance.get_monitor(Performance.TIME_PROCESS))
	if frames in [60, 120, 150]:
		root.get_viewport().get_texture().get_image().save_png("%s/game_%d.png" % [out, frames])
		var game := root.get_node_or_null("Game")
		var player: Variant = game.get("player") if game != null else null
		var camera := root.get_viewport().get_camera_3d()
		if player != null and camera != null:
			var screen := root.get_viewport().get_visible_rect()
			var projected := 0
			for enemy in game.get("enemies"):
				if is_instance_valid(enemy):
					var above: Vector3 = enemy.global_position + Vector3.UP * 1.2
					if not camera.is_position_behind(above) and screen.has_point(camera.unproject_position(above)):
						projected += 1
			print("TACTICAL_4_FRAME frame=%d player=%s camera=%s enemies=%d projected=%d size=%s" % [frames, player.global_position, camera.global_position, game.get("enemies").size(), projected, screen.size])
	if frames == 151:
		var total := 0.0
		for sample in samples:
			total += sample
		print("TACTICAL_4_MEASURE process_ms_mean=%.3f sample_count=%d renderer=%s" % [total / maxi(1, samples.size()) * 1000.0, samples.size(), DisplayServer.get_name()])
	return frames > 152
