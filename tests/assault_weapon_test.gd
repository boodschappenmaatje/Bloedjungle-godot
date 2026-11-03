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
	enemy.set("dead", true) # Freeze the AI at its initial prepared combat pose.
	get_tree().root.add_child(enemy)
	for _frame in 4:
		await get_tree().process_frame
		await get_tree().physics_frame
	var model: Node = enemy.get_node("Model")
	var skel: Skeleton3D = model.get("_mesh_skeleton")
	var adapter: Node3D = model.get("_mesh_weapon_adapter")
	var right_target: Node3D = model.get("_mesh_right_target")
	var weapon: Node3D = adapter.get("weapon")
	var muzzle: Node3D = adapter.get("muzzle")
	var assault_model: Node3D = model.get("_model")
	var lod_meshes: Array[MeshInstance3D] = []
	for child in assault_model.find_children("*", "MeshInstance3D", true, false):
		lod_meshes.append(child as MeshInstance3D)
	var lod_begin := {"LOD0": 0.0, "LOD1": 18.0, "LOD2": 36.0}
	var lod_end := {"LOD0": 18.0, "LOD1": 36.0, "LOD2": 0.0}
	var lod_ok := lod_meshes.size() == 6
	for mesh in lod_meshes:
		var level := ""
		for suffix in lod_begin:
			if mesh.name.ends_with(suffix):
				level = suffix
				break
		var correct_lod := not level.is_empty() and is_equal_approx(mesh.visibility_range_begin, lod_begin[level]) and is_equal_approx(mesh.visibility_range_end, lod_end[level])
		lod_ok = lod_ok and correct_lod
		print("ASSAULT_LOD mesh=", mesh.name, " begin=", mesh.visibility_range_begin, " end=", mesh.visibility_range_end)
	print("ASSAULT_LOD_TEST=", lod_ok, " mesh_count=", lod_meshes.size())
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
	var right_error: float = ik_samples.right
	var left_error: float = ik_samples.left
	print("ASSAULT_MESHY_WEAPON_IK hand_error_m right=", right_error, " left=", left_error, " muzzle=", model.call("muzzle_position"))
	var ok: bool = adapter.get("weapon") != null and right_ik_signal.is_running() and left_ik_signal.is_running() and right_error >= 0.0 and left_error >= 0.0 and right_error < 0.05 and left_error < 0.05
	var one_separate_weapon: bool = weapon != null and weapon.name == "Assault_Meshy_Weapon" and weapon.get_parent() == adapter and adapter.get_parent() == assault_model
	print("ASSAULT_MESHY_WEAPON_SEPARATE=", one_separate_weapon, " visual=", weapon.name if weapon != null else "missing")
	ok = ok and one_separate_weapon
	ok = ok and lod_ok
	var muzzle_forward := (muzzle.global_position - right_target.global_position).normalized()
	var enemy_forward := (enemy as Node3D).global_transform.basis.z.normalized()
	var muzzle_alignment := muzzle_forward.dot(enemy_forward)
	var muzzle_ok := muzzle_alignment > 0.95 and muzzle.global_position.distance_to(right_target.global_position) > 0.5
	print("ASSAULT_MESHY_MUZZLE_ALIGNMENT=", muzzle_ok, " forward_dot=", muzzle_alignment, " hand_to_muzzle_m=", muzzle.global_position.distance_to(right_target.global_position))
	ok = ok and muzzle_ok
	print("ASSAULT_MESHY_IK_TEST=", ok)
	model.call("play", "stil", 0.05, 1.0)
	await get_tree().create_timer(0.28).timeout
	var idle_right_error: float = ik_samples.right
	var idle_left_error: float = ik_samples.left
	var hold_ok: bool = model.get("current") == "stil" and model.get("_mesh_armed") and idle_right_error < 0.05 and idle_left_error < 0.05
	print("ASSAULT_MESHY_IDLE_HOLD_TEST=", hold_ok, " right_error_m=", idle_right_error, " left_error_m=", idle_left_error)
	ok = ok and hold_ok
	model.call("play", "schieten", 0.05)
	await get_tree().create_timer(0.18).timeout
	var fire_right_error: float = ik_samples.right
	var fire_left_error: float = ik_samples.left
	var fire_animation: Animation = model.get("anim").get_animation("schieten") if model.get("anim").has_animation("schieten") else null
	var fire_pose_ok: bool = model.get("current") == "schieten" and fire_animation != null and fire_animation.loop_mode == Animation.LOOP_LINEAR and fire_right_error < 0.05 and fire_left_error < 0.05
	print("ASSAULT_MESHY_STATIONARY_FIRE_POSE_TEST=", fire_pose_ok, " source_clip=Combat_Stance", " right_error_m=", fire_right_error, " left_error_m=", fire_left_error)
	ok = ok and fire_pose_ok
	var bullets_before: int = PerfMonitor.bullets_live
	var player: Node3D = Game.player
	var player_hp_before: float = float(player.get("hp"))
	var shoot_angle: float = enemy.call("_angle_to", player.global_position)
	enemy.call("_shoot", shoot_angle)
	await get_tree().process_frame
	var shot_ok: bool = PerfMonitor.bullets_live > bullets_before and int(enemy.get("_shot_sequence")) == 1
	await get_tree().create_timer(0.25).timeout
	var damage_ok := float(player.get("hp")) < player_hp_before
	var ammo_after_shot := int(enemy.get("_assault_ammo"))
	print("ASSAULT_MESHY_WEAPON_SHOT=", shot_ok, " bullet_delta=", PerfMonitor.bullets_live - bullets_before, " ammo=", ammo_after_shot, " hit_player=", damage_ok)
	ok = ok and shot_ok
	ok = ok and damage_ok and ammo_after_shot == 7
	var weapon_rest: Vector3 = adapter.position
	model.call("shoot_recoil", "garand")
	await get_tree().create_timer(0.08).timeout
	var recoil_offset: float = adapter.position.distance_to(weapon_rest)
	var recoil_right_error: float = ik_samples.right
	var recoil_left_error: float = ik_samples.left
	var recoil_ok: bool = recoil_offset > 0.005 and recoil_right_error < 0.05 and recoil_left_error < 0.05
	print("ASSAULT_MESHY_DETACHED_WEAPON_RECOIL_TEST=", recoil_ok, " weapon_offset_m=", recoil_offset, " hand_errors_m=", recoil_right_error, "/", recoil_left_error)
	ok = ok and recoil_ok
	await get_tree().create_timer(0.55).timeout
	var recoil_return: bool = adapter.position.distance_to(weapon_rest) < 0.01
	print("ASSAULT_MESHY_RECOIL_RETURN_TEST=", recoil_return, " offset_m=", adapter.position.distance_to(weapon_rest))
	ok = ok and recoil_return
	var grip: Node3D = adapter.get("left_hand_grip")
	var grip_rest: Vector3 = grip.position
	var action_player: AnimationPlayer = model.get("_mesh_action_player")
	print("ASSAULT_MESHY_RELOAD_AVAILABLE=", action_player != null and action_player.has_animation("herladen"), " animations=", action_player.get_animation_list() if action_player != null else [])
	enemy.set("_assault_ammo", 1)
	enemy.set("dead", false)
	enemy.call("_shoot", shoot_angle)
	await get_tree().create_timer(0.42).timeout
	var reload_started: bool = action_player.is_playing() and float(enemy.get("_assault_reload_t")) > 0.0
	var grip_moves_to_magazine: bool = grip.position.distance_to(grip_rest) > 0.02
	await get_tree().create_timer(1.55).timeout
	var grip_returns: bool = grip.position.distance_to(grip_rest) < 0.02
	var reload_refills := int(enemy.get("_assault_ammo")) == 8 and float(enemy.get("_assault_reload_t")) <= 0.0
	var reload_ok := reload_started and grip_moves_to_magazine and grip_returns and reload_refills
	print("ASSAULT_MESHY_RELOAD_TEST=", reload_ok, " started=", reload_started, " moves=", grip_moves_to_magazine, " returns=", grip_returns, " refilled=", reload_refills)
	ok = ok and reload_ok
	enemy.set("dead", false)
	var health_before: float = float(enemy.get("hp"))
	enemy.call("hit", 6.0, Vector3.FORWARD, true)
	var damage_received := is_equal_approx(float(enemy.get("hp")), health_before - 6.0)
	print("ASSAULT_MESHY_PLAYER_DAMAGE_TEST=", damage_received, " hp_before=", health_before, " hp_after=", enemy.get("hp"))
	ok = ok and damage_received
	var death_health_before: float = float(enemy.get("hp"))
	enemy.call("hit", death_health_before + 1.0, Vector3.FORWARD, true)
	var death_clip: String = str(model.get("current"))
	var death_length: float = model.call("clip_length", death_clip)
	var hips_idx := skel.find_bone("mixamorig_Hips")
	var hips_before: Vector3 = skel.get_bone_global_pose(hips_idx).origin
	await get_tree().create_timer(0.4).timeout
	var death_started: bool = bool(enemy.get("dead")) and death_clip in ["dood1", "dood2"] and model.get("anim").current_animation_position > 0.15
	var death_pose_changed: bool = skel.get_bone_global_pose(hips_idx).origin.distance_to(hips_before) > 0.01
	await get_tree().create_timer(maxf(0.0, death_length - 0.4) + 0.15).timeout
	var death_finished: bool = not model.get("anim").is_playing()
	var death_ok := death_length > 0.0 and death_started and death_pose_changed and death_finished
	print("ASSAULT_MESHY_DEATH_TEST=", death_ok, " clip=", death_clip, " length_s=", death_length, " started=", death_started, " changed=", death_pose_changed, " finished=", death_finished)
	ok = ok and death_ok
	enemy.queue_free()
	main.queue_free()
	print("ASSAULT_MESHY_WEAPON_TEST=", ok)
	get_tree().quit(0 if ok else 1)
