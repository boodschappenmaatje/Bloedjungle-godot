extends SceneTree
## Op het hoofdkwartier tikken opent het upgradepaneel (hq_menu.gd): niveau 2 voor 1.500, niveau 3 voor 2.500; ernaast tikken sluit het.
## godot --headless --path . --script tests/hq_menu_test.gd --fixed-fps 60

var main: Node
var frames := 0
var fails := 0


func _initialize() -> void:
	root.size = Vector2i(932, 430)   # iPhone-scherm
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FOUT ") + name)
	if not ok:
		fails += 1


## De knop met "Upgrade" in het paneel (null = geen).
func _upgrade_knop(menu) -> Button:
	for b in menu._box.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with("Upgrade") and not b.is_queued_for_deletion():
			return b
	return null


func _process(_d: float) -> bool:
	frames += 1
	if frames < 40:
		root.size = Vector2i(932, 430)   # iPhone-scherm (in headless valt het venster anders terug op 64x64)
	var g = root.get_node("Game")
	if frames == 2:
		main.get_node("Hud/Sticks").set_process(false)
	if frames == 4:
		main.begin()
		for m in get_nodes_in_group("menus"):
			m._show("")   # het hoofdmenu (halfdoorzichtige laag) sluit zoals na "Start"
	if frames == 40:
		var menus := main.find_children("*", "HqMenu", true, false)
		_check("tikmenu van het hoofdkwartier bestaat", menus.size() == 1)
		var menu = menus[0]
		var hq := get_first_node_in_group("hq") as Node3D
		_check("hoofdkwartier staat in de groep hq", hq != null)
		var cam := root.get_camera_3d()
		_check("er is een camera", cam != null)
		var op_hq: Vector2 = cam.unproject_position(hq.global_position + Vector3(0, menu.HIT_HEIGHT, 0))
		var ernaast: Vector2 = cam.unproject_position(hq.global_position + Vector3(9, 0, 9))
		print("staat van het spel: ", g.state, " | tik op HK: ", op_hq, " | ernaast: ", ernaast)
		_check("tik ernaast opent niets", not menu.hit_hq(ernaast))
		menu._tap(ernaast)
		_check("paneel dicht na tik ernaast", not menu._panel.visible)
		_check("tik op het hoofdkwartier raakt het", menu.hit_hq(op_hq))
		g.points = 2000
		var base0: float = g.base_max
		menu._tap(op_hq)
		_check("paneel open na tik op het hoofdkwartier", menu._panel.visible)
		var knop := _upgrade_knop(menu)
		_check("knop 'Upgrade naar niveau 2 · 1.500' actief", knop != null and knop.text.contains("niveau 2") and knop.text.contains("1.500") and not knop.disabled)
		knop.pressed.emit()
		_check("niveau 2", g.hq_level == 2)
		_check("1.500 punten betaald", g.points == 500)
		_check("sterkte +400 en vol", is_equal_approx(g.base_max, base0 + 400.0) and is_equal_approx(g.base_hp, g.base_max))
		var knop2 := _upgrade_knop(menu)
		_check("niveau 3 kost 2.500, nog niet te koop met 500 punten", knop2 != null and knop2.text.contains("niveau 3") and knop2.text.contains("2.500") and knop2.disabled)
		g.points = 2500
		g.changed.emit()
		var knop3 := _upgrade_knop(menu)
		_check("met 2.500 punten actief", knop3 != null and not knop3.disabled)
		knop3.pressed.emit()
		_check("niveau 3", g.hq_level == 3)
		_check("sterkte nog +500", is_equal_approx(g.base_max, base0 + 900.0))
		_check("op niveau 3 geen upgradeknop meer", _upgrade_knop(menu) == null and menu._panel.visible)
		menu._tap(ernaast)
		_check("paneel sluit weer", not menu._panel.visible)
		# zonder genoeg punten: Game.upgrade_hq doet niets
		g.hq_level = 1
		g.points = 100
		_check("te weinig punten: geen upgrade", not g.upgrade_hq() and g.hq_level == 1 and g.points == 100)
	if frames == 44:
		print("klaar, fouten: ", fails)
		quit(1 if fails > 0 else 0)
	return false
