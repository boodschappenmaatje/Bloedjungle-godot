extends SceneTree
## Schietsysteem 2.0: world-space read-only aim preview and confirmed jeep M2 hits.
## godot --headless --path . --script tests/combat_feedback_test.gd --fixed-fps 60
var failures := 0
var watchdog := 0

func _initialize() -> void:
	call_deferred("_run")

func _process(_dt: float) -> bool:
	watchdog += 1
	if watchdog > 900:
		push_error("combat feedback test watchdog expired")
		quit(99)
	return false

func _frames(n: int) -> void:
	for _i in n:
		await process_frame

func _check(label: String, success: bool) -> void:
	print(("PASS " if success else "FAIL ") + label)
	if not success:
		failures += 1

func _wall(parent: Node3D, at: Vector3) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.collision_layer = Kit.LAYER_FORTIFICATION
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 10.0, 0.4)
	var shape := CollisionShape3D.new()
	shape.shape = box
	wall.add_child(shape)
	parent.add_child(wall)
	wall.global_position = at
	return wall

func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(main)
	await _frames(3)
	main.begin()
	await _frames(40)

	_check("damage preview is never a confirmed hit", is_zero_approx(CombatAimFeedback.actual_damage(90.0, 90.0)))
	_check("actual HP decrease is positive", is_equal_approx(CombatAimFeedback.actual_damage(90.0, 81.0), 9.0))
	_check("healing is not reported as gunshot damage", is_zero_approx(CombatAimFeedback.actual_damage(81.0, 90.0)))

	var hud := get_first_node_in_group("combat_target_hud") as CombatTargetHud
	_check("HUD exists and never intercepts input", hud != null and hud.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	var tower = load("res://scripts/vijand_m2_toren.gd").new()
	tower.name = "CombatFeedbackTower"
	tower.position = Vector3(300.0, 0.0, -20.0)
	main.add_child(tower)
	var shooter = load("res://scenes/vijand_verdediger.tscn").instantiate()
	shooter.setup("assault", 1)
	shooter.post = "schutter"
	shooter.add_to_group("vijand_verdediger")
	shooter.hp = 90.0
	shooter.max_hp = 90.0
	main.add_child(shooter)
	shooter.global_position = tower.get_node("ShooterMount").global_position
	shooter.tower = tower
	tower.shooter = shooter

	var jeep = load("res://scenes/jeep.tscn").instantiate()
	main.add_child(jeep)
	jeep.global_position = tower.global_position + Vector3(0.0, 0.0, 21.0)
	jeep.rotation.y = 0.0
	jeep.set_physics_process(false)
	await _frames(3)

	var shield: Node3D = tower.yaw.get_node_or_null("MG_ShieldCollision")
	_check("steel shield is not a vulnerable gunner", shield != null and CombatAimFeedback.target_kind(shield) == "blocked")
	_check("live tower gunner is a valid enemy", CombatAimFeedback.target_kind(shooter) == "enemy")
	var from: Vector3 = jeep._monding.global_position
	var to: Vector3 = shooter.global_position + Vector3.UP * 1.85
	var diff: Vector3 = to - from
	var angle := atan2(diff.x, diff.z)
	var assist: Dictionary = jeep._tower_gunner_solution(from, angle)
	_check("existing narrow gunner solution stays available", not assist.is_empty() and assist.target == shooter)
	if assist.is_empty():
		print("COMBAT FEEDBACK TEST FAIL: no aim solution")
		quit(1)
		return
	var space := main.get_world_3d().direct_space_state
	var preview := CombatAimFeedback.predict(space, from, float(assist.angle), float(assist.rise))
	_check("world aim ray hits actual gunner capsule", preview.state == "enemy" and preview.target == shooter)
	_check("predicted point is near tower gunner", preview.point.distance_to(to) < 1.5)
	if hud != null:
		hud.set_prediction(preview)
		_check("HUD receives only one active target", hud._prediction.get("target") == shooter)
		hud.clear_prediction()
		_check("HUD drops prediction when controls are released", hud._prediction.is_empty())

	var wall := _wall(main, from.lerp(to, 0.5))
	await _frames(3)
	preview = CombatAimFeedback.predict(space, from, float(assist.angle), float(assist.rise))
	_check("wall wins over gunner in preview", preview.state == "blocked" and preview.target == null)
	_check("existing gunner assist still rejects wall", jeep._tower_gunner_solution(from, angle).is_empty())
	wall.queue_free()
	await _frames(3)
	preview = CombatAimFeedback.predict(space, from, float(assist.angle), float(assist.rise))
	_check("gunner becomes visible when wall is removed", preview.state == "enemy" and preview.target == shooter)

	var hits: Array = []
	Game.combat_hit_confirmed.connect(func(point: Vector3, amount: float, source: String) -> void:
		if source == "jeep":
			hits.append({"point": point, "amount": amount}))
	var hp_before: float = shooter.hp
	# The *real* Bullet path, not calling shooter.hit() directly.
	for _shot in 11:
		jeep._shoot(float(assist.angle), float(assist.rise))
	await _frames(60)
	_check("real jeep M2 bullets still damage live tower gunner", shooter.hp < hp_before)
	_check("confirmed hit events follow real HP decreases", hits.size() > 0)
	_check("each event has only positive actual damage", hits.all(func(h: Dictionary) -> bool: return float(h.amount) > 0.0))
	_check("gunner death does not destroy tower", shooter.dead and not tower.destroyed)
	print("COMBAT FEEDBACK TEST ", "PASS" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures else 0)
