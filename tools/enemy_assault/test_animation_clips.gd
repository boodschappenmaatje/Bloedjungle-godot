extends SceneTree

const LIBRARIES := [
	"res://resources/animations/meshy_player_animation_library.res",
	"res://resources/animations/meshy_player_animation_library_api.res",
]

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	GameSettings.get_value("soldaat")
	root.get_node("Game").set("state", "menu")
	var enemy: Node = load("res://scenes/enemy.tscn").instantiate()
	enemy.call("setup", "assault", 1)
	enemy.set("dead", true)
	root.add_child(enemy)
	for _frame in 4:
		await process_frame
		await physics_frame
	var model: SoldierModel = enemy.get_node("Model")
	var anim: AnimationPlayer = model.anim
	var skeleton: Skeleton3D = model.get("_mesh_skeleton")
	if skeleton == null or skeleton.get_bone_count() != 28:
		_fail("Assault does not use the expected 28-bone Mixamo rig")
		quit(1)
		return
	var clips: Array[String] = []
	for path in LIBRARIES:
		var library := load(path) as AnimationLibrary
		if library == null:
			_fail("Could not load animation library: " + path)
			continue
		print("ASSAULT_ANIMATION_LIBRARY path=", path, " count=", library.get_animation_list().size())
		for clip in library.get_animation_list():
			if not clips.has(String(clip)):
				clips.append(String(clip))
	clips.sort()
	var inspected := 0
	var bad_tracks := 0
	for clip in clips:
		var animation: Animation = anim.get_animation(clip) if anim.has_animation(clip) else null
		if animation == null or not model.play_meshy_library_clip(clip):
			_fail("Clip is not available through the Assault inspection hook: " + clip)
			continue
		await process_frame
		anim.advance(minf(0.1, animation.length * 0.5))
		inspected += 1
		for track in animation.get_track_count():
			var path := String(animation.track_get_path(track))
			if not path.contains(":"):
				bad_tracks += 1
				continue
			var bone := path.get_slice(":", 1)
			if skeleton.find_bone(bone) < 0:
				bad_tracks += 1
		if animation.get_track_count() == 0:
			bad_tracks += 1
	print("ASSAULT_ANIMATION_INSPECTION clips=", inspected, " unique_source_clips=", clips.size(), " bad_tracks=", bad_tracks)
	_check(inspected == 75, "expected all 75 supplied clips to be inspectable")
	_check(bad_tracks == 0, "retargeted animation tracks must point to bones on the Assault rig")
	var adapter: Node3D = model.get("_mesh_weapon_adapter")
	var right_ik: SkeletonIK3D = model.get("_mesh_right_ik")
	var left_ik: SkeletonIK3D = model.get("_mesh_left_ik")
	for clip in ["Combat_Stance", "Walk_Backward_with_Gun", "Walk_Left_with_Gun", "Run_and_Shoot", "Rifle_Charge_inplace", "Cautious_Crouch_Walk_Forward", "Cautious_Crouch_Walk_Left", "Cautious_Crouch_Walk_Right_inplace", "Crouch_Walk_Left_with_Gun"]:
		var worst: Dictionary = await _measure_held_clip(model, anim, skeleton, adapter, right_ik, left_ik, clip)
		var held := float(worst.right) < 0.05 and float(worst.left) < 0.05
		print("ASSAULT_ANIMATION_HAND_HOLD clip=", clip, " max_error_m=", worst.right, "/", worst.left, " passed=", held)
		_check(held, "weapon hand IK lost its anchor while playing " + clip)
	for mapping in [{"game": "lopen", "source": "Cautious_Crouch_Walk_Forward", "animation": "Cautious_Crouch_Walk_Forward"}, {"game": "rennen", "source": "Run_and_Shoot", "animation": "Run_and_Shoot"}, {"game": "achteruit", "source": "achteruit", "animation": "achteruit"}]:
		model.play("stil", 0.08)
		await create_timer(0.18).timeout
		model.play(String(mapping.game), 0.08, 1.0)
		var selected: bool = model.current == String(mapping.source) and bool(model.get("_mesh_armed"))
		var movement_worst: Dictionary = await _measure_active_clip(anim, skeleton, model, adapter, right_ik, left_ik, String(mapping.animation))
		var movement_ok: bool = selected and float(movement_worst.right) < 0.05 and float(movement_worst.left) < 0.05
		print("ASSAULT_GAMEPLAY_LOCOMOTION alias=", mapping.game, " source=", mapping.source, " passed=", movement_ok, " max_hand_error_m=", movement_worst.right, "/", movement_worst.left)
		_check(movement_ok, "Assault gameplay locomotion lost its rifle grip for " + String(mapping.game))
	enemy.queue_free()
	main.queue_free()
	print("ASSAULT_ANIMATION_TEST=", failures == 0)
	quit(1 if failures > 0 else 0)


func _hand_error(skeleton: Skeleton3D, bone_name: String, target: Node3D) -> float:
	var index := skeleton.find_bone(bone_name)
	if index < 0 or target == null:
		return INF
	var hand := skeleton.to_global(skeleton.get_bone_global_pose(index).origin)
	return hand.distance_to(target.global_position)


func _measure_held_clip(model: SoldierModel, player: AnimationPlayer, skeleton: Skeleton3D, adapter: Node3D, right_ik: SkeletonIK3D, left_ik: SkeletonIK3D, clip: String) -> Dictionary:
	if not model.play_meshy_library_clip(clip):
		return {"right": INF, "left": INF}
	return await _measure_active_clip(player, skeleton, model, adapter, right_ik, left_ik, clip)


func _measure_active_clip(player: AnimationPlayer, skeleton: Skeleton3D, model: SoldierModel, adapter: Node3D, right_ik: SkeletonIK3D, left_ik: SkeletonIK3D, clip: String) -> Dictionary:
	await create_timer(0.2).timeout
	var animation: Animation = player.get_animation(clip)
	var worst_right := 0.0
	var worst_left := 0.0
	for sample in 12:
		player.seek(animation.length * float(sample) / 12.0, true)
		await process_frame
		await right_ik.modification_processed
		await left_ik.modification_processed
		worst_right = maxf(worst_right, _hand_error(skeleton, "mixamorig_RightHand", model.get("_mesh_right_target")))
		worst_left = maxf(worst_left, _hand_error(skeleton, "mixamorig_LeftHand", adapter.get("left_hand_grip")))
	return {"right": worst_right, "left": worst_left}


func _check(ok: bool, message: String) -> void:
	if not ok:
		_fail(message)


func _fail(message: String) -> void:
	failures += 1
	push_error("ASSAULT ANIMATION TEST: " + message)
