extends SceneTree
## v234: vergrendelen (1A), automatische dekking (3A), dubbeltik-rol (4A), treffergewicht (7A).
## godot --headless --path . -s tests/besturing_v234_test.gd --fixed-fps 60
var failures := 0
var watchdog := 0


func _initialize() -> void:
	call_deferred("_run")


func _process(_d: float) -> bool:
	watchdog += 1
	if watchdog > 3000:
		push_error("BESTURING v234 watchdog")
		quit(99)
	return false


func _check(ok: bool, msg: String) -> void:
	print(("PASS v234: " if ok else "FAIL v234: ") + msg)
	if not ok:
		failures += 1


func _frames(n: int) -> void:
	for _i in n:
		await process_frame


func _enemy(main: Node, pos: Vector3) -> Node3D:
	var e: Node3D = load("res://scenes/vijand_verdediger.tscn").instantiate()
	e.setup("assault", 1)
	e.post = "poort"
	main.add_child(e)
	e.set_physics_process(false)
	e.add_to_group("vijand_verdediger")
	e.global_position = pos
	e.hp = 500.0
	e.max_hp = 500.0
	return e


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(main)
	await _frames(3)
	main.begin()
	await _frames(40)
	var game: Variant = root.get_node("Game")
	var p: Variant = game.player
	game.state = "prep"
	p.set_physics_process(false)
	p.global_position = Vector3(300.0, 0.0, 0.0)
	p.face = 0.0
	var a := _enemy(main, Vector3(300.0, 0.0, 12.0))                 # recht vooruit
	var b := _enemy(main, Vector3(300.0 + 5.0, 0.0, 12.0))           # ca. 22 graden rechts van a
	await _frames(3)
	# 1A: vergrendelen
	var out: float = p._aim_assist(0.15)    # 8,6 graden naast a: hij kleeft aan a
	_check(absf(out) < 0.03, "stick 9 graden naast de vijand: het richten klikt op de vijand (%.3f rad)" % out)
	out = p._aim_assist(0.30)               # 17 graden: buiten het houd-gebied van a, b ligt op ca. 0.39
	_check(p._lock == b or p._lock == a, "verder opzij pakt een vijand (lock gezet)")
	var far := _enemy(main, Vector3(300.0, 0.0, 60.0))
	p._lock = null
	out = p._aim_assist(0.0)
	_check(p._lock == a, "dichtstbijzijnde vijand wint van een verre (60 m wordt niet gepakt)")
	far.queue_free()
	a.dead = true
	p._aim_assist(0.0)
	_check(p._lock != a, "een dode vijand blijft niet vergrendeld")
	# 3A: dekking
	var wall := StaticBody3D.new()
	wall.collision_layer = 2
	wall.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 1.3, 0.4)
	cs.shape = box
	wall.add_child(cs)
	main.add_child(wall)
	wall.global_position = Vector3(300.0, 0.65, 0.8)
	p.global_position = Vector3(300.0, 0.0, 0.0)
	p.face = 0.0
	p.stance = 0
	await _frames(3)
	if p.model.meshy_player:
		for _i in 40:
			p._update_cover(1.0 / 60.0, 0.0)
		_check(p.stance == 1 and p._cover_auto, "stil tegen lage dekking: hij zakt erachter (hurken)")
		for _i in 40:
			p._update_cover(1.0 / 60.0, 0.8)
		_check(p.stance == 0, "weglopen: hij staat weer op")
	else:
		print("SKIP v234: dekking heeft de Meshy-soldaat nodig")
	wall.queue_free()
	# 7A: hitstop
	game.hitstop(0.03)
	_check(Engine.time_scale < 1.0, "treffer: korte stop begint")
	await create_timer(0.2, true, false, true).timeout
	_check(is_equal_approx(Engine.time_scale, 1.0), "de stop eindigt weer op normale snelheid")
	print("BESTURING v234 ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(1 if failures > 0 else 0)
