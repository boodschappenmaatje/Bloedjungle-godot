extends SceneTree
## Wiel + richten (krachten van de generaalsrang): ver buiten het krachtenwiel slepen op napalm sluit het wiel en dezelfde vinger richt;
## loslaten zet de strook neer (START bevestigt en zet de afkoeling). Een kracht zonder richten (satelliet) kiest alleen. Tikken: wiel blijft open.
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


func _touch(pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.pressed = pressed
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
		game.krachten = {"artillerie": 1, "napalm": 1, "satelliet": 1}
		game.kracht_sel = "artillerie"
		game.kracht_cd.clear()
		game.changed.emit()
	if frames == 40:
		# wiel: boven artillerie, rechts napalm, onder satelliet, links reparatie
		combat._wheel_kind = "support"
		combat._held_pointer = 0
		combat._hold_origin = Vector2(700, 300)
		_drag(Vector2(700, 300) + Vector2(80, 0))
		_check(combat._wheel_kind == "support" and combat._wheel_sector == 1, "binnen het wiel: sector napalm (rechts), wiel open")
		_check(combat.air_finger == -2, "nog niet aan het richten")
		_drag(Vector2(700, 300) + Vector2(170, 0))
		_check(combat._wheel_kind == "", "ver buiten het wiel: wiel dicht")
		_check(game.kracht_sel == "napalm", "napalm gekozen")
		_check(combat.air_finger == 0, "dezelfde vinger richt")
		_drag(Vector2(870, 300) + Vector2(60, -40))
		_check(combat.air_drag.length() > 16.0, "slepen verplaatst de strook")
		var rel := InputEventScreenTouch.new()
		rel.index = 0
		rel.pressed = false
		rel.position = Vector2(930, 260)
		combat._input(rel)
		_check(combat.air_finger == -2, "loslaten beeindigt het richten")
		_check(combat._place != null and is_instance_valid(combat._place), "de strook staat neergezet en wacht op START")
		_check(not game.kracht_cd.has("napalm"), "de afkoeling start pas bij het bevestigen")
		combat._place._confirm()
		_check(game.kracht_cd.has("napalm") and float(game.kracht_cd["napalm"]) > 100.0, "napalm gebruikt: afkoeling loopt (%s)" % str(game.kracht_cd.get("napalm")))
	if frames == 50:
		# satelliet: ver slepen kiest niet en richt niet (geen richthulp)
		game.kracht_cd.clear()
		combat._wheel_kind = "support"
		combat._held_pointer = 0
		combat._hold_origin = Vector2(700, 300)
		_drag(Vector2(700, 300) + Vector2(0, 170))
		_check(combat._wheel_kind == "support" and combat.air_finger == -2, "satelliet: wiel blijft, geen richten")
		combat._wheel_kind = ""
		combat._held_pointer = -2
	if frames == 60:
		# tikken op de krachtenknop opent een wiel dat open blijft; tik op een optie kiest, tik op de gekozen optie gebruikt
		game.kracht_cd.clear()
		game.krachten = {"artillerie": 1, "satelliet": 1}
		game.kracht_sel = "artillerie"
		game.changed.emit()
		var c: Vector2 = combat._air.global_position + combat._air.size * 0.5
		_touch(c, true)
		_touch(c, false)
		_check(combat._wheel_kind == "support" and combat._wheel_sticky, "tik op krachtenknop: wiel blijft open")
		var w: Vector2 = combat._wheel_center()
		_touch(w + Vector2(0, 70), true)
		_touch(w + Vector2(0, 70), false)
		_check(combat._wheel_kind == "" and game.kracht_sel == "satelliet", "tik op SATELLIET kiest satelliet en sluit")
		_touch(c, true)
		_touch(c, false)
		_check(combat._wheel_sticky, "opnieuw tikken opent het wiel")
		w = combat._wheel_center()
		_touch(w + Vector2(0, 70), true)
		_touch(w + Vector2(0, 70), false)
		_check(game.kracht_cd.has("satelliet") and game.satelliet_t > 0.0, "tik op de gekozen optie gebruikt de satelliet")
		# tijdens de afkoeling doet nog eens tikken niets en kiest het wiel gewoon
		var t0: float = game.satelliet_t
		game.kracht_cd["satelliet"] = 50.0
		_touch(c, true)
		_touch(c, false)
		w = combat._wheel_center()
		_touch(w + Vector2(0, 70), true)
		_touch(w + Vector2(0, 70), false)
		_check(is_equal_approx(float(game.kracht_cd["satelliet"]), 50.0) and game.satelliet_t <= t0, "tijdens de afkoeling: niet nog eens")
		# met één kracht opent de knop geen wiel maar gebruikt hem meteen
		game.krachten = {"satelliet": 1}
		game.kracht_cd.clear()
		game.satelliet_t = 0.0
		game.changed.emit()
		_touch(c, true)
		_touch(c, false)
		_check(combat._wheel_kind == "" and game.satelliet_t > 0.0, "één kracht over: tik gebruikt hem zonder wiel")
	if frames == 65:
		print("FAILS=", fails)
		quit(fails)
	return false
