extends SceneTree
## Schermafbeeldingen van de killstreak in de echte spelcamera (iPhone-formaat liggend, 2x): teller, knop, napalm richten,
## het toestel, brandende vijanden en de versterking.
## xvfb-run -a -s "-screen 0 1900x900x24" godot --rendering-driver opengl3 --path . -s tests/killstreak_foto.gd --fixed-fps 60

var main: Node
var game: Node
var out := "/tmp/claude-0/ks_%s.png"


func _initialize() -> void:
	OS.set_environment("BJ_TOUCH", "1")
	root.size = Vector2i(1864, 860)
	call_deferred("_run")


func _frames(n: int) -> void:
	for _i in n:
		await process_frame


func _shot(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(out % name)
	print("foto ", name)


func _enemy(at: Vector3, stay := true) -> Node:
	var e: Node = load("res://scenes/enemy.tscn").instantiate()
	e.setup("rifle", 1)
	main.add_child(e)
	e.global_position = at
	if stay:
		e.stun_t = 100.0
	return e


func _touch(pressed: bool, at: Vector2) -> void:
	var e := InputEventScreenTouch.new()
	e.position = root.get_final_transform() * at
	e.pressed = pressed
	root.push_input(e)


func _drag(at: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.position = root.get_final_transform() * at
	root.push_input(e)


func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	game = root.get_node("Game")
	await _frames(3)
	main.get_node("Hud/Sticks").set_process(false)
	await main.call("begin")
	await _frames(3)
	for m in get_nodes_in_group("menus"):
		m._show("")
	GameSettings.set_value("time", "day")
	for a in get_nodes_in_group("atmosphere"):
		a.apply_settings()
	game.player.global_position = Vector3(10, 0, 40)
	game.player.face = PI
	await _frames(40)
	game.move = Vector2.ZERO
	for i in 7:
		game.streak_kill()
	await _frames(20)
	_shot("1_teller")
	for i in 3:
		game.streak_kill()
	await _frames(25)
	_shot("2_versterking_klaar")
	# napalm klaar en richten met de echte knop
	for i in 6:
		game.streak_kill()
	await _frames(20)
	var btn: Control
	for n in get_nodes_in_group("hud_button"):
		if n.get("kind") == "lucht":
			btn = n
	var p: Vector3 = game.player.global_position
	var foes: Array = []
	for i in 6:
		foes.append(_enemy(p + Vector3(0.7 * (i % 2) - 0.3, 0, -3.0 - i * 2.8)))
	foes.append(_enemy(p + Vector3(9, 0, -9)))   # buiten de strook
	# eerst de truck gebruiken (staat achteraan de bank), dan blijft napalm over
	game.streak_bank = ["truck", "napalm"]
	game.changed.emit()
	await _frames(10)
	var c: Vector2 = btn.get_global_rect().get_center()
	_touch(true, c)
	await _frames(4)
	_drag(c + Vector2(0, -13.0))   # slepen: strook ongeveer 10 m naar het noorden (omhoog op het scherm)
	await _frames(30)
	_shot("3_napalm_richten")
	_touch(false, c)
	await _frames(1)
	await _frames(70)
	_shot("4_toestel")
	await _frames(70)
	_shot("5_inslag")
	await _frames(120)
	_shot("6_brandend_rennen")
	await _frames(240)
	_shot("7_gevallen")
	# versterking
	_touch(true, c)
	await _frames(2)
	_touch(false, c)
	await _frames(150)
	_shot("8_truck_komt")
	await _frames(300)
	_shot("9_soldaten")
	quit(0)
