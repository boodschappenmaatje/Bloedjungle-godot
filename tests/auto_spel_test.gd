extends SceneTree
## Test zoals in Dennis' opname: echte stad (StadData), golf loopt (vijanden en richthulp actief), iPhone-scherm met touch-sticks.
## De speler staat schuin onder de geparkeerde auto en richt met de rechter duim op de auto; elk wapen moet raken.
## Daarna hetzelfde op de bus, en van verder weg.
## Draaien: godot --headless --path . -s tests/auto_spel_test.gd --fixed-fps 60

const WEAPONS := ["m1911", "thompson", "garand", "trench", "mg42", "bazooka"]

var failures := 0
var game
var main: Node


func _initialize() -> void:
	OS.set_environment("BJ_TOUCH", "1")
	root.size = Vector2i(932, 430)
	call_deferred("_run")


func _check(name: String, ok: bool) -> void:
	print(("OK    " if ok else "FAIL  ") + name)
	if not ok:
		failures += 1


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
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	root.size = Vector2i(932, 430)
	game = root.get_node("Game")
	await _frames(3)
	await main.call("begin")
	var pause_menu := get_first_node_in_group("menus")
	if pause_menu != null:
		pause_menu.call("_show", "")
	await _frames(3)
	main.call("start_wave")
	await _frames(240)
	_check("golf loopt met vijanden (richthulp actief): %d vijanden" % game.enemies.size(), game.state == "play" and game.enemies.size() > 0)
	var car: Node3D = null
	var bus: Node3D = null
	for n in root.find_children("*", "CharacterBody3D", true, false):
		var path := String(n.get_script().resource_path) if n.get_script() else ""
		if path.ends_with("auto.gd") and n.get("kind") == "auto" and car == null:
			car = n
		elif path.ends_with("bus.gd") and n.get("kind") == "bus" and bus == null:
			bus = n
	_check("auto en bus uit de echte stad gevonden", car != null and bus != null)
	if car == null or bus == null:
		quit(1)
		return
	var sticks: Control = main.get_node("Hud/Sticks")
	var right: Vector2 = sticks.call("_anchor", true)
	for w in WEAPONS:
		if not game.owned.has(w):
			game.owned[w] = {"up": {"dmg": 0, "rate": 0, "mag": 0, "rel": 0}, "ammo": load("res://scripts/data.gd").WEAPONS[w].mag}
		if not game.loadout.has(w):
			game.loadout.append(w)
	# [doel, plek van de speler t.o.v. het doel] — eerst zoals in de opname: schuin eronder op het trottoir, ~3 m
	var setups := [[car, Vector3(-1.6, 0, 3.4), "auto, schuin eronder op 3 m (opname)"], [car, Vector3(-9.0, 0, 6.0), "auto, 11 m schuin"],
			[car, Vector3(0.0, 0, -4.0), "auto, van boven op 4 m"], [bus, Vector3(-2.0, 0, 4.0), "bus, schuin eronder op 4 m"], [bus, Vector3(12.0, 0, 2.5), "bus, 12 m over de weg"]]
	for s in setups:
		var target: Node3D = s[0]
		for w in WEAPONS:
			target.hp = target.HP
			target.burning = false
			target._fuse = 0.0
			var p = game.player
			p.global_position = target.global_position + s[1]
			p.velocity = Vector3.ZERO
			p.hp = 9999.0
			game.cur = w
			p.equip(w)
			p.fire_t = 0.0
			p.reload_t = 0.0
			p.ammo = load("res://scripts/data.gd").WEAPONS[w].mag
			await _frames(2)
			# duim richting de auto zoals op het scherm: rechts = +x, omlaag = +z (zoals touch_sticks)
			var to: Vector3 = target.global_position - p.global_position
			var d := Vector2(to.x, to.z).normalized() * 56.0
			var hp0: float = target.hp
			_touch(1, right, true)
			_drag(1, right + d)
			await _frames(70 if w != "bazooka" else 30)
			_touch(1, right, false)
			await _frames(3)
			var lost: float = hp0 - target.hp
			_check("%s: %s raakt (%.0f hp schade)" % [s[2], w, lost], lost > 0.5)
			if target.exploded:
				break
	print("AUTO SPEL TEST KLAAR, fouten: ", failures)
	quit(1 if failures > 0 else 0)
