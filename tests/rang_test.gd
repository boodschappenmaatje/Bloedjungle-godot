extends SceneTree
## Test van de generaalsrang met krachten (Generals-plan, stap E1; Dennis' keuzes 1A 2A 3A 4A 5A 6A 7A 8A van 11 november 2026, killstreaks eruit, Napalm als vierde kracht):
##  1. de score geeft sterren (600, 2.000, 4.500, 8.000, 13.000) en per ster een punt, ook als je er in één keer meerdere haalt
##  2. kills en een gesloopte M2-toren leveren score op (en dus rang), de balk toont de voortgang
##  3. het kiesscherm (KIES-knop): een punt geeft een nieuwe kracht of een niveau hoger, maximaal niveau 3, het scherm sluit als de punten op zijn
##  4. de KRACHTEN-knop toont de gekozen kracht met afkoelring; artillerie via het hoofdkwartier niveau 3 is niveau 1 (een punt erop is dan niveau 2)
##  5. afkoeling per kracht en per niveau, tikken in Game._process, geen tweede gebruik tijdens de afkoeling
##  6. Spionagesatelliet: alle vijanden op de radar zolang hij werkt, duur per niveau
##  7. Noodreparatie: jij, je soldaten, gebouwen en voertuigen binnen de straal worden geheeld, rook verdwijnt, wat ver weg staat niet
##  8. Napalm en Artillerie als kracht (granaten en brandtijd per niveau)
##  9. de rang blijft na sneuvelen en is weg bij een nieuw spel; killstreaks bestaan niet meer; de testschakelaar geeft alles op niveau 3
## godot --headless --path . --script tests/rang_test.gd --fixed-fps 60

var fails := 0
var main: Node
var G: Node
var Rg: GDScript
var _watchdog := 0
var _banners := 0


func _initialize() -> void:
	call_deferred("_run")


func _process(_d: float) -> bool:
	_watchdog += 1
	if _watchdog > 30000:
		push_error("Rangtest hangt")
		quit(99)
	return false


func _check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FOUT ") + name)
	if not ok:
		fails += 1


func _frames(n: int) -> void:
	for _i in n:
		await process_frame


func _enemy(at: Vector3, kind := "rifle") -> Node:
	var e: Node = load("res://scenes/enemy.tscn").instantiate()
	e.call("setup", kind, 1)
	main.add_child(e)
	e.global_position = at
	e.set_physics_process(false)
	return e


func _reset_rang() -> void:
	G.rang = 0
	G.rang_punten = 0
	G.krachten.clear()
	G.kracht_cd.clear()
	G.kracht_sel = ""
	G.satelliet_t = 0.0
	G.score = 0
	G.hq_level = 1


func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	G = root.get_node("Game")
	Rg = load("res://scripts/rang.gd")
	await _frames(3)
	main.get_node("Hud/Sticks").set_process(false)
	await main.call("begin")
	await _frames(3)
	G.state = "play"
	G.prep_t = 99999.0
	var hud: Node = main.get_node("Hud")
	var extra: Node = hud.get_node("HudExtra")
	var buttons: Node = hud.get_node("CombatButtons")
	var player = G.player
	player.global_position = Vector3(10, 0, 40)
	G.banner.connect(func(_a, _b, _c): _banners += 1)

	# ---- 0. killstreaks bestaan niet meer
	_check("geen streak.gd, streak_hud.gd en versterking.gd meer", not ResourceLoader.exists("res://scripts/streak.gd") and not ResourceLoader.exists("res://scripts/streak_hud.gd") and not ResourceLoader.exists("res://scripts/versterking.gd"))
	_check("Game kent geen killstreak meer", G.get("streak") == null and G.get("streak_bank") == null)

	# ---- 1. begin en rang uit de score
	_check("begin: rang 0, geen punten, geen krachten", G.rang == 0 and G.rang_punten == 0 and G.krachten.is_empty() and Rg.beschikbaar().is_empty())
	_check("zonder kracht: de KRACHTEN-knop is verborgen", not buttons._air.visible and not buttons._air2.visible)
	_check("de rangbalk staat in beeld (sterren)", extra.get("_rang") != null and extra._rang.visible)
	_check("grenzen: 599 = rang 0, 600 = 1, 2000 = 2, 4500 = 3, 8000 = 4, 13000 = 5, daarboven blijft 5",
		Rg.voor_score(599) == 0 and Rg.voor_score(600) == 1 and Rg.voor_score(2000) == 2 and Rg.voor_score(4500) == 3 and Rg.voor_score(8000) == 4 and Rg.voor_score(13000) == 5 and Rg.voor_score(99999) == 5)
	_check("namen: Soldaat, Sergeant, Luitenant, Kapitein, Majoor, Generaal", Rg.naam(0) == "SOLDAAT" and Rg.naam(1) == "SERGEANT" and Rg.naam(5) == "GENERAAL")
	G.score = 0
	var vg0: Dictionary = Rg.voortgang()
	_check("voortgang bij 0 score: 0 van 600", int(vg0.done) == 0 and int(vg0.span) == 600 and int(vg0.volgende) == 600)
	var b0 := _banners
	G.add_score(300)
	var vg1: Dictionary = Rg.voortgang()
	_check("voortgang bij 300 score: halverwege (%s)" % str(vg1), int(vg1.done) == 300 and G.rang == 0)
	G.add_score(300)
	_check("600 score: rang 1 en 1 punt", G.rang == 1 and G.rang_punten == 1)
	_check("een bevordering meldt zich met een banner", _banners > b0)
	var vg2: Dictionary = Rg.voortgang()
	_check("voortgang na ster 1: begint opnieuw naar 2.000 (%s)" % str(vg2), int(vg2.done) == 0 and int(vg2.span) == 1400 and int(vg2.volgende) == 2000)
	G.add_score(1500)
	_check("2.100 score: rang 2 en 2 punten", G.rang == 2 and G.rang_punten == 2)
	G.add_score(100000)
	_check("een grote sprong geeft alle sterren tegelijk: rang 5 en 5 punten", G.rang == 5 and G.rang_punten == 5)
	var vg3: Dictionary = Rg.voortgang()
	_check("op rang 5 is de balk vol", int(vg3.volgende) == -1 and int(vg3.done) == int(vg3.span))
	G.add_score(5000)
	_check("meer score geeft geen zesde ster", G.rang == 5 and G.rang_punten == 5)

	# ---- 2. kills en torens
	_reset_rang()
	G.score = 580
	var rifle := _enemy(Vector3(60, 0, 60))
	var s0: int = G.score
	rifle.hit(99999.0, Vector3.FORWARD, true)
	_check("een schutter doden geeft score (%d -> %d)" % [s0, G.score], G.score - s0 == 60)
	_check("en daarmee je eerste ster (580 + 60 = 640)", G.rang == 1 and G.rang_punten == 1)
	var torens := get_nodes_in_group("vijand_toren")
	if torens.is_empty():
		_check("er staat een M2-toren in de vijandbasis", false)
	else:
		var toren = torens[0]
		toren.shooter = null    # de schutter op de toren geeft zelf ook score: hier meten we alleen de toren
		var before: int = G.score
		toren.damage(99999.0, "bullet")
		_check("een toren slopen geeft score (%d -> %d)" % [before, G.score], G.score - before == 200)
		var after: int = G.score
		toren.damage(99999.0, "bullet")
		_check("een toren die al stuk is geeft niet nog eens", G.score == after)
	_check("de score telde door voor de rang (%d)" % G.score, G.score >= 840 and G.rang == 1)

	# ---- 3. kiesscherm en punten
	_reset_rang()
	G.add_score(13000)    # rang 5, 5 punten
	await _frames(3)
	_check("met punten: de KIES-knop staat er met het aantal", buttons._air2.visible and buttons._air2.badge == "+5")
	_check("nog geen kracht: de KRACHTEN-knop blijft verborgen", not buttons._air.visible)
	buttons._open_keuze()
	await _frames(2)
	var keuze: Node = buttons._keuze
	_check("het kiesscherm opent en houdt sticks en schieten stil", keuze != null and is_instance_valid(keuze) and keuze.is_in_group("kaart_open"))
	_check("vier kaarten: artillerie, napalm, satelliet, reparatie", keuze._cards.size() == 4 and Rg.VOLGORDE == ["artillerie", "napalm", "satelliet", "reparatie"])
	_check("kies napalm: niveau 1, een punt minder", keuze.kies("napalm") and int(G.krachten["napalm"]) == 1 and G.rang_punten == 4)
	_check("de eerste kracht wordt meteen de gekozen kracht", G.kracht_sel == "napalm" and Rg.huidig() == "napalm")
	_check("kies napalm nog eens: niveau 2, daarna 3", keuze.kies("napalm") and keuze.kies("napalm") and int(G.krachten["napalm"]) == 3 and G.rang_punten == 2)
	_check("niveau 3 is het maximum: geen punt verloren", not keuze.kies("napalm") and G.rang_punten == 2 and int(G.krachten["napalm"]) == 3)
	_check("kies satelliet: niveau 1 en de gekozen kracht blijft napalm", keuze.kies("satelliet") and int(G.krachten["satelliet"]) == 1 and G.kracht_sel == "napalm")
	_check("het scherm blijft open zolang er een punt over is", is_instance_valid(keuze) and G.rang_punten == 1)
	_check("een raak op een kaart zonder punt kan niet", Rg.punt_uitgeven("onzin") == false)
	_check("kies reparatie met het laatste punt", keuze.kies("reparatie") and G.rang_punten == 0)
	await _frames(3)
	_check("zonder punten sluit het kiesscherm vanzelf", buttons._keuze == null or not is_instance_valid(buttons._keuze) or buttons._keuze.is_queued_for_deletion())
	_check("de KIES-knop is weg en de KRACHTEN-knop staat er", not buttons._air2.visible and buttons._air.visible)
	_check("de knop toont de gekozen kracht", buttons._air.reward == "napalm")
	_check("beschikbaar in volgorde van het wiel: napalm, satelliet, reparatie", Rg.beschikbaar() == ["napalm", "satelliet", "reparatie"])
	_check("de tekst van een niveau noemt de waarden (%s)" % Rg.tekst("artillerie", 2), Rg.tekst("artillerie", 2) == "8 granaten, 75 s afkoeling" and Rg.tekst("satelliet", 3).contains("45 s"))

	# ---- 4. artillerie via het hoofdkwartier
	_reset_rang()
	G.hq_level = 3
	_check("HK niveau 3: artillerie is er op niveau 1 zonder punt", Rg.heeft("artillerie") and Rg.niveau("artillerie") == 1 and Rg.echt_niveau("artillerie") == 1)
	G.rang_punten = 1
	_check("een punt op artillerie is dan niveau 2 (niet verspild aan niveau 1)", Rg.punt_uitgeven("artillerie") and int(G.krachten["artillerie"]) == 2 and Rg.niveau("artillerie") == 2)
	G.hq_level = 1
	_check("zonder HK en met niveau 2 gekozen blijft artillerie bestaan", Rg.heeft("artillerie") and Rg.niveau("artillerie") == 2)
	_reset_rang()
	_check("zonder rang en zonder HK: geen artillerie", not Rg.heeft("artillerie"))

	# ---- 5. afkoeling
	_reset_rang()
	G.krachten = {"artillerie": 1, "satelliet": 2, "reparatie": 3}
	_check("afkoeling per niveau: artillerie 90 s (1), satelliet 100 s (2), reparatie 40 s (3)", is_equal_approx(Rg.afkoeling("artillerie"), 90.0) and is_equal_approx(Rg.afkoeling("satelliet"), 100.0) and is_equal_approx(Rg.afkoeling("reparatie"), 40.0))
	_check("een kracht die je niet hebt is nooit klaar", not Rg.klaar("napalm") and not Rg.gebruik("napalm", main, Vector3.ZERO, Vector3.FORWARD))
	_check("een kracht die je hebt is klaar", Rg.klaar("satelliet"))
	Rg.start_cd("satelliet")
	_check("na gebruik: afkoeling loopt, niet klaar", is_equal_approx(float(G.kracht_cd["satelliet"]), 100.0) and not Rg.klaar("satelliet"))
	G._process(10.0)
	_check("Game._process tikt de afkoeling af (90 s over)", is_equal_approx(float(G.kracht_cd["satelliet"]), 90.0))
	G.kracht_cd["satelliet"] = 0.5
	G._process(1.0)
	_check("op nul verdwijnt de afkoeling en is hij weer klaar", not G.kracht_cd.has("satelliet") and Rg.klaar("satelliet"))
	G.state = "over"
	G.kracht_cd["satelliet"] = 30.0
	G._process(10.0)
	_check("buiten het spel (game over) tikt de afkoeling niet", is_equal_approx(float(G.kracht_cd["satelliet"]), 30.0))
	G.state = "play"
	G.kracht_cd.clear()
	# de knop toont de ring
	G.kracht_sel = "satelliet"
	G.kracht_cd["reparatie"] = 20.0
	G.kracht_sel = "reparatie"
	await _frames(3)
	_check("de knop toont afkoelring en seconden (%s, %.2f)" % [buttons._air.badge, buttons._air.bar], buttons._air.visible and buttons._air.disabled and buttons._air.badge != "" and buttons._air.bar > 0.0 and buttons._air.bar < 1.0)
	G.kracht_cd.clear()
	await _frames(3)
	_check("klaar: de knop is weer aan zonder seconden", not buttons._air.disabled and buttons._air.badge == "" and buttons._air.bar < 0.0)

	# ---- 6. spionagesatelliet
	_reset_rang()
	G.krachten = {"satelliet": 1}
	G.kracht_sel = "satelliet"
	var ver := Vector3(300, 0, 300)
	_check("zonder satelliet ziet de radar ver weg niets", not extra._in_friendly_sight(ver))
	_check("de satelliet gebruiken lukt", Rg.gebruik("satelliet", main, Vector3.ZERO, Vector3.ZERO))
	_check("niveau 1: 20 s, 120 s afkoeling", is_equal_approx(G.satelliet_t, 20.0) and is_equal_approx(float(G.kracht_cd["satelliet"]), 120.0))
	_check("nu staat alles op de radar", extra._in_friendly_sight(ver))
	_check("niet nog eens tijdens de afkoeling", not Rg.gebruik("satelliet", main, Vector3.ZERO, Vector3.ZERO))
	G._process(15.0)
	_check("de seconden lopen af (5 over)", is_equal_approx(G.satelliet_t, 5.0) and extra._in_friendly_sight(ver))
	G._process(6.0)
	_check("na afloop: weer geen zicht ver weg", is_equal_approx(G.satelliet_t, 0.0) and not extra._in_friendly_sight(ver))
	G.krachten = {"satelliet": 3}
	G.kracht_cd.clear()
	Rg.gebruik("satelliet", main, Vector3.ZERO, Vector3.ZERO)
	_check("niveau 3: 45 s en 80 s afkoeling", is_equal_approx(G.satelliet_t, 45.0) and is_equal_approx(float(G.kracht_cd["satelliet"]), 80.0))
	G.satelliet_t = 0.0

	# ---- 7. noodreparatie
	_reset_rang()
	G.krachten = {"reparatie": 1}
	G.kracht_sel = "reparatie"
	player.global_position = Vector3(10, 0, 40)
	var max_hp: float = G.max_hp()
	player.hp = max_hp * 0.2
	var ally = load("res://scripts/ally.gd").new()
	ally.kind = "geweer"
	main.add_child(ally)
	ally.setup(100.0, 10.0, 0)
	ally.global_position = Vector3(14, 0, 40)
	G.allies.append(ally)
	ally.hp = 20.0
	var ally_ver = load("res://scripts/ally.gd").new()
	ally_ver.kind = "geweer"
	main.add_child(ally_ver)
	ally_ver.setup(100.0, 10.0, 1)
	ally_ver.global_position = Vector3(10, 0, 40) + Vector3(80, 0, 0)
	G.allies.append(ally_ver)
	ally_ver.hp = 20.0
	var jeep: Node = (load("res://scenes/jeep.tscn") as PackedScene).instantiate()
	main.add_child(jeep)
	jeep.global_position = Vector3(10, 0, 40) + Vector3(0, 0, 8)
	var jeep_ver: Node = (load("res://scenes/jeep.tscn") as PackedScene).instantiate()
	main.add_child(jeep_ver)
	jeep_ver.global_position = Vector3(10, 0, 40) + Vector3(-70, 0, 0)
	await _frames(3)
	jeep._schade.take(150.0, Vector3.FORWARD)     # 220 -> 70: onder de helft, dus rook
	jeep_ver._schade.take(150.0, Vector3.FORWARD)
	_check("de jeep rookt", jeep._schade._smoke != null and jeep._schade.hp < 110.0)
	var plaats: Variant = G.builds.place("zandzak", Vector3(10, 0, 40) + Vector3(5, 0, -5), 0.0, false, true)
	var b: Dictionary = plaats if plaats is Dictionary else {}
	if b.is_empty():
		_check("een zandzak geplaatst voor de test", false)
	else:
		G.builds.damage(b, float(b.max_hp) * 0.7)    # 30% over: gebarsten
		_check("de zandzak is gebarsten", b.cracked and float(b.hp) < float(b.max_hp) * 0.5)
		var hp_b: float = b.hp
		var geheeld: int = load("res://scripts/noodreparatie.gd").heel(Vector3(10, 0, 40), 20.0, 0.4)
		_check("niveau 1: 40%% in 20 m: jij, de dichte soldaat, de jeep en de zandzak (%d)" % geheeld, geheeld == 4)
		_check("jij krijgt 40% van je maximum erbij", is_equal_approx(player.hp, max_hp * 0.6))
		_check("de soldaat dichtbij krijgt 40% erbij", is_equal_approx(ally.hp, 20.0 + 0.4 * ally.hp_max))
		_check("de soldaat ver weg blijft zoals hij is", is_equal_approx(ally_ver.hp, 20.0))
		_check("de jeep dichtbij is geheeld (%.0f) en rookt niet meer" % jeep._schade.hp, is_equal_approx(jeep._schade.hp, 70.0 + 0.4 * 220.0) and jeep._schade._smoke == null)
		_check("de jeep ver weg is niet geheeld en rookt nog", is_equal_approx(jeep_ver._schade.hp, 70.0) and jeep_ver._schade._smoke != null)
		_check("de zandzak heeft 40%% van zijn maximum teruggekregen (%.0f -> %.0f)" % [hp_b, float(b.hp)], is_equal_approx(float(b.hp), minf(float(b.max_hp), hp_b + 0.4 * float(b.max_hp))))
		_check("boven de helft is de zandzak niet meer gebarsten", not b.cracked)
		load("res://scripts/noodreparatie.gd").heel(Vector3(10, 0, 40), 20.0, 1.0)    # alles in bereik helemaal heel
		var al_heel: int = load("res://scripts/noodreparatie.gd").heel(Vector3(10, 0, 40), 20.0, 0.4)
		_check("wat al heel is telt niet mee (nog %d te heelen)" % al_heel, al_heel == 0)
	var banner0 := _banners
	_check("de kracht gebruiken lukt, met afkoeling 60 s", Rg.gebruik("reparatie", main, Vector3.ZERO, Vector3.ZERO) and is_equal_approx(float(G.kracht_cd["reparatie"]), 60.0))
	var ring: Node = null
	for n in main.get_children():
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("noodreparatie.gd"):
			ring = n
	_check("er verschijnt een groene ring en een banner", _banners > banner0 and ring != null)
	await _frames(90)
	# niveau 3: alles heel
	G.krachten = {"reparatie": 3}
	G.kracht_cd.clear()
	player.hp = 5.0
	jeep._schade.take(200.0, Vector3.FORWARD)
	Rg.gebruik("reparatie", main, player.global_position, Vector3.ZERO)
	_check("niveau 3: jij en de jeep zijn weer volledig heel", is_equal_approx(player.hp, max_hp) and is_equal_approx(jeep._schade.hp, 220.0) and jeep._schade._fire == null and jeep._schade._smoke == null)
	# een wrak blijft een wrak
	jeep._schade.take(99999.0, Vector3.FORWARD)
	_check("de jeep is nu een wrak", jeep._schade.dead)
	load("res://scripts/noodreparatie.gd").heel(player.global_position, 40.0, 1.0)
	_check("een wrak wordt niet geheeld", jeep._schade.dead and jeep._schade.hp <= 0.0)
	ally.queue_free()
	ally_ver.queue_free()
	G.allies.erase(ally)
	G.allies.erase(ally_ver)
	jeep_ver.queue_free()

	# ---- 8. napalm en artillerie
	_reset_rang()
	G.krachten = {"napalm": 2, "artillerie": 3}
	G.kracht_sel = "napalm"
	_check("napalm gebruiken lukt, 100 s afkoeling op niveau 2", Rg.gebruik("napalm", main, Vector3(0, 0, 60), Vector3(0, 0, -1)) and is_equal_approx(float(G.kracht_cd["napalm"]), 100.0))
	var vlam: Node = null
	for n in main.get_children():
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("napalm_aanval.gd"):
			vlam = n
	_check("er is een napalmaanval met 14 s vuur (niveau 2)", vlam != null and is_equal_approx(vlam.burn_time, 14.0))
	if vlam != null:
		vlam.queue_free()
	_check("artillerie niveau 3: 12 granaten, 60 s afkoeling", Rg.gebruik("artillerie", main, Vector3(0, 0, 80), Vector3.ZERO) and is_equal_approx(float(G.kracht_cd["artillerie"]), 60.0))
	var strike: Node = null
	for n in main.get_children():
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("artillerie.gd"):
			strike = n
	_check("de strike heeft 12 granaten", strike != null and strike.shells == 12 and strike.impacts.size() == 12)
	if strike != null:
		strike.queue_free()
	# het wiel toont de krachten met niveau
	G.kracht_cd.clear()
	buttons._wheel_kind = "support"
	buttons._hold_origin = Vector2(400, 200)
	buttons._wheel_ui.queue_redraw()
	await _frames(3)
	_check("het krachtenwiel tekent zonder fouten", buttons._wheel_kind == "support")
	buttons._wheel_kind = ""

	# ---- 9. rang blijft na sneuvelen, nieuw spel begint opnieuw, testschakelaar
	_reset_rang()
	G.krachten = {"reparatie": 2}
	G.score = 700
	G.rang = 1
	G.rang_punten = 1
	player.call("sneuvel")
	await _frames(3)
	_check("sneuvelen kost je niets aan rang, punten of krachten", G.rang == 1 and G.rang_punten == 1 and int(G.krachten["reparatie"]) == 2)
	await _frames(1)
	G.reset()
	_check("een nieuw spel begint zonder sterren, punten, krachten, afkoeling en satelliet", G.rang == 0 and G.rang_punten == 0 and G.krachten.is_empty() and G.kracht_cd.is_empty() and G.kracht_sel == "" and is_equal_approx(G.satelliet_t, 0.0) and G.score == 0)
	var gs: GDScript = load("res://scripts/game_settings.gd")
	gs.set_value("t_krachten", "on")
	_check("testschakelaar: alle krachten op niveau 3 zonder afkoeling", Rg.heeft("napalm") and Rg.niveau("satelliet") == 3 and Rg.beschikbaar().size() == 4)
	G.kracht_cd["satelliet"] = 99.0
	_check("testschakelaar: nooit afkoeling", Rg.klaar("satelliet") and is_equal_approx(Rg.cd_rest("satelliet"), 0.0))
	gs.set_value("t_krachten", "off")
	_check("schakelaar uit: weer niets", not Rg.heeft("napalm") and Rg.beschikbaar().is_empty())

	print("klaar, fouten: ", fails)
	quit(1 if fails > 0 else 0)
