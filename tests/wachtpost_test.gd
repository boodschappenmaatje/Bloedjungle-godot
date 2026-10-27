extends SceneTree
## Test: bij elke poort staat een slagboom en een wachthuisje met botsing; de arm gaat omhoog als de poort open gaat en zakt als hij dicht gaat;
## er kan niets gebouwd worden op het wachthuisje. Draaien: godot --headless --path . -s tests/wachtpost_test.gd --fixed-fps 60

var main: Node
var game: Node
var frames := 0
var fails := 0
var arm: Array = []


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		push_error("WACHTPOST TEST FAIL: " + msg)


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _arm_angle(i: int) -> float:
	return rad_to_deg(arm[i].rotation.z)   # Blender-Y wordt Godot-Z; open = +82 graden


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
	if frames == 20:
		var booms := root.find_children("Boom", "Node3D", true, false)
		_check(booms.size() == 2, "twee slagbomen (%d)" % booms.size())
		for b in booms:
			arm.append(b)
		var huts := root.find_children("Wachthuis", "Node3D", true, false)
		_check(huts.size() == 2, "twee wachthuisjes (%d)" % huts.size())
		var solid := 0
		for b: StaticBody3D in root.find_children("*", "StaticBody3D", true, false):
			if b.collision_layer == Kit.LAYER_WALL and b.get_child_count() == 1 and b.get_child(0) is CollisionShape3D:
				var sh: Shape3D = (b.get_child(0) as CollisionShape3D).shape
				if sh is BoxShape3D and absf((sh as BoxShape3D).size.y - 2.5) < 0.01:
					solid += 1
		_check(solid == 2, "twee wachthuisjes met botsing (%d)" % solid)
		var wp := (load("res://scripts/wachtpost.gd") as GDScript)
		for sz in [-1.0, 1.0]:
			var pos: Vector3 = wp.call("hut_pos", sz)
			_check(not game.builds.can_place("garage", pos, 0.0), "geen garage op het wachthuisje (sz %.0f)" % sz)
		for i in 2:
			_check(absf(_arm_angle(i)) < 1.0, "slagboom %d begint dicht (%.1f)" % [i, _arm_angle(i)])
	if frames >= 30 and frames < 60:
		game.gates.list[0].open = 1.0   # de poort zelf zou weer dichtgaan: houd hem open voor de meting
	if frames == 60:
		_check(_arm_angle(0) > 80.0, "slagboom 0 staat omhoog als de poort open is (%.1f)" % _arm_angle(0))
		_check(absf(_arm_angle(1)) < 1.0, "slagboom 1 blijft dicht (%.1f)" % _arm_angle(1))
	if frames >= 60 and frames <= 70:
		game.gates.list[0].open = 0.5
	if frames == 70:
		var a := _arm_angle(0)
		_check(a > 1.0 and a < 80.0, "slagboom 0 staat halverwege (%.1f)" % a)
		game.gates.list[1].broken = true
	if frames == 90:
		_check(_arm_angle(1) > 80.0, "slagboom 1 staat omhoog als de poort kapot is (%.1f)" % _arm_angle(1))
		print("WACHTPOST TEST ", "OK" if fails == 0 else "%d FOUT(EN)" % fails)
		quit(1 if fails > 0 else 0)
		return true
	return false
