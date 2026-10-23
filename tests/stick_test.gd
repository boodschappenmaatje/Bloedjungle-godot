extends SceneTree
## Controleert beide vaste thumb-zones, richten/vuren en herstel na een gemiste loslaatmelding.
## Draaien: godot --headless --path . -s tests/stick_test.gd --fixed-fps 60

var failures: Array[String] = []


func _initialize() -> void:
	OS.set_environment("BJ_TOUCH", "1")
	root.size = Vector2i(932, 430)
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error("STICK TEST: " + message)


func _frames(n: int) -> void:
	for _i in n:
		await process_frame


func _touch(idx: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.position = pos
	e.pressed = pressed
	Input.parse_input_event(e)


func _drag(idx: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = idx
	e.position = pos
	Input.parse_input_event(e)


func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	root.size = Vector2i(932, 430)
	var game = root.get_node("Game")
	await _frames(3)
	await main.call("begin")
	var pause_menu := get_first_node_in_group("menus")
	if pause_menu != null:
		pause_menu.call("_show", "")  # simulate the real menu's start action
	await _frames(3)
	var sticks: Control = main.get_node("Hud/Sticks")
	var left: Vector2 = sticks.call("_anchor", false)
	var right: Vector2 = sticks.call("_anchor", true)
	_check(Rect2(Vector2.ZERO, root.get_visible_rect().size).has_point(left), "linker stick valt buiten beeld")
	_check(Rect2(Vector2.ZERO, root.get_visible_rect().size).has_point(right), "richtstick valt buiten beeld")

	# Linker duim beweegt de speler soepel in een diagonale richting.
	_touch(0, left, true)
	_drag(0, left + Vector2(36, -27))
	await _frames(2)
	_check(game.move.length() > 0.6 and game.move.x > 0.0 and game.move.y < 0.0, "linker stick levert geen 360°-bewegingsrichting")

	# Rechter duim richt en vuurt onafhankelijk van de bewegingstick.
	_touch(1, right, true)
	_drag(1, right + Vector2(0, 52))
	await _frames(2)
	_check(is_finite(game.aim) and absf(game.aim) < 0.1, "rechter stick stuurt geen richtingshoek")
	_check(game.fire, "rechter stick vuurt niet aan de buitenrand")
	_check(game.move.length() > 0.6, "rechter stick wist de linker bewegingsinput")

	_touch(0, left, false)
	await _frames(2)
	_check(game.move == Vector2.ZERO and game.fire, "linker loslaten wist de actieve richtstick")
	_touch(1, right, false)
	await _frames(2)
	_check(not game.fire and is_nan(game.aim), "rechter loslaten laat vuren of richten actief")

	# Een nieuwe vinger aan dezelfde kant vervangt een stick waarvan release verloren ging.
	_touch(5, left, true)
	_drag(5, left + Vector2(32, 0))
	await _frames(1)
	_touch(6, left, true)
	_drag(6, left + Vector2(0, -42))
	await _frames(2)
	var active: Dictionary = sticks.get("_sticks")
	_check(not active.has(5) and active.has(6), "nieuwe linker aanraking vervangt geen vastgelopen stick")
	_check(game.move.y < -0.5, "vervangende linker aanraking bestuurt de speler niet")
	_touch(6, left, false)
	await _frames(2)
	_check(sticks.get("_sticks").is_empty() and game.move == Vector2.ZERO, "loslaten laat de bewegingstick actief")

	_touch(7, right, true)
	await _frames(1)
	paused = true
	await _frames(1)
	_check(sticks.get("_sticks").is_empty() and game.move == Vector2.ZERO and not game.fire, "pauze laat een virtuele stick vaststaan")
	paused = false

	main.queue_free()
	await process_frame
	if failures.is_empty():
		print("STICK TEST PASS: bewegen, richten, vuren, loslaten en pauzeren")
		quit(0)
	else:
		quit(1)
