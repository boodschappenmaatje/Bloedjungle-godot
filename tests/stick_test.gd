extends SceneTree
## Test: een gemiste loslaat-gebeurtenis laat de linker stick niet vastlopen. Draaien: godot --headless --path . -s tests/stick_test.gd --fixed-fps 60

var main: Node
var frames := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _touch(idx: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.position = pos
	e.pressed = pressed
	Input.parse_input_event(e)


func _drag(idx: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = idx
	e.position = pos
	Input.parse_input_event(e)


func _process(_d: float) -> bool:
	frames += 1
	var game = root.get_node("Game")
	var ts: Node = main.find_children("*", "Control", true, false).filter(func(n): return n.get_script() != null and n.get_script().resource_path.ends_with("touch_sticks.gd"))[0]
	if frames == 3:
		main.begin()
	if frames == 8:
		for b in get_nodes_in_group("hud_button"):
			b.visible = false
	if frames == 10:
		_touch(0, Vector2(5, 55), true)   # linker vinger, loslaten gaat "verloren"
	if frames == 14:
		_drag(0, Vector2(25, 55))
	if frames == 16:
		print("sticks ", ts._sticks, " vp ", ts.get_viewport_rect().size, " state ", game.state, " bm ", game.build_mode)
	if frames == 18:
		print("vinger 1 beweegt: move ", game.move.snapped(Vector2(0.01, 0.01)))
		_touch(5, Vector2(6, 58), true)   # nieuwe vinger op dezelfde kant, zonder dat de eerste los was
	if frames == 22:
		_drag(5, Vector2(6, 18))
	if frames == 26:
		print("nieuwe vinger wint: move ", game.move.snapped(Vector2(0.01, 0.01)), " (y moet negatief zijn)")
		_touch(5, Vector2(6, 18), false)
	if frames == 30:
		print("na loslaten: move ", game.move, " sticks ", ts._sticks.size(), " (0 verwacht)")
		_touch(1, Vector2(5, 62), true)
	if frames == 32:
		paused = true
	if frames == 36:
		_touch(1, Vector2(5, 62), false)  # loslaten tijdens pauze
	if frames == 38:
		paused = false
	if frames == 42:
		print("na pauze: sticks ", ts._sticks.size(), " move ", game.move, " (0 verwacht)")
		quit()
	return false
