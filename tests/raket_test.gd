extends SceneTree
## Test: een raketwerper buiten de muur beschadigt een kazerne. Draaien: godot --headless --path . -s tests/raket_test.gd

var main: Node
var frames := 0
var kaz: Variant


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_d: float) -> bool:
	frames += 1
	var game = root.get_node("Game")
	if frames == 3:
		main.begin()
		game.build_credit = 5000
		kaz = game.builds.place("kazerne", Vector3(-10, 0, -24), 0.0)
	if frames == 5:
		main.start_wave()
		main.queue.clear()
		main._spawn("rocket")
		var e = game.enemies[0]
		e.global_position = Vector3(-10, 0, -44)
		e.slow_t = 0.0
		print("raketman gespawnd, type ", e.type, " hp ", e.hp)
	if frames % 300 == 0:
		var e = game.enemies[0] if game.enemies.size() else null
		print("t=", frames / 60.0, " kazerne hp ", kaz.hp, " down ", kaz.down, " raketman ", e.global_position.snapped(Vector3.ONE * 0.1) if e else "weg", " bunker ", game.base_hp, " poorten ", game.gates.list.map(func(g): return roundi(g.hp)))
	if frames > 60 * 70:
		print("KLAAR")
		quit()
	return false
