extends SceneTree
## Test: bij elke poort staat een slagboom en een wachthuisje met botsing; de arm gaat omhoog als de poort open gaat en zakt als hij dicht gaat;
## er kan niets gebouwd worden op het wachthuisje. Draaien: godot --headless --path . -s tests/wachtpost_test.gd --fixed-fps 60

var main: Node
var game: Node
var frames := 0
var fails := 0
var arm: Array = []
var enemy: Node
var enemy_hp := 0.0


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
		# de wacht in het huisje schiet op een vijand die door de poort is gekomen
		var wp := load("res://scripts/wachtpost.gd") as GDScript
		var spot: Vector3 = wp.call("hut_pos", -1.0)
		enemy = load("res://scenes/enemy.tscn").instantiate()
		enemy.call("setup", "rifle", 1)
		enemy.position = spot + Vector3(5.0, 0, 0)
		main.add_child(enemy)
		enemy.set_physics_process(false)
		enemy_hp = enemy.get("hp")
	if frames == 300:
		var hp_now: float = enemy.get("hp") if is_instance_valid(enemy) else 0.0
		_check(hp_now < enemy_hp, "de wacht in het huisje schiet op de vijand (hp %.0f van %.0f)" % [hp_now, enemy_hp])
		var guard: Node3D
		for n in main.get_children():
			if n.get_script() and String(n.get_script().resource_path).ends_with("patrouille.gd"):
				guard = n.guards[3]
		var hut_pos: Vector3 = wp_static().call("hut_pos", -1.0)
		_check(guard.global_position.distance_to(hut_pos) < 1.5, "de wacht zit in het huisje (%.1f m van het midden)" % guard.global_position.distance_to(hut_pos))
		# kogels van de vijand slopen het huisje
		var inst = main.get_node_or_null("Wachtpost")
		for n in main.get_children():
			if n.get_script() and String(n.get_script().resource_path).ends_with("wachtpost.gd"):
				inst = n
		var p0: Dictionary = inst.posts[0]
		var body: Node = p0.hut_body
		var hp0: float = p0.hut_hp
		game.hit_src = "soldaat"
		body.call("hit", 20.0, Vector3.RIGHT, true)
		_check(is_equal_approx(p0.hut_hp, hp0), "kogels van soldaten beschadigen het huisje niet")
		game.hit_src = "speler"
		body.call("hit", 20.0, Vector3.RIGHT, true)
		_check(p0.hut_hp < hp0, "jouw eigen kogels beschadigen het huisje wel")
		hp0 = p0.hut_hp
		body.call("hit", 20.0, Vector3.RIGHT, false)
		_check(p0.hut_hp < hp0, "vijandelijke kogels beschadigen het huisje")
		for i in 40:
			body.call("hit", 50.0, Vector3.RIGHT, false)
		_check(p0.hut_down, "het huisje gaat kapot")
		_check((p0.hut_body.get_child(0) as CollisionShape3D).disabled, "een kapot huisje heeft geen botsing meer")
		_check(game.wachtpost_cost() >= 300, "repareren kost punten (%d)" % game.wachtpost_cost())
		# explosie slaat de slagboom van de zuidpoort kapot
		var p1: Dictionary = inst.posts[1]
		wp_static().call("blast", p1.barrier.global_position, 6.0, 200.0)
		_check(p1.boom_down, "een ontploffing slaat de slagboom kapot")
		_check(not (p1.arm as Node3D).visible, "de arm is weg")
		inst.repair_all()
		_check(not p0.hut_down and not p1.boom_down and (p1.arm as Node3D).visible and game.wachtpost_cost() == 0, "repareren zet alles terug")
		print("WACHTPOST TEST ", "OK" if fails == 0 else "%d FOUT(EN)" % fails)
		quit(1 if fails > 0 else 0)
		return true
	return false


func wp_static() -> GDScript:
	return load("res://scripts/wachtpost.gd") as GDScript
