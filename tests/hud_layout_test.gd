extends SceneTree
## Controleert dat de touch-knoppen elkaar niet overlappen en binnen beeld blijven op een liggende en
## staande iPhone en op een kleiner liggend scherm.
## Draaien: godot --headless --path . -s tests/hud_layout_test.gd --fixed-fps 60

var failures: Array[String] = []
const SIZES := [Vector2i(932, 430), Vector2i(844, 390), Vector2i(430, 932)]


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("HUD TEST: " + message)


func _visible_buttons(node: Node, out: Array) -> void:
	for c in node.get_children():
		if c is Control and c.is_in_group("hud_button") and not c is ColorRect and (c as Control).is_visible_in_tree() and (c as Control).size.x > 1.0 and (c as Control).size.x < 400.0:
			out.append(c)
		_visible_buttons(c, out)


func _label(c: Control) -> String:
	var t: String = c.get("kind") if c.get("kind") != null else ""
	if t == "":
		t = c.text if c is Button and c.text != "" else c.name
	return "%s@%s" % [t, c.get_global_rect()]


func _run() -> void:
	OS.set_environment("BJ_TOUCH", "1")
	root.size = SIZES[0]
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var game = root.get_node("Game")
	for _i in 3:
		await process_frame
	await main.call("begin")
	for _i in 3:
		await process_frame
	game.inv = {"bags": 2, "trench": 1, "mine": 2, "wire": 1, "sentry": 1}
	game.place_sel = "bags"
	game.place_armed = true
	game.emit_signal("changed")
	var equipment_toggle := main.get_node("Hud").find_child("ExpandEquipment", true, false) as Button
	if equipment_toggle != null:
		equipment_toggle.pressed.emit()
	await process_frame
	var action_btn: Script = load("res://scripts/action_btn.gd")
	var sticks: Control = main.get_node("Hud/Sticks")
	_check(sticks.get("_last_touch_hud_visible"), "vaste mobiele joysticks worden na de start niet getekend")
	for s in SIZES:
		root.size = s
		root.content_scale_factor = 1.0
		for _i in 6:
			await process_frame
		var view := Vector2(root.get_visible_rect().size)
		var buttons: Array = []
		_visible_buttons(main.get_node("Hud"), buttons)
		var equipment := main.get_node("Hud").find_child("EquipmentSelector", true, false) as Control
		_check(equipment != null and equipment.visible, "%s: uitrustingsselector ontbreekt" % s)
		for item in ["grenade", "mine", "c4"]:
			_check(main.get_node("Hud").find_child("Equipment_" + item, true, false) != null, "%s: uitrustingsvak %s ontbreekt" % [s, item])
		var use_button: Button = null
		for b in buttons:
			if b is Button and b.get_script() != null and b.get_script().resource_path == "res://scripts/action_btn.gd" and b.get("kind") == "granaat":
				use_button = b
		_check(use_button != null and use_button.get("caption") == "GEBRUIK", "%s: GEBRUIK-knop ontbreekt" % s)
		_check(buttons.size() >= 10, "%s: te weinig zichtbare knoppen (%d)" % [s, buttons.size()])
		var names := {}
		for b in buttons:
			names[str(b.get("kind"))] = true
		for k in ["herlaad", "sprint", "granaat", "rol"]:
			_check(names.has(k), "%s: knop %s ontbreekt" % [s, k])
		for i in buttons.size():
			var a: Rect2 = (buttons[i] as Control).get_global_rect()
			_check(Rect2(Vector2.ZERO, view).encloses(a), "%s: knop buiten beeld: %s" % [s, _label(buttons[i])])
			for j in range(i + 1, buttons.size()):
				var b: Rect2 = (buttons[j] as Control).get_global_rect()
				if a.intersects(b):
					_check(false, "%s: overlap %s en %s" % [s, _label(buttons[i]), _label(buttons[j])])
		# de contextknoppen staan onder de wapenbalk in landschap en portret.
		for slot in 3:
			var context_y: float = view.y - 126.0 if view.x < view.y else view.y - 68.0
			var ctx := Rect2(Vector2(view.x * 0.5 + float(action_btn.call("slot_x", slot)), context_y), action_btn.get("SIZE"))
			for b in buttons:
				if ctx.intersects((b as Control).get_global_rect()):
					_check(false, "%s: contextknop-plek %d overlapt %s" % [s, slot, _label(b)])
		# radar en knoppen
		for aim in [false, true]:
			var center: Vector2 = sticks.call("_anchor", aim)
			var zone := Rect2(center - Vector2(76.0, 76.0), Vector2.ONE * 152.0)
			_check(Rect2(Vector2.ZERO, view).encloses(zone), "%s: joystickzone buiten safe-area (%s)" % [s, str(aim)])
			for b in buttons:
				if b.name == "MenuButton":
					continue
				_check(not zone.intersects((b as Control).get_global_rect()), "%s: joystickzone overlapt %s" % [s, _label(b)])
		var radar: Control = main.get_node("Hud").find_child("TacticalRadar", true, false)
		if radar != null and radar.visible:
			var rr := radar.get_global_rect()
			for b in buttons:
				if b.name == "MenuButton":
					continue  # deze menuactie zit bewust in de rand van de radar
				if rr.intersects((b as Control).get_global_rect()):
					_check(false, "%s: radar overlapt %s" % [s, _label(b)])
	# De voorbereidingsknop verdwijnt zodra de golfovergang plaatsvindt.
	var start_wave: Button = main.get_node("Hud/StartWave")
	_check(start_wave.visible, "startknop ontbreekt tijdens golfvoorbereiding")
	main.call("start_wave")
	await process_frame
	_check(game.state == "play" and not start_wave.visible, "golfstart sluit het voorbereidingspaneel niet")
	main.queue_free()
	await process_frame
	if failures.is_empty():
		print("HUD TEST PASS: geen overlappende of verdwenen knoppen")
		quit(0)
	else:
		quit(1)
