extends SceneTree
## Regression for a Meshy run frame left on the legs after stopping to fire.

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error("MESHY COMMANDO TRANSITION: " + message)

func _frames(n: int) -> void:
	for _i in n:
		await process_frame

func _run() -> void:
	GameSettings.get_value("soldaat")
	var old_setting: String = str(GameSettings.values["soldaat"])
	GameSettings.values["soldaat"] = "meshy"
	var game: Node = root.get_node("Game")
	game.set("state", "menu")
	var world := Node3D.new()
	root.add_child(world)
	var player: Node = load("res://scenes/player.tscn").instantiate()
	world.add_child(player)
	await _frames(3)
	player.set_physics_process(false)
	var model: SoldierModel = player.get_node("Model")
	var skel: Skeleton3D = model._mesh_skeleton
	_check(model.meshy_player and skel != null, "test did not instantiate the Meshy player")
	if skel != null:
		_check(skel.get_bone_count() == 28, "commando no longer uses the original 28-bone rig")
		_check(model._model.find_child("High-cut olive helmet shell", true, false) != null, "visible commando helmet missing")
		_check(model._model.find_child("Headset earcup", true, false) != null, "visible commando headset missing")
		var legs := [skel.find_bone("mixamorig_LeftUpLeg"), skel.find_bone("mixamorig_RightUpLeg")]
		var feet := [skel.find_bone("mixamorig_LeftFoot"), skel.find_bone("mixamorig_RightFoot")]
		_check(legs[0] >= 0 and legs[1] >= 0, "leg bones missing")
		if legs[0] >= 0 and legs[1] >= 0:
			model.play("stil", 0.0)
			await _frames(5)
			var idle_left := skel.get_bone_pose_rotation(legs[0])
			var idle_right := skel.get_bone_pose_rotation(legs[1])
			model.play("rennen", 0.0)
			await _frames(19)
			var run_left := skel.get_bone_pose_rotation(legs[0])
			var run_right := skel.get_bone_pose_rotation(legs[1])
			_check(maxf(run_left.angle_to(idle_left), run_right.angle_to(idle_right)) > 0.12, "run frame is not distinct from idle")
			model.set_shoot_pose(true, "m1911", 0.25)
			model.play("stil", 0.18)
			await _frames(25)
			_check(skel.get_bone_pose_rotation(legs[0]).angle_to(idle_left) < 0.06, "left leg remains in running pose during stationary fire")
			_check(skel.get_bone_pose_rotation(legs[1]).angle_to(idle_right) < 0.06, "right leg remains in running pose during stationary fire")
			if feet[0] >= 0 and feet[1] >= 0:
				var left_foot: Vector3 = skel.get_bone_global_pose(feet[0]).origin
				var right_foot: Vector3 = skel.get_bone_global_pose(feet[1]).origin
				_check(absf(left_foot.z - right_foot.z) < 0.15, "stationary fire leaves feet split in a running stride")
			_check(model.current == "stil", "base clip did not switch to idle")
			model.set_shoot_pose(false, "m1911", 0.25)
			model.play("lopen")
			await _frames(5)
			_check(model.current == "lopen", "movement did not resume after stationary fire")
			model.play("stil", 0.0)
			await _frames(10)
			var hips := skel.find_bone("mixamorig_Hips")
			var chest := skel.find_bone("mixamorig_Spine2")
			var direction_sample := {}
			model._mesh_leg_pose.modification_processed.connect(func() -> void:
				direction_sample["hip"] = skel.get_bone_global_pose(hips).basis.get_rotation_quaternion()
				direction_sample["chest"] = skel.get_bone_global_pose(chest).basis.get_rotation_quaternion()
			)
			await _frames(2)
			var hip_before: Quaternion = direction_sample["hip"]
			var chest_before: Quaternion = direction_sample["chest"]
			model.set_leg_yaw(PI / 2.0)
			await _frames(20)
			var hip_after: Quaternion = direction_sample["hip"]
			var chest_after: Quaternion = direction_sample["chest"]
			_check(hip_before.angle_to(hip_after) > 1.0, "Meshy legs do not turn toward sideways travel")
			_check(chest_before.angle_to(chest_after) < 0.3, "Meshy chest no longer stays aimed while legs turn")
			model.play("stil")
			await _frames(20)
			_check(hip_before.angle_to(direction_sample["hip"]) < 0.15, "Meshy legs do not settle after sideways travel")
	world.queue_free()
	GameSettings.values["soldaat"] = old_setting
	await _frames(2)
	print("MESHY COMMANDO TRANSITION: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
