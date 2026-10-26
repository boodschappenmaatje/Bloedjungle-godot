extends SceneTree
## Test: killstreak (luchtsteun). Kills van de speler tellen, die van soldaten en luchtsteun niet; bij 5 staat Versterking klaar,
## bij 12 Napalm; de dogtag-teller en de luchtsteun-knop verschijnen; de truck rijdt aan en zet 4 soldaten af; napalm verbrandt
## vijanden in de strook zonder je streak te verhogen; einde van de golf zet de teller op nul, maar bewaart wat klaarstaat.
## Draaien: godot --headless --path . -s tests/killstreak_test.gd --fixed-fps 60

var failures: Array[String] = []
var main: Node
var game: Node
var streak_script: GDScript   # via load(): class_names die de autoload Game gebruiken mogen niet statisch in een -s test staan


func _initialize() -> void:
	OS.set_environment("BJ_TOUCH", "1")
	root.size = Vector2i(932, 430)
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error("KILLSTREAK TEST: " + message)
		print("FAIL ", message)


func _frames(n: int) -> void:
	for _i in n:
		await process_frame


func _is(n: Node, name: String) -> bool:
	var sc: Script = n.get_script()
	return sc != null and sc.resource_path == "res://scripts/%s.gd" % name


func _enemy(at: Vector3) -> Node:
	var e: Node = load("res://scenes/enemy.tscn").instantiate()
	e.setup(Data.ETYPES.keys()[0], 1)
	main.add_child(e)
	e.global_position = at
	return e


func _kill(e: Node, src: String) -> void:
	game.hit_src = src
	e.hit(9999.0, Vector3.FORWARD, true)
	game.hit_src = "speler"


func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	game = root.get_node("Game")
	streak_script = load("res://scripts/streak.gd")
	await _frames(3)
	main.get_node("Hud/Sticks").set_process(false)
	await main.call("begin")
	await _frames(3)
	game.player.global_position = Vector3(10, 0, 40)
	var far := Vector3(-30, 0, -30)

	# 1. wie telt mee
	_check(game.streak == 0 and game.streak_bank.is_empty(), "begin: streak moet 0 zijn")
	_kill(_enemy(far), "soldaat")
	_kill(_enemy(far), "lucht")
	_check(game.streak == 0, "kills van soldaten en luchtsteun mogen de streak niet verhogen (streak=%d)" % game.streak)
	for i in 4:
		_kill(_enemy(far), "speler")
	_check(game.streak == 4 and game.streak_bank.is_empty(), "4 kills: nog geen beloning (streak=%d)" % game.streak)

	print('stap 1 klaar')
	# 2. 5 kills: versterking klaar, teller en knop zichtbaar
	_kill(_enemy(far), "speler")
	_check(game.streak_bank == ["truck"], "5 kills: versterking klaar (bank=%s)" % str(game.streak_bank))
	await _frames(8)
	var hud: Node = main.get_node("Hud")
	var tag := hud.find_child("StreakHud", true, false) as Control
	_check(tag != null and tag.visible and tag.modulate.a > 0.5, "de dogtag-teller staat niet in beeld na een kill")
	var air: Button = null
	for b in get_nodes_in_group("hud_button"):
		if b is Button and b.get("kind") == "lucht":
			air = b
	_check(air != null and air.is_visible_in_tree(), "de luchtsteun-knop ontbreekt terwijl er een beloning klaarstaat")
	if air != null:
		_check(air.get("reward") == "truck" and air.get("caption") == "TRUCK", "de knop toont niet de truck")

	print('stap 2 klaar')
	# 3. de teller vervaagt 4 s na de laatste kill
	await _frames(60 * 6)
	_check(tag.modulate.a < 0.05 or not tag.visible, "de teller moet na 4 s vervagen (alpha=%.2f)" % tag.modulate.a)

	print('stap 3 klaar')
	# 4. versterking: truck rijdt aan, 4 soldaten
	var taken: String = game.streak_take()
	_check(taken == "truck", "streak_take gaf %s" % taken)
	streak_script.use("truck", main, Vector3.ZERO, Vector3.ZERO)
	var crew_seen := 0
	var truck_seen := false
	for f in 60 * 25:
		await process_frame
		for n in main.get_children():
			if _is(n, "versterking"):
				truck_seen = n.truck != null
				crew_seen = maxi(crew_seen, n.crew.size())
		if crew_seen >= 4:
			break
	_check(truck_seen, "de truck is niet verschenen")
	_check(crew_seen == 4, "er moeten 4 soldaten uit de truck komen (zag %d)" % crew_seen)
	var helpers := 0
	for a in game.allies:
		if is_instance_valid(a) and a.get("helper"):
			helpers += 1
	_check(helpers == 4, "de soldaten horen in Game.allies te staan (%d)" % helpers)
	# soldaten schieten: hun kills tellen niet voor de streak
	var before: int = game.streak
	var target := _enemy(game.player.global_position + Vector3(6, 0, 0))
	for i in 60 * 6:
		await process_frame
		if target.dead:
			break
	_check(target.dead, "de versterking moet een vijand in de buurt neerschieten")
	_check(game.streak == before, "kills van de versterking mogen je streak niet verhogen (%d -> %d)" % [before, game.streak])

	print('stap 4 klaar')
	# 5. de truck rijdt weg, de soldaten blijven bij de speler
	for f in 60 * 25:
		await process_frame
		var still := false
		for n in main.get_children():
			if _is(n, "versterking"):
				still = true
		if not still:
			break
	var left := 0
	for a in game.allies:
		if is_instance_valid(a) and a.get("helper"):
			left += 1
	_check(left == 4, "de soldaten moeten bij de speler blijven na het vertrek van de truck (%d)" % left)
	for a in game.allies.duplicate():
		if is_instance_valid(a) and a.get("helper"):
			a.queue_free()
	game.allies.clear()

	print('stap 5 klaar')
	# 6. nog 6 kills: napalm klaar; napalm brandt vijanden in de strook en telt niet mee
	game.streak_reset()
	game.streak_bank.clear()
	for i in 12:
		_kill(_enemy(far), "speler")
	_check(game.streak_bank.has("napalm"), "12 kills: napalm klaar (bank=%s)" % str(game.streak_bank))
	var center := Vector3(30, 0, 20)
	var dir := Vector3(1, 0, 0)
	var burning: Array = []
	for i in 4:
		burning.append(_enemy(center + dir * (-6.0 + i * 4.0)))
	var safe := _enemy(center + Vector3(0, 0, 14))
	for e in burning + [safe]:
		e.stun_t = 100.0   # blijven staan, zodat de test niet afhangt van waar ze heen lopen
	var streak0: int = game.streak
	game.streak_take()
	streak_script.use("napalm", main, center, dir)
	var seen_jet := false
	var ran := 0.0
	var anim_ok := false
	var pos0: Vector3 = burning[0].global_position
	for f in 60 * 14:
		await process_frame
		for n in main.get_children():
			if _is(n, "napalm_aanval") and n.jet != null:
				seen_jet = true
		if burning[0].burn_t > 0.0:
			ran = maxf(ran, burning[0].global_position.distance_to(pos0))
			anim_ok = anim_ok or burning[0].model.current == "brand_rennen"
		var all_dead := true
		for e in burning:
			if not e.dead:
				all_dead = false
		if all_dead:
			break
	_check(seen_jet, "het toestel is niet verschenen")
	var dead_n := 0
	for e in burning:
		if e.dead:
			dead_n += 1
	_check(dead_n == 4, "napalm moet de vier vijanden in de strook doden (%d)" % dead_n)
	_check(ran > 2.0, "een brandende vijand moet wegrennen (%.1f m)" % ran)
	_check(anim_ok, "een brandende vijand moet de animatie brand_rennen spelen")
	_check(burning[0].model.current == "brand_val", "na het rennen valt hij met brand_val (%s)" % burning[0].model.current)
	_check(not safe.dead and safe.burn_t <= 0.0, "een vijand buiten de strook mag niet branden")
	_check(game.streak == streak0, "napalm-kills mogen je streak niet verhogen (%d -> %d)" % [streak0, game.streak])
	await _frames(60 * 10)
	var left_n := 0
	for n in main.get_children():
		if _is(n, "napalm_aanval"):
			left_n += 1
	_check(left_n == 0, "de napalm-aanval moet na het doven zichzelf opruimen")

	print('stap 6 klaar')
	# 7. einde golf: teller nul, bank blijft
	game.streak_bank.append("truck")
	game.streak_reset()
	_check(game.streak == 0 and game.streak_bank.has("truck"), "einde golf: teller 0, maar wat klaarstaat blijft")

	# 8. de luchtsteun-knop overlapt geen andere knop op liggende en staande iPhones
	game.streak_bank = ["napalm"]
	game.changed.emit()
	for size in [Vector2i(932, 430), Vector2i(844, 390), Vector2i(430, 932)]:
		root.size = size
		root.content_scale_factor = 1.0
		await _frames(6)
		var view := Vector2(root.get_visible_rect().size)
		var btns: Array = []
		for b in get_nodes_in_group("hud_button"):
			if b is Control and b.is_visible_in_tree() and b.size.x > 1.0 and b.size.x < 400.0:
				btns.append(b)
		var a2: Control = null
		for b in btns:
			if b.get("kind") == "lucht":
				a2 = b
		_check(a2 != null, "%s: luchtsteun-knop niet zichtbaar" % size)
		if a2 == null:
			continue
		var r: Rect2 = a2.get_global_rect()
		_check(Rect2(Vector2.ZERO, view).encloses(r), "%s: luchtsteun-knop valt buiten beeld %s" % [size, r])
		for b in btns:
			if b != a2 and b.get_global_rect().intersects(r):
				_check(false, "%s: luchtsteun-knop overlapt %s %s" % [size, b.get("kind") if b.get("kind") != null else b.name, b.get_global_rect()])
	game.streak_bank.clear()

	# 8. testschakelaar: alles staat klaar en raakt niet op
	var old_t: String = GameSettings.get_value("t_streak")
	GameSettings.set_value("t_streak", "on")
	var seen := {}
	for i in 6:
		seen[game.streak_take()] = true
	_check(seen.has("truck") and seen.has("napalm"), "testmodus: beide beloningen moeten beschikbaar zijn (%s)" % str(seen.keys()))
	_check(game.streak_bank.size() == 2, "testmodus: de bank mag niet leeg raken (%d)" % game.streak_bank.size())
	GameSettings.set_value("t_streak", old_t)
	game.streak_bank.clear()

	print("TEST OK" if failures.is_empty() else "TEST MISLUKT")
	quit(0 if failures.is_empty() else 1)
