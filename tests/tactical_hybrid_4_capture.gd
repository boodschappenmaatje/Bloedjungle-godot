extends SceneTree
## TH4_OUT=/tmp/th4 godot --path . --rendering-driver opengl3 -s tests/tactical_hybrid_4_capture.gd

var scene: Node3D
var frames := 0
var out := "/tmp/th4"
var samples: Array[float] = []


func _initialize() -> void:
	if OS.get_environment("TH4_OUT") != "":
		out = OS.get_environment("TH4_OUT")
	DirAccess.make_dir_recursive_absolute(out)
	scene = load("res://tests/tactical_hybrid_4.tscn").instantiate()
	root.add_child.call_deferred(scene)


func _process(_delta: float) -> bool:
	frames += 1
	if OS.has_environment("BJ_CAPTURE_FIRE") and frames in [116, 146]:
		var game := root.get_node_or_null("Game")
		var player: Variant = game.get("player") if game != null else null
		if player != null:
			var w: Dictionary = game.call("wstat", player.weapon)
			player.model.set_shoot_pose(true, player.weapon, w.rate)
			player._shoot(w)
	if frames >= 60 and frames <= 150:
		samples.append(Performance.get_monitor(Performance.TIME_PROCESS))
	if frames == 120 or frames == 150:
		root.get_viewport().get_texture().get_image().save_png("%s/game_%d.png" % [out, frames])
	if frames == 151:
		var total := 0.0
		for sample in samples:
			total += sample
		print("TACTICAL_4_MEASURE process_ms_mean=%.3f sample_count=%d renderer=%s" % [total / maxi(1, samples.size()) * 1000.0, samples.size(), DisplayServer.get_name()])
	return frames > 152
