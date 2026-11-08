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
	D.set("mcv_mode", true)
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
		_check("een tik op een muurstuk maakt er een poort van", g.gates.list.size() == 1 and K.count() == 1)
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
		print("klaar, fouten: ", fails)
		quit(1 if fails > 0 else 0)
	return false
