extends SceneTree
## Wiel + richten (krachten van de generaalsrang, op aanraking): tikken opent het wiel dat open blijft; een kracht kiezen (ook ver buiten het wiel slepen)
## sluit het wiel en zet de rechterstick klaar; een NIEUWE aanraking richt en loslaten vuurt. De volledige aanrakingsketen test kracht_stick_test.gd.
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
		game.state = "play"
		game.player.driving = false    # het spel begint in de bouwwagen; Dennis speelt te voet
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
		_check(not combat.kracht_stick_armed, "nog niets klaargezet")
		_drag(Vector2(700, 300) + Vector2(170, 0))
		_check(combat._wheel_kind == "", "ver buiten het wiel: wiel dicht")
		_check(game.kracht_sel == "napalm", "napalm gekozen")
		_check(combat.kracht_stick_armed and combat.air_finger == -2 and combat.kstick_finger == -2, "de rechterstick staat klaar; de vinger uit het wiel richt niet zelf")
		# een NIEUWE aanraking op de rechterstick richt (hier rechtstreeks aangeroepen; het echte pad test kracht_stick_test.gd)
		combat.kracht_stick_begin(1)
		combat.kracht_stick_drag(1, Vector2(0.7, -0.4))
		_check(combat.kstick_drag.length() > 16.0 and combat._air_vis != null and combat._air_vis.visible, "slepen verplaatst de strook")
		combat.kracht_stick_release(1)
		_check(not combat.kracht_stick_armed and combat.kstick_finger == -2, "loslaten beeindigt het richten")
		_check(combat._place == null, "de strook gaat meteen, er staat niets te wachten op START")
		_check(game.kracht_cd.has("napalm") and float(game.kracht_cd["napalm"]) > 100.0, "napalm gebruikt: afkoeling loopt (%s)" % str(game.kracht_cd.get("napalm")))
	if frames == 50:
		# satelliet: ver buiten het wiel kiest en zet de stick klaar (geen richthulp, loslaten vuurt)
		game.kracht_cd.clear()
		combat._wheel_kind = "support"
		combat._held_pointer = 0
		combat._hold_origin = Vector2(700, 300)
		_drag(Vector2(700, 300) + Vector2(0, 170))
		_check(combat._wheel_kind == "" and game.kracht_sel == "satelliet" and combat.kracht_stick_armed, "satelliet: gekozen en klaargezet")
		combat.kracht_stick_begin(1)
		combat.kracht_stick_drag(1, Vector2(0, 0.8))
		_check(combat._air_vis == null and combat._arty_vis == null, "satelliet heeft geen richthulp")
		combat.kracht_stick_release(1)
		_check(game.satelliet_t > 0.0 and game.kracht_cd.has("satelliet"), "loslaten gebruikt de satelliet")
	if frames == 60:
		# tikken op de krachtenknop opent een wiel dat open blijft; tik op een optie kiest en zet de stick klaar
		game.kracht_cd.clear()
		game.satelliet_t = 0.0
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
		_check(combat._wheel_kind == "" and game.kracht_sel == "satelliet" and combat.kracht_stick_armed, "tik op SATELLIET kiest satelliet, sluit het wiel en zet de stick klaar")
		_check(game.satelliet_t <= 0.0 and not game.kracht_cd.has("satelliet"), "kiezen gebruikt hem niet")
		combat.cancel_stick()
		# met één kracht opent de knop ook gewoon het wiel (zoals UITRUSTING)
		game.krachten = {"satelliet": 1}
		game.changed.emit()
		_touch(c, true)
		_touch(c, false)
		_check(combat._wheel_kind == "support" and combat._wheel_sticky and game.satelliet_t <= 0.0, "één kracht over: tik opent het wiel, geen direct gebruik")
		combat._close_wheel()
	if frames == 65:
		print("FAILS=", fails)
		quit(fails)
	return false
