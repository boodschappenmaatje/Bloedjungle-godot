extends SceneTree
## v236 (6A): schildsoldaat (kogels van voren ketsen af), granaatwerper (rode cirkel, knal), tekens en eenmalige melding.
## godot --headless --path . -s tests/vijandsoorten_test.gd --fixed-fps 60
var failures := 0
var watchdog := 0


func _initialize() -> void:
	call_deferred("_run")


func _process(_d: float) -> bool:
	watchdog += 1
	if watchdog > 3000:
		push_error("VIJANDSOORTEN watchdog")
		quit(99)
	return false


func _check(ok: bool, msg: String) -> void:
	print(("PASS v236: " if ok else "FAIL v236: ") + msg)
	if not ok:
		failures += 1


func _frames(n: int) -> void:
	for _i in n:
		await process_frame


func _enemy(main: Node, pos: Vector3, soort: String) -> Node3D:
	var e: Node3D = load("res://scenes/enemy.tscn").instantiate()
	e.setup("assault", 1)
	if soort != "":
		e.set_soort(soort)
	main.add_child(e)
	e.set_physics_process(false)
	e.global_position = pos
	e.hp = 100.0
	e.max_hp = 100.0
	e.face = 0.0
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
	game.hit_class = ""
	var sh := _enemy(main, Vector3(300.0, 0.0, 12.0), "schild")
	var norm := _enemy(main, Vector3(310.0, 0.0, 12.0), "")
	await _frames(2)
	_check(sh.get_node_or_null("Teken") != null and sh.get_node_or_null("Schild") != null, "schildsoldaat heeft een teken en een schild")
	_check(norm.get_node_or_null("Teken") == null or norm.soort == "flank", "gewone schutter heeft geen schild-teken")
	# kogel vanuit het zuiden (speler) naar het noorden: dir = (0,0,1); hij kijkt naar de speler (face 0 = +z)... face 0 kijkt naar +z, dus een kogel met dir -z komt van voren
	var hp0: float = sh.hp
	sh.hit(20.0, Vector3(0, 0, -1), true)
	var voor: float = hp0 - sh.hp
	hp0 = sh.hp
	sh.hit(20.0, Vector3(0, 0, 1), true)
	var achter: float = hp0 - sh.hp
	_check(voor > 0.0 and voor < 6.0, "schot op het schild doet weinig (%.1f)" % voor)
	_check(achter > 15.0, "schot van achteren doet volle schade (%.1f)" % achter)
	hp0 = sh.hp
	sh.hit(20.0, Vector3(1, 0, 0), true)
	_check(hp0 - sh.hp > 15.0, "schot van opzij doet volle schade")
	var a: Node = load("res://scenes/enemy.tscn").instantiate()
	a.setup("assault", 1)
	var b: Node = load("res://scenes/enemy.tscn").instantiate()
	b.setup("assault", 1)
	b.set_soort("schild")
	_check(b.max_hp > a.max_hp * 1.5, "schildsoldaat is taaier")
	a.free()
	b.free()
	# granaatwerper
	var gw := _enemy(main, Vector3(300.0, 0.0, 12.0), "granaat")
	p.hp = 100.0
	p.dodge_t = 0.0
	p.shield_t = 0.0
	var hp_p: float = p.hp
	gw._gooi_granaat(p.global_position)
	var ringen := 0
	for c in main.get_children():
		if c is MeshInstance3D and c.mesh is CylinderMesh:
			ringen += 1
	_check(ringen == 1, "er verschijnt een rode waarschuwingscirkel")
	await _frames(100)   # 1,3 s bij 60 fps
	_check(p.hp < hp_p, "de granaat raakt de speler als hij blijft staan (%.1f -> %.1f)" % [hp_p, p.hp])
	_check(main.get_children().filter(func(c): return c is MeshInstance3D and c.mesh is CylinderMesh).size() == 0, "cirkel is na de knal weg")
	# wegrennen
	hp_p = p.hp
	p.dodge_t = 0.0
	p.shield_t = 0.0
	gw._gooi_granaat(p.global_position)
	p.global_position = Vector3(300.0, 0.0, -10.0)
	await _frames(100)
	_check(is_equal_approx(p.hp, hp_p), "wie uit de cirkel loopt blijft heel")
	# melding
	game.soort_gezien = {}
	var got := []
	game.banner.connect(func(big, _s, _t): got.append(big))
	sh._meld_soort()
	sh._meld_soort()
	_check(got == ["SCHILDSOLDAAT"], "de melding komt maar één keer (%s)" % [got])
	print("VIJANDSOORTEN KLAAR, fouten: %d" % failures)
	quit(1 if failures > 0 else 0)
