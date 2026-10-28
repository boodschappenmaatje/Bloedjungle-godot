extends SceneTree
## Wiel + richten: ver buiten het steunwiel slepen op napalm sluit het wiel en dezelfde vinger richt; loslaten gebruikt napalm.
## BJ_TOUCH=1 xvfb-run -a -s "-screen 0 932x430x24" godot --rendering-driver vulkan --path . -s tests/wiel_richten_test.gd --resolution 932x430 --fixed-fps 60
var main: Node
var game: Node
var frames := 0
var combat: Node
var fails := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _check(ok: bool, what: String) -> void:
	print(("OK   " if ok else "FAAL ") + what)
	if not ok:
		fails += 1


func _drag(pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = 0
	e.position = pos
	combat._input(e)


func _process(_d: float) -> bool:
	frames += 1
	game = root.get_node("Game")
	if frames == 3:
		main.begin()
		for m in get_nodes_in_group("menus"):
			m._show("")
		game.prep_t = 9999.0
		combat = main.get_node("Hud").find_child("CombatButtons", true, false)
	if frames == 30:
		game.streak_bank = ["truck", "napalm"]
		game.streak_sel = "truck"
		game.changed.emit()
	if frames == 40:
		combat._wheel_kind = "support"
		combat._held_pointer = 0
		combat._hold_origin = Vector2(700, 300)
		_drag(Vector2(700, 300) + Vector2(-80, 0))
		_check(combat._wheel_kind == "support" and combat._wheel_sector == 3, "binnen het wiel: sector napalm, wiel open")
		_check(combat.air_finger == -2, "nog niet aan het richten")
		_drag(Vector2(700, 300) + Vector2(-170, 0))
		_check(combat._wheel_kind == "", "ver buiten het wiel: wiel dicht")
		_check(game.streak_current() == "napalm", "napalm gekozen")
		_check(combat.air_finger == 0, "dezelfde vinger richt")
		_drag(Vector2(530, 300) + Vector2(-60, -40))
		_check(combat.air_drag.length() > 16.0, "slepen verplaatst de strook")
		var rel := InputEventScreenTouch.new()
		rel.index = 0
		rel.pressed = false
		rel.position = Vector2(470, 260)
		combat._input(rel)
		_check(combat.air_finger == -2, "loslaten beeindigt het richten")
		_check(not game.streak_bank.has("napalm"), "napalm is gebruikt")
	if frames == 50:
		# truck: ver slepen kiest niet en richt niet
		game.streak_bank = ["truck", "napalm"]
		game.changed.emit()
		combat._wheel_kind = "support"
		combat._held_pointer = 0
		combat._hold_origin = Vector2(700, 300)
		_drag(Vector2(700, 300) + Vector2(0, -170))
		_check(combat._wheel_kind == "support" and combat.air_finger == -2, "truck: wiel blijft, geen richten")
		combat._wheel_kind = ""
		combat._held_pointer = -2
	if frames == 55:
		print("FAILS=", fails)
		quit(fails)
	return false
