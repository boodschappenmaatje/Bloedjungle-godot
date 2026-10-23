extends SceneTree
## Controleert de gedeelde uitrustingsvoorraad en bestaande verdedigingsplaatsing.
## Draaien: godot --headless --path . -s tests/hud_equipment_test.gd --fixed-fps 60

var failures: Array[String] = []


func _initialize() -> void:
	OS.set_environment("BJ_TOUCH", "1")
	root.size = Vector2i(932, 430)
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error("UITRUSTING TEST: " + message)


func _frames(n: int) -> void:
	for _i in n:
		await process_frame


func _count_kind(defs: Node, kind: String) -> int:
	var n := 0
	for item in defs.items:
		if item.kind == kind:
			n += 1
	return n


func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var game = root.get_node("Game")
	await _frames(3)
	main.get_node("Hud/Sticks").set_process(false)
	await main.call("begin")
	await _frames(3)
	var player = game.player
	player.global_position = Vector3(10, 0, 40)
	player.face = 0.0
	game.inv = {"bags": 1, "trench": 0, "mine": 1, "wire": 0, "sentry": 0}
	game.place_sel = "bags"
	game.place_armed = false
	game.equipment_sel = "grenade"
	game.changed.emit()
	await _frames(2)
	var hud: Node = main.get_node("Hud")
	var selector := hud.find_child("EquipmentSelector", true, false) as Control
	var next := hud.find_child("EquipmentNext", true, false) as Button
	var c4 := hud.find_child("Equipment_c4", true, false) as Button
	_check(selector != null and selector.visible, "uitrustingsbalk staat niet in beeld")
	_check(next != null and c4 != null and c4.disabled, "C4 moet als niet-beschikbaar staan")
	var use_btn: Button
	for b in get_nodes_in_group("hud_button"):
		if b is Button and b.get_script() != null and b.get_script().resource_path == "res://scripts/action_btn.gd" and b.get("kind") == "granaat":
			use_btn = b
	_check(use_btn != null and use_btn.get("caption") == "GEBRUIK", "de bestaande granaatknop is niet de GEBRUIK-knop")
	if use_btn == null or next == null:
		quit(1)
		return
	# Pijltjes houden de voorraadselectie bij; C4 heeft geen implementatie of voorraad.
	next.button_down.emit()
	_check(game.equipment_sel == "mine", "pijl selecteert de mijn niet")
	await _frames(2)
	var items_before: int = _count_kind(game.defs, "mine")
	use_btn.button_down.emit()
	await _frames(2)
	_check(game.inv.mine == 0, "mijnvoorraad wordt niet precies eenmaal verbruikt")
	_check(_count_kind(game.defs, "mine") == items_before + 1, "GEBRUIK plaatst geen bestaande landmijn")
	_check(game.inv.bags == 1 and game.place_sel == "bags", "mijngebruik wijzigt of verbruikt de gekozen verdediging")
	# De bestaande verdedigingsbalk blijft dezelfde plaatsingsroute gebruiken.
	game.defs.place()
	_check(game.inv.bags == 0 and _count_kind(game.defs, "bags") == 1, "bestaande zandzakplaatsing werkt niet")
	# Dezelfde knop gebruikt nog steeds de bestaande granaatlogica.
	game.equipment_sel = "grenade"
	game.grenades = 3
	game.changed.emit()
	await _frames(2)
	use_btn.button_down.emit()
	_check(game.grenades == 2, "GEBRUIK vermindert de bestaande granaatvoorraad niet")
	var flying := 0
	for child in main.get_children():
		if child.get_script() != null and child.get_script().resource_path == "res://scripts/grenade.gd":
			flying += 1
	_check(flying == 1, "GEBRUIK start geen bestaande granaat")

	main.queue_free()
	await process_frame
	if failures.is_empty():
		print("UITRUSTING TEST PASS: selectie, granaat, mijnvoorraad en bestaande verdediging")
		quit(0)
	else:
		quit(1)
