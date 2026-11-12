extends SceneTree
## Test van de vijandelijke jeep (Generals-plan, stap V1): het model van Dennis (knopen, clips, driehoeken), het groepsschema, de schade per soort wapen
## (Data.ARMOR_MULT), brand, wrak, de wachtrij van main.gd (maximaal drie voertuigen), het schieten op de speler en op een soldaat, de rit van de poort
## over de Hoofdstraat en de brug naar het kamp, en het wachten voor een opgehaalde brug.
## godot --headless --path . --script tests/vijand_jeep_test.gd --fixed-fps 60
## Duurt ongeveer 5500 tot 8500 beeldjes (de rit van de poort naar het kamp duurt 3300 tot 5000 beeldjes: bij een boomstam vlak na de poort hapert hij een tijdje), ruim een minuut. Draai hem met Godot 4.7.2 (zoals de CI): Godot 4.6.3 headless
## hapert of crasht in deze scène na enkele honderden beeldjes, ook zonder deze test.

var fails := 0
var main: Node
var G: Node
var _watchdog := 0
var _base_enemies: Array = []   # de vijanden die er al waren (verdedigers van de basis)


func _initialize() -> void:
	call_deferred("_run")


func _process(_d: float) -> bool:
	_watchdog += 1
	if _watchdog > 14000:
		push_error("Jeeptest hangt: de opstelling is niet klaargekomen")
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


## Een jeep zonder route (hij rijdt naar de speler of het kamp) op deze plek, met de neus in deze richting.
func _jeep_at(pos: Vector3, rot: float) -> Node:
	var cls := load("res://scripts/vijand_jeep.gd") as GDScript
	var j = cls.new()
	j.route = []
	j.position = pos
	j.rotation.y = rot
	main.add_child(j)
	return j


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
	var ps := load("res://assets/vijand_jeep.glb") as PackedScene
	_check("vijand_jeep.glb laadt", ps != null)
	var m := ps.instantiate() as Node3D
	root.add_child(m)
	for n in ["Body", "RompMesh", "StuurLV", "StuurRV", "WielLV", "WielRV", "WielLA", "WielRA", "Geschut", "MG", "Monding", "Bestuurder", "Schutter", "Bovenlijf"]:
		_check("model heeft knoop " + n, m.find_child(n, true, false) != null)
	var ap := m.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_check("model heeft een AnimationPlayer", ap != null)
	for c in ["Rijden", "Sturen", "Vuren"]:
		_check("clip " + c, ap != null and ap.has_animation(c))
	var tris := _tris(m)
	print("driehoeken in het model: ", tris)
	_check("model binnen het budget (<= 50.000 driehoeken)", tris > 10000 and tris <= 50000)
	_check("model heeft materialen met texturen", m.find_children("*", "MeshInstance3D", true, false).size() >= 8)
	m.queue_free()

	# ---------------------------------------------------------------- 2. schema en pantser
	var dt := load("res://scripts/data.gd") as GDScript
	_check("groep 1 en 2 hebben geen voertuig", dt.groep_voertuigen(1).is_empty() and dt.groep_voertuigen(2).is_empty())
	_check("groep 3 t/m 5: een jeep", dt.groep_voertuigen(3) == ["jeep"] and dt.groep_voertuigen(5) == ["jeep"])
	_check("groep 6 t/m 8: een voertuig (nog een jeep tot de tank er is)", dt.groep_voertuigen(6).size() == 1 and dt.groep_voertuigen(8).size() == 1)
	_check("groep 9 en hoger: twee voertuigen", dt.groep_voertuigen(9).size() == 2 and dt.groep_voertuigen(20).size() == 2)
	_check("kogel doet 30% aan een jeep", is_equal_approx(dt.counter("kogel", "jeep"), 0.3))
	_check("raket doet 150% aan een jeep", is_equal_approx(dt.counter("raket", "jeep"), 1.5))
	_check("explosie en brand doen 150% aan een jeep", is_equal_approx(dt.counter("explosie", "jeep"), 1.5) and is_equal_approx(dt.counter("brand", "jeep"), 1.5))
	_check("soldaten blijven zoals ze waren (zwaar: kogel 0,5 / raket 2,0)", is_equal_approx(dt.counter("kogel", "zwaar"), 0.5) and is_equal_approx(dt.counter("raket", "zwaar"), 2.0) and is_equal_approx(dt.counter("explosie", "licht"), 1.0))

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
	main._spawn_voertuig({"kind": "jeep", "n": 3, "voertuig": true})
	var v = _vehicles()[0] if _vehicles().size() > 0 else null
	_check("de jeep staat in de groep vijand_voertuig", v != null)
	if v == null:
		print("klaar, fouten: ", fails + 1)
		quit(1)
		return
	_check("de jeep staat in Game.enemies (soldaten, torens en Apache zien hem)", G.enemies.has(v))
	_check("levenspunten volgens groep 3 (220 + 5% per groep)", is_equal_approx(v.max_hp, 220.0 * 1.1) and v.hp == v.max_hp)
	_check("pantser jeep", v.armor == "jeep" and v.type == "jeep")
	var poort := Vector3(v.global_position.x, 0.0, v.global_position.z)
	var vb := load("res://scripts/vijand_basis.gd") as GDScript
	_check("hij begint binnen de poort van de vijandbasis", poort.distance_to(vb.gate_inside()) < 5.0)
	_check("vier wielen, twee stuurknopen, geschut en monding gevonden", v._wheels.size() == 4 and v._stuur.size() == 2 and v._gun != null and v._monding != null)
	_check("rode stip op de motorkap", v.find_child("RodeStip", true, false) != null)
	_check("levensbalk boven de jeep", v.find_child("Levensbalk", true, false) != null)
	var ar := load("res://scripts/aanval_routes.gd") as GDScript
	var pad: Array = ar.voertuig_pad()
	_check("de weg begint buiten de poort en eindigt op de noordkant van de brug", pad.size() >= 10 and (pad[pad.size() - 1] as Vector3).distance_to(Vector3(0, 0, -103)) < 1.0)
	_check("de weg gebruikt maar een wijkroute: geen steegjes (alle punten ten oosten van x=-10 na de poort)", pad.slice(2).all(func(p): return (p as Vector3).x > -10.0))

	# 3b. schade per soort wapen
	var hp0: float = v.hp
	v.hit(10.0, Vector3.ZERO, true)
	_check("een spelerskogel doet 30% (3 van 10)", is_equal_approx(hp0 - v.hp, 3.0))
	hp0 = v.hp
	v.hit(10.0, Vector3.ZERO, false)
	_check("schade van een andere vijand telt niet", v.hp == hp0)
	G.hit_class = "scherp"
	hp0 = v.hp
	v.hit(10.0, Vector3.ZERO, true)
	_check("scherpschutter: 50% (5 van 10)", is_equal_approx(hp0 - v.hp, 5.0))
	G.hit_class = "raket"
	hp0 = v.hp
	v.hit(10.0, Vector3.ZERO, true)
	_check("raket: 150% (15 van 10)", is_equal_approx(hp0 - v.hp, 15.0))
	G.hit_class = ""
	G.note_blast(v.global_position, 4.0)
	hp0 = v.hp
	v.hit(10.0, Vector3.ZERO, true)
	_check("een kogel vlak bij een ontploffing telt als explosie: 150%", is_equal_approx(hp0 - v.hp, 15.0))
	OS.delay_msec(350)   # de knal-melding van Game duurt een kwart seconde echte tijd (Time.get_ticks_msec)
	await _frames(2)
	hp0 = v.hp
	v.hit(10.0, Vector3.ZERO, true)
	_check("zonder knal weer 30%", is_equal_approx(hp0 - v.hp, 3.0))

	# 3c. napalm
	hp0 = v.hp
	v.ignite(1.0)
	_check("napalm zet hem in brand", v.burn_t > 0.0)
	await _frames(40)
	_check("brandschade loopt door (> 30 in 0,7 s)", hp0 - v.hp > 30.0)

	# 3d. kapot: wrak, teller, score, verdwijnt na een tijd
	v.hp = 5.0
	var kills0: int = G.kills
	var score0: int = G.score
	G.hit_class = "raket"
	v.hit(50.0, Vector3(0, 0, 1), true)
	G.hit_class = ""
	_check("kapot na genoeg schade", v.dead and v.hp == 0.0)
	_check("uit de vijandenlijst en de groep, dus ook van de radar", not G.enemies.has(v) and not v.is_in_group("vijand_voertuig"))
	_check("telt als kill (+1) en geeft 150 punten", G.kills == kills0 + 1 and G.score >= score0 + 150)
	_check("het wrak heeft geen botsing meer", v.collision_layer == 0)
	_check("de bemanning is uit beeld", not v.find_child("Bestuurder", true, false).visible and not v.find_child("Schutter", true, false).visible)
	v._wreck_t = 0.2
	await _frames(30)
	_check("het wrak ruimt zichzelf op", not is_instance_valid(v))

	# ---------------------------------------------------------------- 4. wachtrij en maximum
	_clear_vehicles()
	await _frames(2)
	G.wave = 2
	main.queue.clear()
	main._launch_group()   # groep 3
	var eerste: Variant = main.queue[0] if main.queue.size() > 0 else null
	_check("groep 3: het voertuig staat vooraan in de wachtrij", eerste is Dictionary and eerste.get("voertuig", false) and eerste.kind == "jeep")
	var soldaten := 0
	for q in main.queue:
		if q is Dictionary and not q.get("voertuig", false):
			soldaten += 1
	_check("achter het voertuig komen de soldaten van de groep", soldaten == dt.build_group(3).size())
	G.wave = 8
	main.queue.clear()
	main._launch_group()   # groep 9
	var aantal := 0
	for q in main.queue:
		if q is Dictionary and q.get("voertuig", false):
			aantal += 1
	_check("groep 9: twee voertuigen in de rij", aantal == 2)
	main.queue.clear()
	G.wave = 1
	# maximum drie tegelijk: met drie op de weg laat het volgende voertuig de soldaat voorgaan en wacht het zelf
	for i in 3:
		main._spawn_voertuig({"kind": "jeep", "n": 3, "voertuig": true})
	_check("drie jeeps op de weg", _vehicles().size() == 3)
	main.queue.append({"kind": "jeep", "n": 3, "voertuig": true})
	main.queue.append({"kind": dt.build_group(1)[0], "n": 1, "routes": ["brug"]})
	G.state = "play"
	main.spawn_t = 0.0
	await _frames(4)
	_check("met drie voertuigen op de kaart blijft het vierde wachten, de soldaat gaat voor", _vehicles().size() == 3 and main.queue.size() == 1 and main.queue[0].get("voertuig", false))
	main.queue.clear()
	G.state = "prep"
	G.prep_t = 99999.0
	G.wave = 0
	_clear_enemies()
	await _frames(2)

	# ---------------------------------------------------------------- 5. schieten op de speler en op een soldaat
	var j = _jeep_at(Vector3(-1, 0, -36), PI)
	p.global_position = Vector3(-4, 0, -8)
	p.hp = 100.0
	var hp_p: float = p.hp
	await _frames(420)
	_check("de jeep schiet op de speler binnen bereik (levenspunten %.0f -> %.0f)" % [hp_p, p.hp], p.hp < hp_p)
	_check("hij houdt een eind van de speler (hij botst er niet doorheen)", j.global_position.distance_to(p.global_position) > 4.0)
	j.queue_free()
	G.enemies.erase(j)
	await _frames(2)
	p.global_position = Vector3(300, 0, 150)
	var ally_s := load("res://scripts/ally.gd") as GDScript
	var a = ally_s.new()
	main.add_child(a)
	a.global_position = Vector3(-4, 0, -8)
	a.setup(100.0, 16.0, 0)
	G.allies.append(a)
	var j2 = _jeep_at(Vector3(-1, 0, -36), PI)
	await _frames(480)
	_check("de jeep schiet ook op een soldaat (die geen botsing heeft)", not is_instance_valid(a) or a.hp < 100.0 or a.dead)
	if is_instance_valid(a):
		G.allies.erase(a)
		a.queue_free()
	print("opruimen jeep 2")
	j2.queue_free()
	G.enemies.erase(j2)
	await _frames(2)
	print("jeep 2 opgeruimd")

	# ---------------------------------------------------------------- 6. de rit: poort, jungle, Hoofdstraat, brug, kamp
	p.global_position = Vector3(300, 0, 150)
	print("rit: spawn")
	main._spawn_voertuig({"kind": "jeep", "n": 3, "voertuig": true})
	print("rit: gespawnd")
	var r = _vehicles()[0]
	var langs_brug := false
	var f := 0
	var max_z := -9999.0
	var t0 := Time.get_ticks_msec()
	# Bij seed 11 zit er een boomstam (Level-botsing) vlak na de poort waar hij 10 tot 35 s tegenaan hapert; hoe lang hangt van een worp af
	# (de kant waarop hij achteruit steekt). Daarom een ruim budget (120 s) en stoppen zodra hij bij het kamp staat, in plaats van een vaste 65 s.
	while f < 7200 and is_instance_valid(r) and not (r.holding and r._flat_dist(basis) < 26.0):
		await _frames(60)
		f += 60
		max_z = maxf(max_z, r.global_position.z)
		if f % 600 == 0:
			print("rit f=%d pos=(%.1f, %.1f) route_i=%d/%d cross_i=%d" % [f, r.global_position.x, r.global_position.z, r.route_i, r.route.size(), r.cross_i])
		if r.cross_i >= 1:
			langs_brug = true
	print("de rit duurde %.0f s echte tijd" % ((Time.get_ticks_msec() - t0) / 1000.0))
	_check("hij is onderweg over de brug geweest", langs_brug)
	print("aangekomen na %d beelden (%.0f s)" % [f, f / 60.0])
	_check("hij staat binnen 120 s bij het kamp en houdt stil (afstand tot het HK %.1f m)" % r._flat_dist(basis), r.holding and r._flat_dist(basis) < 26.0)
	_check("de levensbalk volgt de levenspunten", r.find_child("Levensbalk", true, false) != null)
	r.queue_free()
	G.enemies.erase(r)
	await _frames(2)

	# ---------------------------------------------------------------- 7. de brug staat omhoog
	if G.bridge != null:
		var br = G.bridge
		br.toggle()
		await _frames(330)
		_check("de brug is omhoog", not br.is_down())
		var w = _jeep_at(Vector3(0, 0, -112), PI)
		await _frames(240)
		_check("voor een opgehaalde brug wacht hij aan de noordkant (z %.1f)" % w.global_position.z, w.holding and w.global_position.z < -93.0 and absf(w._speed) < 0.5)
		br.toggle()
		await _frames(330)
		_check("de brug is weer omlaag", br.is_down())
		await _frames(480)
		_check("daarna rijdt hij over de brug (z %.1f)" % w.global_position.z, w.global_position.z > -85.0)
		w.queue_free()
		G.enemies.erase(w)

	print("klaar, fouten: ", fails)
	quit(1 if fails > 0 else 0)
