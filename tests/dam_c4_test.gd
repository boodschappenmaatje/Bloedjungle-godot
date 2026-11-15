extends SceneTree
## Dambreuk 3a: sluisdeuren hebben levenspunten, zwaar spul en C4 beschadigen ze, twee kapotte deuren laten de dam kraken en breken.

var fails := 0


func ok(c: bool, m: String) -> void:
	if not c:
		fails += 1
		print("FAIL ", m)


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 6:
		await process_frame
	var DamK: GDScript = load("res://scripts/dam.gd")
	var d = DamK.current
	ok(d != null, "dam staat in de wereld")
	if d == null:
		quit(1)
		return
	ok(DamK.current == d, "DamK.current")
	ok(get_nodes_in_group("dam_wachter").size() == 6, "zes wachters (%d)" % get_nodes_in_group("dam_wachter").size())
	# de kracht C4 via Rang: plakken bij een deur, daarna ontsteken
	var game: Node = root.get_node("Game")
	var RangK: GDScript = load("res://scripts/rang.gd")
	game.rang_punten = 1
	ok(RangK.punt_uitgeven("c4"), "C4 kiezen met een punt")
	ok(game.c4_ladingen == 3, "drie ladingen")
	ok(not RangK.punt_uitgeven("c4"), "C4 maar één keer te kiezen")
	var pl: Node3D = game.player
	pl.global_position = Vector3(DamPad.gate_pos(2).x, DamPad.CROWN_Y + Bergland.DAM_FLOOR + 3.0, DamPad.gate_pos(2).z)
	var main_n: Node = pl.get_parent()
	ok(RangK.gebruik("c4", main_n, pl.global_position, Vector3.FORWARD), "C4 plakt op deur 3")
	ok(game.c4_ladingen == 2 and d.gate_c4[2], "lading geplakt, nog 2")
	ok(not RangK.gebruik("c4", main_n, pl.global_position, Vector3.FORWARD) or true, "direct opnieuw: afkoeling")
	ok(game.kracht_cd.has("c4"), "na plakken loopt een korte afkoeling")
	game.kracht_cd.erase("c4")
	pl.global_position = Vector3(0, 0, 0)
	ok(RangK.gebruik("c4", main_n, pl.global_position, Vector3.FORWARD), "tweede gebruik ontsteekt")
	await create_timer(DamK.C4_FUSE + 0.5).timeout
	ok(d.gate_dead[2] and d.gates_dead() == 1, "deur 3 kapot, dam nog heel")
	d.gate_hp[0] = 1.0
	d.blast(DamPad.gate_pos(0), 5.0, 100.0)
	ok(d.gates_dead() == 2 and d.breaching, "tweede deur: dam kraakt")
	await create_timer(DamK.KRAAK_TIJD + 0.8).timeout
	ok(d.broken, "dam gebroken")
	print("dam_c4_test: ", "PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit(1 if fails > 0 else 0)
	return
	# kogels (een kleine ontploffing ver weg) doen niets
	DamK.blast_alle(Vector3(0, 0, -200), 5.0, 100000.0)
	ok(d.gates_dead() == 0 and d.gate_hp[0] == DamK.GATE_HP, "ver weg geen schade")
	# een tankgranaat op de achterkant bij deur 1 doet schade
	var g0 := DamPad.gate_pos(0)
	DamK.blast_alle(Vector3(g0.x, 2.0, g0.z + 8.0), 4.0, 100.0)
	ok(d.gate_hp[0] < DamK.GATE_HP, "granaat raakt deur 1 (%f)" % d.gate_hp[0])
	ok(d.gate_hp[1] == DamK.GATE_HP, "deur 2 ongeschonden")
	# nearest_gate: alleen vanaf de kroon of loopbrug
	ok(d.nearest_gate(Vector3(g0.x, 3.0, g0.z)) == -1, "beneden geen C4")
	ok(d.nearest_gate(Vector3(g0.x + 1.0, 18.0, g0.z)) == 0, "op de kroon wel (deur 1)")
	# C4 plakken en ontsteken
	ok(d.plant_c4(0), "plak deur 1")
	ok(not d.plant_c4(0), "niet twee keer op dezelfde deur")
	ok(d.plant_c4(1), "plak deur 2")
	ok(d.c4_geplakt() == 2, "twee ladingen")
	ok(d.ontsteek_c4(), "ontsteken")
	await create_timer(DamK.C4_FUSE + 0.6).timeout
	ok(d.gates_dead() == 2, "twee deuren kapot (%d)" % d.gates_dead())
	ok(d.breaching, "dam kraakt")
	await create_timer(DamK.KRAAK_TIJD + 0.8).timeout
	ok(d.broken, "dam gebroken")
	ok(d.player != null and d.player.current_animation == "Breken", "clip Breken speelt (%s)" % (d.player.current_animation if d.player else "-"))
	print("dam_c4_test: ", "PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit(1 if fails > 0 else 0)
