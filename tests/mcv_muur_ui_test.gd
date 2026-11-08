extends SceneTree
## Test van MCV stap 3a, het bouwscherm: kaartje KAMPMUUR (GRATIS), muur trekken met een vinger (voorbeeld en bouwen), tikken op een muurstuk (paneel zonder
## Draai, wel Verkoop). godot --headless --path . --script tests/mcv_muur_ui_test.gd --fixed-fps 60

var D: GDScript
var M: GDScript
var K: GDScript
var main: Node
var frames := 0
var fails := 0
var mcv: Node
var bm: Node


func _initialize() -> void:
	root.size = Vector2i(932, 430)
	D = load("res://scripts/data.gd")
	M = load("res://scripts/mcv.gd")
	K = load("res://scripts/kampmuur.gd")
	D.set("mcv_autodeploy", false)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FOUT ") + name)
	if not ok:
		fails += 1


func _bm() -> Node:
	for c in main.get_node("Hud").get_children():
		if c.has_method("_enter") and c.has_method("_exit") and c.get("_ui") != null:
			return c
	return null


func _buttons(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is Button:
			out.append(c)
		_buttons(c, out)


func _screen(world: Vector3) -> Vector2:
	return main.get_node("Camera").unproject_position(world)


func _process(_d: float) -> bool:
	frames += 1
	var g = root.get_node("Game")
	if frames < 60:
		root.size = Vector2i(932, 430)
	if frames == 2:
		main.get_node("Hud/Sticks").set_process(false)
	if frames == 4:
		main.begin()
	if frames > 4 and g.state == "prep" and g.mcv_deployed:
		g.prep_t = 1e9
	if frames == 12:
		mcv = get_nodes_in_group("mcv")[0]
		mcv.global_position = Vector3(40.0, 0.0, 40.0)
		mcv.rotation.y = 0.0
	if frames == 16:
		mcv.deploy_now()
	if frames == 20:
		bm = _bm()
		_check("bouwscherm gevonden", bm != null)
		bm._enter()
		var card = null
		for c in bm._cards:
			if c.kind == "kampmuur":
				card = c
		_check("kaartje KAMPMUUR staat in het bouwmenu", card != null)
		var oud := false
		for c in bm._cards:
			if c.kind == "muur":
				oud = true
		_check("de oude betonmuur staat er in de MCV-modus niet meer", not oud)
		if card != null:
			bm._refresh()
			_check("het kaartje toont GRATIS", card.sub == "GRATIS")
			bm._wall_armed = true
	if frames == 120:
		# een muur trekken: drie stukken ten noorden van het hoofdkwartier (rooster (8,8) naar (11,8): x 28..38,5, z 28)
		_check("bouwmodus is aan", g.build_mode)
		var s0 := _screen(K.vertex(Vector2i(8, 8)))
		var s1 := _screen(K.vertex(Vector2i(11, 8)))
		print("schermpunten: ", s0, " -> ", s1)
		bm._down(7, s0)
		_check("slepen begint een muur (geen kaartverschuiving)", bm._drag.get("wall", false))
		bm._move(7, s0.lerp(s1, 0.5))
		bm._move(7, s1)
		_check("tijdens het slepen staat er een voorbeeld", bm._wall_ghost != null and bm._wall_ghost.get_child_count() >= 3 and int(bm._wall_plan.built) == 3)
		bm._up(7)
		_check("na loslaten staan er drie muurstukken", K.count() == 3)
		_check("het voorbeeld is weg", bm._wall_ghost == null)
	if frames == 130:
		# tikken op een muurstuk (kaartje uit): selecteert het
		bm._wall_armed = false
		var k = K.edge_key(Vector2i(9, 8), Vector2i(10, 8))
		var mid := _screen(K.edge_center(k))
		bm._down(8, mid)
		bm._up(8)
		_check("een tik selecteert het muurstuk", bm._sel != null and bm._sel.kind == "kampmuur")
		var btns: Array = []
		bm._fill_panel()
		_buttons(bm.get("_panel"), btns)
		var texts: Array = []
		for b in btns:
			texts.append(b.text.replace("\n", " "))
		print("knoppen: ", texts)
		var heeft_draai := false
		var heeft_verkoop := false
		for t in texts:
			if t.begins_with("Draai"):
				heeft_draai = true
			if t.begins_with("Verkoop"):
				heeft_verkoop = true
		_check("het paneel heeft Verkoop maar geen Draai", heeft_verkoop and not heeft_draai)
		# slepen op een muurstuk verplaatst het niet (kaart verschuift)
		var before := []
		for b in g.buildings:
			if b.kind == "kampmuur":
				before.append(b.at)
		var bcam0: Vector3 = g.bcam
		bm._down(9, mid)
		bm._move(9, mid + Vector2(60, 0))
		bm._up(9)
		var after := []
		for b in g.buildings:
			if b.kind == "kampmuur":
				after.append(b.at)
		_check("een muurstuk is niet te verslepen (de kaart schuift)", before == after and K.count() == 3 and g.bcam != bcam0)
	if frames == 136:
		# poort: kaartje POORT, tik op een muurstuk (rooster (9,8)-(10,8), kant van (10,8)); het buurstuk (10,8)-(11,8) gaat mee
		var card = null
		for c in bm._cards:
			if c.kind == "poort":
				card = c
		_check("kaartje POORT staat in het bouwmenu", card != null)
		bm._refresh()
		_check("het poort-kaartje kost 100 pt", card != null and card.sub.contains("100"))
		bm._wall_armed = false
		bm._gate_armed = true
		var k2 = K.edge_key(Vector2i(9, 8), Vector2i(10, 8))
		var tap := _screen(K.edge_center(k2) + Vector3(1.2, 0, 0))
		bm._down(10, tap)
		bm._up(10)
		_check("een tik op een muurstuk plaatst de poort nog niet, maar toont een voorbeeld", g.gates.list.is_empty() and bm._gate_pending != null and bm._wall_ghost != null)
		var ptxt: Array = []
		var pbtn: Array = []
		bm._fill_panel()
		_buttons(bm.get("_panel"), pbtn)
		for bt in pbtn:
			ptxt.append(bt.text.replace("\n", " "))
		print("poortpaneel: ", ptxt)
		var heeft_plaats := false
		var heeft_annuleer := false
		for t in ptxt:
			if t.begins_with("Plaats"):
				heeft_plaats = true
			if t.begins_with("Annuleer"):
				heeft_annuleer = true
		_check("het paneel vraagt om bevestiging (Plaats en Annuleer)", heeft_plaats and heeft_annuleer)
		# Annuleer: er komt niets
		for bt in pbtn:
			if bt.text.begins_with("Annuleer"):
				bt.pressed.emit()
		_check("Annuleer: geen poort en het voorbeeld is weg", g.gates.list.is_empty() and bm._gate_pending == null and bm._wall_ghost == null)
		# opnieuw tikken en bevestigen
		bm._down(10, tap)
		bm._up(10)
		var pbtn2: Array = []
		bm._fill_panel()
		_buttons(bm.get("_panel"), pbtn2)
		for bt in pbtn2:
			if bt.text.begins_with("Plaats"):
				bt.pressed.emit()
		_check("Plaats: de poort staat er en is gemaakt van twee muurstukken", g.gates.list.size() == 1 and K.count() == 1)
	if frames == 142:
		bm._gate_armed = false
		var gp: Vector3 = g.gates.list[0].at
		bm._down(11, _screen(gp))
		bm._up(11)
		_check("een tik op de poort selecteert hem", bm._gate_sel != null)
		bm._fill_panel()
		var btns: Array = []
		_buttons(bm.get("_panel"), btns)
		var verkoop := false
		for b in btns:
			if b.text.begins_with("Verkoop"):
				verkoop = true
		_check("het poortpaneel heeft Verkoop", verkoop)
		for b in btns:
			if b.text.begins_with("Verkoop"):
				b.pressed.emit()
		_check("verkopen haalt de poort weg", g.gates.list.is_empty())
	if frames == 150:
		# een rechte muur: je vinger dwaalt zijwaarts af (rij 11 -> +2,5 stuk omlaag), de muur blijft recht langs rij 11
		bm._wall_armed = true
		bm._wall_mode = "lijn"
		var n0: int = K.count()
		var row := 11
		for r in [11, 12, 13, 10, 9]:   # een vat of dergelijks kan een plek blokkeren: kies een rij die vrij is
			if int(K.plan(K.line_path(Vector2i(6, r), Vector2i(9, r))).built) == 3:
				row = r
				break
		var a0 := _screen(K.vertex(Vector2i(6, row)))
		var a1 := _screen(K.vertex(Vector2i(9, row))) + Vector2(0, 38)
		bm._down(12, a0)
		bm._move(12, a0.lerp(a1, 0.5))
		bm._move(12, a1)
		var rows := {}
		for e in bm._wall_plan.edges:
			rows[Vector2i(e.key.y, e.key.w)] = true
		_check("de muur blijft recht ondanks een afdwalende vinger (%s)" % str(rows.keys()), rows.size() == 1 and bm._wall_plan.edges.size() == 3)
		var states := []
		for e in bm._wall_plan.edges:
			states.append(e.state)
		print("rij 11 stukken: ", states, " ", bm._wall_plan.get("reason", ""))
		bm._up(12)
		_check("drie rechte muurstukken gebouwd (%d -> %d)" % [n0, K.count()], K.count() == n0 + 3)
		# aansluiten: een nieuwe lijn begint aan het eind van de vorige, ook als je er 1,5 m naast tikt
		var end: Vector3 = K.vertex(Vector2i(9, row))
		_check("een nieuwe muur sluit aan op het eind van een bestaande", K.snap_start(end + Vector3(1.4, 0, 1.0)) == Vector2i(9, row))
	if frames == 156:
		# vierkant: één sleep van hoek naar hoek = vier muren
		bm._wall_mode = "vierkant"
		var n1: int = K.count()
		var o := 3
		for cand in [3, 2, 1, 4]:   # idem: een vierkant waarvan alle 12 stukken kunnen
			if int(K.plan(K.rect_path(Vector2i(cand, cand), Vector2i(cand + 3, cand + 3))).built) == 12:
				o = cand
				break
		var c0 := _screen(K.vertex(Vector2i(o, o)))
		var c1 := _screen(K.vertex(Vector2i(o + 3, o + 3)))
		bm._down(13, c0)
		bm._move(13, c0.lerp(c1, 0.5))
		bm._move(13, c1)
		_check("voorbeeld van een vierkant: 12 stukken", int(bm._wall_plan.built) == 12)
		bm._up(13)
		_check("het vierkant staat er (12 stukken)", K.count() == n1 + 12)
		print("klaar, fouten: ", fails)
		quit(1 if fails > 0 else 0)
	return false
