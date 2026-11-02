extends SceneTree
const SCENE_PATH := "res://source_assets/enemy_assault/rig_test/enemy_assault_rigged_test.glb"
const LIB_PATH := "res://resources/animations/meshy_player_animation_library.res"
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	var root := packed.instantiate()
	get_root().add_child(root)
	var skeleton := _find_skeleton(root)
	var player := AnimationPlayer.new()
	player.root_node = NodePath("..")
	root.add_child(player)
	var source := load(LIB_PATH) as AnimationLibrary
	var lib := AnimationLibrary.new()
	for clip in ["Walking", "Rifle_Aim_Turn_Right", "dying_backwards"]:
		if source.has_animation(clip): lib.add_animation(clip, source.get_animation(clip))
	player.add_animation_library("", lib)
	var passed := skeleton != null and skeleton.get_bone_count() == 28
	print("ASSAULT_BONES=", skeleton.get_bone_name(0), ",", skeleton.get_bone_name(1), ",", skeleton.get_bone_name(15))
	for clip in lib.get_animation_list():
		var animation := lib.get_animation(clip)
		player.play(clip)
		player.advance(min(0.3, animation.length))
		var changed := false
		for i in skeleton.get_bone_count():
			if skeleton.get_bone_pose(i).origin.length() > 0.0001 or not skeleton.get_bone_pose(i).basis.is_equal_approx(Basis.IDENTITY): changed = true
		print("ASSAULT_CLIP ", clip, " changed_pose=", changed, " tracks=", animation.get_track_count())
		passed = passed and changed
	print("ASSAULT_CLIPS_PASSED=", passed, " skeleton_path=", skeleton.get_path())
	quit(0 if passed else 1)
func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D: return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null: return found
	return null
