extends SceneTree
## Schermafbeeldingen van granaat richten: vrije baan (gele cirkel), auto in de weg (rood) en de worp.
## xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --path . -s tests/granaat_foto.gd --fixed-fps 60

var main: Node
var frames := 0
var game: Node
var btn: Control
var car: Node3D


func _initialize() -> void:
	OS.set_environment("BJ_TOUCH", "1")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	physics_frame.connect(func(): if frames > 3: game.move = Vector2.ZERO)


func _shot(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("/tmp/claude-0/granaat_%s.png" % name)
	print("foto ", name)


func _touch(pressed: bool, at: Vector2) -> void:
	var e := InputEventScreenTouch.new()
	e.position = root.get_final_transform() * at   # schermpunt: de HUD is geschaald (content_scale_factor)
	e.pressed = pressed
	root.push_input(e)


func _drag(at: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.position = root.get_final_transform() * at   # schermpunt: de HUD is geschaald (content_scale_factor)
	root.push_input(e)


func _process(_d: float) -> bool:
	frames += 1
	game = root.get_node("Game")
	if frames == 3:
		main.begin()
		for n in root.find_children("*", "", true, false):
			if n.get_script() and String(n.get_script().resource_path).ends_with("touch_sticks.gd"):
				n.set_process(false)
		for m in get_nodes_in_group("menus"):
			m._show("")
	if frames == 6:
		GameSettings.set_value("time", "day")
		for a in get_nodes_in_group("atmosphere"):
			a.apply_settings()
	if frames == 10:
		var Stad = load("res://scripts/stad.gd")
		var lines: Array = [["weg_recht", 0, -96, 0, 0], ["weg_recht", 0, -102, 0, 0], ["weg_recht", 0, -108, 0, 0],
			["stoep", 6, -96, 0, 0], ["stoep", -6, -96, 0, 0], ["stoep", 6, -102, 0, 0], ["stoep", -6, -102, 0, 0],
			["auto", 4.5, -102, 1, 0]]
		Stad.current.set_items(Stad.from_lines(lines))
		for d in Stad.current.items:
			if d.k == "auto":
				car = d.node
		game.grenades = 5
		game.equipment_sel = "grenade"
		game.changed.emit()
		for n in get_nodes_in_group("hud_button"):
			if n.get_script() != null and n.get_script().resource_path == "res://scripts/action_btn.gd" and n.get("kind") == "granaat":
				btn = n
	if frames == 100:
		game.player.global_position = Vector3(0.0, 0, -100.0)
		game.player.face = PI
	if frames == 150:
		var c := btn.get_global_rect().get_center()
		_touch(true, c)
	if frames == 152:
		_drag(btn.get_global_rect().get_center() + Vector2(-50, -70))   # naar linksboven: vrij veld
	if frames == 170:
		_shot("vrij")
		_drag(btn.get_global_rect().get_center() + Vector2(95, -28))   # naar rechts: de auto staat in de weg
	if frames == 190:
		_shot("auto_rood")
		_drag(btn.get_global_rect().get_center() + Vector2(-50, -70))
	if frames == 200:
		_touch(false, btn.get_global_rect().get_center() + Vector2(-50, -70))
	if frames == 240:
		_shot("worp")
	if frames == 330:
		_shot("boem")
		quit()
	return false
