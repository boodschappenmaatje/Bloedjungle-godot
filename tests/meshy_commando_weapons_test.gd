extends SceneTree
## Every playable weapon must remain reachable by both hands on the Meshy rig.

const WEAPONS := ["m1911", "thompson", "garand", "trench", "mg42", "bazooka"]
var failures: Array[String] = []
var sample := {"right": INF, "left": INF}
var model: SoldierModel

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error("MESHY COMMANDO WEAPONS: " + message)

func _frames(n: int) -> void:
	for _i in n:
		await process_frame

func _measure_grips() -> void:
	var skel: Skeleton3D = model._mesh_skeleton
	for side in ["right", "left"]:
		var bone := skel.find_bone("mixamorig_RightHand" if side == "right" else "mixamorig_LeftHand")
		var hand: Vector3 = skel.to_global(skel.get_bone_global_pose(bone).origin)
		var target: Node3D = model._mesh_right_target if side == "right" else model._mesh_weapon_adapter.left_hand_grip
		sample[side] = hand.distance_to(target.global_position)

func _weapon_front_z(weapon: Node3D) -> float:
	var front := INF
	for child in weapon.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		var box := mesh.get_aabb()
		for x in [box.position.x, box.end.x]:
			for y in [box.position.y, box.end.y]:
				for z in [box.position.z, box.end.z]:
					front = minf(front, weapon.to_local(mesh.to_global(Vector3(x, y, z))).z)
	return front

func _run() -> void:
	GameSettings.get_value("soldaat")
	var old_setting: String = str(GameSettings.values["soldaat"])
	GameSettings.values["soldaat"] = "meshy"
	var game: Node = root.get_node("Game")
	game.set("state", "menu")
	var world := Node3D.new()
	root.add_child(world)
	var player: Node3D = load("res://scenes/player.tscn").instantiate()
	world.add_child(player)
	await _frames(3)
	player.set_physics_process(false)
	model = player.get_node("Model")
	_check(model.meshy_player and model._mesh_skeleton != null, "real Meshy player missing")
	if model._mesh_skeleton != null:
		model._mesh_left_ik.modification_processed.connect(_measure_grips)
		for weapon in WEAPONS:
			model.set_gun(weapon)
			model.play("stil")
			await _frames(12)
			_check(model._mesh_weapon_adapter != null and model._mesh_weapon_adapter.weapon != null, "%s model missing" % weapon)
			print("MESHY_WEAPON_GRIP ", weapon, " right_m=", sample.right, " left_m=", sample.left)
			_check(sample.right < 0.04, "%s right hand misses its grip by %.3f m" % [weapon, sample.right])
			_check(sample.left < 0.04, "%s left hand misses its grip by %.3f m" % [weapon, sample.left])
			if weapon != "m1911":
				var adapter: Node3D = model._mesh_weapon_adapter
				var front_z := _weapon_front_z(adapter.weapon)
				var muzzle_z: float = adapter.weapon.to_local(adapter.muzzle.global_position).z
				print("MESHY_WEAPON_MUZZLE ", weapon, " mesh_front_z=", front_z, " muzzle_z=", muzzle_z)
				_check(absf(front_z - muzzle_z) < 0.14, "%s muzzle marker is not at its real barrel end" % weapon)
			model.play("rennen")
			await _frames(12)
			model.play("stil")
			model.set_shoot_pose(true, weapon, 0.25)
			await _frames(12)
			_check(sample.right < 0.04 and sample.left < 0.04, "%s loses a grip after run-to-fire" % weapon)
			model.set_shoot_pose(false, weapon, 0.25)
			model.play("lopen")
			await _frames(8)
			_check(model.current == "lopen", "%s does not resume walking after fire" % weapon)
			model.play("herladen")
			await _frames(5)
			_check(model.current == "herladen" and model._mesh_action_player.is_playing(), "%s reload does not play" % weapon)
			model.play("rennen")
			await _frames(8)
			_check(model.current == "rennen" and sample.right < 0.04 and sample.left < 0.04, "%s does not resume running with both grips after reload" % weapon)
	world.queue_free()
	GameSettings.values["soldaat"] = old_setting
	await _frames(2)
	print("MESHY COMMANDO WEAPONS: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
