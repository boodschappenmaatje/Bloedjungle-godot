extends SceneTree
## Test: het woonhuis achter de brug. Naar binnen lopen (dak en verdieping weg), de trap op (hoogte 3,2),
## en slopen met ontploffingen tot de verdieping inzakt. Draaien: godot --headless --path . -s tests/huis_test.gd --fixed-fps 60

var main: Node
var frames := 0
var game: Node
var move := Vector2.ZERO
var huis


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	physics_frame.connect(func(): if frames > 3: game.move = move)


func _p() -> Vector3:
	return game.player.global_position


func _process(_d: float) -> bool:
	frames += 1
	game = root.get_node("Game")
	var t0 := 3
	if frames == t0:
		main.begin()
		for n in root.find_children("*", "", true, false):
			if n.get_script() and String(n.get_script().resource_path).ends_with("touch_sticks.gd"):
				n.set_process(false)
		# de stad heeft meer gebouwen: neem het woonhuis dat het dichtst bij HUIS_POS staat
		for h in get_nodes_in_group("huis"):
			if h.kind == "woonhuis" and (huis == null or h.global_position.distance_to(Data.HUIS_POS) < huis.global_position.distance_to(Data.HUIS_POS)):
				huis = h
		print("huis op ", huis.global_position, " muurstukken ", huis.segs.size(), " deuren ", huis.doors.size())
		game.player.global_position = Data.HUIS_POS + Vector3(1.0, 0, 7.0)
		move = Vector2(0, -1)
	if frames == t0 + 60 * 2:
		move = Vector2.ZERO
		print("na 2 s naar binnen: speler ", _p().snapped(Vector3(0.01, 0.01, 0.01)), " binnen=", huis._inside, " dak zichtbaar=", huis._dak.visible, " verdieping zichtbaar=", huis._ver.visible, " weg voor camera=", huis._hidden.size())
		var deur: Node3D = huis.doors[0].node
		print("voordeur draai ", snappedf(deur.rotation.y, 0.01), " (open = ", snappedf(huis.doors[0].closed + PI / 2, 0.01), ")")
		# naar de voet van de trap
		game.player.global_position = Data.HUIS_POS + Vector3(-3.25, 0.3, 2.4)
		move = Vector2(0, -1)
	if frames == t0 + 60 * 2 + 30:
		print("halverwege trap: y ", snappedf(_p().y, 0.01), " z ", snappedf(_p().z - Data.HUIS_POS.z, 0.01))
	if frames == t0 + 60 * 4:
		print("boven? y ", snappedf(_p().y, 0.01), " (3.2) z ", snappedf(_p().z - Data.HUIS_POS.z, 0.01), " binnen=", huis._inside, " verdieping zichtbaar=", huis._ver.visible)
		move = Vector2(1, 0)
	if frames == t0 + 60 * 5:
		print("boven naar oost: ", (_p() - Data.HUIS_POS).snapped(Vector3(0.01, 0.01, 0.01)), " (y blijft 3.2)")
		move = Vector2(0, 1)
	if frames == t0 + 60 * 7:
		print("boven naar voor (balkon): ", (_p() - Data.HUIS_POS).snapped(Vector3(0.01, 0.01, 0.01)))
		move = Vector2.ZERO
		game.player.global_position = Data.HUIS_POS + Vector3(0, 0, 14)
		game.player.position.y = 0.0
	if frames == t0 + 60 * 8:
		print("buiten: binnen=", huis._inside, " dak=", huis._dak.visible)
		# raketten op de voorgevel, begane grond
		var n := 0
		for x in [-3.0, -1.0, 1.0, 3.0]:
			for k in 3:
				huis.blast(Data.HUIS_POS + Vector3(x, 1.4, 4.2), 2.6, 90.0)
		for s in huis.segs:
			if s.staat > 0:
				n += 1
		var states := {}
		for s in huis.segs:
			states[s.name] = s.staat
		print("na raketten voorgevel: ", n, " stukken geraakt ", states)
		for x in [-4.6, 4.6]:
			for z in [-2.2, 0.0, 2.2]:
				for k in 4:
					huis.blast(Data.HUIS_POS + Vector3(x, 1.4, z), 2.0, 90.0)
		print("ingestort=", huis._collapsed, " dak weg=", huis._dak.get_meta("weg", false))
	if frames == t0 + 60 * 10:
		print("KLAAR")
		return true
	return false
