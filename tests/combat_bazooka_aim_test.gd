extends SceneTree
## Schietsysteem 2.0 stap 3A: bazooka preview never changes rocket ballistics.
## Run after import: godot --headless --path . -s tests/combat_bazooka_aim_test.gd --fixed-fps 60
var failures := 0
var watchdog := 0

func _initialize() -> void:
	call_deferred("_run")


func _process(_delta: float) -> bool:
	watchdog += 1
	if watchdog > 900:
		push_error("COMBAT BAZOOKA AIM TEST watchdog expired")
		quit(99)
	return false


func _frames(count: int) -> void:
	for _i in count:
		await process_frame


func _check(condition: bool, label: String) -> void:
	print(("PASS " if condition else "FAIL ") + "bazooka: " + label)
	if not condition:
		failures += 1


func _solid(parent: Node3D, pos: Vector3, layer: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "BazookaAimTestObstacle"
	body.collision_layer = layer
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 4.0, 0.45)
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)
	body.global_position = pos
	return body


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(main)
	await _frames(3)
	main.begin()
	await _frames(35)
	var game: Variant = root.get_node("Game")
	var player: Variant = game.player
	var hud := get_first_node_in_group("combat_target_hud") as CombatTargetHud
	_check(hud != null and hud.mouse_filter == Control.MOUSE_FILTER_IGNORE, "reticle never captures touch input")
	_check(player != null, "game supplies actual player")
	if player == null or hud == null:
		quit(1)
		return

	# Use the live player weapon stats; no source changes to damage, cadence or reload.
	var stats: Dictionary = game.wstat("bazooka")
	var range_m: float = float(stats.speed) * float(stats.life)
	var radius: float = float(stats.explosive)
	_check(is_equal_approx(float(stats.dmg), 240.0), "existing damage remains 240")
	_check(is_equal_approx(float(stats.rate), 1.0), "existing cadence remains 1.0s")
	_check(is_equal_approx(float(stats.speed), 32.0), "existing rocket speed remains 32m/s")
	_check(is_equal_approx(radius, 4.8), "existing explosion radius remains 4.8m")

	var preview_script: Script = load("res://scripts/bazooka_aim_feedback.gd")
	_check(preview_script != null, "dedicated prediction module loads")
	if preview_script == null:
		quit(1)
		return
	var from := Vector3(320.0, 1.65, 25.0)
	var angle := PI
	var space := main.get_world_3d().direct_space_state

	var empty: Dictionary = preview_script.call("predict", space, from, angle, range_m, false, radius)
	_check(empty.state == "range" and not empty.can_explode, "empty corridor shows no fake blast")
	_check(is_zero_approx(float(empty.blast_radius)), "no blast ring for projectile expiry")
	_check(empty.point.distance_to(from + Vector3(0, 0, -range_m)) < 0.05, "empty-ray reticle ends at nominal ballistic range")

	var wall := _solid(main, Vector3(320, 1.65, 15), 2)
	await _frames(3)
	var blocked: Dictionary = preview_script.call("predict", space, from, angle, range_m, false, radius)
	_check(blocked.state == "blocked" and blocked.can_explode, "wall stops projected rocket")
	_check(is_equal_approx(float(blocked.blast_radius), radius), "wall impact gets existing blast radius")
	_check(absf(blocked.point.z - 15.23) < 0.6, "predicted impact agrees with wall collision")
	hud.set_prediction(blocked, "infantry")
	_check(hud._prediction.get("can_explode", false) and hud._prediction.get("source") == "infantry", "HUD receives impact circle without new joystick surface")
	hud.clear_prediction("jeep")
	_check(not hud._prediction.is_empty(), "parked jeep never erases bazooka HUD")
	hud.clear_prediction("infantry")
	_check(hud._prediction.is_empty(), "switching away from bazooka clears blast ring")

	var over: Dictionary = preview_script.call("predict", space, from, angle, range_m, true, radius)
	_check(over.state == "range" and not over.can_explode, "existing over-wall shot ignores ordinary low cover")
	wall.queue_free()
	await _frames(3)

	var high_wall := _solid(main, Vector3(320, 1.65, 15), 4096)
	await _frames(3)
	var fort: Dictionary = preview_script.call("predict", space, from, angle, range_m, true, radius)
	_check(fort.state == "blocked" and fort.can_explode, "high fortification still blocks raised shot")
	_check(fort.point.distance_to(from) < range_m, "fortification is not ignored beyond its actual distance")
	high_wall.queue_free()

	# Aim calculations must never fire a projectile or report actual damage.
	var confirmed := 0
	game.combat_hit_confirmed.connect(func(_at: Vector3, _dmg: float, _source: String) -> void: confirmed += 1)
	await _frames(3)
	preview_script.call("predict", space, from, angle, range_m, false, radius)
	_check(confirmed == 0, "a visual prediction never confirms a hit")
	print("COMBAT BAZOOKA AIM TEST " + ("PASS" if failures == 0 else "%d FAILURES" % failures))
	quit(0 if failures == 0 else 1)
