extends SceneTree

## Dumps a live Godot Assault pose so Blender preview tooling can use the exact
## SkeletonIK3D and AnimationPlayer transforms rather than a guessed IK pose.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var clip := args[0] if not args.is_empty() else "Rifle_Aim_Turn_Right"
	var out_path := args[1] if args.size() > 1 else "res://source_assets/enemy_assault/rig_test/assault_runtime_aim_pose.json"
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	GameSettings.get_value("soldaat")
	root.get_node("Game").set("state", "menu")
	var enemy: Node = load("res://scenes/enemy.tscn").instantiate()
	enemy.call("setup", "assault", 1)
	root.add_child(enemy)
	var model: SoldierModel = enemy.get_node("Model") as SoldierModel
	for _i in 4:
		await process_frame
		await physics_frame
	model.play(clip)
	await create_timer(0.5).timeout
	var skeleton: Skeleton3D = model._mesh_skeleton
	if skeleton == null or skeleton.get_bone_count() != 28:
		push_error("Assault runtime pose did not load the expected 28-bone Skeleton3D")
		quit(1)
		return
	await model._mesh_right_ik.modification_processed
	await model._mesh_left_ik.modification_processed
	var right_hand_idx := skeleton.find_bone("mixamorig_RightHand")
	var left_hand_idx := skeleton.find_bone("mixamorig_LeftHand")
	print("ASSAULT_RUNTIME_IK armed=", model._mesh_armed,
		" right_error_m=", skeleton.to_global(skeleton.get_bone_global_pose(right_hand_idx).origin).distance_to(model._mesh_right_target.global_position),
		" left_error_m=", skeleton.to_global(skeleton.get_bone_global_pose(left_hand_idx).origin).distance_to(model._mesh_weapon_adapter.left_hand_grip.global_position))
	var pose := {}
	for bone_index in skeleton.get_bone_count():
		var transform: Transform3D = skeleton.get_bone_global_pose(bone_index)
		var rest: Transform3D = skeleton.get_bone_global_rest(bone_index)
		var local_rest: Transform3D = skeleton.get_bone_rest(bone_index)
		var local_pose: Transform3D = skeleton.get_bone_pose(bone_index)
		var delta_pose: Transform3D = local_rest.affine_inverse() * local_pose
		var basis: Basis = transform.basis
		var rest_basis: Basis = rest.basis
		var local_basis: Basis = local_pose.basis
		var delta_basis: Basis = delta_pose.basis
		pose[skeleton.get_bone_name(bone_index)] = {
			"origin": [transform.origin.x, transform.origin.y, transform.origin.z],
			"basis": [
				[basis.x.x, basis.y.x, basis.z.x],
				[basis.x.y, basis.y.y, basis.z.y],
				[basis.x.z, basis.y.z, basis.z.z],
			],
			"rest_origin": [rest.origin.x, rest.origin.y, rest.origin.z],
			"rest_basis": [
				[rest_basis.x.x, rest_basis.y.x, rest_basis.z.x],
				[rest_basis.x.y, rest_basis.y.y, rest_basis.z.y],
				[rest_basis.x.z, rest_basis.y.z, rest_basis.z.z],
			],
			"local_origin": [local_pose.origin.x, local_pose.origin.y, local_pose.origin.z],
			"local_basis": [
				[local_basis.x.x, local_basis.y.x, local_basis.z.x],
				[local_basis.x.y, local_basis.y.y, local_basis.z.y],
				[local_basis.x.z, local_basis.y.z, local_basis.z.z],
			],
			"delta_origin": [delta_pose.origin.x, delta_pose.origin.y, delta_pose.origin.z],
			"delta_basis": [
				[delta_basis.x.x, delta_basis.y.x, delta_basis.z.x],
				[delta_basis.x.y, delta_basis.y.y, delta_basis.z.y],
				[delta_basis.x.z, delta_basis.y.z, delta_basis.z.z],
			]
		}
	var result := {
		"clip": clip,
		"model_scale": [model.scale.x, model.scale.y, model.scale.z],
		"bones": pose,
		"right_target": [model._mesh_right_target.global_position.x, model._mesh_right_target.global_position.y, model._mesh_right_target.global_position.z],
		"left_grip": [model._mesh_weapon_adapter.left_hand_grip.global_position.x, model._mesh_weapon_adapter.left_hand_grip.global_position.y, model._mesh_weapon_adapter.left_hand_grip.global_position.z],
		"weapon_transform": {
			"origin": [model._mesh_weapon_adapter.global_position.x, model._mesh_weapon_adapter.global_position.y, model._mesh_weapon_adapter.global_position.z],
			"rotation": [model._mesh_weapon_adapter.global_rotation.x, model._mesh_weapon_adapter.global_rotation.y, model._mesh_weapon_adapter.global_rotation.z],
		}
	}
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	print("ASSAULT_RUNTIME_POSE_SAVED=", out_path)
	quit(0)
