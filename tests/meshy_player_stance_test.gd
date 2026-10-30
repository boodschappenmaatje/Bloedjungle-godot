extends Node
## Houdingen van de Meshy-speler: hurken en liggen (knoplogica, capsule, ruimtecontrole, clips, tempo, geweergreep).

var failures: Array[String] = []
var _samples := {"right": 0.0, "left": 0.0}
var _model: Variant


func _ready() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error("MESHY STANCE: " + message)


func _grip(side: String) -> void:
	var skeleton: Skeleton3D = _model._mesh_skeleton
	var bone := skeleton.find_bone("mixamorig_RightHand" if side == "right" else "mixamorig_LeftHand")
	var target: Node3D = _model._mesh_right_target if side == "right" else _model._mesh_weapon_adapter.left_hand_grip
	_samples[side] = skeleton.to_global(skeleton.get_bone_global_pose(bone).origin).distance_to(target.global_position)


func _run() -> void:
	GameSettings.get_value("soldaat")
	var game: Node = get_tree().root.get_node("Game")
	var old_setting: String = str(GameSettings.values["soldaat"])
	GameSettings.values["soldaat"] = "meshy"
	game.set("state", "menu")
	game.set("cur", "garand")
	game.set("owned", game.call("_fresh_owned"))
	var owned: Dictionary = game.get("owned")
	owned["garand"] = {"up": {"dmg": 0, "rate": 0, "mag": 0, "rel": 0}, "ammo": 5}
	game.set("owned", owned)
	var world := Node3D.new()
	get_tree().root.add_child(world)
	var player: Variant = load("res://scenes/player.tscn").instantiate()
	world.add_child(player)
	await get_tree().process_frame
	await get_tree().physics_frame
	game.set("state", "play")
	var model: Variant = player.get_node("Model")
	_model = model
	model._mesh_right_ik.modification_processed.connect(_grip.bind("right"))
	model._mesh_left_ik.modification_processed.connect(_grip.bind("left"))
	player.set_physics_process(false)   # de controller zou anders elk frame zelf "stil" spelen; dit test roept _animate zelf aan
	var shape := player.get_node("Shape") as CollisionShape3D

	_check(player.stance == 0 and (shape.shape as CapsuleShape3D).height > 2.1, "start niet staand")
	# tik: staan > hurken > liggen > staan
	player.cycle_stance()
	_check(player.stance == 1 and is_equal_approx((shape.shape as CapsuleShape3D).height, 1.4), "tik 1 geeft geen hurken met lagere capsule")
	player.cycle_stance()
	_check(player.stance == 2 and is_equal_approx((shape.shape as CapsuleShape3D).height, 0.7), "tik 2 geeft geen liggen met lage capsule")
	player.cycle_stance()
	_check(player.stance == 0 and (shape.shape as CapsuleShape3D).height > 2.1, "tik 3 staat niet weer op")
	# lang indrukken: meteen liggen, en weer opstaan
	player.cycle_stance(true)
	_check(player.stance == 2, "lang indrukken legt hem niet plat")
	player.cycle_stance(true)
	_check(player.stance == 0, "lang indrukken laat hem niet opstaan")
	# de capsule van een tweede speler is niet gedeeld met de scène
	var other: Variant = load("res://scenes/player.tscn").instantiate()
	world.add_child(other)   # de capsule wordt pas in _ready los gemaakt
	other.set_physics_process(false)
	_check((other.get_node("Shape") as CollisionShape3D).shape != shape.shape, "capsule wordt gedeeld tussen spelers")
	other.queue_free()

	# per houding de juiste clips en een geweergreep binnen 3 cm
	var expected := {1: ["hurken_stil", "hurken_lopen", "hurken_achteruit"], 2: ["liggen_stil", "kruipen", "kruipen"]}
	for st in [1, 2]:
		player.set_stance(st)
		await get_tree().create_timer(0.6).timeout   # de greep zakt mee met de houding
		player._animate(Vector2.ZERO, 0.0)
		await get_tree().process_frame
		_check(model.current == expected[st][0], "stilstaan in houding %d speelt %s" % [st, model.current])
		_check(model._mesh_armed, "geweer niet in de handen in houding %d" % st)
		await get_tree().create_timer(0.4).timeout
		print("MESHY_STANCE_GRIP stance=", st, " clip=", model.current, " right_error_m=", _samples["right"], " left_error_m=", _samples["left"])
		_check(_samples["right"] <= 0.03 and _samples["left"] <= 0.06, "hand %d: rechts %.3f links %.3f m van de greep" % [st, _samples["right"], _samples["left"]])
		player.face = 0.0
		player._animate(Vector2(0, 1), 1.0)
		await get_tree().process_frame
		_check(model.current == expected[st][1], "vooruit in houding %d speelt %s" % [st, model.current])
		await get_tree().create_timer(0.4).timeout
		print("MESHY_STANCE_GRIP_MOVE stance=", st, " clip=", model.current, " right_error_m=", _samples["right"], " left_error_m=", _samples["left"])
		_check(_samples["right"] <= 0.05 and _samples["left"] <= 0.06, "hand lopend %d: rechts %.3f links %.3f m" % [st, _samples["right"], _samples["left"]])
		player._animate(Vector2(0, -1), 1.0)
		await get_tree().process_frame
		_check(model.current == expected[st][2], "achteruit in houding %d speelt %s" % [st, model.current])
		if st == 2:
			_check(model.anim.speed_scale > 0.0, "achteruit kruipen moet de clip voorwaarts spelen")
			player._animate(Vector2(0, 1), 1.0)
			await get_tree().process_frame
			_check(model.anim.speed_scale < 0.0, "vooruit kruipen moet de achteruit-clip omgekeerd spelen")

	# opstaan onder een laag dak: blijft liggen of hurken waar het past
	player.set_stance(2)
	var roof := StaticBody3D.new()
	roof.collision_layer = 2
	var roof_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6, 0.2, 6)
	roof_shape.shape = box
	roof.add_child(roof_shape)
	world.add_child(roof)
	roof.global_position = Vector3(0, 1.1, 0)   # onderkant op 1,0 m: hurken (1,4 m) past niet, liggen (0,7 m) wel
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.set_stance(0)
	_check(player.stance == 2, "kon opstaan onder een dak van 1,0 m (houding %d)" % player.stance)
	roof.global_position = Vector3(0, 1.8, 0)   # onderkant op 1,7 m: hurken past, staan (2,15 m) niet
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.set_stance(0)
	_check(player.stance == 1, "onder een dak van 1,7 m hoort hij te hurken, houding %d" % player.stance)
	roof.free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.set_stance(0)
	_check(player.stance == 0, "kon niet opstaan zonder dak")

	# sprint en koprol laten hem opstaan
	player.set_stance(1)
	player.toggle_sprint()
	_check(player.stance == 0 and player.sprint_on, "sprint zet hem niet rechtop")
	player.sprint_on = false
	player.set_stance(2)
	player.dodge_cd = 0.0
	player.stamina = 1.0
	player.request_dodge()
	_check(player.stance == 0 and player.dodge_t > 0.0, "koprol zet hem niet rechtop")

	GameSettings.values["soldaat"] = old_setting
	world.free()
	await get_tree().process_frame
	if failures.is_empty():
		print("MESHY_STANCE_RESULT=PASS")
		get_tree().quit(0)
	else:
		print("MESHY_STANCE_RESULT=FAIL count=", failures.size())
		get_tree().quit(1)
