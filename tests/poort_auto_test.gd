extends SceneTree
## Poort: opent vanzelf voor jou en je soldaten, vergrendelen via toggle, en de voertuigmodus van de HUD.
## godot --headless --path . -s tests/poort_auto_test.gd --fixed-fps 60

var main: Node
var frames := 0
var fails := 0
var _dummy: Node3D


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		printerr("FOUT: ", msg)
	else:
		print("OK: ", msg)


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _hud_child(script_name: String) -> Control:
	for c in main.get_node("Hud").get_children():
		if c.get_script() != null and c.get_script().resource_path.ends_with(script_name):
			return c
	return null


func _process(_d: float) -> bool:
	frames += 1
	var g = root.get_node("Game")
	if frames == 1:
		root.size = Vector2i(932, 430)
		root.content_scale_factor = 1.0
	if frames == 2:
		main.get_node("Hud/Sticks").set_process(false)
	if frames == 4:
		main.begin()
		g.player.global_position = Vector3(0, 0, -40)  # ver van beide poorten
	if frames == 40:
		var gt = g.gates.list[0]
		_check(gt.open == 0.0, "poort dicht als niemand in de buurt is")
		g.player.global_position = Vector3(0, 0, -26.0)
		_check(g.gates.near_player() != null, "speler staat bij de poort")
	if frames == 40 + 200:
		var gt = g.gates.list[0]
		_check(gt.open > 0.95, "poort gaat vanzelf open voor de speler (open %.2f)" % gt.open)
		var marker: Control = _hud_child("gate_hud.gd")._btn
		var view := Rect2(Vector2.ZERO, Vector2(root.get_visible_rect().size))
		_check(marker.visible, "label boven de poort is zichtbaar als je erbij staat")
		_check(view.encloses(marker.get_global_rect()), "label boven de poort staat in beeld (%s)" % str(marker.get_global_rect()))
		_check(marker.get("caption") == "SLUIT", "label zegt SLUIT zolang de poort niet vergrendeld is")
		g.gates.toggle(gt)
		_check(gt.locked, "tikken op het label vergrendelt de poort")
	if frames == 40 + 200 * 2:
		var gt = g.gates.list[0]
		_check(gt.open < 0.05, "vergrendelde poort blijft dicht ook al staat de speler erbij (open %.2f)" % gt.open)
		_dummy = Node3D.new()
		root.add_child(_dummy)
		_dummy.global_position = g.gates.pos_of(gt) + Vector3(0, 0, -2.5)
		g.allies.append(_dummy)
	if frames == 40 + 200 * 3:
		var gt = g.gates.list[0]
		_check(gt.open > 0.95, "soldaat opent de poort zelf, ook als hij vergrendeld is (open %.2f)" % gt.open)
		g.allies.erase(_dummy)
		_dummy.queue_free()
		g.player.global_position = Vector3(0, 0, -40)
	if frames == 40 + 200 * 4:
		var gt = g.gates.list[0]
		_check(gt.open < 0.05, "poort sluit weer als niemand meer in de buurt is (open %.2f)" % gt.open)
		g.player.global_position = Vector3(0, 0, -26.0)
		g.gates.toggle(gt)
		_check(not gt.locked, "nogmaals tikken ontgrendelt de poort")
	if frames == 40 + 200 * 5:
		var gt = g.gates.list[0]
		_check(gt.open > 0.95, "ontgrendelde poort opent weer (open %.2f)" % gt.open)
		g.player.global_position = Vector3(0, 0, 0)
		# voertuigmodus: wapenbalk, voetsoldaatknoppen en uitrustingskiezer verdwijnen
		var strip := _hud_child("weapon_strip.gd")
		var combat := _hud_child("combat_buttons.gd")
		var equip := main.get_node("Hud").find_child("EquipmentSelector", true, false) as Control
		_check(strip != null and combat != null and equip != null, "HUD-onderdelen gevonden")
		_check(strip.visible and combat.visible and equip.visible, "te voet: wapenbalk, knoppen en uitrusting zichtbaar")
		g.player.driving = true
	if frames == 40 + 200 * 5 + 3:
		var strip := _hud_child("weapon_strip.gd")
		var combat := _hud_child("combat_buttons.gd")
		var equip := main.get_node("Hud").find_child("EquipmentSelector", true, false) as Control
		_check(not strip.visible, "in een voertuig: wapenbalk weg")
		_check(not combat.visible, "in een voertuig: granaat/herlaad/sprint/rol weg")
		_check(not equip.visible, "in een voertuig: uitrustingskiezer weg")
		g.player.driving = false
	if frames == 40 + 200 * 5 + 8:
		var strip := _hud_child("weapon_strip.gd")
		var combat := _hud_child("combat_buttons.gd")
		var equip := main.get_node("Hud").find_child("EquipmentSelector", true, false) as Control
		_check(strip.visible and combat.visible and equip.visible, "uitgestapt: alles komt terug")
		print("POORT_AUTO_TEST fouten=", fails)
		return true
	return false
