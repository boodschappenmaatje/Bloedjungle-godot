extends SceneTree
## Test: voordelen van het hoofdkwartier (Generals-plan stap 3).
## Niveau 2: radar tot 85 m met waarschuwing, bouw- en opleidingstijd 25% korter.
## Niveau 3: dakgeweer (10 s opbouw, schiet binnen 25 m) en artilleriecommando (5 granaten, 90 s afkoeling, alleen vijanden).
## Draaien: godot --headless --path . -s tests/hq_perks_test.gd --fixed-fps 60

var failures: Array[String] = []
var main: Node
var game: Node
var Bld: GDScript   # via load(): class_names die de autoload Game gebruiken mogen niet statisch in een -s test staan
var Art: GDScript
var Perks: GDScript


func _initialize() -> void:
	OS.set_environment("BJ_TOUCH", "1")
	root.size = Vector2i(932, 430)
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	print(("OK   " if ok else "FOUT ") + message)
	if not ok:
		failures.append(message)
		push_error("HQ PERKS TEST: " + message)


func _frames(n: int) -> void:
	for _i in n:
		await process_frame


func _enemy(at: Vector3, kind := "rifle") -> Node:
	var e: Node = load("res://scenes/enemy.tscn").instantiate()
	e.call("setup", kind, 1)
	main.add_child(e)
	e.global_position = at
	return e


func _script_is(n: Node, name: String) -> bool:
	var sc: Script = n.get_script()
	return sc != null and sc.resource_path == "res://scripts/%s.gd" % name


func _find_script(root_node: Node, name: String) -> Node:
	for n in root_node.find_children("*", "", true, false):
		if _script_is(n, name):
			return n
	return null


func _clear_enemies() -> void:
	for e in game.enemies.duplicate():
		if is_instance_valid(e):
			e.queue_free()
	game.enemies.clear()


func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	game = root.get_node("Game")
	Bld = load("res://scripts/buildings.gd")
	Art = load("res://scripts/artillerie.gd")
	Perks = load("res://scripts/hq_perks.gd")
	await _frames(3)
	main.get_node("Hud/Sticks").set_process(false)
	await main.call("begin")
	await _frames(3)
	game.player.global_position = Vector3(10, 0, 40)
	var hq: Node = get_first_node_in_group("hq")
	var perks: Node = hq.get_node_or_null("Voordelen")
	_check(perks != null, "het hoofdkwartier heeft een Voordelen-knoop")
	var hud: Node = main.get_node("Hud")
	var extra: Node = hud.get_node("HudExtra")
	var buttons: Node = hud.get_node("CombatButtons")
	_clear_enemies()

	# ---- niveau 1: geen voordelen
	_check(game.hq_level == 1, "begin op niveau 1")
	_check(is_equal_approx(Bld.time_factor(), 1.0), "niveau 1: bouwtijd normaal")
	_check(not Art.ready_now(), "niveau 1: geen artilleriecommando")
	_check(not extra._in_friendly_sight(Vector3(60, 0, 0)), "niveau 1: radar ziet niet tot 60 m")
	game.state = "play"
	var e1 := _enemy(Vector3(0, 0, -70))
	perks._radar_scan()
	_check(perks.alerts == 0, "niveau 1: geen radarwaarschuwing")
	e1.queue_free()
	game.enemies.erase(e1)
	_check(hq.get_node_or_null("Plaat") == null and get_nodes_in_group("hq_gun").is_empty(), "niveau 1: geen dakgeweer")
	await _frames(2)
	_check(not buttons._arty.visible, "niveau 1: artillerieknop verborgen")

	# ---- niveau 2
	game.hq_level = 2
	game.points = 100000
	game.build_credit = 100000
	_check(is_equal_approx(Bld.time_factor(), 0.75), "niveau 2: tijdsfactor 0,75")
	_check(extra._in_friendly_sight(Vector3(60, 0, 0)), "niveau 2: radar ziet vijanden tot 85 m")
	_check(not extra._in_friendly_sight(Vector3(110, 0, 0)), "niveau 2: voorbij 85 m niet")
	var kz = game.builds.place("kazerne", Vector3(-6, 0, -8), PI, true)
	_check(kz != null and absf(float(kz.build_total) - 9.0) < 0.01, "niveau 2: kazerne bouwt in 9 s i.p.v. 12 s (%s)" % str(kz.build_total if kz else -1))
	_check(absf(Bld.train_time(kz) - 7.5) < 0.01, "niveau 2: rekruut in 7,5 s i.p.v. 10 s")
	_check(Perks.compass(Vector3(0, 0, -70)) == "NOORDEN" and Perks.compass(Vector3(70, 0, 0)) == "OOSTEN" and Perks.compass(Vector3(0, 0, 70)) == "ZUIDEN" and Perks.compass(Vector3(-70, 0, -70)) == "NOORDWESTEN", "windrichtingen kloppen (noord = -Z)")
	var far := _enemy(Vector3(120, 0, 0))
	perks._radar_scan()
	_check(perks.alerts == 0, "vijand buiten 85 m: geen waarschuwing")
	var e2 := _enemy(Vector3(0, 0, -70))
	perks._radar_scan()
	_check(perks.alerts == 1, "vijand binnen 85 m: waarschuwing")
	var e3 := _enemy(Vector3(-5, 0, -72))
	perks._radar_scan()
	_check(perks.alerts == 1, "tweede vijand direct erna: geen nieuwe waarschuwing (pauze)")
	perks._alert_cd = 0.0
	var e4 := _enemy(Vector3(60, 0, 60))
	perks._radar_scan()
	_check(perks.alerts == 2, "na de pauze meldt een nieuwe groep zich weer")
	_check(Perks.contacts().size() == 3, "radar telt 3 contacten binnen 85 m (%d)" % Perks.contacts().size())
	for e in [far, e2, e3, e4]:
		e.queue_free()
		game.enemies.erase(e)
	await _frames(2)
	_check(get_nodes_in_group("hq_gun").is_empty(), "niveau 2: nog geen dakgeweer")

	# ---- niveau 3: dakgeweer
	game.state = "play"
	game.hq_level = 3
	hq._process(0.0)
	perks._process(0.0)
	var gun: Node = perks.gun
	_check(gun != null and is_instance_valid(gun), "niveau 3: dakgeweer verschijnt")
	_check(gun != null and not gun.built and gun.progress() < 0.05, "dakgeweer begint onafgebouwd")
	_check(Art.ready_now(), "niveau 3: artilleriecommando klaar")
	var spot: Vector3 = gun.global_position
	_check(spot.y > 4.0 and spot.y < 5.5 and Vector2(spot.x, spot.z).length() < 2.6, "dakgeweer staat op het dak (y %.2f)" % spot.y)
	var steps := 0
	var saw_half := false
	var gun_visible_early := false
	while not gun.built and steps < 900:
		gun._process(1.0 / 60.0)
		steps += 1
		if steps == 300:
			saw_half = gun.progress() > 0.45 and gun.progress() < 0.55 and gun._post.visible
			gun_visible_early = gun._gun != null and gun._gun.visible
	_check(steps >= 595 and steps <= 605, "opbouw duurt 10 s (%d stappen)" % steps)
	_check(saw_half, "na 5 s staat de paal en is het geweer er nog niet")
	_check(not gun_visible_early, "geweer verschijnt pas aan het eind van de opbouw")
	_check(gun.built and gun._gun != null and gun._gun.visible and gun._plate.visible, "klaar: alle onderdelen zichtbaar")
	# schieten: bereik 25 m
	var near := _enemy(spot + Vector3(0, -4.76, 15), "heavy")
	var out_of_range := _enemy(Vector3(0, 0, 33))
	var ammo0: int = gun.ammo
	var guard := 0
	while gun.shots_fired == 0 and guard < 120:
		gun._fire(1.0 / 60.0)
		guard += 1
	_check(gun.shots_fired > 0 and gun.ammo < ammo0, "dakgeweer schiet op een vijand op 15 m (%d schoten)" % gun.shots_fired)
	near.queue_free()
	game.enemies.erase(near)
	var shots := int(gun.shots_fired)
	for _i in 60:
		gun._fire(1.0 / 60.0)
	_check(gun.shots_fired == shots, "vijand op 33 m is buiten bereik: geen schoten")
	out_of_range.queue_free()
	game.enemies.erase(out_of_range)
	gun.ammo = 0
	var edge := _enemy(spot + Vector3(0, -4.76, 20))
	for _i in 30:
		gun._fire(1.0 / 60.0)
	_check(gun.ammo == 0, "zonder munitie blijft het stil")
	gun.refill()
	_check(gun.ammo == 300, "refill: 300 kogels")
	edge.queue_free()
	game.enemies.erase(edge)

	# ---- niveau 3: artillerie
	game.artillery_cd = 0.0
	await _frames(2)
	_check(buttons._arty.visible and not buttons._arty.disabled, "artillerieknop zichtbaar en klaar")
	var t1: Vector3 = Art.tap_target(Vector3(0, 0, 0), Vector3(0, 0, 1))
	_check(t1.is_equal_approx(Vector3(0, 0, Art.TAP_RANGE)), "tikken zonder vijand: recht vooruit (%s)" % str(t1))
	var d1: Vector3 = Art.drag_target(Vector3(5, 0, 5), Vector3(1, 0, 0), 0.0)
	var d2: Vector3 = Art.drag_target(Vector3(5, 0, 5), Vector3(1, 0, 0), 1.0)
	_check(absf((d1 - Vector3(5, 0, 5)).length() - Art.RANGE_MIN) < 0.01 and absf((d2 - Vector3(5, 0, 5)).length() - Art.RANGE_MAX) < 0.01, "slepen: bereik 14 tot 60 m")
	var target := Vector3(30, 0, 30)
	var v1 := _enemy(target + Vector3(1, 0, 0))
	var v2 := _enemy(target + Vector3(-2, 0, 1), "heavy")
	var safe := _enemy(target + Vector3(25, 0, 0))
	for e in [v1, v2, safe]:
		e.set_physics_process(false)   # ze blijven staan, zodat de test alleen de inslagen meet
	var tap: Vector3 = Art.tap_target(Vector3(10, 0, 40), Vector3(0, 0, 1))
	_check(Vector2(tap.x - v1.global_position.x, tap.z - v1.global_position.z).length() < 8.0 or Vector2(tap.x - v2.global_position.x, tap.z - v2.global_position.z).length() < 8.0, "tikken richt op de dichtstbijzijnde vijand")
	var streak0: int = game.streak
	var hp_player: float = game.player.hp
	var strike = Art.call_in(main, target)
	_check(is_equal_approx(game.artillery_cd, 90.0), "na gebruik: 90 s afkoeling")
	_check(not Art.ready_now(), "tijdens de afkoeling niet nog eens")
	await _frames(2)
	_check(buttons._arty.disabled and buttons._arty.badge != "", "knop grijs met seconden tijdens de afkoeling (%s)" % buttons._arty.badge)
	var guard2 := 0
	while is_instance_valid(strike) and guard2 < 900:
		await process_frame
		guard2 += 1
	_check(not is_instance_valid(strike) or strike.is_queued_for_deletion(), "de strike ruimt zichzelf op (%d frames)" % guard2)
	_check(v1.dead or v1.hp <= 0.0, "vijand in de inslagzone is geraakt")
	_check(v2.hp < 280.0, "zware vijand heeft schade (hp %.0f)" % v2.hp)
	_check(not safe.dead and safe.hp > 60.0, "vijand op 25 m van het doel blijft heel")
	_check(game.streak == streak0, "artillerie-kills tellen niet voor je killstreak")
	_check(is_equal_approx(game.player.hp, hp_player), "jijzelf krijgt geen schade")
	var cd0: float = game.artillery_cd
	perks._process(10.0)
	_check(is_equal_approx(game.artillery_cd, cd0 - 10.0), "afkoeling loopt tijdens een golf (10 s)")
	game.artillery_cd = 0.3
	perks._process(1.0)
	_check(is_equal_approx(game.artillery_cd, 0.0) and Art.ready_now(), "na afkoeling weer klaar")

	# ---- nieuw spel: alles weer uit
	game.reset()
	_check(game.hq_level == 1 and is_equal_approx(game.artillery_cd, 0.0), "nieuw spel: niveau 1 en afkoeling nul")
	perks._process(0.0)
	await _frames(2)
	_check(perks.gun == null and get_nodes_in_group("hq_gun").is_empty(), "nieuw spel: dakgeweer weg")

	print("TEST OK" if failures.is_empty() else "TEST MISLUKT: %d" % failures.size())
	quit(0 if failures.is_empty() else 1)
