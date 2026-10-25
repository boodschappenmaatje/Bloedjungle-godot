extends SceneTree
## Test: granaat richten met slepen en loslaten op de granaatknop (echte touch-events, zoals op de iPhone).
## - landt op de richtcirkel (2-12 m, 8 richtingen) en rolt nauwelijks door
## - verder slepen dan het maximum blijft 12 m, terugslepen naar de knop breekt af, tikken gooit 7 m vooruit
## - een auto in de baan maakt de cirkel rood en houdt de granaat tegen
## - in een gebouw blijft de cirkel binnen het gebouw
## Draaien: godot --headless --path . -s tests/granaat_richten_test.gd --fixed-fps 60

var failures := 0
var game
var main: Node
var cb
var btn: Control


func _initialize() -> void:
	OS.set_environment("BJ_TOUCH", "1")
	root.size = Vector2i(932, 430)
	call_deferred("_run")


func _check(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "FOUT  ") + msg)
	if not ok:
		failures += 1


func _frames(n: int) -> void:
	for _i in n:
		await physics_frame


func _touch(pressed: bool, at: Vector2) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = root.get_final_transform() * at   # schermpunt: de HUD is geschaald (content_scale_factor)
	e.pressed = pressed
	root.push_input(e)


func _drag(at: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = 0
	e.position = root.get_final_transform() * at   # schermpunt: de HUD is geschaald (content_scale_factor)
	root.push_input(e)


## Sleept van de knop naar d (in px) en laat los; geeft de nieuwe granaat terug.
func _throw(d: Vector2, steps := 4):
	var c: Vector2 = btn.get_global_rect().get_center()
	_touch(true, c)
	await _frames(1)
	for i in steps:
		_drag(c + d * float(i + 1) / steps)
		await _frames(1)
	var before: Array = _grenades()
	_touch(false, c + d)
	await _frames(1)
	for g in _grenades():
		if not before.has(g):
			return g
	return null


func _grenades() -> Array:
	var out := []
	for n in game.player.get_parent().get_children():
		if n.get_script() != null and n.get_script().resource_path == "res://scripts/grenade.gd" and not n.is_queued_for_deletion():
			out.append(n)
	return out


## Volgt de granaat: eerste landing en waar hij ligt vlak voor de ontploffing.
func _follow(g) -> Dictionary:
	var land := Vector3.INF
	for i in 95:
		if not is_instance_valid(g):
			break
		if land == Vector3.INF and g._landed:
			land = g.global_position
		await _frames(1)
	var rest: Vector3 = g.global_position if is_instance_valid(g) else Vector3.INF
	if is_instance_valid(g):
		g.queue_free()
	return {"land": land, "rest": rest}


func _px_for(dist: float) -> float:
	return cb.AIM_DEAD + 1.0 + (dist - 2.0) / 10.0 * (cb.AIM_FULL - cb.AIM_DEAD)


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	game = root.get_node("Game")
	await _frames(3)
	main.get_node("Hud/Sticks").set_process(false)
	await main.call("begin")
	await _frames(3)
	for n in get_nodes_in_group("hud_button"):
		if n.get_script() != null and n.get_script().resource_path == "res://scripts/action_btn.gd" and n.get("kind") == "granaat":
			btn = n
	cb = btn.get_parent()
	var p = game.player
	var Stad = load("res://scripts/stad.gd")
	# open veld in de stad: alleen een auto ver weg, die we straks gebruiken
	Stad.current.set_items(Stad.from_lines([["auto", 0, -96, 1, 0], ["woonhuis", 60, -130, 0, 0]]))
	var car: Node3D = Stad.current.items[0].node
	var spot := Vector3(0, 0, -130)
	game.grenades = 99
	game.equipment_sel = "grenade"
	game.changed.emit()
	await _frames(2)

	# 1. raakt de richtcirkel, 8 richtingen, 2-12 m
	var worst_land := 0.0
	var worst_rest := 0.0
	for dist in [2.0, 5.0, 8.0, 12.0]:
		for k in 8:
			p.global_position = spot
			p.grenade_cd = 0.0
			await _frames(2)
			var a := k * TAU / 8.0
			var dir := Vector2(sin(a), cos(a))
			var target: Vector3 = spot + Vector3(dir.x, 0, dir.y) * dist
			var g = await _throw(dir * _px_for(dist))
			if g == null:
				_check(false, "geen granaat bij %.0f m richting %d" % [dist, k])
				continue
			var r: Dictionary = await _follow(g)
			if _flat(r.land, target) > 0.6: print("  afwijking ", dist, " m richting ", k, ": land ", r.land, " doel ", target)
			worst_land = maxf(worst_land, _flat(r.land, target))
			worst_rest = maxf(worst_rest, _flat(r.rest, target))
	_check(worst_land < 0.6, "landt op de richtcirkel (grootste afwijking %.2f m)" % worst_land)
	_check(worst_rest < 2.0, "rolt nauwelijks door (ligt max %.2f m van de cirkel bij ontploffen)" % worst_rest)

	# 2. verder slepen dan het maximum: 12 m
	p.global_position = spot
	p.grenade_cd = 0.0
	await _frames(2)
	var g2 = await _throw(Vector2(400, 0))
	var r2: Dictionary = await _follow(g2)
	_check(absf(_flat(r2.land, spot) - 12.0) < 0.6, "maximaal bereik 12 m (landt op %.2f m)" % _flat(r2.land, spot))

	# 3. terugslepen naar de knop breekt af
	p.grenade_cd = 0.0
	await _frames(2)
	var n0: int = game.grenades
	var c: Vector2 = btn.get_global_rect().get_center()
	_touch(true, c)
	await _frames(1)
	_drag(c + Vector2(-80, -40))
	await _frames(1)
	_check(cb._aim_vis != null and cb._aim_vis.visible, "tijdens slepen staat de boog met richtcirkel in beeld")
	_drag(c + Vector2(4, 3))
	await _frames(1)
	_touch(false, c + Vector2(4, 3))
	await _frames(2)
	_check(game.grenades == n0 and _grenades().is_empty(), "terugslepen naar de knop gooit niet")
	_check(cb._aim_vis == null, "na afbreken is de richthulp weg")

	# 4. alleen tikken: 7 m recht vooruit
	p.global_position = spot
	p.face = PI   # naar het noorden
	p.grenade_cd = 0.0
	await _frames(2)
	var g4 = await _throw(Vector2.ZERO, 0)
	var r4: Dictionary = await _follow(g4)
	_check(g4 != null and absf(_flat(r4.land, spot) - 7.0) < 0.8, "tikken gooit 7 m vooruit (%.2f m)" % _flat(r4.land, spot))

	# 5. auto in de baan: rode cirkel en de granaat komt er niet overheen
	var cp: Vector3 = car.global_position
	p.global_position = cp + Vector3(-4.5, 0, 0)
	p.grenade_cd = 0.0
	await _frames(2)
	_touch(true, c)
	await _frames(1)
	_drag(c + Vector2(_px_for(9.0), 0))
	await _frames(1)
	_check(cb._aim_vis != null and cb._aim_vis.blocked, "auto tussen speler en doel: richtcirkel wordt rood")
	var before: Array = _grenades()
	_touch(false, c + Vector2(_px_for(9.0), 0))
	await _frames(1)
	var g5 = null
	for g in _grenades():
		if not before.has(g):
			g5 = g
	var r5: Dictionary = await _follow(g5)
	_check(g5 != null and r5.rest.x < cp.x + 1.5, "granaat vliegt niet over de auto (x %.2f, auto %.2f)" % [r5.rest.x, cp.x])

	# 6. in een gebouw: de cirkel blijft binnen
	var hs: Array = get_nodes_in_group("woonhuis")
	if hs.is_empty():
		_check(false, "geen woonhuis gevonden")
	else:
		var h = hs[0]
		p.global_position = h.to_global(Vector3(0, float(h.levels[0]) + 0.05, 0))
		p.grenade_cd = 0.0
		await _frames(2)
		var ok := true
		for k in 8:
			var a := k * TAU / 8.0
			var aim: Dictionary = p.grenade_aim(p.global_position + Vector3(sin(a), 0, cos(a)) * 12.0)
			if not h._in_foot(h.to_local(aim.target), -0.3):
				ok = false
		_check(ok, "in een gebouw blijft de richtcirkel binnen het gebouw")

	print("GRANAAT_RICHTEN_TEST fouten=", failures)
	print("TEST OK" if failures == 0 else "TEST MISLUKT")
	quit(1 if failures > 0 else 0)
