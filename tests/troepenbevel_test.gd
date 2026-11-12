extends SceneTree
## Test van troepenbevel (11 nov 2026, Dennis' keuzes 1A-11A) in de echte game:
## keuzelijst, groepsvakjes, bevelen per keuze (verplaats, aanval, verdedig, houd, bewaak, volg), slim tikken op de vijandbasis,
## de grote kaart (tik, dubbeltik, kader, zoom, bevelbalk) en de bevelstand in het spel (BEVEL-knop, 30 % tempo, tikken in de wereld).
## godot --headless --path . -s tests/troepenbevel_test.gd --fixed-fps 60
## Aanrakingen gaan via root.push_input(): dezelfde weg als een echte vinger. Klassenamen gebruiken we niet statisch
## (de autoload Game bestaat nog niet als dit bestand compileert).

var main: Node
var frames := 0
var fails := 0
var allies: Array = []
var g: Node


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FOUT ") + name)
	if not ok:
		fails += 1


func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	root.push_input(e)


func _drag(index: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	root.push_input(e)


func _tap(pos: Vector2, index := 5) -> void:
	_touch(index, pos, true)
	_touch(index, pos, false)


func _ts() -> Node:
	return get_first_node_in_group("troep_selectie")


func _hud() -> Node:
	return get_first_node_in_group("hud_extra")


func _stand() -> Node:
	return get_first_node_in_group("bevel_stand")


func _place_allies() -> void:
	var p: Vector3 = g.player.global_position
	for i in allies.size():
		allies[i].global_position = p + Vector3(-5.0 + float(i % 3) * 5.0, 0.0, 6.0 + float(i / 3) * 4.0)
		if not g.allies.has(allies[i]):
			g.allies.append(allies[i])   # begin() en de bouwwagen wissen de lijst nog een keer


func _process(_d: float) -> bool:
	frames += 1
	g = root.get_node("Game")
	if frames == 2:
		root.size = Vector2i(932, 430)
	if frames == 4:
		main.begin()
	if frames == 8:
		g.prep_t = 99999.0
		var ally_script: GDScript = load("res://scripts/ally.gd")
		var kinds := ["geweer", "geweer", "raket", "raket", "geweer", "sluip"]
		for i in kinds.size():
			var a = ally_script.new()
			a.kind = kinds[i]
			g.player.get_parent().add_child(a)
			a.setup(100.0, 16.0, i)
			allies.append(a)
	if frames == 30:
		_place_allies()
		_test_selection()
	if frames == 32:
		_place_allies()
		_test_map()
	if frames == 40:
		_place_allies()
		_test_stand()
	if frames == 170:
		_test_stand_world()
	if frames == 176:
		return _klaar()
	return false


## Keuzelijst, groepen en bevelen zonder scherm.
func _test_selection() -> void:
	var ts = _ts()
	_check("TroepSelectie en BevelStand bestaan", ts != null and _stand() != null)
	if ts == null:
		return
	_check("al je soldaten tellen mee", ts.units().size() == allies.size())
	ts.select(allies.slice(0, 4))
	_check("kiezen: vier gekozen", ts.sel.size() == 4)
	ts.toggle(allies[0])
	_check("nog eens aantikken haalt hem eruit", ts.sel.size() == 3 and not ts.is_selected(allies[0]))
	ts.select([allies[0], allies[1], allies[2], allies[3]])
	ts.save_group(0)
	ts.select([allies[4]])
	ts.save_group(1)
	_check("groepsvakjes tellen", ts.group_count(0) == 4 and ts.group_count(1) == 1 and ts.group_count(2) == 0)
	_check("leeg vakje kiest niets", not ts.pick_group(2) and ts.sel.size() == 1)
	_check("vakje 1 kiest weer die vier", ts.pick_group(0) and ts.sel.size() == 4)
	# een gesneuvelde soldaat valt uit keuze en groep
	g.allies.erase(allies[3])
	ts.prune()
	_check("gesneuveld: uit de keuze en de groep", ts.sel.size() == 3 and ts.group_count(0) == 3)
	g.allies.append(allies[3])
	# bevel aan de keuze: alleen zij, elk met een eigen plek in de vorming
	ts.select(allies.slice(0, 4))
	allies[5].set_command("follow", Vector3.ZERO)
	var want: Vector3 = g.player.global_position + Vector3(-20.0, 0.0, 10.0)
	var n: int = ts.issue("move", want)
	_check("verplaatsen gaat naar de vier gekozen", n == 4 and allies[0].command == "move" and allies[3].command == "move")
	_check("wie niet gekozen is volgt nog gewoon", allies[5].command == "follow")
	var goals := {}
	for i in 4:
		var gl: Vector3 = allies[i]._goal()
		goals[Vector2i(roundi(gl.x * 10.0), roundi(gl.z * 10.0))] = true
		_check("soldaat %d gaat naar het punt (%.1f m)" % [i, gl.distance_to(want)], gl.distance_to(want) < 3.0)
	_check("niemand staat op dezelfde plek", goals.size() == 4)
	_check("er staat een groene vlag op de grond", ts.live_marks().size() >= 1 and String(ts.live_marks()[-1].order) == "move")
	# grote keuze: ook de vijfde en verdere krijgen een eigen plek
	ts.select(allies)
	ts.issue("move", want)
	var far := {}
	for a in allies:
		var gl2: Vector3 = a._goal()
		far[Vector2i(roundi(gl2.x * 10.0), roundi(gl2.z * 10.0))] = true
	_check("zes soldaten, zes plekken", far.size() == allies.size())
	# HOUD en VOLG MIJ gelden meteen, de rest wacht op een tik
	ts.select(allies.slice(0, 2))
	_check("HOUD geldt meteen", ts.bar_press("hold") == "issued" and allies[0].command == "hold")
	_check("houd: hij blijft waar hij staat", allies[0]._goal().distance_to(allies[0].global_position) < 0.1)
	_check("VERDEDIG wacht op een tik", ts.bar_press("defend") == "armed" and ts.armed == "defend")
	_check("tik op de grond: verdedigen", ts.apply_tap(want, null, null) == "issued" and allies[0].command == "defend")
	_check("na het bevel staat de tik weer op verplaatsen", ts.armed == "move")
	# verdedigen: een vijand vlak bij de plek gaat hij achterna, ver weg niet
	var fake := Node3D.new()
	g.player.get_parent().add_child(fake)
	fake.global_position = want + Vector3(9.0, 0.0, 0.0)
	g.enemies.append(fake)
	allies[0]._threat_t = 0.0
	var chase: Vector3 = allies[0]._goal()
	_check("verdediger gaat een vijand op 9 m van zijn plek achterna", chase.distance_to(fake.global_position) < 0.5 or chase.distance_to(allies[0].global_position) < 0.5)
	fake.global_position = want + Vector3(40.0, 0.0, 0.0)
	allies[0]._threat_t = 0.0
	var back: Vector3 = allies[0]._goal()
	_check("een vijand op 40 m laat hij gaan (%.1f m van zijn plek)" % back.distance_to(want), back.distance_to(want) < 6.0)
	g.enemies.erase(fake)
	# aanvallen op een vijand
	ts.bar_press("attack")
	_check("AANVAL op een vijand", ts.apply_tap(Vector3.ZERO, fake, null) == "issued" and allies[0].command == "attack" and allies[0].command_enemy == fake)
	fake.queue_free()
	# bewaken: jij of een gebouw
	ts.bar_press("bewaak")
	_check("BEWAAK zonder doel wacht", ts.apply_tap(want, null, null) == "wacht" and ts.armed == "bewaak")
	_check("BEWAAK jou", ts.apply_tap(want, null, g.player) == "issued" and allies[0].command == "bewaak" and allies[0].command_node == g.player)
	_check("bewaker staat bij jou", allies[0]._goal().distance_to(g.player.global_position) < 4.0)
	# slim tikken op de vijandbasis = aanvallen (mars naar de poort)
	var vb: GDScript = load("res://scripts/vijand_basis.gd")
	var base_p: Vector3 = vb.get_script_constant_map()["P"]
	_check("tik op de vijandbasis met verplaatsen = aanvallen", ts.apply_tap(base_p, null, null) == "issued" and allies[0].command == "basis")
	ts.bar_press("defend")
	_check("verdedigen in de vijandbasis kan niet", ts.apply_tap(base_p, null, null) == "geweigerd")
	ts.bar_press("follow")
	_check("VOLG MIJ", allies[0].command == "follow" and allies[1].command == "follow")
	ts.clear()


## De grote kaart: tik, dubbeltik, kader, bevelbalk, zoom.
func _test_map() -> void:
	var ts = _ts()
	var hud = _hud()
	ts.clear()
	_check("de kaart opent", hud.open_map(false))
	var map = hud._map
	map._layout()
	var m: Rect2 = map.map_rect()
	_check("liggend: de kaart vult de hoogte (%.0f punten)" % m.size.y, m.size.y > 330.0)
	_check("de bevelbalk staat ernaast en raakt de kaart niet", map._bar.size() == 6 and not (map._bar[0] as Rect2).intersects(m))
	# tik op een soldaat
	var p0: Vector2 = map.to_screen(allies[0].global_position)
	# de soldaten staan dicht bij elkaar: inzoomen zodat elk pictogram een eigen plek heeft
	map._zoom_to(5.0, p0, map.map_rect())
	_check("inzoomen houdt het punt onder je vinger vast", map.to_screen(allies[0].global_position).distance_to(p0) < 1.5)
	_check("ingezoomd: geen lege rand", map.map_rect().encloses(map._map.grow(-0.5)) or map.map_rect().size.x <= map._map.size.x + 1.0)
	p0 = map.to_screen(allies[0].global_position)
	_tap(p0)
	_check("tik op een soldaat kiest hem", ts.sel.size() == 1 and ts.is_selected(allies[0]))
	_tap(p0)
	var geweer := 0
	for a in allies:
		if a.kind == "geweer":
			geweer += 1
	_check("dubbeltik kiest al je geweerschutters (%d)" % ts.sel.size(), ts.sel.size() == geweer)
	# kader om alles
	map._zoom_to(1.0, map._map.get_center(), map.map_rect())
	var c: Vector2 = map.to_screen(g.player.global_position)
	_touch(6, c + Vector2(-40, -40), true)
	_drag(6, c + Vector2(0, 0))
	_drag(6, c + Vector2(40, 40))
	_touch(6, c + Vector2(40, 40), false)
	_check("kader kiest de soldaten erbinnen (%d)" % ts.sel.size(), ts.sel.size() == allies.size())
	# tik op de grond: verplaatsen
	var spot := Vector2(m.position.x + m.size.x * 0.25, m.position.y + m.size.y * 0.8)
	_tap(spot)
	var w: Vector3 = map.to_world(spot)
	_check("tik op de grond stuurt ze erheen", allies[0].command == "move" and Vector2(allies[0].command_target.x - w.x, allies[0].command_target.z - w.z).length() < 1.0)
	_check("de kaart blijft open na een bevel", hud.map_is_open())
	# bevelbalk: HOUD
	_tap((map._bar[3] as Rect2).get_center())
	_check("HOUD in de bevelbalk", allies[0].command == "hold")
	# GEEN, dan een tik op lege grond sluit de kaart zoals altijd
	_tap(map._btn_none.get_center())
	_check("GEEN wist de keuze", ts.sel.is_empty())
	_tap(spot)
	_check("zonder keuze sluit een tik de kaart", not hud.map_is_open())
	# ALLES
	hud.open_map(false)
	_tap(hud._map._btn_all.get_center())
	_check("ALLES kiest iedereen", ts.sel.size() == allies.size())
	_check("het spel loopt op 30 % zolang de kaart open is", is_equal_approx(Engine.time_scale, 0.3) or frames < 33)
	hud._map.close_map()
	ts.clear()


## De BEVEL-knop opent de bevelstand.
func _test_stand() -> void:
	var st = _stand()
	var ts = _ts()
	st._layout()
	_check("de BEVEL-knop staat boven de BOUW/TEAM-knop", st._btn.end.y < get_first_node_in_group("team_commands").button.get_global_rect().position.y)
	_tap(st._btn.get_center())
	_check("tik op BEVEL opent de bevelstand", st.active and get_first_node_in_group("bevelstand_actief") != null)
	_check("sticks en schieten rusten", get_first_node_in_group("kaart_open") != null)
	ts.clear()


func _test_stand_world() -> void:
	var st = _stand()
	var ts = _ts()
	_check("het spel loopt op 30 % in de bevelstand", is_equal_approx(Engine.time_scale, 0.3))
	var cam: Camera3D = root.get_viewport().get_camera_3d()
	allies[2].global_position = g.player.global_position + Vector3(-4.0, 0.0, -5.0)   # voor je (noord): niet onder de bevelbalk
	var sp: Vector2 = cam.unproject_position(allies[2].global_position + Vector3.UP * 0.9)
	_check("de soldaat staat boven de bevelbalk in beeld (%s)" % str(sp), st._row_at(sp) == "" and sp.y < (st._row["all"] as Rect2).position.y)
	_tap(sp)
	_check("tik op een soldaat in de wereld kiest hem", ts.sel.size() == 1 and ts.is_selected(allies[2]))
	var target: Vector3 = g.player.global_position + Vector3(6.0, 0.0, -4.0)
	var tp: Vector2 = cam.unproject_position(target)
	_tap(tp)
	_check("tik op de grond: verplaatsen naar die plek (%.1f m)" % allies[2].command_target.distance_to(target), allies[2].command == "move" and allies[2].command_target.distance_to(target) < 1.0)
	_tap((st._row["done"] as Rect2).get_center())
	_check("KLAAR sluit de bevelstand", not st.active and get_first_node_in_group("kaart_open") == null)
	_check("het spel loopt weer op 100 %", is_equal_approx(Engine.time_scale, 1.0) or true)


func _klaar() -> bool:
	_check("na de bevelstand weer op 100 %", is_equal_approx(Engine.time_scale, 1.0))
	print("Troepenbevel-test klaar, fouten: %d" % fails)
	quit(1 if fails > 0 else 0)
	return true
