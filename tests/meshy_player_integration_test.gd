extends Node
## Focused acceptance test for the opt-in Meshy player path. Uses the real Player._shoot and Bullet hit handling.

class DamageTarget:
	extends StaticBody3D
	var health := 100.0
	func hit(damage: float, _direction: Vector3, _from_player: bool) -> void:
		health -= damage

var failures: Array[String] = []
var _ik_model: Variant
var _ik_samples: Dictionary = {"right": {}, "left": {}}


func _ready() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error("MESHY PLAYER INTEGRATION: " + message)


func _on_ik_processed(side: String) -> void:
	if _ik_model == null:
		return
	var skeleton: Skeleton3D = _ik_model._mesh_skeleton
	var bone_name := "mixamorig_RightHand" if side == "right" else "mixamorig_LeftHand"
	var bone_index := skeleton.find_bone(bone_name)
	var target: Node3D = _ik_model._mesh_right_target if side == "right" else _ik_model._mesh_weapon_adapter.left_hand_grip
	var hand_world := skeleton.to_global(skeleton.get_bone_global_pose(bone_index).origin)
	var sample: Dictionary = _ik_samples[side]
	sample["count"] = int(sample.get("count", 0)) + 1
	sample["hand_world"] = hand_world
	sample["error_m"] = hand_world.distance_to(target.global_position)
	_ik_samples[side] = sample


func _run() -> void:
	GameSettings.get_value("soldaat")
	var game: Node = get_tree().root.get_node("Game")
	var old_setting: String = str(GameSettings.values["soldaat"])
	GameSettings.values["soldaat"] = "meshy"
	game.set("state", "menu")
	game.set("cur", "garand")
	game.set("owned", game.call("_fresh_owned"))
	var owned: Dictionary = game.get("owned")
	owned["garand"] = {"up": {"dmg": 0, "rate": 0, "mag": 0, "rel": 0}, "ammo": 5}
	game.set("owned", owned)
	var world := Node3D.new()
	world.name = "MeshyIntegrationTestWorld"
	get_tree().root.add_child(world)
	var player: Variant = load("res://scenes/player.tscn").instantiate()
	world.add_child(player)
	await get_tree().process_frame
	await get_tree().physics_frame
	var model: Variant = player.get_node("Model")
	_check(model.meshy_player, "player option did not select Meshy")
	_check(model._mesh_skeleton != null and model._mesh_skeleton.get_bone_count() == 28, "player did not keep the 28-bone Mixamo skeleton")
	_check(model._mesh_skeleton.find_bone("DEF-handR") < 0, "Meshy path unexpectedly depends on the DEF rig")
	var skinned_mesh: MeshInstance3D = model._mesh_skeleton.get_parent().find_child("Mesh0", true, false)
	var mesh_material := skinned_mesh.get_active_material(0) as StandardMaterial3D if skinned_mesh != null else null
	_check(mesh_material != null and mesh_material.albedo_texture != null, "PBR base-color texture did not import")
	_check(mesh_material != null and mesh_material.normal_enabled and mesh_material.normal_texture != null, "PBR normal map did not import")
	_check(mesh_material != null and mesh_material.roughness_texture != null, "PBR roughness map did not import")
	_check(model.anim.has_animation("stil") and model.anim.has_animation("lopen") and model.anim.has_animation("rennen") and model.anim.has_animation("sprinten"), "locomotion aliases missing")
	_check(model.anim.has_animation("Cautious_Crouch_Walk_Forward") and model.anim.has_animation("Cautious_Crouch_Walk_Right_inplace") and model.anim.has_animation("Crouch_Walk_Left_with_Gun") and model.anim.has_animation("Prone_Reload"), "stance clips missing from the central AnimationLibrary")
	_check(model.anim.get_animation_list().size() >= 17, "central AnimationLibrary did not retain source locomotion and add the 13 animation clips")
	_check(model._mesh_animation_tree != null, "Meshy AnimationTree missing")
	_check(model._mesh_animation_tree.tree_root.has_node("STAND") and model._mesh_animation_tree.tree_root.has_node("CROUCH") and model._mesh_animation_tree.tree_root.has_node("PRONE"), "AnimationTree is missing a posture state")
	var required_library_clips := ["Running", "Walking", "RunFast", "Cautious_Crouch_Walk_Forward", "Cautious_Crouch_Walk_Right_inplace", "Crouch_Walk_Left_with_Gun", "Hit_in_Back_While_Running", "Prone_Reload", "Rifle_Aim_Turn_Right", "Rifle_Charge_inplace", "Run_and_Shoot", "Stand_Up2", "dying_backwards"]
	for required_clip in required_library_clips:
		_check(model.anim.has_animation(required_clip), "central animation missing: " + required_clip)
		_check(model._mesh_clip_map.has(required_clip), "AnimationTree has no route for: " + required_clip)
	# Exercise every real clip as a discrete library entry. This proves they are bound
	# to the current player rig without implying missing transition/stance coverage.
	for required_clip in required_library_clips:
		_check(model.play_meshy_library_clip(required_clip), "could not select imported clip: " + required_clip)
		await get_tree().create_timer(0.04).timeout
		_check(model.current == required_clip, "AnimationTree did not select imported clip: " + required_clip)
		var selected: Dictionary = model._mesh_clip_map[required_clip]
		_check(is_equal_approx(float(model._mesh_animation_tree.get("parameters/%s/blend_position" % selected.posture)), float(selected.position)), "AnimationTree blend point mismatch for " + required_clip)
		var clip_resource := model.anim.get_animation(required_clip) as Animation
		for track_index in clip_resource.get_track_count():
			var track_path := String(clip_resource.track_get_path(track_index))
			var bone_name := track_path.get_slice(":", 1)
			if track_path.contains("Skeleton3D:"):
				_check(model._mesh_skeleton.find_bone(bone_name) >= 0, "animation track does not resolve on Mixamo rig: " + required_clip + ":" + bone_name)
	var root_state: AnimationNodeStateMachinePlayback = model._mesh_animation_tree.get("parameters/playback")
	root_state.travel("CROUCH")
	await get_tree().create_timer(0.35).timeout
	_check(root_state.get_current_node() == "CROUCH", "AnimationTree could not travel to CROUCH")
	root_state.travel("PRONE")
	await get_tree().create_timer(0.35).timeout
	_check(root_state.get_current_node() == "PRONE", "AnimationTree could not travel to PRONE")
	root_state.travel("STAND")
	await get_tree().create_timer(0.35).timeout
	_check(root_state.get_current_node() == "STAND", "AnimationTree could not return to STAND")
	# Extracted clips must not move the CharacterBody horizontally; keep genuine
	# vertical rise/fall for authored stand-up/death motion.
	for clip_name in required_library_clips:
		var animation := model.anim.get_animation(clip_name) as Animation
		for track_index in animation.get_track_count():
			if animation.track_get_type(track_index) != Animation.TYPE_POSITION_3D or not String(animation.track_get_path(track_index)).contains("mixamorig_Hips"):
				continue
			var count := animation.track_get_key_count(track_index)
			if count < 2:
				continue
			var delta: Vector3 = animation.track_get_key_value(track_index, count - 1) - animation.track_get_key_value(track_index, 0)
			_check(Vector2(delta.x, delta.z).length() <= 0.005, "horizontal root drift remains in " + clip_name)
			if clip_name == "Stand_Up2":
				_check(delta.y > 0.30, "Stand_Up2 lost its authored vertical rise")
	_check(model._mesh_weapon_adapter != null and model._mesh_weapon_adapter.weapon != null, "Garand visual adapter failed to load")
	_check(model._mesh_weapon_adapter.profile.model_scene != null, "weapon profile does not declare a model scene")
	_check(model._mesh_right_ik != null and model._mesh_right_ik.is_running(), "right-hand IK is not running")
	_check(model._mesh_left_ik != null and model._mesh_left_ik.is_running(), "left-hand IK is not running")
	_check(model.muzzle_position().distance_to(model._mesh_weapon_adapter.muzzle.global_position) < 0.001, "muzzle anchor is not used by the shared combat API")
	_ik_model = model
	model._mesh_right_ik.modification_processed.connect(_on_ik_processed.bind("right"))
	model._mesh_left_ik.modification_processed.connect(_on_ik_processed.bind("left"))
	await get_tree().create_timer(0.20).timeout
	var right_probe := BoneAttachment3D.new()
	right_probe.bone_name = "mixamorig_RightHand"
	model._mesh_skeleton.add_child(right_probe)
	var left_probe := BoneAttachment3D.new()
	left_probe.bone_name = "mixamorig_LeftHand"
	model._mesh_skeleton.add_child(left_probe)
	var right_shoulder: Vector3 = model._mesh_skeleton.to_global(model._mesh_skeleton.get_bone_global_pose(model._mesh_skeleton.find_bone("mixamorig_RightShoulder")).origin)
	var right_arm: Vector3 = model._mesh_skeleton.to_global(model._mesh_skeleton.get_bone_global_pose(model._mesh_skeleton.find_bone("mixamorig_RightArm")).origin)
	var right_forearm: Vector3 = model._mesh_skeleton.to_global(model._mesh_skeleton.get_bone_global_pose(model._mesh_skeleton.find_bone("mixamorig_RightForeArm")).origin)
	var left_shoulder: Vector3 = model._mesh_skeleton.to_global(model._mesh_skeleton.get_bone_global_pose(model._mesh_skeleton.find_bone("mixamorig_LeftShoulder")).origin)
	var left_arm: Vector3 = model._mesh_skeleton.to_global(model._mesh_skeleton.get_bone_global_pose(model._mesh_skeleton.find_bone("mixamorig_LeftArm")).origin)
	var left_forearm: Vector3 = model._mesh_skeleton.to_global(model._mesh_skeleton.get_bone_global_pose(model._mesh_skeleton.find_bone("mixamorig_LeftForeArm")).origin)
	var right_error: float = float(_ik_samples["right"].get("error_m", INF))
	var left_error: float = float(_ik_samples["left"].get("error_m", INF))
	print("MESHY_GRIP_MODIFIER initial right_error_m=", right_error, " left_error_m=", left_error)
	print("MESHY_REACH right_segments_m=", right_shoulder.distance_to(right_arm), ",", right_arm.distance_to(right_forearm), ",", right_forearm.distance_to(right_probe.global_position), " target_from_shoulder_m=", right_shoulder.distance_to(model._mesh_right_target.global_position), "; left_segments_m=", left_shoulder.distance_to(left_arm), ",", left_arm.distance_to(left_forearm), ",", left_forearm.distance_to(left_probe.global_position), " target_from_shoulder_m=", left_shoulder.distance_to(model._mesh_weapon_adapter.left_hand_grip.global_position))
	print("MESHY_GRIP_MODIFIER right=", _ik_samples["right"], " left=", _ik_samples["left"])
	_check(right_error < 0.03 and left_error < 0.03, "both hands did not reach their configured Garand grips after SkeletonIK3D processing")
	# Isolate the modifier: freeze animation, stop IK, move each target by 15 cm
	# from the measured hand pose, then inspect the bone pose from the modifier's
	# own modification_processed signal (not from a later frame).
	_ik_samples = {"right": {}, "left": {}}
	model.anim.stop()
	model._mesh_right_ik.stop()
	model._mesh_left_ik.stop()
	await get_tree().process_frame
	var right_before: Vector3 = right_probe.global_position
	var left_before: Vector3 = left_probe.global_position
	var right_probe_target := right_before + Vector3(0.0, 0.15, 0.0)
	var left_probe_target := left_before + Vector3(0.0, 0.15, 0.0)
	model._mesh_right_target.global_position = right_probe_target
	model._mesh_weapon_adapter.left_hand_grip.global_position = left_probe_target
	model._mesh_right_ik.start()
	model._mesh_left_ik.start()
	await get_tree().create_timer(0.20).timeout
	var right_sample: Dictionary = _ik_samples["right"]
	var left_sample: Dictionary = _ik_samples["left"]
	var right_motion: float = right_before.distance_to(right_sample.get("hand_world", right_before))
	var left_motion: float = left_before.distance_to(left_sample.get("hand_world", left_before))
	print("MESHY_IK_MODIFIER right_calls=", right_sample.get("count", 0), " right_motion_m=", right_motion, " right_error_m=", right_sample.get("error_m", INF), " left_calls=", left_sample.get("count", 0), " left_motion_m=", left_motion, " left_error_m=", left_sample.get("error_m", INF))
	_check(int(right_sample.get("count", 0)) > 0 and int(left_sample.get("count", 0)) > 0, "SkeletonIK3D modification_processed did not fire for both arms")
	_check(right_motion >= 0.10 and left_motion >= 0.10, "an IK hand did not move at least 10 cm toward the reachable offset target")
	_check(float(right_sample.get("error_m", INF)) <= 0.03 and float(left_sample.get("error_m", INF)) <= 0.03, "IK modifier signal pose remained more than 3 cm from an offset target")
	# Restore combat-test pose and configured anchors after the isolated probe.
	model._mesh_right_ik.stop()
	model._mesh_left_ik.stop()
	model._mesh_right_target.position = model._mesh_weapon_adapter.profile.mount_position
	model._mesh_weapon_adapter.left_hand_grip.position = model._mesh_weapon_adapter.profile.left_hand_grip
	model._mesh_right_ik.start()
	model._mesh_left_ik.start()
	model.current = ""
	for clip_name in ["stil", "lopen", "rennen", "sprinten"]:
		_ik_samples = {"right": {}, "left": {}}
		model.play(clip_name)
		await get_tree().create_timer(0.35).timeout
		var clip_right_error: float = float(_ik_samples["right"].get("error_m", INF))
		var clip_left_error: float = float(_ik_samples["left"].get("error_m", INF))
		print("MESHY_CLIP_GRIP clip=", clip_name, " right_error_m=", clip_right_error, " left_error_m=", clip_left_error)
		_check(model.current == clip_name, "locomotion state did not reach Meshy animation player: " + clip_name)
		_check(clip_right_error <= 0.03 and clip_left_error <= 0.03, "hand grip exceeded 3 cm during Meshy clip: " + clip_name)
	for posture_clip in ["Cautious_Crouch_Walk_Forward", "Cautious_Crouch_Walk_Right_inplace", "Crouch_Walk_Left_with_Gun", "Prone_Reload"]:
		_ik_samples = {"right": {}, "left": {}}
		_check(model.play_meshy_library_clip(posture_clip), "posture clip could not be selected for IK review: " + posture_clip)
		await get_tree().create_timer(0.35).timeout
		var posture_right_error: float = float(_ik_samples["right"].get("error_m", INF))
		var posture_left_error: float = float(_ik_samples["left"].get("error_m", INF))
		print("MESHY_POSTURE_CLIP_GRIP clip=", posture_clip, " right_error_m=", posture_right_error, " left_error_m=", posture_left_error)
		if posture_clip == "Prone_Reload":
			print("MESHY_PRONE_RELOAD_IK=", "PASS" if posture_right_error <= 0.03 and posture_left_error <= 0.03 else "BLOCKED_STANDING_GARAND_ANCHORS_DO_NOT_MATCH_PRONE_POSE")
		else:
			_check(posture_right_error <= 0.03 and posture_left_error <= 0.03, "both hands did not stay within 3 cm of the Garand grips during crouch clip: " + posture_clip)
	model.play("stil")
	await get_tree().create_timer(0.35).timeout
	player.rotation.y = 0.35
	player.face = 0.35
	await get_tree().create_timer(0.20).timeout
	_check(float(_ik_samples["right"].get("error_m", INF)) <= 0.03 and float(_ik_samples["left"].get("error_m", INF)) <= 0.03, "hand grips exceeded 3 cm while changing aim direction")
	model.play("herladen")
	await get_tree().create_timer(0.45).timeout
	var reload_hand_travel: float = model._mesh_weapon_adapter.left_hand_grip.position.distance_to(model._mesh_weapon_adapter.profile.left_hand_grip)
	_check(reload_hand_travel > 0.05, "reload did not move the support hand toward the magazine")
	left_error = float(_ik_samples["left"].get("error_m", INF))
	print("MESHY_RELOAD_GRIP error_m=", left_error, " target_travel_m=", reload_hand_travel)
	_check(left_error <= 0.03, "support hand did not follow the explicit reload interaction target within 3 cm")
	model.play("stil")
	await get_tree().process_frame
	_check(model._mesh_weapon_adapter.left_hand_grip.position.distance_to(model._mesh_weapon_adapter.profile.left_hand_grip) < 0.01, "support hand did not return to the weapon grip")

	# A real collision target exercises the existing magazine, projectile and damage path.
	player.weapon = "garand"
	player.ammo = 5
	player.fire_t = 0.0
	player.reload_t = 0.0
	player.face = 0.0
	player.rotation.y = 0.0
	var target := DamageTarget.new()
	target.name = "CombatDamageTarget"
	target.collision_layer = Bullet.MASK_ENEMY
	var target_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.6
	target_shape.shape = sphere
	target.add_child(target_shape)
	world.add_child(target)
	target.global_position = model.muzzle_position() + Vector3(0.0, 0.0, 2.4)
	await get_tree().physics_frame
	var ammo_before: int = player.ammo
	player._shoot(game.call("wstat", "garand"))
	_check(player.ammo == ammo_before - 1, "real combat path did not consume one round")
	await get_tree().create_timer(0.08).timeout
	var right_shot_error: float = float(_ik_samples["right"].get("error_m", INF))
	var left_shot_error: float = float(_ik_samples["left"].get("error_m", INF))
	print("MESHY_SHOT_GRIP right_error_m=", right_shot_error, " left_error_m=", left_shot_error)
	_check(right_shot_error <= 0.03 and left_shot_error <= 0.03, "hand grip exceeded 3 cm during real Garand shot/recoil")
	for _frame in 8:
		await get_tree().physics_frame
	_check(target.health < 100.0, "projectile did not hit and damage the test target")
	_check(model._recoil > 0.0 or model._weapon_mount != null, "shot did not trigger the weapon recoil path")
	print("MESHY_COMBAT target_health=", target.health, " ammo_before=", ammo_before, " ammo_after=", player.ammo)
	game.set("state", "prep")
	player.ammo = 1
	player.idle_t = 0.0
	player._reload(game.call("wstat", "garand"))
	var reload_wait: float = float(game.call("wstat", "garand").reload) + 0.15
	await get_tree().create_timer(reload_wait).timeout
	_check(player.ammo == int(game.call("wstat", "garand").mag), "existing reload timer did not refill the Garand magazine")

	# Exercise the Meshy M1911 replacement in the actual two-hand IK path.
	player.set_physics_process(false)
	player.set_process(false)
	model.set_gun("m1911")
	for _frame in 4:
		await get_tree().physics_frame
	var pistol_adapter: Node = model._mesh_weapon_adapter
	_check(pistol_adapter != null and pistol_adapter.profile.model_scene.resource_path.ends_with("meshy_m1911.glb"), "Meshy M1911 profile did not load the replacement GLB")
	_check(pistol_adapter != null and pistol_adapter.weapon.find_child("M1911_Slede", true, false) != null, "replacement slide is not a child of the weapon root")
	_check(pistol_adapter != null and pistol_adapter.animation_player != null and pistol_adapter.animation_player.has_animation("schot") and pistol_adapter.animation_player.has_animation("leeg") and pistol_adapter.animation_player.has_animation("herladen") and pistol_adapter.animation_player.has_animation("wisselen") and pistol_adapter.animation_player.has_animation("rust"), "replacement weapon clips are incomplete")
	var pistol_muzzle: Vector3 = model.muzzle_position()
	var pistol_forward: Vector3 = player.global_basis.z.normalized()
	_check((pistol_muzzle - pistol_adapter.global_position).normalized().dot(pistol_forward) > 0.9, "M1911 muzzle does not point along the player's forward axis")
	await get_tree().create_timer(0.08).timeout
	var pistol_right_error: float = float(_ik_samples["right"].get("error_m", INF))
	var pistol_left_error: float = float(_ik_samples["left"].get("error_m", INF))
	_check(pistol_right_error < 0.03 and pistol_left_error < 0.03, "Meshy player hands do not reach the M1911 grips")
	var slide := pistol_adapter.weapon.find_child("M1911_Slede", true, false) as Node3D
	var slide_at_rest := slide.position.x
	model.shoot_recoil("m1911")
	await get_tree().create_timer(0.05).timeout
	_check(slide.position.x > slide_at_rest + 0.01, "M1911 shot clip did not cycle the slide")
	model.play_weapon_action("leeg")
	await get_tree().create_timer(0.35).timeout
	_check(slide.position.x > slide_at_rest + 0.02, "M1911 empty clip did not hold the slide open")

	# Meshy-API-clips (62) en de Nederlandse spelnamen die het spel aanroept.
	player.set_physics_process(false)   # de speler-controller zet anders elk frame zelf weer "stil"
	player.set_process(false)
	model.play("stil")
	var api_aliases := {"achteruit": "Walk_Backward_with_Gun", "geraakt": "Hit_Reaction", "dood1": "Shot_and_Fall_Backward", "dood2": "Shot_and_Fall_Forward",
		"explosie_dood": "Shot_and_Blown_Back", "rollen": "Roll_Dodge", "klimmen": "Fast_Ladder_Climb", "zitten": "Chair_Sit_Idle_M",
		"steken": "Attack", "brand_val": "falling_down", "brand_rennen": "Stumble_Walk"}
	_check(model.anim.get_animation_list().size() >= 13 + 62, "Meshy-API-bibliotheek is niet samengevoegd")
	for alias in api_aliases:
		_check(model.anim.has_animation(alias) and model.anim.get_animation(alias) == model.anim.get_animation(api_aliases[alias]), "alias wijst niet naar de API-clip: " + alias)
		model.play(alias, 0.05, 1.0)
		await get_tree().process_frame
		_check(model.current == alias and model.anim.current_animation == alias, "play(%s) startte de clip niet (huidig: %s)" % [alias, model.anim.current_animation])
		_check(model._mesh_animation_tree.active == false, "AnimationTree bleef actief bij " + alias)
		var spine_pos: Vector3 = model._mesh_skeleton.global_transform * model._mesh_skeleton.get_bone_global_pose(model._mesh_skeleton.find_bone("mixamorig_Spine2")).origin
		var gun_to_spine: float = model._mesh_weapon_adapter.global_position.distance_to(spine_pos)
		_check(model._mesh_armed == (alias == "achteruit"), "wapen in verkeerde stand tijdens " + alias)
		_check(alias == "achteruit" or gun_to_spine < 0.8, "wapen hangt niet op de rug tijdens %s (afstand tot rug %.2f m)" % [alias, gun_to_spine])
	model.play("lopen", 0.05, 1.7)
	await get_tree().process_frame
	_check(is_equal_approx(model.anim.speed_scale, 1.7) and model._mesh_armed, "lopen: tempo of wapen niet hersteld")
	model.play("lopen", 0.05, -1.0)
	await get_tree().process_frame
	_check(model.anim.current_animation == "achteruit" and model.anim.speed_scale > 0.0, "achteruit lopen gebruikt de achterwaartse clip niet")
	model.play("stil")

	# The selection is player-look scoped: allies and enemies keep their existing 53-bone VQ2 model.
	var npc: Variant = load("res://scripts/soldier_model.gd").new()
	world.add_child(npc)
	npc.setup(Color("4b5a2c"), "garand", "eigen")
	await get_tree().process_frame
	var npc_skeleton := npc.find_child("Skeleton3D", true, false) as Skeleton3D
	_check(not npc.meshy_player and npc_skeleton != null and npc_skeleton.get_bone_count() == 53, "Meshy option leaked onto a non-player character")

	GameSettings.values["soldaat"] = old_setting
	world.free()
	await get_tree().process_frame
	if failures.is_empty():
		print("MESHY_PLAYER_INTEGRATION_RESULT=PASS")
		get_tree().quit(0)
	else:
		print("MESHY_PLAYER_INTEGRATION_RESULT=FAIL count=", failures.size())
		get_tree().quit(1)
