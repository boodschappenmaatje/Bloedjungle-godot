extends SceneTree
## Test van de bediening van het voertuigbevel (stap "voertuigbevel", Dennis' keuze 2A van 11 november 2026): jeep en tank in de bevelstand en op de grote kaart, met de knop VOERTUIGEN,
## tikken op een voertuig, dubbeltik, een bevel aan beide en de bevellijnen. Aanrakingen gaan via root.push_input(): dezelfde weg als een echte vinger.
## godot --headless --path . -s tests/voertuig_bevel_ui_test.gd --fixed-fps 60
## Klassenamen gebruiken we niet statisch (de autoload Game bestaat nog niet als dit bestand compileert).

var main: Node
var frames := 0
var fails := 0
var g: Node
var jeep: Node
var tank: Node
var bj: Node
var bt: Node


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


func _tap(pos: Vector2, index := 5) -> void:
	_touch(index, pos, true)
	_touch(index, pos, false)


func _ts() -> Node:
	return get_first_node_in_group("troep_selectie")


func _hud() -> Node:
	return get_first_node_in_group("hud_extra")


func _stand() -> Node:
	return get_first_node_in_group("bevel_stand")


func _process(_d: float) -> bool:
	frames += 1
	g = root.get_node("Game")
	if frames == 2:
		root.size = Vector2i(932, 430)
	if frames == 4:
		main.begin()
	if frames == 8:
		g.prep_t = 99999.0
		jeep = load("res://scenes/jeep.tscn").instantiate()
		main.add_child(jeep)
		tank = load("res://scenes/tank.tscn").instantiate()
		main.add_child(tank)
	if frames == 14:
		_place()
		bj = jeep.get_node("Bestuurder")
		bt = tank.get_node("Bestuurder")
	if frames == 30:
		_place()
		_test_kaart()
	if frames == 36:
		_place()
		_test_stand_open()
	if frames == 60:
		_place()
		_test_stand_wereld()
	if frames == 66:
		return _klaar()
	return false


## De voertuigen staan vlak voor je (noord), ver genoeg uit elkaar voor een eigen schermplek, en niet onder de bevelbalk.
func _place() -> void:
	var p: Vector3 = g.player.global_position
	jeep.global_position = p + Vector3(-9.0, 0.0, -9.0)
	jeep.rotation.y = 0.0
	tank.global_position = p + Vector3(9.0, 0.0, -11.0)
	tank.rotation.y = 0.0


func _test_kaart() -> void:
	var ts = _ts()
	var hud = _hud()
	ts.clear()
	_check("jeep en tank hebben een bestuurder", bj != null and bt != null)
	_check("de kaart opent", hud.open_map(false))
	var map = hud._map
	map._layout()
	var rects: Array = [map._btn_all, map._btn_none, map._btn_veh, map._groups[0], map._groups[1], map._groups[2], map._close]
	var overlap := false
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			if (rects[i] as Rect2).intersects(rects[j]):
				overlap = true
	_check("liggend: de knop VOERTUIGEN heeft een eigen plek (geen overlap met de andere knoppen)", map._btn_veh.size.x > 100.0 and not overlap)
	_check("de knoppen liggen in het paneel", map._panel.encloses(map._btn_veh))
	_tap(map._btn_veh.get_center())
	_check("VOERTUIGEN kiest jeep en tank", ts.sel.size() == 2 and ts.is_selected(bj) and ts.is_selected(bt))
	_tap(map._btn_none.get_center())
	_check("GEEN wist de keuze", ts.sel.is_empty())
	# tik op een voertuig op de kaart
	var pj: Vector2 = map.to_screen(jeep.global_position)
	map._zoom_to(5.0, pj, map.map_rect())
	pj = map.to_screen(jeep.global_position)
	_tap(pj)
	_check("tik op de jeep kiest alleen de jeep", ts.sel.size() == 1 and ts.is_selected(bj))
	var pt: Vector2 = map.to_screen(tank.global_position)
	_tap(pt)
	_check("tik op de tank kiest alleen de tank", ts.sel.size() == 1 and ts.is_selected(bt))
	# een bevel vanaf de kaart
	map._zoom_to(1.0, map._map.get_center(), map.map_rect())
	ts.select([bj, bt])
	var m: Rect2 = map.map_rect()
	var spot := Vector2(m.position.x + m.size.x * 0.25, m.position.y + m.size.y * 0.8)
	_tap(spot)
	var w: Vector3 = map.to_world(spot)
	_check("een tik op de grond stuurt jeep en tank erheen", bj.command == "move" and bt.command == "move" and Vector2(bj.command_target.x - w.x, bj.command_target.z - w.z).length() < 1.0)
	# een vast voertuig krijgt een geel teken: de kaart tekent zonder fout
	bj.vast = true
	hud._map.queue_redraw()
	hud._map._view.queue_redraw()
	_check("de kaart is nog open met een vast voertuig", hud.map_is_open())
	bj.vast = false
	_tap(map._btn_none.get_center())
	hud._map.close_map()
	ts.clear()


func _test_stand_open() -> void:
	var st = _stand()
	var ts = _ts()
	st._layout()
	_tap(st._btn.get_center())
	_check("tik op BEVEL opent de bevelstand", st.active)
	var r: Rect2 = st._row["veh"]
	var clash := false
	for key in ["all", "none", "g0", "g1", "g2", "done"]:
		if r.intersects(st._row[key]):
			clash = true
	_check("de knop VOERTUIGEN heeft een eigen plek in de rij (geen overlap)", r.size.x > 60.0 and not clash)
	ts.clear()


func _test_stand_wereld() -> void:
	var st = _stand()
	var ts = _ts()
	var cam: Camera3D = root.get_viewport().get_camera_3d()
	var sj: Vector2 = cam.unproject_position(jeep.global_position + Vector3.UP * 0.9)
	var stk: Vector2 = cam.unproject_position(tank.global_position + Vector3.UP * 0.9)
	_check("de voertuigen staan boven de bevelbalk in beeld (%s, %s)" % [str(sj), str(stk)], st._row_at(sj) == "" and st._row_at(stk) == "" and sj.y < (st._row["all"] as Rect2).position.y and stk.y < (st._row["all"] as Rect2).position.y)
	_tap(sj)
	_check("tik op de jeep in de wereld kiest hem", ts.sel.size() == 1 and ts.is_selected(bj))
	_tap(stk)
	_check("tik op de tank in de wereld kiest hem", ts.sel.size() == 1 and ts.is_selected(bt))
	_tap((st._row["none"] as Rect2).get_center())
	_check("GEEN wist de keuze", ts.sel.is_empty())
	_tap((st._row["veh"] as Rect2).get_center())
	_check("VOERTUIGEN kiest jeep en tank", ts.sel.size() == 2)
	_check("de keuze heet twee voertuigen", ts.wie(ts.sel) == "2 voertuigen")
	var target: Vector3 = g.player.global_position + Vector3(0.0, 0.0, -20.0)
	var tp: Vector2 = cam.unproject_position(target)
	_tap(tp)
	_check("tik op de grond: beide rijden erheen (%.1f m)" % bj.command_target.distance_to(target), bj.command == "move" and bt.command == "move" and bj.command_target.distance_to(target) < 1.5)
	var gj: Dictionary = bj._goal()
	var gt: Dictionary = bt._goal()
	_check("ze krijgen elk een eigen plek bij het doel", (gj.pos as Vector3).distance_to(gt.pos) > 3.0)
	_check("een bevellijn loopt vanaf het voertuig (bevel move is zichtbaar)", ts.lines_fresh() and not ts.live_marks().is_empty())
	# HOUD in de bevelbalk
	_tap((st._bar[3] as Rect2).get_center())
	_check("HOUD in de bevelbalk: beide staan stil", bj.command == "hold" and bt.command == "hold")
	# groepsvakje 1 bewaart de twee voertuigen
	ts.save_group(0)
	ts.clear()
	_tap((st._row["g0"] as Rect2).get_center())
	_check("groepsvakje 1 kiest de twee voertuigen weer", ts.sel.size() == 2)
	_tap((st._row["done"] as Rect2).get_center())
	_check("KLAAR sluit de bevelstand", not st.active)
	ts.clear()


func _klaar() -> bool:
	_check("na de bevelstand weer op 100 %", is_equal_approx(Engine.time_scale, 1.0))
	print("Voertuigbevel-bediening klaar, fouten: %d" % fails)
	quit(1 if fails > 0 else 0)
	return true
