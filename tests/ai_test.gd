extends SceneTree
## Test: groepsgedrag van de vijanden (dekking zoeken, flankeren, terugtrekken en helpen, gespreid aanvallen).
## Draaien: godot --headless --path . -s tests/ai_test.gd

var main: Node
var frames := 0
var fails := 0
var a: Node
var b: Node
var c: Node
var d: Node
var assault_model: SoldierModel


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		push_error("AI TEST: " + msg)


func _spawn(kind: String, pos: Vector3) -> Node:
	var e: Node = load("res://scenes/enemy.tscn").instantiate()
	e.call("setup", kind, 1)
	e.position = pos
	main.add_child(e)
	return e


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_dt: float) -> bool:
	frames += 1
	var game = root.get_node("Game")
	if frames == 3:
		main.begin()
		game.build_credit = 5000
		game.builds.place("muur", Vector3(-8, 0, -14), 0.0)
		game.player.global_position = Vector3(-8, 0, -4)
		# 1. spreiding: schutters nemen om beurten de noord- en zuidpoort
		var zs := {}
		for i in 8:
			var e := _spawn("assault", Vector3(50, 0, 50 + i))
			zs[signf(e.get("gate_z"))] = true
			e.queue_free()
		_check(zs.size() == 2, "schutters kiezen niet allebei de poorten")
		# 2. dekking: een geraakte schutter loopt naar een plek achter het gebouw
		a = _spawn("assault", Vector3(-4, 0, -16))
		assault_model = a.get_node("Model") as SoldierModel
		_check(assault_model.meshy_player, "Assault did not load the rigged Meshy body")
		_check(assault_model._mesh_skeleton != null and assault_model._mesh_skeleton.get_bone_count() == 28, "Assault is not using the 28-bone rig")
		_check(assault_model._mesh_weapon_adapter != null and assault_model._mesh_weapon_adapter.profile != null, "Assault did not attach the existing Garand adapter")
		_check(assault_model._mesh_right_ik != null and assault_model._mesh_left_ik != null, "Assault Garand hand IK chains are missing")
		_check(assault_model.anim.has_animation("Walking") and assault_model.anim.has_animation("Rifle_Aim_Turn_Right") and assault_model.anim.has_animation("dying_backwards"), "Assault walk, aim or death clips were not made available")
		a.set("gate_z", 0.0)
		a.set("role", "assault")
		a.set("cover_cd", 0.0)
		a.call("hit", 20.0, Vector3.DOWN, true)
		# 3. terugtrekken en helpen
		b = _spawn("assault", Vector3(20, 0, -3))
		b.set("role", "assault")
		b.set("gate_z", 0.0)
		c = _spawn("knife", Vector3(26, 0, -3))
		b.call("hit", b.get("max_hp") * 0.72, Vector3.RIGHT, true)  # hp onder 30 procent
		# 4. flankeren
		d = _spawn("assault", Vector3(-8, 0, 8))
		d.set("role", "flank")
		d.set("gate_z", 0.0)
	if frames == 12:
		if assault_model != null and assault_model._mesh_skeleton != null and assault_model._mesh_weapon_adapter != null:
			var skel: Skeleton3D = assault_model._mesh_skeleton
			var right_idx := skel.find_bone("mixamorig_RightHand")
			var left_idx := skel.find_bone("mixamorig_LeftHand")
			if right_idx >= 0 and left_idx >= 0:
				var right_hand := skel.to_global(skel.get_bone_global_pose(right_idx).origin)
				var left_hand := skel.to_global(skel.get_bone_global_pose(left_idx).origin)
				var right_error := right_hand.distance_to(assault_model._mesh_right_target.global_position)
				var left_error := left_hand.distance_to(assault_model._mesh_weapon_adapter.left_hand_grip.global_position)
				_check(right_error < 0.12, "Assault right hand misses Garand grip (%.3fm)" % right_error)
				_check(left_error < 0.12, "Assault left hand misses Garand grip (%.3fm)" % left_error)
		_check(str(a.get("mode")) == "cover", "geraakte schutter zoekt geen dekking (mode=%s)" % str(a.get("mode")))
		_check(str(b.get("mode")) == "retreat", "zwaar gewonde schutter trekt zich niet terug (mode=%s)" % str(b.get("mode")))
		_check(float(c.get("alert_t")) > 0.0, "de buurman wordt niet gewaarschuwd")
		_check(float(d.get("flank_left")) < 7.0, "flankeerder loopt niet om")
		d.call("hit", 9999.0, Vector3.RIGHT, true)
	if frames == 14:
		print("modes: ", a.get("mode"), " ", b.get("mode"), " flank_left ", d.get("flank_left"))
		if fails == 0:
			print("AI TEST PASS: dekking, terugtrekken met hulp, flankeren en gespreid aanvallen")
		quit(1 if fails > 0 else 0)
	return false
