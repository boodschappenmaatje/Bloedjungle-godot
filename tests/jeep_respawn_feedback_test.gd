extends SceneTree
## 5a-3b: death in a driven jeep must never pin the player to the vehicle;
## confirmed M2 gunner hits show option-B feedback only on actual body hits.
## Run: godot --headless --path . --script tests/jeep_respawn_feedback_test.gd --fixed-fps 60

var fails := 0
var watchdog := 0


func _initialize() -> void:
	call_deferred("_run")


func _process(_delta: float) -> bool:
	watchdog += 1
	if watchdog > 850:
		push_error("jeep respawn / feedback fixture stalled")
		quit(99)
	return false


func _frames(count: int) -> void:
	for _i in count:
		await process_frame


func _check(label: String, yes: bool) -> void:
	print(("OK " if yes else "FOUT ") + label)
	if not yes:
		fails += 1


func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	main.begin()
	await _frames(12)
	var game = root.get_node("Game")
	game.state = "play"
	var player = game.player
	var camera = main.get_node("Camera")
	_check("player starts at home", player.home.distance_to(Vector3(0, 0, 4)) < 0.2)

	var jeep = load("res://scenes/jeep.tscn").instantiate()
	main.add_child(jeep)
	jeep.global_position = Vector3(52.0, 0.0, -48.0)
	player.global_position = jeep.global_position
	await _frames(3)
	jeep._toggle()
	_check("jeep can be driven", jeep.driven and player.driving and not player.visible)
	var parked: Vector3 = jeep.global_position
	# Stap V3: in je jeep vangt de jeep de schade op; je sneuvelt pas als de jeep vernield wordt.
	player.hit(99999.0, Vector3.FORWARD, false)
	_check("zittend in de jeep raakt een kogel jou niet persoonlijk", not player.dead and player.hp > 0.0)
	jeep._schade.take(99999.0, Vector3.FORWARD)
	_check("player died inside jeep", player.dead and player.respawn_t > 0.0)
	await _frames(3)
	_check("death forcibly ends jeep driving", not jeep.driven and not player.driving)
	_check("player visible again after death", player.visible)
	_check("collision mask restored after jeep death", player.collision_mask == player.get("_mask0"))
	_check("jeep stays at death scene", jeep.global_position.distance_to(parked) < 0.1)
	player.respawn_t = 0.04
	await _frames(8)
	_check("respawned alive after death in jeep", not player.dead)
	_check("respawn back at own bunker", player.global_position.distance_to(player.home) < 0.1)
	_check("respawn not in driving mode", not player.driving and not jeep.driven)
	_check("respawn visible and collidable", player.visible and player.collision_mask == player.get("_mask0"))
	var focus: Vector3 = camera.focus
	_check("camera snapped back to own base", Vector2(focus.x, focus.z).distance_to(Vector2(player.home.x, player.home.z)) < 20.0)

	# Actual defenders are used (approved Meshy 60k tower + assault rig).
	var towers = get_nodes_in_group("vijand_toren")
	_check("existing four towers remain", towers.size() == 4)
	if towers.size() > 0:
		var tower = towers[0]
		var gunner = tower.shooter
		_check("tower starts with living gunner", is_instance_valid(gunner) and not gunner.dead)
		if is_instance_valid(gunner) and not gunner.dead:
			game.hit_src = "speler"
			var hp_before: float = gunner.hp
			gunner.hit(9.0, Vector3.FORWARD, true)
			await _frames(2)
			_check("hit lowers actual gunner HP", gunner.hp == hp_before - 9.0)
			_check("visible short gunner hit marker", gunner.get_node("M2HitConfirm").visible and gunner.get_node("M2HitConfirm").text == "×")
			_check("gunner HP bar enlarged for confirmed hits", gunner._range_marker.visible and gunner._range_marker.scale.x > 1.3)
			# The marker lives for 0.24 seconds of _process(delta) time. In a
			# headless run, process_frame count is not a reliable wall-clock timer;
			# 18 frames may elapse before the game has simulated 0.24 seconds.
			var marker: Label3D = gunner.get_node("M2HitConfirm")
			var marker_lifetime: float = gunner._hit_cross_t
			_check("confirmed hit marker uses a short lifetime", marker_lifetime > 0.0 and marker_lifetime <= 0.25)
			var marker_faded := false
			# Wait for the *actual* timer to expire, but keep a strict watchdog so
			# a stuck, repeated or non-updating marker still fails the regression.
			for _frame in 120:
				await process_frame
				if not marker.visible:
					marker_faded = true
					break
			if not marker_faded:
				print("Hit marker remained visible after 120 frames; timer=", gunner._hit_cross_t)
			_check("hit marker fades rather than cluttering HUD", marker_faded and gunner._hit_cross_t <= 0.0)
			gunner.hit(9999.0, Vector3.UP, true)
			await _frames(2)
			_check("kill has an MG-out marker", gunner.dead and gunner.get_node("M2HitConfirm").visible and gunner.get_node("M2HitConfirm").text == "MG UIT")
			_check("dead gunner stops tower weapon", not tower.operational() and not tower.destroyed)

	print("jeep respawn and feedback errors: ", fails)
	quit(1 if fails else 0)
