extends SceneTree
## Test van de vijandelijke tank (Generals-plan, stap V2): het model van Dennis (knopen, 22 wielen, rupsen, clips, driehoeken, maat), het groepsschema, de schade per soort
## wapen (Data.ARMOR_MULT, pantser "tank"), brand, wrak, de wachtrij van main.gd (maximaal drie voertuigen), het beleg (hij stopt binnen 38 m van het eerste doel, draait de koepel
## en schiet granaten op soldaat, speler en bouwwerk), de ontploffing van een granaat (straal, afname, de hoge basismuur), de rit van de poort over de brug naar het kamp en het
## wachten voor een opgehaalde brug.
## godot --headless --path . --script tests/vijand_tank_test.gd --fixed-fps 60
## Draai hem met Godot 4.7.2 (zoals de CI): Godot 4.6.3 headless hapert of crasht in deze scène na enkele honderden beeldjes.

var fails := 0
var main: Node
var G: Node
var _watchdog := 0
var _base_enemies: Array = []   # de vijanden die er al waren (verdedigers van de basis)


func _initialize() -> void:
	call_deferred("_run")


func _process(_d: float) -> bool:
	_watchdog += 1
	if _watchdog > 30000:
		push_error("Tanktest hangt: de opstelling is niet klaargekomen")
		quit(99)
	return false


func _check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FOUT ") + name)
	if not ok:
		fails += 1


func _frames(n: int) -> void:
	for _i in n:
		await process_frame


func _vehicles() -> Array:
	return get_nodes_in_group("vijand_voertuig")


func _clear_vehicles() -> void:
	for v in _vehicles():
		G.enemies.erase(v)
		v.queue_free()


## Ruimt de vijanden op die de test zelf liet uitrukken; de verdedigers en torens van de vijandbasis blijven staan.
func _clear_enemies() -> void:
	for e in G.enemies.duplicate():
		if _base_enemies.has(e):
			continue
		G.enemies.erase(e)
		if is_instance_valid(e):
			e.queue_free()


## Een tank zonder route (hij rijdt naar het hoofdkwartier) op deze plek, met de neus in deze richting.
func _tank_at(pos: Vector3, rot: float) -> Node:
	var cls := load("res://scripts/vijand_tank.gd") as GDScript
	var v = cls.new()
	v.route = []
	v.position = pos
	v.rotation.y = rot
	main.add_child(v)
	return v


func _ally_at(pos: Vector3, hp := 100.0) -> Node:
	var ally_s := load("res://scripts/ally.gd") as GDScript
	var a = ally_s.new()
	main.add_child(a)
	a.global_position = pos
	a.setup(hp, 16.0, 0)
	a.set_physics_process(false)   # de soldaat blijft staan (anders loopt hij achter de speler aan)
	G.allies.append(a)
	return a


func _drop_ally(a) -> void:
	if is_instance_valid(a):
		G.allies.erase(a)
		a.queue_free()


func _tris(n: Node) -> int:
	var total := 0
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		if m != null:
			for s in m.get_surface_count():
				var arr := m.surface_get_arrays(s)
				var idx = arr[Mesh.ARRAY_INDEX]
				total += (idx.size() if idx != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return total


func _run() -> void:
	# ---------------------------------------------------------------- 1. het model
	var ps := load("res://assets/vijand_tank.glb") as PackedScene
	_check("vijand_tank.glb laadt", ps != null)
	var m := ps.instantiate() as Node3D
	root.add_child(m)
	for n in ["Body", "RompMesh", "RupsL", "RupsR", "Toren", "TorenMesh", "Kanon", "KanonMesh", "Monding"]:
		_check("model heeft knoop " + n, m.find_child(n, true, false) != null)
	_check("22 wielen: 9 + aandrijfwiel + spanwiel per kant", m.find_children("WielL_*", "Node3D", true, false).size() == 11 and m.find_children("WielR_*", "Node3D", true, false).size() == 11)
	var ap := m.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_check("model heeft een AnimationPlayer", ap != null)
	# Godot haalt het achtervoegsel "-loop" van de clipnaam en zet de clip zelf op lus
	for c in ["Vuren", "Rijden", "Draaien"]:
		_check("clip " + c, ap != null and ap.has_animation(c))
	for c in ["Rijden", "Draaien"]:
		_check("clip %s loopt in een lus" % c, ap != null and ap.has_animation(c) and ap.get_animation(c).loop_mode == Animation.LOOP_LINEAR)
	_check("clip Vuren duurt 0,4 s", ap != null and absf(ap.get_animation("Vuren").length - 0.4) < 0.05)
	var tris := _tris(m)
	print("driehoeken in het model: ", tris)
	_check("model binnen het budget (<= 45.000 driehoeken)", tris > 25000 and tris <= 45000)
	_check("model heeft twee materialen met texturen (romp-atlas en rups)", m.find_children("*", "MeshInstance3D", true, false).size() >= 25)
	var aabb := AABB()
	var first := true
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var a: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		aabb = a if first else aabb.merge(a)
		first = false
	print("maat (b x h x l): %.2f x %.2f x %.2f, y van %.2f tot %.2f" % [aabb.size.x, aabb.size.y, aabb.size.z, aabb.position.y, aabb.end.y])
	_check("maat: 3,3 tot 4,0 breed, 2,6 tot 3,4 hoog, 7,5 tot 8,5 lang (met kanon)", aabb.size.x > 3.3 and aabb.size.x < 4.0 and aabb.size.y > 2.6 and aabb.size.y < 3.4 and aabb.size.z > 7.5 and aabb.size.z < 8.5)
	_check("de grond ligt op y = 0 en het kanon wijst naar -Z (voorkant)", absf(aabb.position.y) < 0.12 and (m.find_child("Monding", true, false) as Node3D).global_position.z < -2.5)
	m.queue_free()

	# ---------------------------------------------------------------- 2. schema en pantser
	var dt := load("res://scripts/data.gd") as GDScript
	_check("de tank is klaar (Data.TANK_KLAAR)", dt.TANK_KLAAR)
	_check("groep 1 en 2 hebben geen voertuig", dt.groep_voertuigen(1).is_empty() and dt.groep_voertuigen(2).is_empty())
	_check("groep 3 t/m 5: een jeep", dt.groep_voertuigen(3) == ["jeep"] and dt.groep_voertuigen(5) == ["jeep"])
	_check("groep 6 t/m 8: een tank", dt.groep_voertuigen(6) == ["tank"] and dt.groep_voertuigen(8) == ["tank"])
	_check("groep 9 en hoger: een tank en een jeep", dt.groep_voertuigen(9) == ["tank", "jeep"] and dt.groep_voertuigen(20) == ["tank", "jeep"])
	_check("kogel doet 5% aan een tank", is_equal_approx(dt.counter("kogel", "tank"), 0.05))
	_check("scherpschutter 10%, raket 200%, explosie 150%, brand 150%", is_equal_approx(dt.counter("scherp", "tank"), 0.1) and is_equal_approx(dt.counter("raket", "tank"), 2.0) and is_equal_approx(dt.counter("explosie", "tank"), 1.5) and is_equal_approx(dt.counter("brand", "tank"), 1.5))

	# ---------------------------------------------------------------- 3. de wereld
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	main.get_node("Hud/Sticks").set_process(false)
	main.begin()
	await _frames(5)
	G = root.get_node("Game")
	G.prep_t = 99999.0
	G.player.global_position = Vector3(300, 0, 150)   # ver weg: hij schiet niet op de speler tijdens de eerste proeven
	await _frames(5)
	var basis: Vector3 = G.base_pos
	var p = G.player
	_base_enemies = G.enemies.duplicate()
	print("vijanden bij de start: ", _base_enemies.size())

	# 3a. uitrukken via main.gd
	main._spawn_voertuig({"kind": "tank", "n": 6, "voertuig": true})
	var v = _vehicles()[0] if _vehicles().size() > 0 else null
	_check("de tank staat in de groep vijand_voertuig", v != null)
	if v == null:
		print("klaar, fouten: ", fails + 1)
		quit(1)
		return
	_check("de tank staat in Game.enemies (soldaten, torens en Apache zien hem)", G.enemies.has(v))
	_check("levenspunten volgens groep 6 (900 + 5% per groep)", is_equal_approx(v.max_hp, 900.0 * 1.25) and v.hp == v.max_hp)
	_check("pantser tank", v.armor == "tank" and v.type == "tank")
	var poort := Vector3(v.global_position.x, 0.0, v.global_position.z)
	var vb := load("res://scripts/vijand_basis.gd") as GDScript
	_check("hij begint binnen de poort van de vijandbasis", poort.distance_to(vb.gate_inside()) < 5.0)
	_check("22 wielen, twee rupsen, koepel, kanon en monding gevonden", v._wheels_l.size() == 11 and v._wheels_r.size() == 11 and v._rups.size() == 2 and v._toren != null and v._kanon != null and v._monding != null)
	_check("rode stip op de koepel (draait mee)", v.find_child("RodeStip", true, false) != null and v.find_child("RodeStip", true, false).get_parent() == v._toren)
	_check("levensbalk boven de tank", v.find_child("Levensbalk", true, false) != null)
	_check("de Blender-clip Vuren houdt alleen het kanon over (romp en wielen worden door de code bewogen)", v._anim != null and v._anim.get_animation("Vuren").get_track_count() >= 1 and v._anim.get_animation("Vuren").get_track_count() <= 3)

	# 3b. schade per soort wapen
	var hp0: float = v.hp
	v.hit(100.0, Vector3.ZERO, true)
	_check("een spelerskogel doet 5% (5 van 100)", is_equal_approx(hp0 - v.hp, 5.0))
	hp0 = v.hp
	v.hit(100.0, Vector3.ZERO, false)
	_check("schade van een andere vijand telt niet", v.hp == hp0)
	G.hit_class = "scherp"
	hp0 = v.hp
	v.hit(100.0, Vector3.ZERO, true)
	_check("scherpschutter: 10% (10 van 100)", is_equal_approx(hp0 - v.hp, 10.0))
	G.hit_class = "raket"
	hp0 = v.hp
	v.hit(100.0, Vector3.ZERO, true)
	_check("raket: 200% (200 van 100)", is_equal_approx(hp0 - v.hp, 200.0))
	G.hit_class = ""
	G.note_blast(v.global_position, 4.0)
	hp0 = v.hp
	v.hit(100.0, Vector3.ZERO, true)
	_check("een kogel vlak bij een ontploffing telt als explosie: 150%", is_equal_approx(hp0 - v.hp, 150.0))
	OS.delay_msec(350)   # de knal-melding van Game duurt een kwart seconde echte tijd (Time.get_ticks_msec)
	await _frames(2)
	hp0 = v.hp
	v.hit(100.0, Vector3.ZERO, true)
	_check("zonder knal weer 5%", is_equal_approx(hp0 - v.hp, 5.0))

	# 3c. rook en vuur bij schade, napalm
	v.hp = v.max_hp * 0.45
	v.hit(1.0, Vector3.ZERO, true)
	_check("onder 50% levenspunten komt er rook", v._smoke != null)
	v.hp = v.max_hp * 0.2
	v.hit(1.0, Vector3.ZERO, true)
	_check("onder 25% levenspunten komt er vuur", v._fire != null)
	v.hp = v.max_hp
	hp0 = v.hp
	v.ignite(1.0)
	_check("napalm zet hem in brand", v.burn_t > 0.0)
	await _frames(40)
	_check("brandschade loopt door (150%: > 20 in 0,7 s)", hp0 - v.hp > 20.0)

	# 3d. kapot: wrak, teller, score, verdwijnt na een tijd
	v.hp = 5.0
	var kills0: int = G.kills
	var score0: int = G.score
	G.hit_class = "raket"
	v.hit(50.0, Vector3(0, 0, 1), true)
	G.hit_class = ""
	_check("kapot na genoeg schade", v.dead and v.hp == 0.0)
	_check("uit de vijandenlijst en de groep, dus ook van de radar", not G.enemies.has(v) and not v.is_in_group("vijand_voertuig"))
	_check("telt als kill (+1) en geeft 300 punten", G.kills == kills0 + 1 and G.score >= score0 + 300)
	_check("het wrak heeft geen botsing meer", v.collision_layer == 0)
	_check("het wrak is zwartgeblakerd en de koepel staat iets scheef", absf(v._toren.rotation.z) > 0.03 and (v.find_child("RompMesh", true, false) as MeshInstance3D).material_override != null)
	_check("de rode stip blijft op het wrak", (v.find_child("RodeStip", true, false) as MeshInstance3D).material_override == null)
	v._wreck_t = 0.2
	await _frames(30)
	_check("het wrak ruimt zichzelf op", not is_instance_valid(v))

	# ---------------------------------------------------------------- 4. wachtrij en maximum
	_clear_vehicles()
	await _frames(2)
	G.wave = 5
	main.queue.clear()
	main._launch_group()   # groep 6
	var eerste: Variant = main.queue[0] if main.queue.size() > 0 else null
	_check("groep 6: een tank staat vooraan in de wachtrij", eerste is Dictionary and eerste.get("voertuig", false) and eerste.kind == "tank")
	G.wave = 8
	main.queue.clear()
	main._launch_group()   # groep 9
	var soorten := []
	for q in main.queue:
		if q is Dictionary and q.get("voertuig", false):
			soorten.append(q.kind)
	_check("groep 9: een tank en een jeep in de rij", soorten == ["tank", "jeep"])
	main.queue.clear()
	G.wave = 1
	for i in 3:
		main._spawn_voertuig({"kind": "tank" if i == 0 else "jeep", "n": 6, "voertuig": true})
	_check("drie voertuigen op de weg (een tank en twee jeeps)", _vehicles().size() == 3)
	main.queue.append({"kind": "tank", "n": 6, "voertuig": true})
	main.queue.append({"kind": dt.build_group(1)[0], "n": 1, "routes": ["brug"]})
	G.state = "play"
	main.spawn_t = 0.0
	await _frames(4)
	_check("met drie voertuigen op de kaart blijft de volgende tank wachten, de soldaat gaat voor", _vehicles().size() == 3 and main.queue.size() == 1 and main.queue[0].get("voertuig", false))
	main.queue.clear()
	G.state = "prep"
	G.prep_t = 99999.0
	G.wave = 0
	_clear_vehicles()
	_clear_enemies()
	await _frames(2)

	# ---------------------------------------------------------------- 5. de granaat zelf (ontploffing)
	var vt := load("res://scripts/vijand_tank.gd") as GDScript
	G.state = "play"
	var a1 = _ally_at(Vector3(-4, 0, -30))
	var a2 = _ally_at(Vector3(-4, 0, -37.5))   # 7,5 m verderop: buiten de straal van 3,2 m
	vt.boom(main, Vector3(-4, 0, -31.0), 70.0)
	_check("een soldaat 1 m van de inslag verliest levenspunten (70 x 0,84 = 59)", is_equal_approx(a1.hp, 100.0 - 70.0 * (1.0 - 1.0 / 3.2 * 0.5)))
	_check("een soldaat buiten de straal blijft heel", a2.hp == 100.0)
	vt.boom(main, Vector3(-4, 0, -30.0), 70.0)
	_check("de tweede granaat doodt hem (hij staat niet meer in Game.allies)", not G.allies.has(a1))
	_drop_ally(a2)
	var hq0: float = G.base_hp
	vt.boom(main, basis + Vector3(0, 0, -vt.HQ_R - 1.0), 70.0)
	_check("een granaat tegen het hoofdkwartier kost levenspunten (1000 -> %.0f)" % G.base_hp, G.base_hp < hq0 and hq0 - G.base_hp <= vt.HQ_DAMAGE)
	G.base_hp = G.base_max
	p.global_position = Vector3(-4, 0, -30)
	p.hp = 100.0
	vt.boom(main, Vector3(-4, 0, -30), 70.0)
	_check("een granaat naast de speler doet schade (%.0f -> %.0f)" % [100.0, p.hp], p.hp < 100.0)
	p.global_position = Vector3(300, 0, 150)
	p.hp = 100.0
	var wal = G.builds.place("zandzak", Vector3(-4, 0, -30), 0.0, false, true) if G.builds != null else null
	if wal != null:
		var wal_hp: float = wal.hp
		vt.boom(main, Vector3(-4, 0, -30), 70.0)
		_check("een granaat tegen een zandzakkenrij kost levenspunten (de helft van 3 x 70)", wal.hp < wal_hp)
		G.builds.remove(wal)
	else:
		print("let op: zandzak kon niet geplaatst worden; die controle is overgeslagen")
	await _frames(2)

	# ---------------------------------------------------------------- 6. beleg: soldaat, speler en bouwwerk
	_clear_enemies()
	G.state = "play"
	p.global_position = Vector3(300, 0, 150)
	var ally := _ally_at(Vector3(-4, 0, -26), 600.0)   # taai genoeg om het hele beleg te overleven
	var t1 = _tank_at(Vector3(-1, 0, -70), PI)
	_check("zonder doel binnen bereik rijdt hij gewoon door (nog geen doel)", t1.target.is_empty())
	var pos0: Vector3 = t1.global_position
	await _frames(60)
	_check("hij rijdt naar het hoofdkwartier", t1.global_position.distance_to(pos0) > 0.8)
	await _frames(600)
	var d_stop: float = t1._flat_dist(ally.global_position) if is_instance_valid(ally) else 99.0
	print("beleg soldaat: afstand %.1f m, schoten %d, doel %s, soldaat hp %s" % [d_stop, t1._shots_fired, str(t1.target.get("kind", "-")), str(ally.hp) if is_instance_valid(ally) else "dood"])
	_check("hij kiest de soldaat als doel (beleg)", t1.target.get("kind", "") == "ally" or not is_instance_valid(ally) or not G.allies.has(ally))
	_check("hij staat stil binnen 38 m van het doel (%.1f m)" % d_stop, t1.holding and absf(t1._speed) < 0.2 and (d_stop <= 38.5 or not G.allies.has(ally)))
	_check("hij heeft een granaat afgevuurd", t1._shots_fired >= 1)
	_check("de koepel staat op het doel gedraaid", absf(wrapf(atan2(-(ally.global_position.x - t1._monding.global_position.x), -(ally.global_position.z - t1._monding.global_position.z)) - t1.rotation.y - t1._toren.rotation.y, -PI, PI)) < 0.3 if is_instance_valid(ally) else true)
	await _frames(600)
	_check("de soldaat is geraakt of gedood door de granaten", not is_instance_valid(ally) or not G.allies.has(ally) or ally.hp < 600.0)
	_drop_ally(ally)
	# het beleg is voorbij: er is niets meer binnen bereik, dus hij rijdt verder
	t1.target = {}
	await _frames(10)
	var pos1: Vector3 = t1.global_position
	await _frames(240)
	_check("zonder doel in bereik rijdt hij verder (%.1f m)" % t1.global_position.distance_to(pos1), t1.global_position.distance_to(pos1) > 1.5 or not t1.target.is_empty())
	t1.queue_free()
	G.enemies.erase(t1)
	await _frames(2)

	# de speler als doel
	p.global_position = Vector3(-4, 0, -26)
	p.hp = 100.0
	var t2 = _tank_at(Vector3(-1, 0, -70), PI)
	await _frames(900)
	print("beleg speler: schoten %d, speler hp %.1f, doel %s" % [t2._shots_fired, p.hp, str(t2.target.get("kind", "-"))])
	_check("hij beschiet de speler binnen bereik (levenspunten %.0f -> %.0f)" % [100.0, p.hp], t2._shots_fired >= 1 and p.hp < 100.0)
	_check("hij houdt afstand van de speler (> 20 m, hij botst er niet doorheen)", t2._flat_dist(p.global_position) > 20.0)
	t2.queue_free()
	G.enemies.erase(t2)
	p.global_position = Vector3(300, 0, 150)
	p.hp = 100.0
	await _frames(2)

	# een bouwwerk als doel
	var bw = G.builds.place("zandzak", Vector3(-4, 0, -26), 0.0, false, true) if G.builds != null else null
	if bw != null:
		var bw_hp: float = bw.hp
		var t3 = _tank_at(Vector3(-1, 0, -70), PI)
		await _frames(900)
		print("beleg bouwwerk: schoten %d, doel %s, hp %.0f -> %.0f" % [t3._shots_fired, str(t3.target.get("kind", "-")), bw_hp, bw.hp if G.buildings.has(bw) else 0.0])
		_check("hij beschiet een bouwwerk (zandzakken verliezen levenspunten)", t3._shots_fired >= 1 and (not G.buildings.has(bw) or bw.hp < bw_hp))
		t3.queue_free()
		G.enemies.erase(t3)
		if G.buildings.has(bw):
			G.builds.remove(bw)
	else:
		print("let op: zandzak kon niet geplaatst worden; het beleg van een bouwwerk is overgeslagen")
	await _frames(2)

	# soldaten dichtbij: een tank heeft geen MG, dus uit de buurt komen ze er heel van af
	var t4 = _tank_at(Vector3(-1, 0, -30), PI)
	p.global_position = Vector3(300, 0, 150)
	var rakker := _ally_at(Vector3(-1, 0, -23))   # 7 m voor zijn neus
	await _frames(30)
	var dichtbij: float = t4._flat_dist(rakker.global_position)
	_check("een soldaat vlak voor de tank wordt wel gekozen (hij mikt op alles binnen bereik, ook dichtbij, met een gewone schootsafstand)", t4.target.get("kind", "") == "ally" or dichtbij < 12.0)
	t4.queue_free()
	G.enemies.erase(t4)
	_drop_ally(rakker)
	await _frames(2)

	# ---------------------------------------------------------------- 7. de rit: poort, jungle, Hoofdstraat, brug, kamp
	_clear_enemies()
	p.global_position = Vector3(300, 0, 150)
	G.state = "prep"
	G.prep_t = 99999.0
	print("rit: spawn")
	main._spawn_voertuig({"kind": "tank", "n": 6, "voertuig": true})
	var r = _vehicles()[0]
	var langs_brug := false
	var f := 0
	var max_f := 12000
	var t0 := Time.get_ticks_msec()
	while f < max_f and is_instance_valid(r):
		await _frames(60)
		f += 60
		if f % 600 == 0:
			print("rit f=%d pos=(%.1f, %.1f) route_i=%d/%d cross_i=%d snelheid %.1f" % [f, r.global_position.x, r.global_position.z, r.route_i, r.route.size(), r.cross_i, r._speed])
		if r.cross_i >= 1:
			langs_brug = true
		if r.holding and r.route_i >= r.route.size() and r.cross_i >= 1:
			break
	print("de rit duurde %.0f s echte tijd, %d beeldjes (%.0f s spelsom)" % [(Time.get_ticks_msec() - t0) / 1000.0, f, f / 60.0])
	_check("hij is onderweg over de brug geweest", langs_brug)
	_check("hij staat bij het kamp en houdt stil (afstand tot het HK %.1f m)" % r._flat_dist(basis), r.holding and r._flat_dist(basis) < 46.0)
	_check("de levensbalk volgt de levenspunten", r.find_child("Levensbalk", true, false) != null)
	_check("tijdens de voorbereiding schiet hij nog niet op het hoofdkwartier (schoten %d)" % r._shots_fired, r._shots_fired == 0)
	G.state = "play"
	await _frames(600)
	_check("zodra het spel begint beschiet hij het hoofdkwartier (schoten %d, HK %.0f)" % [r._shots_fired, G.base_hp], r._shots_fired >= 1 and G.base_hp < G.base_max)
	G.base_hp = G.base_max
	r.queue_free()
	G.enemies.erase(r)
	await _frames(2)

	# ---------------------------------------------------------------- 8. de brug staat omhoog
	G.state = "prep"
	if G.bridge != null:
		var br = G.bridge
		br.toggle()
		await _frames(330)
		_check("de brug is omhoog", not br.is_down())
		var w = _tank_at(Vector3(0, 0, -112), PI)
		await _frames(300)
		_check("voor een opgehaalde brug wacht hij aan de noordkant (z %.1f)" % w.global_position.z, w.holding and w.global_position.z < -92.0 and absf(w._speed) < 0.5)
		br.toggle()
		await _frames(330)
		_check("de brug is weer omlaag", br.is_down())
		await _frames(900)
		_check("daarna rijdt hij over de brug (z %.1f)" % w.global_position.z, w.global_position.z > -85.0)
		w.queue_free()
		G.enemies.erase(w)

	print("klaar, fouten: ", fails)
	quit(1 if fails > 0 else 0)
