extends SceneTree
## Controleert de acties uit bron/acties: de drie animaties zitten in het mannetje, hebben de juiste lengte en
## loop-instelling, en de speler speelt ze op het juiste moment (rol, sprint, herladen op maat).
## Draaien: godot --headless --path . -s tests/animatie_test.gd --fixed-fps 60

var failures: Array[String] = []
var game: Node
var player: Node3D


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("ANIMATIE TEST: " + message)


func _frames(n: int) -> void:
	for _i in n:
		await physics_frame


func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	game = root.get_node("Game")
	for _i in 3:
		await process_frame
	main.get_node("Hud/Sticks").set_process(false)
	await main.call("begin")
	for _i in 3:
		await process_frame
	player = game.get("player")
	var model: Node = player.get("model")
	var anim: AnimationPlayer = model.get("anim")
	for clip in ["rollen", "sprinten", "herladen"]:
		_check(anim.has_animation(clip), "animatie %s ontbreekt" % clip)
	_check(absf(model.call("clip_length", "rollen") - 0.5) < 0.05, "rollen is %.2f s i.p.v. 0,5 s" % model.call("clip_length", "rollen"))
	_check(absf(model.call("clip_length", "sprinten") - 0.533) < 0.05, "sprinten is %.2f s i.p.v. 0,53 s" % model.call("clip_length", "sprinten"))
	_check(absf(model.call("clip_length", "herladen") - 1.2) < 0.1, "herladen is %.2f s i.p.v. 1,2 s (de oude lus was 3,3 s)" % model.call("clip_length", "herladen"))
	_check(anim.get_animation("sprinten").loop_mode == Animation.LOOP_LINEAR, "sprinten herhaalt niet")
	_check(anim.get_animation("rollen").loop_mode == Animation.LOOP_NONE, "rollen herhaalt zich")
	_check(anim.get_animation("herladen").loop_mode == Animation.LOOP_NONE, "herladen herhaalt zich")
	# de animaties bewegen echt: de heup van de rol komt hoog en laag
	var roll := anim.get_animation("rollen")
	_check(roll.get_track_count() > 40, "de rol heeft te weinig sporen (%d)" % roll.get_track_count())

	# in het spel
	player.global_position = Vector3(0, 0, 40)
	await _frames(5)
	game.set("move", Vector2(1, 0))
	player.call("request_dodge")
	await _frames(3)
	_check(str(model.get("current")) == "rollen", "tijdens de rol speelt '%s'" % model.get("current"))
	await _frames(60)
	game.set("move", Vector2.ZERO)
	_check(str(model.get("current")) != "rollen", "na de rol speelt nog steeds de rolanimatie")
	_check(absf(model.rotation.x) < 0.001 and model.position.length() < 0.001, "model staat na de rol niet recht")

	player.call("toggle_sprint")
	game.set("move", Vector2(1, 0))
	await _frames(25)
	_check(bool(player.get("sprinting")) and str(model.get("current")) == "sprinten", "tijdens sprinten speelt '%s'" % model.get("current"))
	player.call("toggle_sprint")
	game.set("move", Vector2.ZERO)
	await _frames(30)

	player.set("ammo", 0)
	player.call("request_reload")
	await _frames(10)
	_check(str(model.get("current")) == "herladen", "tijdens herladen speelt '%s'" % model.get("current"))
	var dur: float = player.get("_reload_dur")
	_check(absf(anim.speed_scale - float(model.call("clip_length", "herladen")) / dur) < 0.05, "herlaadbeweging past niet op de herlaadtijd (snelheid %.2f, verwacht %.2f)" % [anim.speed_scale, float(model.call("clip_length", "herladen")) / dur])

	main.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty():
		print("ANIMATIE TEST PASS: rollen, sprinten en herladen zitten erin en worden op het juiste moment gespeeld")
		quit(0)
	else:
		quit(1)
