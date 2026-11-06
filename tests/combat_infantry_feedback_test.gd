extends SceneTree
## Schietsysteem 2.0 — real on-foot Colt bullet, enemy HP, cover and HUD ownership.
## godot --headless --path . -s tests/combat_infantry_feedback_test.gd --fixed-fps 60
var failures := 0
var watchdog := 0

func _initialize() -> void:
	call_deferred("_run")


func _process(_delta: float) -> bool:
	watchdog += 1
	if watchdog > 900:
		push_error("COMBAT INFANTRY feedback watchdog exceeded")
		quit(99)
	return false


func _check(ok: bool, message: String) -> void:
	print(("PASS infantry: " if ok else "FAIL infantry: ") + message)
	if not ok:
		failures += 1


func _frames(amount: int) -> void:
	for _i in amount:
		await process_frame


func _wall(main: Node3D, middle: Vector3) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.name = "InfantryFeedbackTemporaryWall"
	wall.collision_layer = 2  # Canonical Bullet.MASK_WALL; no test preload cycle.
	wall.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(5.0, 3.0, 0.35)
	shape.shape = box
	wall.add_child(shape)
	main.add_child(wall)
	wall.global_position = middle + Vector3.UP * 1.4
	return wall


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(main)
	await _frames(3)
	main.begin()
	await _frames(40)
	var game: Variant = root.get_node("Game")
	var hud := get_first_node_in_group("combat_target_hud") as CombatTargetHud
	_check(hud != null and hud.mouse_filter == Control.MOUSE_FILTER_IGNORE, "on-foot HUD exists without intercepting iPhone touches")
	var player: Variant = game.player
	_check(player != null, "existing playable soldier is available")
	if player == null or hud == null:
		quit(1)
		return

	# Isolated actual bullet physics outside world props, as in jeep_m2_schutter_test.
	player.set_physics_process(false)
	player.global_position = Vector3(300.0, 0.0, 0.0)
	player.face = PI
	player.rotation.y = PI
	player.weapon = "m1911"
	player.model.set_gun("m1911")
	player.m1911_chambered = true
	player.m1911_mag_rounds = 7
	player._sync_m1911_ammo()
	var enemy: Variant = load("res://scenes/vijand_verdediger.tscn").instantiate()
	enemy.setup("assault", 1)
	enemy.post = "poort"
	main.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.add_to_group("vijand_verdediger")
	enemy.global_position = Vector3(300.0, 0.0, -9.0)
	enemy.hp = 300.0
	enemy.max_hp = 300.0
	game.state = "prep"
	await _frames(3)

	var muzzle: Vector3 = player.model.muzzle_position()
	var offset: Vector3 = enemy.global_position - muzzle
	var angle := atan2(offset.x, offset.z)
	player.face = angle
	player.rotation.y = angle
	muzzle = player.model.muzzle_position()
	var space := main.get_world_3d().direct_space_state
	var w: Dictionary = game.wstat("m1911")
	var expected_range := float(w.speed) * float(w.life)
	var preview := CombatAimFeedback.predict_infantry(space, muzzle, angle, expected_range, false)
	_check(preview.state == "enemy" and preview.target == enemy, "M1911 centerline recognizes an exposed living soldier")
	_check(preview.point.distance_to(enemy.global_position + Vector3.UP * 1.3) < 2.5, "M1911 target marker stays in target's 3D vicinity")
	_check(hud._active(), "HUD is enabled for on-foot soldier, not only jeep")

	hud.set_prediction(preview, "infantry")
	hud.clear_prediction("jeep")
	_check(hud._prediction.get("source") == "infantry", "parked jeep cannot erase on-foot aiming")
	hud.clear_prediction("infantry")
	_check(hud._prediction.is_empty(), "on-foot aim clears on control release")
	hud.set_prediction(preview, "jeep")
	hud.clear_prediction("infantry")
	_check(hud._prediction.get("source") == "jeep", "infantry cleanup does not erase jeep aiming")
	hud.clear_prediction("jeep")

	var wall := _wall(main, muzzle.lerp(enemy.global_position, 0.52))
	await _frames(3)
	preview = CombatAimFeedback.predict_infantry(space, muzzle, angle, expected_range, false)
	_check(preview.state == "blocked" and preview.target == null, "ordinary pistol bullets are visibly blocked by a low wall")
	preview = CombatAimFeedback.predict_infantry(space, muzzle, angle, expected_range, true)
	_check(preview.state == "enemy", "existing over-wall firing exemption is preserved")
	wall.queue_free()
	await _frames(3)

	# Real damage confirmation must originate from Player._shoot -> Bullet physics,
	# never from setting the preview or from the interface callback.
	var confirmed: Array = []
	game.combat_hit_confirmed.connect(func(at: Vector3, amount: float, source: String) -> void:
		if source == "infantry":
			confirmed.append({"point": at, "amount": amount}))
	var hp_before: float = enemy.hp
	var original_rounds: int = player.ammo
	player.fire_t = 0.0
	player.reload_t = 0.0
	player._shoot(w)
	_check(player.ammo == original_rounds - 1, "M1911 consumes exactly one existing cartridge")
	await _frames(25)
	_check(enemy.hp < hp_before, "physical pistol bullet reduces enemy HP")
	_check(confirmed.size() > 0, "one or more real enemy hits emit confirmed infantry feedback")
	_check(confirmed.all(func(e: Dictionary) -> bool: return float(e.amount) > 0.0), "hit events only report positive HP loss")
	_check(hud._hit_time <= CombatTargetHud.HIT_DURATION, "HUD hit flash remains short and bounded")

	# Moving the screen-space aim alone never fires or emits a second hit.
	var count_before := confirmed.size()
	preview = CombatAimFeedback.predict_infantry(space, muzzle, angle, expected_range, false)
	hud.set_prediction(preview, "infantry")
	await _frames(2)
	_check(confirmed.size() == count_before, "aim prediction alone never confirms damage")
	hud.clear_prediction("infantry")

	# Weapon presets are read-only: keep their existing ballistic ranges.
	for weapon_id in ["m1911", "thompson", "garand", "trench", "mg42"]:
		var stats: Dictionary = game.wstat(weapon_id)
		var radius := float(stats.speed) * float(stats.life)
		_check(radius > 0.0 and CombatAimFeedback.predict_infantry(space, muzzle, angle, radius, false).has("state"), weapon_id + " shares the on-foot reticle system")
	_check(CombatAimFeedback.actual_damage(26.0, 26.0) == 0.0, "zero HP change is never a confirmed hit")
	print("COMBAT INFANTRY FEEDBACK TEST " + ("PASS" if failures == 0 else "%d FAILURES" % failures))
	quit(0 if failures == 0 else 1)
