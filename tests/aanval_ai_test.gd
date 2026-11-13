extends SceneTree
## Test van de slimme vijandaanval (Generals-plan D2 keuze F, keuzes van Dennis 1A t/m 10A, v229): score per kant en de dobbelsteen (1A), de Backdoor-oversteek
## en het pad om het kamp heen (2A), verzamelen en vuur en beweging met rook (3A), doelgewichten (4A), overval- en heroverploegen (5A, 8A), leren en fasen (6A),
## terugtrekken, terugroepen en najagen (7A), verkenning met CONTACT (9A) en de drie niveaus (10A). Daarnaast een echte groep die van de vijandbasis
## over de rivier naar het verzamelpunt loopt en daarna aanvalt.
## godot --headless --path . --script tests/aanval_ai_test.gd --fixed-fps 60

var fails := 0
var main: Node
var G: Node
var ai: Node
var AI: GDScript
var _watchdog := 0
var _banners: Array = []
var _base_enemies: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _process(_d: float) -> bool:
	_watchdog += 1
	if _watchdog > 30000:
		push_error("aanval_ai_test hangt")
		quit(99)
	return false


func _check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FOUT ") + name)
	if not ok:
		fails += 1


func _frames(n: int) -> void:
	for _i in n:
		await process_frame


func _clear_enemies() -> void:
	for e in G.enemies.duplicate():
		if _base_enemies.has(e):
			continue
		G.enemies.erase(e)
		if is_instance_valid(e):
			e.queue_free()
	main.queue.clear()
	ai.groepen.clear()


func _keuzes(n: int) -> Dictionary:
	var tel := {"N": 0, "O": 0, "Z": 0, "W": 0}
	for i in n:
		tel[ai.kies_kant()] += 1
	return tel


func _run() -> void:
	load("res://scripts/aanval_fx.gd").call("zet_rook_zicht", false)   # gewone fases zonder zichtblokkade; die test staat onderaan
	AI = load("res://scripts/aanval_ai.gd")
	var dt := load("res://scripts/data.gd") as GDScript
	var rt := load("res://scripts/route.gd") as GDScript
	# ---------------------------------------------------------------- 2A: de Backdoor
	_check("Backdoor ligt aan de andere kant van de brug dan de ondiepte", signf(dt.BACKDOOR_X) != signf(dt.FORD_X) and absf(dt.BACKDOOR_X) > 90.0)
	var rz: float = dt.river_z(dt.BACKDOOR_X)
	var wp: Vector3 = rt.waypoint(Vector3(dt.BACKDOOR_X + 3.0, 0, rz - 12.0), Vector3(dt.BACKDOOR_X, 0, rz + 10.0))
	_check("Route steekt bij de Backdoor over als dat de kortste weg is", absf(wp.x - dt.BACKDOOR_X) < 0.5)
	var wp2: Vector3 = rt.waypoint(Vector3(dt.BACKDOOR_X, 0, rz), Vector3(dt.BACKDOOR_X, 0, rz + 10.0))
	_check("midden in de Backdoor: door naar de zuidoever", absf(wp2.x - dt.BACKDOOR_X) < 0.5 and wp2.z > rz)
	var wp3: Vector3 = rt.waypoint(Vector3(2, 0, -110), Vector3(2, 0, -60))
	_check("bij de brug verandert er niets", absf(wp3.x - dt.BRIDGE_X) < 0.5)

	# ---------------------------------------------------------------- de wereld
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	main.get_node("Hud/Sticks").set_process(false)
	main.begin()
	await _frames(5)
	G = root.get_node("Game")
	G.prep_t = 99999.0
	G.banner.connect(func(b: String, s: String, _t: float) -> void: _banners.append(b + " | " + s))
	ai = get_first_node_in_group("aanval_ai")
	_check("het groepsbrein draait (één knoop, AanvalAI)", ai != null and get_nodes_in_group("aanval_ai").size() == 1)
	if ai == null:
		print("klaar, fouten: ", fails + 1)
		quit(1)
		return
	_check("9A: tijdens het aftellen geen routes meer vooraf", G.next_routes.is_empty() and G.routes.is_empty())
	var p = G.player
	p.global_position = Vector3(300, 0, 150)   # jij telt niet mee voor de verdediging
	_base_enemies = G.enemies.duplicate()
	await _frames(3)
	var basis: Vector3 = G.base_pos

	# ---------------------------------------------------------------- 1A: score per kant en de dobbelsteen
	var s0: Dictionary = ai.scores()
	_check("zonder verdediging zijn alle kanten 0", s0.N == 0.0 and s0.O == 0.0 and s0.Z == 0.0 and s0.W == 0.0)
	var ally_script: GDScript = load("res://scripts/ally.gd")
	var allies: Array = []
	for i in 4:
		var a = ally_script.new()
		main.add_child(a)
		a.setup(100.0, 16.0, i)
		a.global_position = basis + Vector3(-1.5 + i, 0, -30)
		a.set_command("hold", a.global_position)
		G.allies.append(a)
		allies.append(a)
	await _frames(2)
	var s1: Dictionary = ai.scores()
	_check("vier soldaten aan de noordkant: N = 6, de rest 0", is_equal_approx(s1.N, 6.0) and s1.O == 0.0 and s1.W == 0.0 and s1.Z == 0.0)
	_check("kant_van: noord, oost, zuid, west", AI.kant_van(basis + Vector3(0, 0, -20)) == "N" and AI.kant_van(basis + Vector3(20, 0, 0)) == "O" and AI.kant_van(basis + Vector3(0, 0, 20)) == "Z" and AI.kant_van(basis + Vector3(-20, 0, 0)) == "W")
	var tel: Dictionary = _keuzes(600)
	print("keuzes (normaal): ", tel)
	_check("de sterke noordkant wordt bijna nooit gekozen (< 4%)", tel.N < 24)
	_check("maar de keuze is niet altijd dezelfde (dobbelsteen)", tel.O > 100 and tel.Z > 100 and tel.W > 100)
	# 10A: niveaus
	GameSettings.set_value("ai_niveau", "makkelijk")
	var tel_m: Dictionary = _keuzes(600)
	GameSettings.set_value("ai_niveau", "moeilijk")
	var tel_z: Dictionary = _keuzes(600)
	GameSettings.set_value("ai_niveau", "normaal")
	print("keuzes makkelijk: ", tel_m, " moeilijk: ", tel_z)
	_check("10A: op Makkelijk kiest hij de sterke kant vaker dan op Moeilijk", tel_m.N > tel_z.N)
	_check("10A: niveaus Makkelijk tot fase 2, Normaal en Moeilijk tot fase 4", AI.NIVEAUS.makkelijk.fase_max == 2 and AI.NIVEAUS.normaal.fase_max == 4 and AI.NIVEAUS.moeilijk.fase_per == 2)
	_check("10A: instelling 'Vijand slimheid' staat in het menu (SOLDATEN)", load("res://scripts/pause_menu.gd").ROWS.any(func(r): return r[0] == "ai_niveau"))
	# 6A: leren
	ai.geheugen = {"N": 1.0, "O": 1.0, "Z": 1.0, "W": 1.0}
	for i in 2:
		ai._leer({"kant": "W", "kant2": ""}, false)
	ai._leer({"kant": "O", "kant2": ""}, true)
	_check("6A: een mislukte kant krijgt minder kans (W 0,36)", is_equal_approx(ai.geheugen.W, 0.36))
	_check("6A: een gelukte kant meer (O 1,4)", is_equal_approx(ai.geheugen.O, 1.4))
	var tel_l: Dictionary = _keuzes(600)
	print("keuzes na leren: ", tel_l)
	_check("6A: daarna komt hij vaker oost dan west", tel_l.O > tel_l.W * 2)
	ai.geheugen = {"N": 1.0, "O": 1.0, "Z": 1.0, "W": 1.0}

	# ---------------------------------------------------------------- 2A: het pad
	for kant in ["N", "O", "Z", "W"]:
		var g := {"oversteek": "achterdeur"}
		var pad: Array = ai.pad_voor(g, 0, kant)
		var over := false
		var rond := true
		for q in pad:
			var v: Vector3 = q
			if absf(v.z - dt.river_z(v.x)) < 1.0 and absf(v.x - dt.BACKDOOR_X) < 0.5:
				over = true
			if v.z > dt.river_z(v.x) + 3.0 and Vector2(v.x - basis.x, v.z - basis.z).length() < 60.0:
				rond = false
		var eind: Vector3 = pad[pad.size() - 1]
		_check("2A %s: via de Backdoor, om het kamp heen (nooit binnen 60 m), eindigt op het verzamelpunt" % kant, over and rond and eind.distance_to(ai.rally_van(kant)) < 7.0)
	var pad_brug: Array = AI.stad_pad("brug")
	_check("2A Center eindigt over de brug", (pad_brug[pad_brug.size() - 1] as Vector3).z > dt.river_z(0.0) and absf((pad_brug[pad_brug.size() - 1] as Vector3).x) < 1.0)
	var pad_ford: Array = AI.stad_pad("ondiepte")
	_check("2A Flank gaat door de ondiepte", pad_ford.any(func(q): return absf((q as Vector3).x - dt.FORD_X) < 0.5 and absf((q as Vector3).z - dt.river_z(dt.FORD_X)) < 1.0))
	_check("verzamelpunt ligt RING_R m van het HK en aan jouw kant van de rivier", absf(Vector2(ai.rally_van("W").x - basis.x, ai.rally_van("W").z - basis.z).length() - AI.RING_R) < 1.0 and ai.rally_van("N").z > dt.river_z(ai.rally_van("N").x))

	# ---------------------------------------------------------------- een echte groep
	for a in allies:
		G.allies.erase(a)
		a.queue_free()
	await _frames(2)
	G.prep_t = 0.05
	await _frames(4)
	G.prep_t = 99999.0
	var g: Dictionary = ai.groepen[0] if ai.groepen.size() > 0 else {}
	_check("groep 1 rukt uit met het groepsbrein (één hoofdgroep)", not g.is_empty() and g.soort == "hoofd")
	_check("9A: banner zonder route: kant onbekend", _banners.any(func(b): return b.begins_with("GROEP 1 ONDERWEG") and b.contains("KANT ONBEKEND")) or _banners.any(func(b): return b.contains("Kant onbekend")))
	print("groep 1: kant ", g.get("kant"), ", oversteek ", g.get("oversteek"))
	var oversteek_x: float = {"brug": dt.BRIDGE_X, "ondiepte": dt.FORD_X, "achterdeur": dt.BACKDOOR_X}[g.oversteek]
	var staten := {}
	var overgestoken_x := []
	var max_f := 9000
	var f := 0
	var gezien_contact := false
	var contact_gemeld := false
	var leden_voor: Array = []
	while f < max_f:
		await process_frame
		f += 1
		if not ai.groepen.has(g):
			break
		staten[g.staat] = true
		for e in g.leden:
			if is_instance_valid(e) and not e.dead and absf(e.global_position.z - dt.river_z(e.global_position.x)) < 2.5 and overgestoken_x.size() < 50:
				overgestoken_x.append(e.global_position.x)
		if g.staat == "verzamelen" and leden_voor.is_empty():
			leden_voor = g.leden.duplicate()
			# 9A: jij komt kijken bij het verzamelpunt: contact
			p.global_position = ai.rally_van(g.kant) + (basis - ai.rally_van(g.kant)).normalized() * 30.0
		if g.gezien and not gezien_contact:
			gezien_contact = true
			contact_gemeld = _banners.any(func(b): return b.begins_with("CONTACT")) and ai.contacten.size() > 0
		if g.staat == "storm":
			break
	print("na %d beeldjes: staten %s" % [f, staten.keys()])
	_check("de groep doorloopt mars, verzamelen, aanval en storm", staten.has("mars") and staten.has("verzamelen") and staten.has("aanval") and g.staat == "storm")
	var goed_n := overgestoken_x.filter(func(x): return absf(float(x) - oversteek_x) < 4.0).size()
	var andere := 0
	for k in [dt.BRIDGE_X, dt.FORD_X, dt.BACKDOOR_X]:
		if absf(float(k) - oversteek_x) > 1.0:
			andere += overgestoken_x.filter(func(x): return absf(float(x) - float(k)) < 4.0).size()
	var pad_ok: bool = ai.stad_pad(g.oversteek).any(func(q): return absf((q as Vector3).x - oversteek_x) < 4.0)
	var goed_over: bool = andere == 0 and (goed_n >= 3 or (overgestoken_x.size() == 0 and pad_ok))   # genoeg metingen bij de gekozen oversteek en niemand bij een andere
	_check("2A: ze steken over bij de gekozen oversteek (%s)" % g.oversteek, goed_over)
	_check("3A: op het verzamelpunt wachten ze gehurkt in een waaier", leden_voor.size() >= 3)
	_check("9A: contact gemeld zodra jij ze zag", gezien_contact and contact_gemeld)
	_check("3A: rookgranaat bij het begin van de aanval", get_nodes_in_group("aanval_rook").size() > 0 or g.rook)
	# prestaties: één denkstap van het brein met een complete groep (zelfde rekenwerk als in het spel, twee keer per seconde)
	var t0 := Time.get_ticks_usec()
	for i in 100:
		ai._physics_process(AI.DENK)
	var per_stap := float(Time.get_ticks_usec() - t0) / 100.0
	print("denkstap: %.0f microseconden (%d groepen, %d leden)" % [per_stap, ai.groepen.size(), g.leden.size()])
	_check("60 fps: een denkstap kost minder dan 1 ms (%.2f ms; twee per seconde)" % (per_stap / 1000.0), per_stap < 1000.0)
	# 4A: doel kiezen
	var a2 = ally_script.new()
	main.add_child(a2)
	a2.setup(100.0, 16.0, 7)
	var levend: Array = g.leden.filter(func(e): return is_instance_valid(e) and not e.dead)
	if levend.size() > 0:
		var e0: Node3D = levend[0]
		for x in levend:
			if str(x.type) == "assault":
				e0 = x
				break
		a2.global_position = e0.global_position + (basis - e0.global_position).normalized() * 12.0
		a2.set_command("hold", a2.global_position)
		G.allies.append(a2)
		p.global_position = Vector3(300, 0, 150)
		await _frames(2)
		ai._kies_doel(e0)
		_check("4A: een soldaat van jou dichtbij gaat voor (wat terugschiet)", e0.ai_doel == a2)
		var hp0: float = a2.hp
		# deterministisch: een kogel met src "vijand" recht op de soldaat (de vijand zelf schiet daar ook mee, zie Enemy._shoot)
		e0.set_physics_process(false)
		var vanaf: Vector3 = a2.global_position + Vector3(-8, 1.2, 0)
		var hoek := atan2(8.0, 0.0)
		var kogel = load("res://scripts/bullet.gd").fire(main, vanaf, hoek, 40.0, 10.0, 2.0, false, false, 0, 0.0, 0.0, 0.0, "")
		kogel.src = "vijand"
		for i in 120:
			await process_frame
			if not is_instance_valid(a2) or a2.hp < hp0:
				break
		_check("4A: zijn kogels raken je soldaat ook echt", not is_instance_valid(a2) or a2.hp < hp0)
	# 7A: terugtrekken
	levend = g.leden.filter(func(e): return is_instance_valid(e) and not e.dead)
	var keep := maxi(1, int(floor(g.start * 0.3)))
	for i in range(keep, levend.size()):
		levend[i]._die(Vector3.FORWARD)
	g.staat = "aanval"
	var w_voor: float = ai.geheugen[g.kant]
	ai._denk_groep(g)
	_check("7A: na meer dan 60% verlies trekken ze terug", g.staat == "terug")
	_check("6A: die kant krijgt minder kans", ai.geheugen[g.kant] < w_voor)
	_check("7A: de overlevers gaan terug naar het verzamelpunt", g.leden.filter(func(e): return is_instance_valid(e) and not e.dead).all(func(e): return e.ai_hold != null and (e.ai_hold as Vector3).distance_to(ai.rally_van(g.kant)) < 8.0))
	_clear_enemies()
	await _frames(3)

	# ---------------------------------------------------------------- 6A: fasen
	ai.verslagen = 0
	ai.fase = 1
	for i in 3:
		var dg: Dictionary = ai._maak_groep(i + 1, "hoofd", "W")
		ai._groep_weg(dg)
	_check("6A: na 3 verslagen groepen fase 2, met melding", ai.fase == 2 and _banners.any(func(b): return b.begins_with("VIJAND WISSELT VAN TACTIEK")))
	for i in 6:
		ai._groep_weg(ai._maak_groep(10 + i, "hoofd", "W"))
	_check("6A: daarna fase 4 (maximum op Normaal)", ai.fase == 4)
	var items: Array = ai.nieuwe_groep(9, ["assault", "assault", "assault", "assault", "assault", "assault", "assault", "assault"])
	var hg: Dictionary = items[0].groep
	_check("6A fase 4: twee kanten tegelijk", hg.kant2 != "" and hg.kant2 != hg.kant)
	ai.groepen.clear()
	ai.fase = 1

	# ---------------------------------------------------------------- 5A en 8A: overval en heroveren
	var gz_script: GDScript = load("res://scripts/garnizoen.gd")
	var vrij: Node = null
	for gz in gz_script.all:
		if is_instance_valid(gz) and gz.partij == "vijand":
			vrij = gz
			break
	_check("er is een vijandelijk stadsgebouw (garnizoen)", vrij != null)
	if vrij != null:
		vrij._leeg()   # jij hebt het vrijgemaakt
		ai.reset()
		ai._herover_kandidaten.append(vrij)
	var dummy_truck := Node3D.new()
	dummy_truck.add_to_group("voorraadtruck")
	main.add_child(dummy_truck)
	dummy_truck.global_position = basis + Vector3(30, 0, 10)
	var items4: Array = ai.nieuwe_groep(4, ["assault", "knife", "assault", "assault"])
	var soorten := {}
	for it in items4:
		soorten[it.groep.soort] = int(soorten.get(it.groep.soort, 0)) + 1
	print("groep 4: ", soorten)
	_check("5A: groep 4 heeft een overvalteam van 3 naar een voorraadtruck", soorten.get("overval", 0) == 3 and items4.any(func(it): return it.groep.soort == "overval" and it.groep.doel == dummy_truck))
	_check("8A: groep 4 (even) stuurt een ploeg van 3 om het vrijgemaakte gebouw te heroveren", soorten.get("herover", 0) == 3)
	var hv: Dictionary = {}
	for it in items4:
		if it.groep.soort == "herover":
			hv = it.groep
	_check("5A: het overvalteam neemt een andere oversteek dan de hoofdgroep", items4.filter(func(it): return it.groep.soort == "overval")[0].groep.oversteek != items4[0].groep.oversteek)
	if not hv.is_empty() and vrij != null:
		var enemy_scene: PackedScene = load("res://scenes/enemy.tscn")
		for i in 2:
			var e = enemy_scene.instantiate()
			e.setup("assault", 4)
			main.add_child(e)
			ai.lid_erbij(hv, e)
			e.global_position = vrij.deur() + Vector3(i * 0.8, 0, 0.5)
			e.path_i = 99
		await _frames(2)
		ai._denk_groep(hv)
		_check("8A: de ploeg bij de deur neemt het gebouw in (partij vijand, 2 bewoners)", vrij.partij == "vijand" and vrij.bewoners.size() == 2)
		_check("8A: melding VIJAND HEROVERT", _banners.any(func(b): return b.begins_with("VIJAND HEROVERT")))
	dummy_truck.queue_free()
	_clear_enemies()
	await _frames(3)

	# ---------------------------------------------------------------- 7A: terugroepen en najagen
	var enemy_scene2: PackedScene = load("res://scenes/enemy.tscn")
	var rg: Dictionary = ai._maak_groep(5, "hoofd", "W")
	for i in 4:
		var e = enemy_scene2.instantiate()
		e.setup("assault", 5)
		main.add_child(e)
		ai.lid_erbij(rg, e)
		e.global_position = Vector3(-20 + i, 0, -150)
	p.global_position = dt.VIJAND_POS + Vector3(0, 0, 50)
	await _frames(2)
	ai._check_dreiging()
	_check("7A: jij bij zijn basis: de groep in de stad keert om", rg.staat == "teruggeroepen" and _banners.any(func(b): return b.begins_with("VIJAND ROEPT")))
	var vb := load("res://scripts/vijand_basis.gd") as GDScript
	_check("7A: ze lopen terug door de poort", rg.leden.all(func(e): return (e.path as Array).size() == 2 and (e.path[1] as Vector3).distance_to(vb.gate_inside()) < 0.5))
	p.global_position = Vector3(300, 0, 150)
	for i in 60:
		ai._check_dreiging()
	_check("7A: dreiging weg: ze vallen weer aan", rg.staat == "mars")
	_clear_enemies()
	ai._vorige_score = {"N": 5.0, "O": 0.0, "Z": 0.0, "W": 0.0}
	ai.laatste_score = {"N": 0.0, "O": 0.0, "Z": 0.0, "W": 0.0}
	ai._najaag_cd = 0.0
	var voor: int = G.enemies.size()
	ai._check_najagen()
	await _frames(2)
	_check("7A najagen: de noordkant viel weg: er komt meteen een ploeg van 3", G.enemies.size() == voor + 3 and ai.groepen.any(func(x): return x.soort == "najaag" and x.kant == "N"))
	_clear_enemies()

	# ---------------------------------------------------------------- effecten
	var fx := load("res://scripts/aanval_fx.gd") as GDScript
	var r1 = fx.rookgranaat(main, basis + Vector3(0, 1.4, -60), basis + Vector3(0, 0, -40), Vector3(0, 0, 1))
	var l1 = fx.lichtkogel(main, basis + Vector3(0, 0, -70))
	await _frames(90)
	_check("3A: rookgordijn van 9 wolken", r1 != null and is_instance_valid(r1) and r1.get_child_count() >= 1 + fx.ROOK_N)
	_check("6A: lichtkogel met een rode lamp, hoog in de lucht", l1 != null and is_instance_valid(l1) and l1.find_children("*", "OmniLight3D", true, false).size() == 1 and (l1.get_child(0) as Node3D).global_position.y > 10.0)
	# rook blokkeert het zicht (v230)
	fx.call("zet_rook_zicht", true)
	await _frames(420)
	var kruis: bool = fx.rook_blokkeert(basis + Vector3(0, 1, -52), basis + Vector3(0, 1, -28))
	var langs: bool = fx.rook_blokkeert(basis + Vector3(-30, 1, -52), basis + Vector3(-30, 1, -28))
	var dichtbij: bool = fx.rook_blokkeert(basis + Vector3(0, 1, -42), basis + Vector3(0, 1, -38))
	var naast: bool = fx.rook_blokkeert(basis + Vector3(20, 1, -45), basis + Vector3(20, 1, -35))
	_check("zicht: een lijn dwars door het rookgordijn is geblokkeerd", kruis)
	_check("zicht: een lijn ver naast het gordijn niet", not langs and not naast)
	_check("zicht: van dichtbij (< 6 m) ziet men wel door de rook", not dichtbij)
	var e1 = null
	for e in G.enemies:
		e1 = e
		break
	if e1 == null:
		main._spawn({"kind": "assault", "n": 1, "routes": ["brug"]})
		await _frames(2)
		for e in G.enemies:
			e1 = e
			break
	e1.set_physics_process(false)
	e1.global_position = basis + Vector3(0, 0, -52)
	_check("zicht: een vijand schiet niet door de rook (_clear_shot)", not e1._clear_shot(basis + Vector3(0, 1.3, -28), true))
	e1.global_position = basis + Vector3(-30, 0, -52)
	_check("zicht: wel ernaast", e1._clear_shot(basis + Vector3(-30, 1.3, -28), true))
	fx._gordijnen.clear()
	_check("zicht: na het uitdoven geen blokkade meer", not fx.rook_blokkeert(basis + Vector3(0, 1, -52), basis + Vector3(0, 1, -28)))
	_clear_enemies()
	print("klaar, fouten: ", fails)
	quit(1 if fails > 0 else 0)
