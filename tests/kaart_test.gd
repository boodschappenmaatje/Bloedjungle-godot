extends SceneTree
## Test: grote kaart en soldatenbevel. De kaart opent en sluit, een tik kiest een gebied, AANVALLEN stuurt de soldaten erheen,
## ze schakelen de verdedigers uit (het gebied is dan vrij), en SOLDATEN TERUG haalt ze weer naar de speler.
## Draaien: godot --headless --path . -s tests/kaart_test.gd --fixed-fps 60

var main: Node
var frames := 0
var fails := 0
var game
var kaart
var allies: Array = []


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		push_error("KAART TEST: " + msg)


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_dt: float) -> bool:
	frames += 1
	game = root.get_node("Game")
	if frames == 2:
		root.size = Vector2i(934, 430)
	if frames == 3:
		main.begin()
		game.player.global_position = Vector3(0, 0, -60)
		for i in 4:
			var a = load("res://scripts/ally.gd").new()
			main.add_child(a)
			a.global_position = Vector3(float(i) - 1.5, 0, -62)
			a.setup(100.0, 40.0, i)
			game.allies.append(a)
			allies.append(a)
	if frames > 3:
		game.player.hp = 100000.0
	if frames == 20:
		kaart = main.get_node("Hud").find_children("*", "Kaart", true, false)[0]
		kaart.open()
		_check(kaart.visible and paused, "kaart opent niet of pauzeert niet")
		# tik midden op de Brugkop
		var c: Vector3 = game.gebieden.center("brugkop")
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = true
		ev.position = kaart._to_screen(c.x, c.z)
		kaart._gui_input(ev)
		_check(kaart.selected == "brugkop", "tik kiest brugkop niet: '%s'" % kaart.selected)
		_check(not kaart._attack.disabled and not kaart._defend.disabled, "knoppen staan uit met soldaten")
		kaart._attack.pressed.emit()
		_check(not kaart.visible and not paused, "kaart sluit niet na bevel")
		_check(game.order.zone == "brugkop" and game.order.mode == "aanval", "bevel niet gezet")
	if frames == 20 + 60 * 40:
		_check(game.gebieden.is_cleared("brugkop"), "soldaten hebben de brugkop niet gewonnen (nog %d)" % game.gebieden.alive("brugkop"))
		var near := 0
		for a in allies:
			if is_instance_valid(a) and game.gebieden.inside("brugkop", a.global_position, 12.0):
				near += 1
		_check(near > 0, "soldaten staan niet bij het gebied")
		kaart.open()
		kaart.selected = "brugkop"
		kaart._refresh()
		_check(kaart._attack.disabled and not kaart._defend.disabled, "vrij gebied: aanvallen uit, verdedigen aan")
		kaart._recall.pressed.emit()
		_check(game.order.zone == "", "terug werkt niet")
		kaart.close()
	if frames == 20 + 60 * 40 + 60 * 25:
		var close := 0
		for a in allies:
			if is_instance_valid(a) and a.global_position.distance_to(game.player.global_position) < 8.0:
				close += 1
		_check(close > 0, "soldaten komen niet terug naar de speler")
		print("KAART TEST: %s" % ("OK" if fails == 0 else "%d FOUT" % fails))
		quit(1 if fails else 0)
		return true
	return false
