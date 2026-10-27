extends SceneTree
## Test: vier wachten: drie lopen in de pauze heen en weer binnen de muur en blijven bij hun eindpunt even staan; bij het begin van de golf
## gaat het alarm (sirene) en rennen ze naar hun post langs de muur. Draaien: godot --headless --path . -s tests/patrouille_test.gd --fixed-fps 60

var main: Node
var game: Node
var frames := 0
var fails := 0
var pat
var start_pos := []
var moved := [0.0, 0.0, 0.0]


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		push_error("PATROUILLE TEST FAIL: " + msg)


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


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
		game.prep_t = 9999.0
	if frames == 10:
		for n in main.get_children():
			if n.get_script() and String(n.get_script().resource_path).ends_with("patrouille.gd"):
				pat = n
		_check(pat != null and pat.guards.size() == 4, "vier wachten staan er")
		for g in pat.guards:
			start_pos.append(g.global_position)
	if frames > 10 and frames < 1500 and pat != null:
		for i in 3:
			var g: Node3D = pat.guards[i]
			var c: float = Data.COMPOUND
			if absf(g.global_position.x) > c or absf(g.global_position.z) > c:
				_check(false, "wacht %d buiten de muur: %s" % [i, str(g.global_position)])
			moved[i] = maxf(moved[i], g.global_position.distance_to(start_pos[i]))
	if frames == 1500:
		for i in 3:
			_check(moved[i] > 6.0, "wacht %d patrouilleert (verste afstand %.1f m)" % [i, moved[i]])
		# de golf begint: alarm
		main.start_wave()
	if frames == 1400:
		var spot: Vector3 = (load("res://scripts/wachtpost.gd") as GDScript).call("guard_spot", -1.0)
		var gd: float = (pat.guards[3] as Node3D).global_position.distance_to(spot)
		_check(gd < 2.0, "wacht 3 staat voor het wachthuisje (%.1f m ervandaan)" % gd)
	if frames == 1500 + 5:
		_check(pat._sirene != null, "alarm klinkt")
	if frames == 1500 + 900:
		for i in 4:
			var g: Node3D = pat.guards[i]
			var posts: Array = (load("res://scripts/ally.gd") as GDScript).get_script_constant_map()["POSTS"]
			var q: Vector2 = posts[(i * 4 + 1) % posts.size()] * (Data.COMPOUND / 14.0)
			var d := Vector2(g.global_position.x - q.x, g.global_position.z - q.y).length()
			_check(d < 3.0, "wacht %d staat na het alarm op zijn post (%.1f m ervandaan)" % [i, d])
		print("PATROUILLE TEST ", "OK" if fails == 0 else "%d FOUT(EN)" % fails)
		quit(1 if fails > 0 else 0)
		return true
	return false
