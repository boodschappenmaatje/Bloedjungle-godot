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
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var game = root.get_node("Game")
	for _i in 3:
		await process_frame
	main.get_node("Hud/Sticks").set_process(false)
	await main.call("begin")
	for _i in 3:
		await process_frame
	game.inv = {"bags": 2, "trench": 1, "mine": 2, "wire": 1, "sentry": 1}
	game.place_sel = "bags"
	game.place_armed = true
	game.emit_signal("changed")
	var action_btn: Script = load("res://scripts/action_btn.gd")
	for s in SIZES:
		root.size = s
		root.content_scale_factor = 1.0
		for _i in 6:
			await process_frame
		var view := Vector2(root.get_visible_rect().size)
		var buttons: Array = []
		_visible_buttons(main.get_node("Hud"), buttons)
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
		# de contextknoppen (poort, brug, repareer, voertuig) staan op vaste plekken onderin het midden; ook daar mag niets overlappen
		for slot in 3:
			var ctx := Rect2(Vector2(view.x * 0.5 + float(action_btn.call("slot_x", slot)), view.y - 126.0), action_btn.get("SIZE"))
			for b in buttons:
				if ctx.intersects((b as Control).get_global_rect()):
					_check(false, "%s: contextknop-plek %d overlapt %s" % [s, slot, _label(b)])
		# radar en knoppen
		var radar: Control = main.get_node("Hud").find_child("TacticalRadar", true, false)
		if radar != null and radar.visible:
			var rr := radar.get_global_rect()
			for b in buttons:
				if rr.intersects((b as Control).get_global_rect()):
					_check(false, "%s: radar overlapt %s" % [s, _label(b)])
	main.queue_free()
	await process_frame
	if failures.is_empty():
		print("HUD TEST PASS: geen overlappende of verdwenen knoppen")
		quit(0)
	else:
		quit(1)
