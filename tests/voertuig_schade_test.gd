extends SceneTree
## Test van de levenspunten van jouw eigen jeep en tank (Generals-plan, stap V3; keuzes van Dennis 1A 2A 3B 4A 5A 6A): hoeveel levenspunten en welk pantser, schade per soort wapen
## (alleen van de vijand), rook, vuur, wrak, levensbalk, instappen (de balk in je scherm, het voertuig vangt de schade op), sneuvelen mee (3B), weg is weg (4A, de garage telt terug)
## en de vijand die op een leeg geparkeerd voertuig mikt (6A: vijandelijke jeep, tank en raketsoldaat).
## godot --headless --path . --script tests/voertuig_schade_test.gd --fixed-fps 60
## Draai hem met Godot 4.7.2 (zoals de CI): Godot 4.6.3 headless hapert of crasht in deze scène na enkele honderden beeldjes.

var fails := 0
var main: Node
var G: Node
var _watchdog := 0
var VS: GDScript
var VJ: GDScript
var VT: GDScript
var BU: GDScript
var _base_enemies: Array = []   # de vijanden die er al waren (verdedigers van de basis)


func _initialize() -> void:
	call_deferred("_run")


func _process(_d: float) -> bool:
	_watchdog += 1
	if _watchdog > 30000:
		push_error("Voertuigschadetest hangt: de opstelling is niet klaargekomen")
		quit(99)
	return false


func _check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FOUT ") + name)
	if not ok:
		fails += 1


func _frames(n: int) -> void:
	for _i in n:
		await process_frame


## Ruimt de vijanden op die de test zelf liet uitrukken; de verdedigers en torens van de vijandbasis blijven staan.
func _clear_enemies() -> void:
	for e in G.enemies.duplicate():
		if _base_enemies.has(e):
			continue
		G.enemies.erase(e)
		if is_instance_valid(e):
			e.queue_free()


func _own(kind: String, pos: Vector3, rot := 0.0) -> Node:
	var v = (load("res://scenes/%s.tscn" % kind) as PackedScene).instantiate()
	main.add_child(v)
	v.global_position = pos
	v.rotation.y = rot
	return v


func _drop(v) -> void:
	if is_instance_valid(v):
		v.queue_free()


func _hp(v) -> float:
	return v._schade.hp


## Een echte garage (met fleet en has) op een vrije plek, of null als de bouwregels geen plek geven.
func _garage() -> Variant:
	for at in [Vector3(30, 0, 30), Vector3(-30, 0, 30), Vector3(30, 0, -30), Vector3(-30, 0, -30), Vector3(50, 0, 10), Vector3(-50, 0, 10), Vector3(0, 0, 40)]:
		var b: Variant = G.builds.place("garage", at, 0.0, false, true)
		if b != null:
			return b
	return null


func _run() -> void:
	# ---------------------------------------------------------------- 2. de wereld
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	main.get_node("Hud/Sticks").set_process(false)
	main.begin()
	await _frames(5)
	G = root.get_node("Game")
	G.prep_t = 99999.0
	G.player.global_position = Vector3(300, 0, 150)   # ver weg: vijanden schieten niet op de speler tijdens de eerste proeven
	await _frames(5)
	var p = G.player
	_base_enemies = G.enemies.duplicate()

	# de scripts pas laden als de wereld (en dus alle autoloads) er is: een `class_name` rechtstreeks gebruiken lukt niet in een -s script
	VS = load("res://scripts/voertuig_schade.gd") as GDScript
	VJ = load("res://scripts/vijand_jeep.gd") as GDScript
	VT = load("res://scripts/vijand_tank.gd") as GDScript
	BU = load("res://scripts/bullet.gd") as GDScript
	var s_cls: GDScript = VS

	# ---------------------------------------------------------------- 1. de gegevens
	var kinds: Dictionary = s_cls.KINDS
	_check("jeep: 220 levenspunten, pantser jeep (zoals de vijandelijke jeep)", is_equal_approx(float(kinds.jeep.hp), 220.0) and kinds.jeep.armor == "jeep" and is_equal_approx(float(kinds.jeep.hp), VJ.HP))
	_check("tank: 900 levenspunten, pantser tank (zoals de vijandelijke tank)", is_equal_approx(float(kinds.tank.hp), 900.0) and kinds.tank.armor == "tank" and is_equal_approx(float(kinds.tank.hp), VT.HP))
	_check("rook onder de helft, vuur onder een kwart, wrak 30 s", is_equal_approx(s_cls.SMOKE_AT, 0.5) and is_equal_approx(s_cls.FIRE_AT, 0.25) and is_equal_approx(s_cls.WRECK_STAY, 30.0))
	_check("zonder voertuigen: geen balk in je scherm, geen doelen", VS.bestuurd_fractie() < 0.0 and VS.bestuurd_naam() == "" and VS.doelen().is_empty())


	# ---------------------------------------------------------------- 3. de jeep: gegevens en schade per soort wapen
	var j = _own("jeep", Vector3(-4, 0, -8))
	await _frames(3)
	_check("de jeep heeft een onderdeel voor levenspunten", j._schade != null and j._schade.kind == "jeep" and j._schade.get_parent() == j)
	_check("220 levenspunten, pantser jeep", is_equal_approx(_hp(j), 220.0) and j._schade.armor == "jeep" and is_equal_approx(j._schade.max_hp, 220.0))
	_check("de jeep staat in de lijst en is een doel voor de vijand", VS.all.has(j._schade) and VS.doelen().has(j))
	_check("levensbalk boven de jeep (groen, volgt de camera)", j.find_child("Levensbalk", true, false) != null)
	var hp0 := _hp(j)
	j._schade.hit(100.0, Vector3.ZERO, true)
	_check("jouw eigen schot doet niets", _hp(j) == hp0)
	j._schade.hit(100.0, Vector3.ZERO, false)
	_check("een gewone kogel van de vijand: 30% (30 van 100)", is_equal_approx(hp0 - _hp(j), 30.0))
	G.hit_class = "scherp"
	hp0 = _hp(j)
	j._schade.hit(100.0, Vector3.ZERO, false)
	_check("scherpschutter: 50%", is_equal_approx(hp0 - _hp(j), 50.0))
	G.hit_class = "raket"
	hp0 = _hp(j)
	j._schade.hit(40.0, Vector3.ZERO, false)
	_check("raket: 150% (60 van 40)", is_equal_approx(hp0 - _hp(j), 60.0))
	G.hit_class = ""
	j._schade.hp = 220.0
	var at: Vector3 = j.global_position + Vector3(0, 0.8, 0)
	VS.blast(at, 3.2, 70.0)
	_check("tankgranaat vlak ernaast: 105 (explosie 150% van 70)", is_equal_approx(220.0 - _hp(j), 105.0))
	j._schade.hp = 220.0
	VS.blast(j.global_position + Vector3(9.0, 0, 0), 3.2, 70.0)
	_check("een granaat ver weg doet niets", _hp(j) == 220.0)
	VS.blast(j.global_position + Vector3(0.9 + 1.6, 0, 0), 3.2, 70.0)
	_check("aan de rand van de straal: minder schade dan vlak ernaast", _hp(j) < 220.0 and 220.0 - _hp(j) < 105.0)
	j._schade.hp = 220.0
	G.note_blast(at, 4.0)
	_check("jouw eigen ontploffingen (Game.note_blast) raken je jeep niet", _hp(j) == 220.0)

	# ---------------------------------------------------------------- 4. echte kogels
	var from: Vector3 = j.global_position + Vector3(0, 1.5, 12.0)
	BU.fire(main, from, PI, 34.0, 100.0, 1.1, false)   # een kogel van de vijand, recht op de jeep af
	await _frames(40)
	_check("een echte kogel van de vijand raakt de jeep (levenspunten %.1f)" % _hp(j), _hp(j) < 220.0 - 20.0 and _hp(j) > 220.0 - 40.0)
	j._schade.hp = 220.0
	BU.fire(main, from, PI, 34.0, 100.0, 1.1, true)   # een kogel van jou
	await _frames(40)
	_check("een echte kogel van jou raakt de jeep niet", _hp(j) == 220.0)

	# ---------------------------------------------------------------- 5. rook, vuur
	for fx in [j._schade._smoke, j._schade._fire]:
		if fx != null:
			fx.queue_free()   # de ontploffingen hierboven hadden hem al onder de helft gebracht
	j._schade._smoke = null
	j._schade._fire = null
	j._schade.hp = 220.0 * 0.55
	j._schade.hit(1.0, Vector3.ZERO, false)
	_check("boven de helft nog geen rook", j._schade._smoke == null)
	j._schade.hp = 220.0 * 0.45
	j._schade.hit(1.0, Vector3.ZERO, false)
	_check("onder 50% komt er rook", j._schade._smoke != null and j._schade._fire == null)
	j._schade.hp = 220.0 * 0.2
	j._schade.hit(1.0, Vector3.ZERO, false)
	_check("onder 25% komt er vuur", j._schade._fire != null)
	p.global_position = Vector3(-4, 0, 0)
	await _frames(3)
	var fill: MeshInstance3D = j._schade._bar_fill
	_check("de balk is zichtbaar vlakbij en krimpt mee (%.2f)" % fill.scale.x, j._schade._bar.visible and fill.scale.x < 0.4)
	p.global_position = Vector3(300, 0, 150)
	await _frames(2)
	_check("ver weg is de balk uit", not j._schade._bar.visible)

	# ---------------------------------------------------------------- 6. in de jeep: de balk in je scherm en het voertuig vangt de schade op
	j._schade.hp = 220.0
	p.global_position = Vector3(-4, 0, -4)
	p.shield_t = 0.0
	var hp_p: float = p.hp
	p.hit(10.0, Vector3.ZERO, false)
	_check("zonder voertuig raakt een kogel jou wel (levenspunten %.1f -> %.1f)" % [hp_p, p.hp], p.hp < hp_p)
	p.hp = hp_p
	j._toggle()
	await _frames(2)
	_check("je zit in de jeep", j.driven and p.driving and VS.bestuurd == j._schade)
	_check("de balk in je scherm is die van de jeep (vol)", is_equal_approx(VS.bestuurd_fractie(), 1.0) and VS.bestuurd_naam() == "JEEP")
	p.hit(80.0, Vector3(0, 0, 1), false, true)
	_check("terwijl je in de jeep zit, raakt het jou niets", p.hp == hp_p and not p.dead)
	j._schade.hit(110.0, Vector3.ZERO, false)
	_check("de schade gaat naar de jeep: balk %.2f" % VS.bestuurd_fractie(), is_equal_approx(VS.bestuurd_fractie(), 0.85) or (VS.bestuurd_fractie() > 0.8 and VS.bestuurd_fractie() < 0.9))
	var hud_bar: ProgressBar = null
	for n in main.find_children("*", "Control", true, false):
		if n.get_script() != null and String(n.get_script().resource_path).ends_with("hud_extra.gd"):
			hud_bar = n._hp_bar
	await _frames(3)
	_check("de balk bovenin je scherm toont de jeep (%.2f)" % (hud_bar.value if hud_bar != null else -1.0), hud_bar != null and absf(hud_bar.value - VS.bestuurd_fractie()) < 0.02)

	# ---------------------------------------------------------------- 7. de jeep gaat kapot terwijl jij erin zit (keuze 3B)
	var garage: Variant = _garage()
	_check("een echte garage geplaatst voor de administratie", garage != null)
	if garage != null:
		garage.fleet.append(j)
		garage.has.jeep = 1
	var all_n: int = VS.all.size()
	j._schade.hit(10000.0, Vector3(0, 0, 1), false)
	await _frames(2)
	_check("de jeep is kapot", j._schade.dead and _hp(j) == 0.0)
	_check("hij staat niet meer in de lijst met doelen", not VS.all.has(j._schade) and not VS.doelen().has(j) and VS.all.size() == all_n - 1)
	_check("je sneuvelt mee (3B): dood, 8 s wachten, uitgestapt", p.dead and p.respawn_t > 7.0 and p.respawn_t <= 8.01 and not p.driving and not j.driven)
	_check("je zit in geen voertuig meer: geen balk in je scherm", VS.bestuurd == null and VS.bestuurd_fractie() < 0.0)
	_check("het wrak is zwart, zonder botsing en zonder balk", j.collision_layer == 0 and j.collision_mask == 0 and not j._schade._bar.visible and not j.is_in_group("voertuigen"))
	_check("het wrak rookt en brandt", j._schade._smoke != null and j._schade._fire != null)
	var geblakerd := 0
	for mi in j.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).material_override != null:
			geblakerd += 1
	_check("alle onderdelen zijn zwartgeblakerd (%d)" % geblakerd, geblakerd > 5)
	_check("weg is weg (4A): de garage telt de jeep niet meer als in dienst", garage != null and (garage.fleet as Array).is_empty() and int(garage.has.jeep) == 0)
	j._toggle()
	_check("je kunt niet meer instappen in een wrak", not j.driven)
	j._schade.hit(100.0, Vector3.ZERO, false)
	_check("een wrak neemt geen schade meer", _hp(j) == 0.0)
	var jref: Node = j
	jref._schade._physics_process(29.0)
	_check("het wrak ligt er na 29 s nog", is_instance_valid(jref) and not jref.is_queued_for_deletion())
	jref._schade._physics_process(2.0)
	await _frames(3)
	_check("na 30 s is het wrak weg", not is_instance_valid(jref))
	p.respawn()
	_check("na het sneuvelen kom je terug met vol leven", not p.dead and p.hp == G.max_hp())
	await _frames(2)

	# ---------------------------------------------------------------- 8. de tank
	var t = _own("tank", Vector3(-4, 0, -8))
	await _frames(3)
	_check("de tank: 900 levenspunten, pantser tank, balk", t._schade.kind == "tank" and is_equal_approx(_hp(t), 900.0) and t._schade.armor == "tank" and t.find_child("Levensbalk", true, false) != null)
	t._schade.hit(100.0, Vector3.ZERO, false)
	_check("een gewone kogel doet 5% aan de tank (5 van 100)", is_equal_approx(900.0 - _hp(t), 5.0))
	G.hit_class = "raket"
	hp0 = _hp(t)
	t._schade.hit(55.0, Vector3.ZERO, false)
	_check("een raket doet 200% (110 van 55)", is_equal_approx(hp0 - _hp(t), 110.0))
	G.hit_class = ""
	t._schade.hp = 900.0
	VS.blast(t.global_position + Vector3(0, 0.8, 0), 3.2, 70.0)
	_check("een tankgranaat: 105", is_equal_approx(900.0 - _hp(t), 105.0))
	t._schade.hp = 900.0
	var tfrom: Vector3 = t.global_position + Vector3(0, 1.5, 14.0)
	BU.fire_rocket(main, tfrom, PI, 55.0, 1.6)   # een raket van een raketsoldaat van de vijand
	await _frames(60)
	_check("een echte raket van de vijand raakt de tank (%.0f levenspunten over)" % _hp(t), _hp(t) < 900.0 - 60.0)
	t._schade.hp = 900.0
	p.global_position = Vector3(-4, 0, -4)
	p.shield_t = 0.0
	t._toggle()
	await _frames(2)
	_check("je zit in de tank en de balk is die van de tank", t.driven and p.in_tank and VS.bestuurd_naam() == "TANK" and is_equal_approx(VS.bestuurd_fractie(), 1.0))
	var hp_t: float = p.hp
	p.hit(80.0, Vector3(0, 0, 1), false, true)
	_check("zware treffers raken jou niet meer in de tank", p.hp == hp_t)
	t._toggle()
	_check("uitstappen werkt: niet meer bestuurd", not t.driven and not p.driving and VS.bestuurd == null)
	t._toggle()
	if garage != null:
		garage.fleet.append(t)
		garage.has.tank = 1
	t._schade.hit(100000.0, Vector3.ZERO, false)
	await _frames(2)
	_check("de tank is kapot, jij sneuvelt mee en de garage telt hem niet meer", t._schade.dead and p.dead and not t.driven and not p.driving and not p.in_tank and garage != null and int(garage.has.tank) == 0 and (garage.fleet as Array).is_empty())
	_drop(t)
	p.respawn()
	await _frames(2)

	# ---------------------------------------------------------------- 9. de vijand mikt op een leeg geparkeerd voertuig (keuze 6A)
	p.global_position = Vector3(300, 0, 150)
	var parked = _own("jeep", Vector3(-4, 0, -8))
	await _frames(2)
	var ej = VJ.new()
	ej.route = []
	ej.position = Vector3(-1, 0, -36)
	ej.rotation.y = PI
	main.add_child(ej)
	await _frames(40)
	_check("de vijandelijke jeep kiest jouw geparkeerde jeep als doel", ej.target == parked)
	var hp_before := _hp(parked)
	await _frames(420)
	_check("hij beschiet hem (levenspunten %.1f -> %.1f)" % [hp_before, _hp(parked)], _hp(parked) < hp_before)
	_drop(ej)
	G.enemies.erase(ej)
	await _frames(2)

	var pt = _own("tank", Vector3(-4, 0, -10))
	pt.rotation.y = 0.0
	await _frames(2)
	var et = VT.new()
	et.route = []
	et.position = Vector3(-1, 0, -48)
	et.rotation.y = PI
	main.add_child(et)
	parked._schade.hp = 220.0
	_drop(parked)
	await _frames(2)
	var tg: Dictionary = et._pick_target()
	_check("de vijandelijke tank kiest jouw geparkeerde tank als doel (soort %s)" % str(tg.get("kind", "-")), str(tg.get("kind", "")) == "voertuig" and tg.node == pt)
	var hp_pt := _hp(pt)
	await _frames(900)
	_check("hij beschiet hem met granaten (%d schoten, levenspunten %.0f -> %.0f)" % [et._shots_fired, hp_pt, _hp(pt)], et._shots_fired >= 1 and _hp(pt) < hp_pt)
	_drop(et)
	G.enemies.erase(et)
	await _frames(2)

	var rj = _own("jeep", Vector3(-4, 0, -22))
	await _frames(2)
	var saved_buildings: Array = G.buildings
	G.buildings = []   # alleen jouw jeep in de buurt, geen bouwwerken
	var soldier = main.ENEMY.instantiate()
	soldier.setup("rocket", 3)
	soldier.position = Vector3(-4, 0, -30)
	main.add_child(soldier)
	await _frames(2)
	var rb: Variant = soldier._rocket_target()
	_check("een raketsoldaat mikt op jouw jeep binnen 26 m", rb != null and rb.node == rj)
	G.buildings = saved_buildings
	G.enemies.erase(soldier)
	_drop(soldier)
	_drop(rj)
	_drop(pt)
	await _frames(3)
	_check("opgeruimd: geen voertuigen meer in de lijst", VS.all.is_empty())

	print("klaar, fouten: ", fails)
	quit(1 if fails > 0 else 0)
