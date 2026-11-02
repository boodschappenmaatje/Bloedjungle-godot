extends Node
func _ready() -> void: call_deferred("_run")
func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await get_tree().process_frame
	GameSettings.get_value("soldaat")
	get_tree().root.get_node("Game").set("state", "menu")
	var enemy: Node = load("res://scenes/enemy.tscn").instantiate()
	enemy.call("setup", "assault", 1)
	get_tree().root.add_child(enemy)
	for _frame in 4:
		await get_tree().process_frame
		await get_tree().physics_frame
	var model: Node = enemy.get_node("Model")
	var skel: Skeleton3D = model.get("_mesh_skeleton")
	var adapter: Node3D = model.get("_mesh_weapon_adapter")
	var right_target: Node3D = model.get("_mesh_right_target")
	var ik_samples := {"right": -1.0, "left": -1.0}
	var right_ik_signal: SkeletonIK3D = model.get("_mesh_right_ik")
	var left_ik_signal: SkeletonIK3D = model.get("_mesh_left_ik")
	right_ik_signal.modification_processed.connect(func():
		var p: Vector3 = skel.to_global(skel.get_bone_global_pose(skel.find_bone("mixamorig_RightHand")).origin)
		ik_samples.right = p.distance_to(right_target.global_position)
	)
	left_ik_signal.modification_processed.connect(func():
		var p: Vector3 = skel.to_global(skel.get_bone_global_pose(skel.find_bone("mixamorig_LeftHand")).origin)
		ik_samples.left = p.distance_to(adapter.get("left_hand_grip").global_position)
	)
	await get_tree().create_timer(0.3).timeout
	var right := skel.to_global(skel.get_bone_global_pose(skel.find_bone("mixamorig_RightHand")).origin)
	var left := skel.to_global(skel.get_bone_global_pose(skel.find_bone("mixamorig_LeftHand")).origin)
	var right_error := right.distance_to(right_target.global_position)
	var left_error := left.distance_to(adapter.get("left_hand_grip").global_position)
	var right_shoulder := skel.to_global(skel.get_bone_global_pose(skel.find_bone("mixamorig_RightShoulder")).origin)
	var left_shoulder := skel.to_global(skel.get_bone_global_pose(skel.find_bone("mixamorig_LeftShoulder")).origin)
	print("ASSAULT_GARAND_IK modifier_hand_error_m right=", ik_samples.right, " left=", ik_samples.left, " muzzle=", model.call("muzzle_position"))
	var right_ik: SkeletonIK3D = model.get("_mesh_right_ik")
	var left_ik: SkeletonIK3D = model.get("_mesh_left_ik")
	var ok: bool = adapter.get("weapon") != null and right_ik.is_running() and left_ik.is_running() and ik_samples.right >= 0.0 and ik_samples.left >= 0.0 and ik_samples.right < 0.05 and ik_samples.left < 0.05
	print("ASSAULT_GARAND_TEST=", ok)
	var bullets_before: int = PerfMonitor.bullets_live
	enemy.call("_shoot", 0.0)
	await get_tree().process_frame
	var shot_ok: bool = PerfMonitor.bullets_live > bullets_before and int(enemy.get("_shot_sequence")) == 1
	print("ASSAULT_GARAND_SHOT=", shot_ok, " bullet_delta=", PerfMonitor.bullets_live - bullets_before)
	ok = ok and shot_ok
	enemy.queue_free()
	main.queue_free()
	print("ASSAULT_WEAPON_TEST=", ok)
	get_tree().quit(0 if ok else 1)
