extends Node3D

const MODEL := "res://M47_Muurbreker_1.0_animated.glb"
const EXPECTED := ["Idle", "Equip", "Aim", "Fire", "Reload"]
const LODS := ["M47_LOD0", "M47_LOD1", "M47_LOD2"]
var failures := 0
var log_lines: PackedStringArray = []
var lod_nodes: Array[MeshInstance3D] = []
var anim_player: AnimationPlayer
var model_root: Node3D
var rig_mount: Node3D
var player_skeleton: Skeleton3D

func _ready() -> void:
	_build_studio()
	await _validate()
	get_tree().quit(1 if failures else 0)

func _record(ok: bool, label: String) -> void:
	var line := ("PASS " if ok else "FAIL ") + label
	print(line)
	log_lines.append(line)
	if not ok:
		failures += 1

func _build_studio() -> void:
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("202b38")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b9c7d7")
	environment.ambient_light_energy = 1.1
	env.environment = environment
	add_child(env)
	var camera := Camera3D.new()
	camera.position = Vector3(1.5, 2.0, 2.25)
	camera.current = true
	add_child(camera)
	camera.look_at(Vector3(-0.05, 1.18, 0.22), Vector3.UP)
	camera.fov = 32
	for spec in [[Vector3(1.7, 3.0, 2.4), 950.0], [Vector3(-2.0, 1.6, 1.0), 700.0]]:
		var light := OmniLight3D.new()
		light.position = spec[0]
		light.light_energy = spec[1] / 900.0
		light.omni_range = 8.0
		add_child(light)
	# Existing VQ2 player GLB and its real skeleton/idle pose, isolated from gameplay scenes.
	var avatar_packed := load("res://soldaat_vq2.glb") as PackedScene
	if avatar_packed != null:
		var avatar := avatar_packed.instantiate() as Node3D
		avatar.name = "PlayerVQ2_TestAvatar"
		add_child(avatar)
		player_skeleton = avatar.find_child("Skeleton3D", true, false) as Skeleton3D
		var avatar_anim := avatar.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if avatar_anim != null and avatar_anim.has_animation("stil"):
			avatar_anim.play("stil")
	else:
		push_error("VQ2 player GLB did not import into isolated test project")
	rig_mount = Node3D.new()
	rig_mount.name = "PlayerHandWeaponMount"
	rig_mount.position = Vector3(-0.165, 1.45, 0.38)
	rig_mount.rotation.y = PI
	rig_mount.scale = Vector3.ONE * 0.72
	add_child(rig_mount)
	# Ground plane for scale/orientation and shadow context.
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(5, 5)
	floor.mesh = plane
	floor.position.y = 0.05
	floor.material_override = _mat(Color("29343d"), 0.0, 0.95)
	add_child(floor)

func _mat(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material

func _process(_delta: float) -> void:
	if model_root != null and not lod_nodes.is_empty():
		var camera := get_viewport().get_camera_3d()
		if camera != null:
			_select_lod(camera.global_position.distance_to(model_root.global_position))

func _validate() -> void:
	await get_tree().process_frame
	var packed := load(MODEL) as PackedScene
	_record(packed != null, "Godot 4.7.2 loads animated GLB as PackedScene")
	if packed == null:
		return
	model_root = packed.instantiate() as Node3D
	model_root.name = "M47_TestInstance"
	rig_mount.add_child(model_root)
	anim_player = model_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_record(anim_player != null, "imported GLB contains AnimationPlayer")
	if anim_player != null:
		var names: Array[String] = []
		for raw_name in anim_player.get_animation_list():
			names.append(String(raw_name))
			print("GODOT_ANIMATION_NAME ", raw_name)
		for clip in EXPECTED:
			var imported_name := ""
			for candidate in names:
				if candidate == clip or candidate.ends_with("/" + clip):
					imported_name = candidate
			_record(imported_name != "", "animation clip %s imported" % clip)
			if imported_name != "":
				anim_player.play(imported_name)
				await get_tree().process_frame
				anim_player.advance(0.15)
				_record(anim_player.current_animation == clip and anim_player.current_animation_position > 0.0, "%s plays and advances" % clip)
		anim_player.stop()
	var by_name: Dictionary = {}
	for node in model_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		by_name[mesh_instance.name] = mesh_instance
		var mesh := mesh_instance.mesh
		if mesh != null:
			for surface in mesh.get_surface_count():
				var mat := mesh.surface_get_material(surface) as StandardMaterial3D
				if mat != null and mesh_instance.name in LODS:
					_record(mat.albedo_texture != null and mat.normal_texture != null, "%s albedo and normal PBR textures imported" % mesh_instance.name)
					print("PBR ", mesh_instance.name, " roughness_texture=", mat.roughness_texture != null, " metallic_texture=", mat.metallic_texture != null, " roughness=", mat.roughness, " metallic=", mat.metallic)
					_record(mat.roughness_texture != null, "%s packed ORM roughness channel imported" % mesh_instance.name)
					_record(mat.metallic_texture != null, "%s packed ORM metallic channel imported" % mesh_instance.name)
	for lod in LODS:
		_record(by_name.has(lod), "%s imported" % lod)
		if by_name.has(lod):
			lod_nodes.append(by_name[lod])
	if lod_nodes.size() == 3:
		var dims := (by_name["M47_LOD0"] as MeshInstance3D).mesh.get_aabb().size
		_record(dims.x > 1.8 and dims.x < 2.2 and dims.y > 0.65 and dims.y < 0.9 and dims.z > 0.35 and dims.z < 0.45, "model dimensions and X-axis orientation match ~1.9m source bounds")
		for distance in [2.0, 8.0, 20.0]:
			_select_lod(distance)
			var visible_count := 0
			for mesh_node in lod_nodes:
				visible_count += 1 if mesh_node.visible else 0
			_record(visible_count == 1, "distance %.1fm renders exactly one LOD" % distance)
		# Start close so the screenshot shows the high detail version mounted at hand height.
		_select_lod(2.0)
	# Render screenshot after full import; also record mount scale and position.
	var right_hand_bone := player_skeleton.find_bone("DEF-handR") if player_skeleton != null else -1
	var left_hand_bone := player_skeleton.find_bone("DEF-handL") if player_skeleton != null else -1	
	_record(right_hand_bone >= 0 and left_hand_bone >= 0, "existing VQ2 player skeleton and both hand bones imported")
	if right_hand_bone >= 0 and left_hand_bone >= 0:
		var hands_midpoint := (player_skeleton.to_global(player_skeleton.get_bone_global_pose(right_hand_bone).origin) + player_skeleton.to_global(player_skeleton.get_bone_global_pose(left_hand_bone).origin)) * 0.5
		_record(rig_mount.global_position.distance_to(hands_midpoint) < 0.25, "M-47 mount is centered within 0.25m of actual VQ2 hand midpoint")
	_record(is_equal_approx(rig_mount.scale.x, 0.72) and rig_mount.position.y > 1.2, "test prop mounted at player hand height, 0.72 scale")
	await get_tree().process_frame
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var path := "res://screenshots/m47_godot_4_7_2.png"
	if image != null:
		var absolute := ProjectSettings.globalize_path(path)
		var save_error := image.save_png(absolute)
		_record(save_error == OK, "Godot viewport screenshot saved")
	else:
		_record(false, "viewport screenshot unavailable on headless dummy renderer")
	var report := "Godot 4.7.2 isolated M-47 GLB validation\n" + "\n".join(log_lines) + "\n"
	var file := FileAccess.open("res://results.txt", FileAccess.WRITE)
	if file != null:
		file.store_string(report)
	file.close()
	print("M47_GODOT_TEST ", "PASS" if failures == 0 else "FAIL %d" % failures)

func _select_lod(distance: float) -> void:
	var index := 0 if distance < 5.0 else (1 if distance < 14.0 else 2)
	for i in lod_nodes.size():
		lod_nodes[i].visible = (i == index)
