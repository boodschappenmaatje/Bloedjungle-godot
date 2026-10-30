extends Node3D

const MODEL_SCENE: PackedScene = preload("res://assets/Meshy_Jungle_Commando.glb")
const WEAPONS_SCENE: PackedScene = preload("res://assets/Bloedjungle_Wapens.glb")
const CLIPS := ["Idle", "Walking", "Running", "RunFast"]
const GAMEPLAY_FOV := 45.0
const SOLDIER_SCALE := 1.2

var actor: CharacterBody3D
var model: Node3D
var skeleton: Skeleton3D
var anim_player: AnimationPlayer
var anim_tree: AnimationTree
var action_player: AnimationPlayer
var playback: AnimationNodeStateMachinePlayback
var status_label: Label
var camera: Camera3D
var weapon_anchor: BoneAttachment3D
var weapon_mount: Node3D
var weapon: Node3D
var muzzle_anchor: Marker3D
var muzzle_flash: MeshInstance3D
var muzzle_light: OmniLight3D
var right_grip_target: Marker3D
var left_grip_target: Marker3D
var left_hand_anchor: BoneAttachment3D
var right_arm_ik: SkeletonIK3D
var left_arm_ik: SkeletonIK3D
var requested_clip := "Idle"
var validation_mode := "--meshy-check" in OS.get_cmdline_user_args() or "--meshy-benchmark" in OS.get_cmdline_user_args()
var preview_locked := false
var combat_view := false
var zoom_step := 0

func _ready() -> void:
	process_priority = 100
	_build_world()
	_build_player()
	_build_animation_system()
	_build_controls()
	set_clip("Idle")
	if "--meshy-ik-static" in OS.get_cmdline_user_args():
		anim_tree.active = false
	if validation_mode:
		call_deferred("_run_validation")

func _build_world() -> void:
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("263c2f")
	sky_material.sky_horizon_color = Color("b5a574")
	sky_material.ground_bottom_color = Color("171b12")
	sky_material.ground_horizon_color = Color("8c8356")
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b9c09d")
	environment.ambient_light_energy = 0.7
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = environment
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_color = Color("fff0ce")
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)

	var ground := MeshInstance3D.new()
	ground.name = "JungleGround"
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	ground.mesh = plane
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color("46452d")
	ground_material.roughness = 0.95
	ground.material_override = ground_material
	ground.position.y = -0.04
	add_child(ground)
	var floor_body := StaticBody3D.new()
	floor_body.name = "GroundCollider"
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(80.0, 0.08, 80.0)
	floor_shape.shape = floor_box
	floor_shape.position.y = -0.04
	floor_body.add_child(floor_shape)
	add_child(floor_body)

	camera = Camera3D.new()
	camera.name = "GameplayCamera"
	camera.fov = GAMEPLAY_FOV
	camera.current = true
	add_child(camera)

func _build_player() -> void:
	actor = CharacterBody3D.new()
	actor.name = "MeshyPlayer"
	actor.floor_snap_length = 0.25
	actor.floor_max_angle = deg_to_rad(50.0)
	add_child(actor)
	var collider := CollisionShape3D.new()
	collider.name = "BodyCollider"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.92
	collider.shape = capsule
	collider.position.y = capsule.height * 0.5
	actor.add_child(collider)

	model = MODEL_SCENE.instantiate() as Node3D
	model.name = "MeshyModel"
	model.scale = Vector3.ONE * SOLDIER_SCALE
	actor.add_child(model)
	var extra := model.find_child("Icosphere", true, false)
	if extra is Node3D:
		extra.hide()
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	anim_player = model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	print("MESHY_RIG bones=", skeleton.get_bone_count(), " clips=", anim_player.get_animation_list())
	for i in range(skeleton.get_bone_count()):
		print("MESHY_BONE ", i, " ", skeleton.get_bone_name(i))
	print("MESHY_SKELETON modifier_mode=", skeleton.modifier_callback_mode_process)
	_attach_weapon()

func _attach_weapon() -> void:
	weapon_anchor = BoneAttachment3D.new()
	weapon_anchor.name = "RightHandWeaponAnchor"
	weapon_anchor.bone_name = "mixamorig_RightHand"
	skeleton.add_child(weapon_anchor)
	var holder := WEAPONS_SCENE.instantiate() as Node3D
	weapon = holder.find_child("Garand", true, false) as Node3D
	if weapon == null:
		push_error("Garand node missing from Bloedjungle weapon pack")
		holder.queue_free()
		return
	weapon.get_parent().remove_child(weapon)
	weapon.owner = null
	weapon.name = "GarandMeshyGrip"
	holder.queue_free()
	weapon_mount = Node3D.new()
	weapon_mount.name = "WeaponMount"
	actor.add_child(weapon_mount)
	weapon_mount.add_child(weapon)
	weapon.transform = Transform3D.IDENTITY
	muzzle_anchor = Marker3D.new()
	muzzle_anchor.name = "MuzzlePosition"
	muzzle_anchor.position = Vector3(0.0, 0.07, -1.08)
	weapon.add_child(muzzle_anchor)
	var flash_mesh := SphereMesh.new()
	flash_mesh.radius = 0.045
	flash_mesh.height = 0.09
	var flash_material := StandardMaterial3D.new()
	flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_material.albedo_color = Color(1.0, 0.58, 0.12)
	flash_material.emission_enabled = true
	flash_material.emission = Color(1.0, 0.36, 0.04)
	flash_material.emission_energy_multiplier = 5.0
	muzzle_flash = MeshInstance3D.new()
	muzzle_flash.name = "MuzzleFlash"
	muzzle_flash.mesh = flash_mesh
	muzzle_flash.material_override = flash_material
	muzzle_flash.position = muzzle_anchor.position
	muzzle_flash.visible = false
	weapon.add_child(muzzle_flash)
	muzzle_light = OmniLight3D.new()
	muzzle_light.name = "MuzzleLight"
	muzzle_light.position = muzzle_anchor.position
	muzzle_light.light_color = Color(1.0, 0.48, 0.1)
	muzzle_light.light_energy = 2.5
	muzzle_light.omni_range = 2.4
	muzzle_light.visible = false
	weapon.add_child(muzzle_light)
	_setup_arm_ik()
	print("MESHY_WEAPON anchor=", weapon_anchor.bone_name, " local=", weapon.transform, " muzzle_world=", muzzle_anchor.global_position)

func _setup_arm_ik() -> void:
	right_grip_target = Marker3D.new()
	right_grip_target.name = "RightGripTarget"
	right_grip_target.position = Vector3(-0.14, 1.42, 0.05)
	actor.add_child(right_grip_target)
	left_grip_target = Marker3D.new()
	left_grip_target.name = "LeftGripTarget"
	left_grip_target.position = Vector3(-0.08, 1.4, 0.4)
	actor.add_child(left_grip_target)
	if "--meshy-ik-rest" in OS.get_cmdline_user_args():
		right_grip_target.global_position = skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("mixamorig_RightHand")).origin)
		left_grip_target.global_position = skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("mixamorig_LeftHand")).origin)
	var right_pole := Marker3D.new()
	right_pole.name = "RightElbowPole"
	right_pole.position = Vector3(-0.58, 1.18, -0.05)
	actor.add_child(right_pole)
	var left_pole := Marker3D.new()
	left_pole.name = "LeftElbowPole"
	left_pole.position = Vector3(0.58, 1.18, -0.05)
	actor.add_child(left_pole)
	right_arm_ik = _make_arm_ik("RightArmIK", "mixamorig_RightShoulder", "mixamorig_RightArm", "mixamorig_RightHand", right_grip_target, right_pole)
	left_arm_ik = _make_arm_ik("LeftArmIK", "mixamorig_LeftShoulder", "mixamorig_LeftArm", "mixamorig_LeftHand", left_grip_target, left_pole)
	left_hand_anchor = BoneAttachment3D.new()
	left_hand_anchor.name = "LeftHandGripProbe"
	left_hand_anchor.bone_name = "mixamorig_LeftHand"
	skeleton.add_child(left_hand_anchor)

func _make_arm_ik(ik_name: String, root_name: String, _middle_name: String, end_name: String, target: Node3D, _pole: Node3D) -> SkeletonIK3D:
	var ik := SkeletonIK3D.new()
	ik.name = ik_name
	ik.root_bone = root_name
	ik.tip_bone = end_name
	ik.min_distance = 0.01
	ik.max_iterations = 32
	skeleton.add_child(ik)
	ik.target_node = ik.get_path_to(target)
	ik.start()
	print("MESHY_IK name=", ik_name, " active=", ik.active, " running=", ik.is_running(), " target=", ik.target_node, " target_resolves=", ik.get_node_or_null(ik.target_node) == target, " bones=", ik.root_bone, "/", ik.tip_bone)
	return ik

func _build_animation_system() -> void:
	var library := anim_player.get_animation_library("")
	for source_clip in ["Walking", "Running", "RunFast"]:
		var clip := library.get_animation(source_clip)
		clip.loop_mode = Animation.LOOP_LINEAR
	_add_idle_animation(library)

	var machine := AnimationNodeStateMachine.new()
	for clip_name in CLIPS:
		var node := AnimationNodeAnimation.new()
		node.animation = clip_name
		machine.add_node(clip_name, node)
	for from_clip in CLIPS:
		for to_clip in CLIPS:
			if from_clip == to_clip:
				continue
			var transition := AnimationNodeStateMachineTransition.new()
			transition.xfade_time = 0.2
			transition.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_ENABLED
			machine.add_transition(from_clip, to_clip, transition)
	anim_tree = AnimationTree.new()
	anim_tree.name = "AnimationTree"
	anim_tree.tree_root = machine
	actor.add_child(anim_tree)
	anim_tree.anim_player = anim_tree.get_path_to(anim_player)
	anim_tree.active = true
	playback = anim_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	_build_action_animations()

func _build_action_animations() -> void:
	action_player = AnimationPlayer.new()
	action_player.name = "ActionAnimationPlayer"
	action_player.root_node = NodePath("..")
	actor.add_child(action_player)
	action_player.animation_finished.connect(_on_action_finished)
	var library := AnimationLibrary.new()
	var shot := Animation.new()
	shot.resource_name = "Shoot"
	shot.length = 0.24
	var recoil_track := shot.add_track(Animation.TYPE_ROTATION_3D)
	shot.track_set_path(recoil_track, NodePath("WeaponMount/GarandMeshyGrip:rotation"))
	shot.track_insert_key(recoil_track, 0.0, Quaternion.IDENTITY)
	shot.track_insert_key(recoil_track, 0.055, Quaternion.from_euler(Vector3(-0.18, 0.0, 0.0)))
	shot.track_insert_key(recoil_track, 0.24, Quaternion.IDENTITY)
	_add_visibility_track(shot, "WeaponMount/GarandMeshyGrip/MuzzleFlash:visible", false, 0.025, true, 0.22, false)
	_add_visibility_track(shot, "WeaponMount/GarandMeshyGrip/MuzzleLight:visible", false, 0.025, true, 0.22, false)
	library.add_animation("Shoot", shot)
	var reload := Animation.new()
	reload.resource_name = "Reload"
	reload.length = 1.5
	var left_start := left_grip_target.position
	var hand_mag := left_start + Vector3(0.07, -0.18, -0.22)
	var left_track := reload.add_track(Animation.TYPE_POSITION_3D)
	reload.track_set_path(left_track, NodePath("LeftGripTarget:position"))
	reload.track_insert_key(left_track, 0.0, left_start)
	reload.track_insert_key(left_track, 0.35, hand_mag)
	reload.track_insert_key(left_track, 0.9, hand_mag)
	reload.track_insert_key(left_track, 1.5, left_start)
	var reload_weapon_track := reload.add_track(Animation.TYPE_ROTATION_3D)
	reload.track_set_path(reload_weapon_track, NodePath("WeaponMount/GarandMeshyGrip:rotation"))
	reload.track_insert_key(reload_weapon_track, 0.0, Quaternion.IDENTITY)
	reload.track_insert_key(reload_weapon_track, 0.35, Quaternion.from_euler(Vector3(0.08, 0.0, 0.0)))
	reload.track_insert_key(reload_weapon_track, 0.9, Quaternion.from_euler(Vector3(0.08, 0.0, 0.0)))
	reload.track_insert_key(reload_weapon_track, 1.5, Quaternion.IDENTITY)
	library.add_animation("Reload", reload)
	action_player.add_animation_library("", library)

func _add_visibility_track(animation: Animation, path: String, initial: bool, flash_on: float, flash_value: bool, flash_off: float, ending: bool) -> void:
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath(path))
	animation.value_track_set_update_mode(track, Animation.UPDATE_DISCRETE)
	animation.track_insert_key(track, 0.0, initial)
	animation.track_insert_key(track, flash_on, flash_value)
	animation.track_insert_key(track, flash_off, ending)

func _add_idle_animation(library: AnimationLibrary) -> void:
	var idle := Animation.new()
	idle.resource_name = "Idle"
	idle.length = 2.4
	idle.loop_mode = Animation.LOOP_LINEAR
	for bone_name in ["mixamorig_Spine2", "mixamorig_Neck", "mixamorig_Head"]:
		var bone_index := skeleton.find_bone(bone_name)
		if bone_index < 0:
			continue
		var track := idle.add_track(Animation.TYPE_ROTATION_3D)
		idle.track_set_path(track, NodePath("target_character/Skeleton3D:" + bone_name))
		var base := skeleton.get_bone_pose_rotation(bone_index)
		var swing := deg_to_rad(0.8 if bone_name == "mixamorig_Spine2" else 0.25)
		var inhale := base * Quaternion(Vector3.RIGHT, swing)
		idle.track_insert_key(track, 0.0, base)
		idle.track_insert_key(track, idle.length * 0.5, inhale)
		idle.track_insert_key(track, idle.length, base)
	library.add_animation("Idle", idle)

func _build_controls() -> void:
	var layer := CanvasLayer.new()
	layer.name = "TestControls"
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(18, 18)
	layer.add_child(panel)
	var stack := VBoxContainer.new()
	panel.add_child(stack)
	status_label = Label.new()
	status_label.text = "Meshy Jungle Commando · Idle"
	stack.add_child(status_label)
	var row := HBoxContainer.new()
	stack.add_child(row)
	for i in range(CLIPS.size()):
		var button := Button.new()
		button.text = "%d · %s" % [i + 1, CLIPS[i]]
		button.pressed.connect(_preview_clip.bind(CLIPS[i]))
		row.add_child(button)
	var help := Label.new()
	help.text = "WASD bewegen · Ctrl lopen · Shift sprint · spatie schieten · R herladen · C camera · wiel zoom · 1–4 preview"
	stack.add_child(help)

func set_clip(clip_name: String) -> void:
	if clip_name not in CLIPS or playback == null:
		return
	if clip_name == requested_clip and playback.get_current_node() == clip_name:
		return
	requested_clip = clip_name
	playback.travel(clip_name)
	if status_label != null:
		status_label.text = "Meshy Jungle Commando · " + clip_name

func _preview_clip(clip_name: String) -> void:
	preview_locked = true
	set_clip(clip_name)

func _physics_process(_delta: float) -> void:
	if validation_mode:
		return
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if input_dir == Vector2.ZERO:
		if Input.is_key_pressed(KEY_W): input_dir.y -= 1.0
		if Input.is_key_pressed(KEY_S): input_dir.y += 1.0
		if Input.is_key_pressed(KEY_A): input_dir.x -= 1.0
		if Input.is_key_pressed(KEY_D): input_dir.x += 1.0
	input_dir = input_dir.normalized()
	var speed := 0.0
	if input_dir.length_squared() > 0.001:
		preview_locked = false
		if Input.is_key_pressed(KEY_SHIFT):
			set_clip("RunFast")
			speed = 4.8
		elif Input.is_key_pressed(KEY_CTRL):
			set_clip("Walking")
			speed = 1.8
		else:
			set_clip("Running")
			speed = 3.2
	elif not preview_locked:
		set_clip("Idle")
	var direction := Vector3(input_dir.x, 0.0, input_dir.y)
	actor.velocity.x = direction.x * speed
	actor.velocity.z = direction.z * speed
	if direction.length_squared() > 0.001:
		actor.rotation.y = atan2(-direction.x, -direction.z)
	if not actor.is_on_floor():
		actor.velocity.y -= 9.8 * _delta
	else:
		actor.velocity.y = 0.0
	actor.move_and_slide()

func _process(delta: float) -> void:
	_sync_weapon_pose()
	_update_camera(delta)

func _sync_weapon_pose() -> void:
	if weapon == null or weapon_anchor == null:
		return
	var weapon_basis := actor.global_transform.basis.orthonormalized() * Basis(Vector3.UP, PI)
	weapon_mount.global_transform = Transform3D(weapon_basis, weapon_anchor.global_position)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		combat_view = event.pressed
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_play_action("Shoot")
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_play_action("Shoot")
		elif event.keycode == KEY_R:
			_play_action("Reload")
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C:
		combat_view = not combat_view
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_step = clampi(zoom_step - 1, -3, 4)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_step = clampi(zoom_step + 1, -3, 4)
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match (event as InputEventKey).keycode:
		KEY_1: _preview_clip("Idle")
		KEY_2: _preview_clip("Walking")
		KEY_3: _preview_clip("Running")
		KEY_4: _preview_clip("RunFast")

func _play_action(action_name: String) -> void:
	if action_player == null or action_player.current_animation == "Reload":
		return
	if action_player.has_animation(action_name):
		muzzle_flash.visible = false
		muzzle_light.visible = false
		action_player.play(action_name, 0.06)

func _on_action_finished(_animation_name: StringName) -> void:
	muzzle_flash.visible = false
	muzzle_light.visible = false
	weapon.rotation = Vector3.ZERO

func _update_camera(_delta: float) -> void:
	var distance := clampf((16.0 if combat_view else 28.0) + float(zoom_step) * 2.5, 8.5, 38.0)
	var elevation := deg_to_rad(48.0 if combat_view else 58.0)
	var target := actor.global_position + Vector3(0.0, 1.2, 0.0)
	camera.far = 220.0
	camera.global_position = actor.global_position + Vector3(0.0, sin(elevation) * distance, cos(elevation) * distance)
	camera.look_at(target)

func _run_validation() -> void:
	await get_tree().process_frame
	var passed := true
	var required := ["Idle", "Walking", "Running", "RunFast"]
	var library := anim_player.get_animation_library("")
	for clip_name in required:
		if not library.has_animation(clip_name):
			push_error("Missing animation: " + clip_name)
			passed = false
			continue
		var before: Array[Transform3D] = []
		for i in range(skeleton.get_bone_count()): before.append(skeleton.get_bone_global_pose(i))
		set_clip(clip_name)
		await get_tree().create_timer(0.55).timeout
		var changed := 0
		var nonunit := 0
		var max_scale_delta := 0.0
		for i in range(skeleton.get_bone_count()):
			var after := skeleton.get_bone_global_pose(i)
			if after.origin.distance_to(before[i].origin) > 0.001 or after.basis.get_euler().distance_to(before[i].basis.get_euler()) > 0.001:
				changed += 1
			var scale := skeleton.get_bone_pose_scale(i)
			var deviation := maxf(absf(scale.x - 1.0), maxf(absf(scale.y - 1.0), absf(scale.z - 1.0)))
			max_scale_delta = maxf(max_scale_delta, deviation)
			if deviation > 0.001: nonunit += 1
		var right_error := weapon_anchor.global_position.distance_to(right_grip_target.global_position)
		var left_error := left_hand_anchor.global_position.distance_to(left_grip_target.global_position)
		var ok := changed > 0 and nonunit == 0 and right_error <= 0.03 and left_error <= 0.03
		print("MESHY_TEST clip=", clip_name, " changed_bones=", changed, "/", skeleton.get_bone_count(), " nonunit_scale_bones=", nonunit, " max_scale_delta=", max_scale_delta, " right_grip_error_m=", right_error, " left_grip_error_m=", left_error, " pass=", ok)
		passed = passed and ok
	action_player.play("Shoot")
	await get_tree().create_timer(0.06).timeout
	var flash_visible := muzzle_flash.visible and muzzle_light.visible
	var shot_recoil := weapon.rotation.x
	print("MESHY_TEST shot_flash=", flash_visible, " recoil_rad=", shot_recoil, " muzzle_world=", muzzle_anchor.global_position)
	passed = passed and flash_visible and absf(shot_recoil) > 0.05
	var reload_hand_start := left_hand_anchor.global_position
	muzzle_flash.visible = false
	muzzle_light.visible = false
	action_player.play("Reload")
	await get_tree().create_timer(0.65).timeout
	var reload_hand_travel := left_hand_anchor.global_position.distance_to(reload_hand_start)
	var reload_left_grip_error := left_hand_anchor.global_position.distance_to(left_grip_target.global_position)
	var reload_target_offset := left_grip_target.position.distance_to(Vector3(-0.08, 1.4, 0.4))
	print("MESHY_TEST reload_hand_travel_m=", reload_hand_travel, " target_offset_m=", reload_target_offset, " hand_target_error_m=", reload_left_grip_error, " authored_action=", action_player.has_animation("Reload"))
	passed = passed and action_player.has_animation("Reload") and reload_target_offset > 0.05 and reload_left_grip_error < 0.03 and reload_hand_travel > 0.05
	await get_tree().create_timer(0.9).timeout
	var reload_return_error := left_grip_target.position.distance_to(Vector3(-0.08, 1.4, 0.4))
	print("MESHY_TEST reload_return_error_m=", reload_return_error)
	passed = passed and reload_return_error < 0.01
	if "--meshy-benchmark" in OS.get_cmdline_user_args():
		var benchmark_start := Time.get_ticks_usec()
		var benchmark_frames := 600
		for _frame in range(benchmark_frames):
			await get_tree().process_frame
		var benchmark_seconds := float(Time.get_ticks_usec() - benchmark_start) / 1_000_000.0
		print("MESHY_DESKTOP_BENCHMARK renderer=", RenderingServer.get_video_adapter_name(), " frames=", benchmark_frames, " seconds=", benchmark_seconds, " average_fps=", float(benchmark_frames) / benchmark_seconds)
	var collider := actor.get_node("BodyCollider") as CollisionShape3D
	print("MESHY_TEST collider=", collider.shape.get_class(), " height=", (collider.shape as CapsuleShape3D).height, " scale=", SOLDIER_SCALE)
	print("MESHY_VALIDATION_RESULT=", "PASS" if passed else "FAIL")
	if "--meshy-capture" in OS.get_cmdline_user_args():
		combat_view = true
		zoom_step = -3
		var preview_dir := ProjectSettings.globalize_path("res://previews")
		DirAccess.make_dir_recursive_absolute(preview_dir)
		for clip_name in required:
			preview_locked = true
			set_clip(clip_name)
			await get_tree().create_timer(0.55).timeout
			var image := get_viewport().get_texture().get_image()
			image.resize(1600, 900)
			var path := preview_dir.path_join("meshy_" + clip_name.to_lower() + ".png")
			image.save_png(path)
			print("MESHY_CAPTURE=", path)
		action_player.play("Shoot")
		await get_tree().create_timer(0.06).timeout
		var shot_image := get_viewport().get_texture().get_image()
		shot_image.resize(1600, 900)
		var shot_path := preview_dir.path_join("meshy_shoot.png")
		shot_image.save_png(shot_path)
		print("MESHY_CAPTURE=", shot_path)
		action_player.play("Reload")
		muzzle_flash.visible = false
		muzzle_light.visible = false
		await get_tree().create_timer(0.65).timeout
		var reload_image := get_viewport().get_texture().get_image()
		reload_image.resize(1600, 900)
		var reload_path := preview_dir.path_join("meshy_reload.png")
		reload_image.save_png(reload_path)
		print("MESHY_CAPTURE=", reload_path)
		await _capture_preview_frames(preview_dir)
	get_tree().quit(0 if passed else 1)

func _capture_preview_frames(preview_dir: String) -> void:
	var frames_dir := preview_dir.path_join("movie_frames")
	DirAccess.make_dir_recursive_absolute(frames_dir)
	var frame_index := 0
	for clip_name in CLIPS:
		preview_locked = true
		set_clip(clip_name)
		for _frame in range(12):
			await get_tree().create_timer(1.0 / 12.0).timeout
			_save_preview_frame(frames_dir, frame_index)
			frame_index += 1
	status_label.text = "Meshy Jungle Commando · Schieten"
	action_player.play("Shoot")
	for _frame in range(4):
		await get_tree().create_timer(1.0 / 12.0).timeout
		_save_preview_frame(frames_dir, frame_index)
		frame_index += 1
	muzzle_flash.visible = false
	muzzle_light.visible = false
	status_label.text = "Meshy Jungle Commando · Herladen"
	action_player.play("Reload")
	for _frame in range(18):
		await get_tree().create_timer(1.0 / 12.0).timeout
		_save_preview_frame(frames_dir, frame_index)
		frame_index += 1
	print("MESHY_MOVIE_FRAMES=", frame_index, " directory=", frames_dir)

func _save_preview_frame(frames_dir: String, frame_index: int) -> void:
	var frame := get_viewport().get_texture().get_image()
	frame.resize(1600, 900)
	var frame_path := frames_dir.path_join("frame_%04d.png" % frame_index)
	frame.save_png(frame_path)
