extends SceneTree
## Loopt de weg naar de dam echt na met de speler (botsing, bomen, rotsen): van het pad tot de kroon. Print waar hij vastloopt.
var main: Node
var game: Node
var pl: Node3D
var frames := 0
var path: Array = []
var wi := 0
var stuck := 0
var last := Vector3.ZERO
var fails := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_d: float) -> bool:
	frames += 1
	game = root.get_node("Game")
	if frames == 3:
		main.begin()
		for m in get_nodes_in_group("menus"):
			m._show("")
		game.prep_t = 9999.0
		for n in root.find_children("*", "", true, false):
			if n.get_script() and String(n.get_script().resource_path).ends_with("touch_sticks.gd"):
				n.set_process(false)
	if frames == 90:
		game.state = "play"
		pl = game.player
		pl.driving = false
		var z0 := Bergland.DAM_Z
		var dx := DamPad.dam_x()
		path = [Vector2(-168, -214), Vector2(-146, -250), Vector2(-128, -290), Vector2(-80, -291), Vector2(Bergland.gorge_x(-291.0), -291.0), Vector2(Bergland.gorge_x(-310.0), -310.0),
			Vector2(Bergland.gorge_x(z0 + 30.0), z0 + 30.0), Vector2(dx + 12.0, z0 + 36.0), Vector2(dx + 30.0, z0 + 14.0), Vector2(dx + 30.0, z0 + 3.0), Vector2(dx + 22.0, z0 + 1.5)]
		pl.global_position = Vector3(path[0].x, Data.ground_y(path[0].x, path[0].y), path[0].y)
		last = pl.global_position
	if frames > 90 and wi < path.size() - 1:
		wi = max(wi, 0)
		var tgt: Vector2 = path[wi + 1]
		var p := Vector2(pl.global_position.x, pl.global_position.z)
		var d := tgt - p
		if d.length() < 1.2:
			print("waypoint ", wi + 1, " bereikt op frame ", frames, " y=", snappedf(pl.global_position.y, 0.1))
			wi += 1
		else:
			game.move = d.normalized()
			game.fire = false
			if frames % 60 == 0:
				if pl.global_position.distance_to(last) < 0.5:
					stuck += 1
					print("VAST bij ", pl.global_position, " richting waypoint ", wi + 1, " ", tgt)
					if stuck >= 3:
						fails += 1
						print("FAIL loopt vast voor waypoint ", wi + 1)
						return _done()
				last = pl.global_position
	if not path.is_empty() and wi >= path.size() - 1:
		return _done()
	if frames > 7000:
		print("FAIL te langzaam")
		fails += 1
		return _done()
	return false


func _done() -> bool:
	print("dam_loop_test: ", "PASS" if fails == 0 else "FAIL", " waypoint ", wi, "/", path.size() - 1, " pos ", pl.global_position)
	quit(1 if fails > 0 else 0)
	return true
