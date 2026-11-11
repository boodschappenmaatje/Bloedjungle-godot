extends SceneTree
## Foto's van de KRACHTEN-knop op aanraking (v218): het wiel na een tik, en de rechterstick in krachtstand met richthulp (napalmstrook, artilleriecirkel).
## KRACHT_OUT = uitvoermap. BJ_TOUCH=1 xvfb-run -a -s "-screen 0 932x430x24" godot --rendering-driver opengl3 --path . -s tests/kracht_stick_foto.gd --resolution 932x430 --fixed-fps 60
var main: Node
var game: Node
var frames := 0
var out := "/tmp/kracht"
var combat: Node


func _initialize() -> void:
	if OS.get_environment("KRACHT_OUT") != "":
		out = OS.get_environment("KRACHT_OUT")
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	Input.parse_input_event(e)


func _drag(index: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	Input.parse_input_event(e)


func _shot(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(out + "/" + name + ".png")


func _process(_d: float) -> bool:
	frames += 1
	game = root.get_node("Game")
	if frames == 3:
		main.begin()
		for m in get_nodes_in_group("menus"):
			m._show("")
		GameSettings.set_value("time", "day")
		game.prep_t = 9999.0
		combat = main.get_node("Hud").find_child("CombatButtons", true, false)
	if frames == 30:
		game.state = "play"
		game.player.driving = false
		game.krachten = {"artillerie": 2, "napalm": 1, "satelliet": 1, "reparatie": 3}
		game.kracht_sel = "artillerie"
		game.kracht_cd["satelliet"] = 42.0
		game.changed.emit()
	if frames == 40:
		var c: Vector2 = combat._air.get_global_rect().get_center()
		_touch(0, c, true)
		_touch(0, c, false)
	if frames == 48:
		_shot("1_tik_opent_wiel")
		var w: Vector2 = combat._wheel_center()
		_touch(0, w + Vector2(70, 0), true)     # napalm
		_touch(0, w + Vector2(70, 0), false)
	if frames == 56:
		_shot("2_napalm_gekozen_stick_klaar")
		var a: Vector2 = main.get_node("Hud/Sticks")._anchor(true)
		_touch(1, a, true)
		_drag(1, a + Vector2(30, -26))
	if frames == 64:
		_shot("3_napalm_richten")
		var a2: Vector2 = main.get_node("Hud/Sticks")._anchor(true)
		_touch(1, a2 + Vector2(30, -26), false)
	if frames == 72:
		game.kracht_cd.clear()
		var c2: Vector2 = combat._air.get_global_rect().get_center()
		_touch(0, c2, true)
		_touch(0, c2, false)
	if frames == 80:
		var w2: Vector2 = combat._wheel_center()
		_touch(0, w2 + Vector2(0, -70), true)   # artillerie
		_touch(0, w2 + Vector2(0, -70), false)
	if frames == 88:
		var a3: Vector2 = main.get_node("Hud/Sticks")._anchor(true)
		_touch(1, a3, true)
		_drag(1, a3 + Vector2(-20, -34))
	if frames == 96:
		_shot("4_artillerie_richten")
	return frames > 100
