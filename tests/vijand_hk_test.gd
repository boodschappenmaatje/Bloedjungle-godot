extends SceneTree
## Stap 5a-2: aanvalsgroepen in plaats van golven, en het vijandelijke hoofdkwartier (scripts/vijand_hk.gd, assets/vijand_hk.glb).
## Controleert: model en botsblok, schade door kogels (ook over een muur heen, niet van vijanden), ontploffingen, rook en vuur bij 60% en 30%,
## instorten en winnen; en het schema van de groepen: 3 min rust, groep uit de poort van de vijandbasis, daarna elke 90 s een volgende,
## alleen stadsroutes, terug naar "prep" als de groep verslagen is.
## godot --headless --path . --script tests/vijand_hk_test.gd --fixed-fps 60

var main: Node
var frames := 0
var fails := 0
var D
var VB
var HK
var AR
var BU
var hk_node: Node3D
var hp0 := 0.0
var hp_mark := 0.0


func _initialize() -> void:
	# pas hier laden: deze scripts verwijzen naar de autoload Game, die bij het maken van dit script nog niet bestaat
	D = load("res://scripts/data.gd")
	VB = load("res://scripts/vijand_basis.gd")
	HK = load("res://scripts/vijand_hk.gd")
	AR = load("res://scripts/aanval_routes.gd")
	BU = load("res://scripts/bullet.gd")
	root.size = Vector2i(932, 430)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FOUT ") + name)
	if not ok:
		fails += 1


func _bullet(from_player: bool, over_wall: bool, dmg: float) -> void:
	var at: Vector3 = VB.hk_pos()
	# van het zuiden naar het noorden, vlak voor de voorkant van het hoofdkwartier, op borsthoogte
	BU.fire(main, Vector3(at.x, 1.2, at.z + 9.0), PI, 70.0, dmg, 1.0, from_player, over_wall)


func _process(_d: float) -> bool:
	frames += 1
	var g = root.get_node("Game")
	if frames == 2:
		main.get_node("Hud/Sticks").set_process(false)
	if frames == 4:
		main.begin()
		for m in get_nodes_in_group("menus"):
			m._show("")
	if frames == 40:
		_model_en_schema(g)
	# kogels: eerst eentje van jou, dan van een vijand, dan een die over de muren vliegt (Apache, jeep)
	if frames == 42:
		hp0 = hk_node.hp
		_bullet(true, false, 100.0)
	if frames == 60:
		_check("een kogel van jou doet schade (100 x 0,1 = 10): %.1f" % (hp0 - hk_node.hp), absf((hp0 - hk_node.hp) - 10.0) < 0.01)
		hp_mark = hk_node.hp
		_bullet(false, false, 100.0)
	if frames == 78:
		_check("een kogel van een vijand doet geen schade", is_equal_approx(hk_node.hp, hp_mark))
		_bullet(true, true, 100.0)
	if frames == 96:
		_check("een kogel die over muren vliegt (Apache, jeep) raakt het ook: %.1f" % (hp_mark - hk_node.hp), absf((hp_mark - hk_node.hp) - 10.0) < 0.01)
		_ontploffingen(g)
	if frames == 100:
		_groepen(g)
	if frames == 170:
		_na_start(g)
	if frames == 175:
		_volgende(g)
	if frames == 195:
		_klaar_en_winnen(g)
	if frames == 240:
		_na_winst(g)
		print("klaar, fouten: ", fails)
		quit(1 if fails > 0 else 0)
	return false


func _model_en_schema(g) -> void:
	hk_node = get_first_node_in_group("vijand_hk") as Node3D
	_check("er is een vijandelijk hoofdkwartier (VijandHk)", hk_node != null and hk_node.get_script() == HK)
	_check("VijandHk.inst wijst ernaar", HK.inst == hk_node)
	_check("levenspunten vol: %.0f" % hk_node.hp, is_equal_approx(hk_node.hp, HK.HP))
	_check("het model is geladen (Romp, Romp_LOD1, Wrak)", hk_node.hi != null and hk_node.lod != null and hk_node.wreck != null)
	_check("het wrak staat verborgen, het gebouw zichtbaar", not hk_node.wreck.visible and hk_node.hi.visible)
	_check("botsblok op muur- en bunkerlaag", hk_node.body.collision_layer == (2 | 16))
	_check("gebouw staat op de plek van de vijandbasis", hk_node.global_position.is_equal_approx(VB.hk_pos()))
	_check("hp-balk is nog verborgen (speler ver weg, geen schade)", not hk_node._bar.visible)
	# driehoeken: romp minstens 40.000 (Dennis), LOD1 en wrak veel minder
	var tri := func(n: Node3D) -> int:
		var m := (n as MeshInstance3D).mesh
		return floori(m.get_faces().size() / 3.0)
	var t_romp: int = tri.call(hk_node.hi)
	var t_lod: int = tri.call(hk_node.lod)
	var t_wrak: int = tri.call(hk_node.wreck)
	_check("romp heeft minstens 40.000 driehoeken: %d" % t_romp, t_romp >= 40000 and t_romp <= 60000)
	_check("LOD1 (%d) en wrak (%d) zijn lichter" % [t_lod, t_wrak], t_lod < 8000 and t_wrak < 10000)
	var bb: AABB = (hk_node.hi as MeshInstance3D).get_aabb()
	_check("breedte even groot als het oude blok (9 m): %.2f x %.2f" % [bb.size.x, bb.size.z], absf(bb.size.x - 9.0) < 0.2 and absf(bb.size.z - 8.9) < 0.3)
	_check("onderkant op de grond, hoogte 7,3 m: %.2f .. %.2f" % [bb.position.y, bb.end.y], absf(bb.position.y) < 0.05 and absf(bb.end.y - 7.25) < 0.2)
	# schema van de groepen
	_check("begin: state prep en nog geen groep gestuurd", g.state == "prep" and g.wave == 0)
	_check("eerste rust is 10 minuten (%.0f s)" % g.prep_t, g.prep_t > 590.0 and g.prep_t <= D.MCV_RUST)
	_check("constanten: 600 s rust (vanaf het uitklappen), 90 s tussen groepen", D.MCV_RUST == 600.0 and D.GROEP_TUSSEN == 90.0)
	_check("de komende routes staan al klaar", not g.next_routes.is_empty())
	var alle_stad := true
	for n in range(1, 25):
		for id in AR.pick_group(n):
			alle_stad = alle_stad and id in AR.CITY
	_check("groepen gebruiken alleen stadsroutes (groep 1 tot 24)", alle_stad)
	_check("groep 1 is een route, groep 8 heeft er drie", AR.pick_group(1).size() == 1 and AR.pick_group(8).size() == 3)
	_check("build_group is kleiner dan build_wave en groeit (n=1: %d, n=10: %d)" % [D.build_group(1).size(), D.build_group(10).size()],
			D.build_group(1).size() <= D.build_wave(1).size() and D.build_group(10).size() > D.build_group(1).size())
	var klok: String = AR.klok(161.2)
	_check("klok toont 02:42 voor 161,2 s: " + klok, klok == "02:42")
	_check("spawnpunt ligt binnen de vijandbasis, bij de poort", VB.contains(VB.spawn_point()) and VB.spawn_point().z > VB.hk_pos().z + 20.0)
	var pad: Array = AR.path_from_base("brug")
	_check("tocht begint buiten de poort en loopt de stadsroute", pad.size() == AR.LIST["brug"].pts.size() + 1 and (pad[0] as Vector3).z > D.VIJAND_POS.z + D.VIJAND_HALF.y)


func _ontploffingen(g) -> void:
	hp_mark = hk_node.hp
	# een granaat vlak naast de muur: volle schade min afstand; ver weg: niets
	var at: Vector3 = VB.hk_pos()
	HK.blast(at + Vector3(0, 0, 5.0), 4.8, 100.0)   # 1,85 m van de rand van het botsblok: (1 - 1,85/4,8) x 100 = ca. 61
	var d1: float = hp_mark - hk_node.hp
	_check("ontploffing vlak bij doet veel schade: %.1f" % d1, d1 > 55.0 and d1 < 70.0)
	hp_mark = hk_node.hp
	HK.blast(at + Vector3(0, 0, 30.0), 4.8, 100.0)
	_check("ontploffing ver weg doet niets", is_equal_approx(hk_node.hp, hp_mark))
	# rook bij 60% en vuur bij 30%, met een melding
	var meldingen: Array = []
	g.banner.connect(func(b: String, _s: String, _t: float) -> void: meldingen.append(b))
	hk_node.hp = HK.HP * 0.61
	hk_node.damage(HK.HP * 0.02, "explosive")
	_check("onder 60%: rook en melding 'beschadigd'", hk_node._fx != null and "VIJANDELIJK HK BESCHADIGD" in meldingen)
	var rook = hk_node._fx
	hk_node.damage(HK.HP * 0.35, "explosive")
	_check("onder 30%: vuur (nieuw effect) en melding 'in brand'", hk_node._fx != null and hk_node._fx != rook and "HET HK STAAT IN BRAND" in meldingen)
	_check("hp-balk blijft in beeld na schade", hk_node._bar_t > 0.0)
	_check("hp-balk is smal (hoogstens 5 m) en zweeft net boven het dak (4,6 tot 7 m)", HK.BAR_BREED <= 5.0 and HK.BAR_Y > 4.6 and HK.BAR_Y <= 7.0 and hk_node._bar.position.y == HK.BAR_Y)
	_check("nog niet gewonnen", not g.won and g.state == "prep")
	hk_node.hp = HK.HP * 0.25
	hk_node._set_bar()


func _groepen(g) -> void:
	var tel: float = g.prep_t
	main.start_wave()
	_check("start nu: state play, groep 1", g.state == "play" and g.wave == 1)
	_check("aftellen naar de tweede groep is 90 s: %.0f" % g.prep_t, g.prep_t > 89.0 and g.prep_t <= D.GROEP_TUSSEN)
	_check("de wachtrij heeft de hele groep (%d)" % main.queue.size(), main.queue.size() == D.build_group(1).size())
	_check("pijlen wijzen naar de route van groep 1 (hoofdstraat)", g.routes == ["brug"])
	_check("de volgende groep is al bepaald", g.next_routes == AR.pick_group(2))
	_check("het vorige aftellen was langer dan 90 s (rust)", tel > 90.0)


func _na_start(g) -> void:
	_check("er zijn vijanden uitgerukt: %d" % g.enemies.size(), g.enemies.size() > 0)
	var uit_poort := true
	var eerste_pad := true
	for e in g.enemies:
		uit_poort = uit_poort and (e as Node3D).global_position.distance_to(D.VIJAND_POS) < 45.0
		eerste_pad = eerste_pad and not e.path.is_empty() and (e.path[0] as Vector3).z > D.VIJAND_POS.z + D.VIJAND_HALF.y
	_check("de vijanden staan in of bij de vijandbasis", uit_poort)
	_check("hun route begint bij de poort van de vijandbasis", eerste_pad)
	var in_basis := false
	for e in g.enemies:
		in_basis = in_basis or VB.contains((e as Node3D).global_position, 0.0)
	_check("minstens één staat binnen de muur van de vijandbasis", in_basis)


func _volgende(g) -> void:
	# het aftellen loopt in "play" door: als het op is komt de volgende groep, ook al loopt de vorige nog
	g.prep_t = 0.02
	for i in 4:
		await process_frame
	_check("tijd op: groep 2 is uitgerukt terwijl groep 1 nog loopt (groep %d, state %s)" % [g.wave, g.state], g.wave == 2 and g.state == "play")
	_check("aftellen staat weer op 90 s", g.prep_t > 85.0)


func _klaar_en_winnen(g) -> void:
	# alle vijanden weg en de wachtrij leeg: terug naar prep (wapenkamer en stadseditor), aftellen loopt door
	main.queue.clear()
	for e in g.enemies.duplicate():
		if is_instance_valid(e):
			e.queue_free()
	g.enemies.clear()
	g.rang = 2
	main._wave_cleared()
	_check("groep verslagen: weer prep", g.state == "prep")
	_check("je rang blijft staan na een afgeslagen groep", g.rang == 2)
	_check("aftellen loopt door (%.0f s)" % g.prep_t, g.prep_t > 0.0 and g.prep_t < D.GROEP_TUSSEN + 0.1)
	# slopen = winnen
	var meldingen: Array = []
	g.banner.connect(func(b: String, _s: String, _t: float) -> void: meldingen.append(b))
	var reden: Array = []
	g.over.connect(func(r: String) -> void: reden.append(r))
	hk_node.hp = 5.0
	hk_node.damage(50.0, "explosive")
	_check("hp op 0, hoofdkwartier is 'down'", hk_node.down and hk_node.hp == 0.0)
	_check("gewonnen: Game.won en state over", g.won and g.state == "over")
	_check("het einde heeft een reden met het aantal groepen: " + str(reden), reden.size() == 1 and "gesloopt" in String(reden[0]) and str(g.wave) in String(reden[0]))
	_check("melding 'gesloopt'", "VIJANDELIJK HOOFDKWARTIER GESLOOPT" in meldingen)
	_check("wrak zichtbaar, gebouw weg", hk_node.wreck.visible and not hk_node.hi.visible and not hk_node.lod.visible)
	_check("botsblok is nu een lage puinhoop", absf((hk_node._cs.shape as BoxShape3D).size.y - HK.PUIN_HOOGTE) < 0.01)


func _na_winst(g) -> void:
	hp0 = hk_node.hp
	hk_node.damage(100.0, "explosive")
	_check("na het slopen doet schade niets meer", hk_node.hp == hp0 and hk_node.down)
	_check("de hp-balk is weg", not hk_node._bar.visible)
	_check("nog steeds gewonnen (geen dubbele eindes)", g.won and g.state == "over")
