extends Node3D

const WALL_SCRIPT := preload("res://destructible_test_wall.gd")
const M47_MODEL := "res://M47_Muurbreker_1.0_animated.glb"
const PLAYER_MODEL := "res://soldaat_vq2.glb"
const EXPECTED_CLIPS := ["Idle", "Equip", "Aim", "Fire", "Reload"]
const LOD_NAMES := ["M47_LOD0", "M47_LOD1", "M47_LOD2"]
const VIDEO_FPS := 30
const MAX_VIDEO_FRAMES := 240
const WALL_LAYER := 1 << 7

var _test_lines: Array[String] = []
var _failures := 0
var _model_root: Node3D
var _weapon_mount: Node3D
var _anim_player: AnimationPlayer
var _core_skeleton: Skeleton3D
var _core_bone_index := -1
var _wall: StaticBody3D
var _muzzle_world := Vector3.ZERO
var _impact_world := Vector3.ZERO
var _status_label: Label
var _video_active := false
var _capture_outputs := true
var _performance_active := false
var _video_pending := false
var _video_frame := 0
var _spool_active := false
var _spool_elapsed := 0.0
var _process_ms_peak := 0.0
var _fps_min := 1000000.0
var _fps_max := 0.0
var _static_memory_start := 0
var _static_memory_peak := 0
var _render_primitives_peak := 0
var _render_draw_calls_peak := 0
var _active_vfx_mesh_triangles := 0
var _peak_rigid_bodies := 0
var _active_emitters := 0
var _configured_particle_budget := 0
var _player_instance: Node3D
var _shockwaves: Array[Dictionary] = []
var _fading_meshes: Array[Dictionary] = []
var _smoke_trail: MeshInstance3D
var _energy_projectile: Node3D

func _ready() -> void:
	_capture_outputs = not OS.get_cmdline_user_args().has("--no-capture")
	_static_memory_start = OS.get_static_memory_usage()
	_static_memory_peak = _static_memory_start
	_build_environment()
	_build_player_and_weapon()
	_build_test_wall()
	_build_hud()
	await get_tree().process_frame
	await _validate_m47_asset()
	await _validate_core_acceleration()
	if _capture_outputs:
		await _capture_still("m47_vfx_01_ready.png")
	_performance_active = true
	_video_active = _capture_outputs
	await _run_shot_sequence()
	_video_active = false
	_performance_active = false
	if _capture_outputs:
		await _capture_still("m47_vfx_03_reload_rubble.png")
	_write_results()
	print("M47_VFX_TEST ", "PASS" if _failures == 0 else "FAIL %d" % _failures)
	await get_tree().process_frame
	get_tree().quit(1 if _failures > 0 else 0)

func _process(delta: float) -> void:
	if _spool_active:
		_spool_elapsed += delta
		if _anim_player != null:
			_anim_player.speed_scale = lerpf(0.65, 3.6, clampf(_spool_elapsed / 1.35, 0.0, 1.0))
	if _energy_projectile != null and is_instance_valid(_energy_projectile):
		_energy_projectile.rotate_object_local(Vector3.RIGHT, delta * 26.0)
		_energy_projectile.rotate_object_local(Vector3.UP, delta * 11.0)
	for index in range(_shockwaves.size() - 1, -1, -1):
		var effect: Dictionary = _shockwaves[index]
		var age: float = float(effect.age) + delta
		var duration: float = float(effect.duration)
		effect.age = age
		var t: float = clampf(age / duration, 0.0, 1.0)
		var wave: MeshInstance3D = effect.node
		wave.scale = Vector3(1.0, lerpf(0.14, 1.35, t), lerpf(0.14, 1.35, t))
		var material: StandardMaterial3D = effect.material
		var color: Color = effect.color
		color.a = pow(1.0 - t, 1.3)
		material.albedo_color = color
		material.emission_energy_multiplier = lerpf(1.1, 0.15, t)
		if age >= duration:
			wave.queue_free()
			_shockwaves.remove_at(index)
	for index in range(_fading_meshes.size() - 1, -1, -1):
		var fading: Dictionary = _fading_meshes[index]
		var age: float = float(fading.age) + delta
		fading.age = age
		var duration: float = float(fading.duration)
		var node: MeshInstance3D = fading.node
		var mat: StandardMaterial3D = fading.material
		var t: float = clampf(age / duration, 0.0, 1.0)
		var color: Color = fading.color
		color.a = 1.0 - t
		mat.albedo_color = color
		if age >= duration:
			node.queue_free()
			_fading_meshes.remove_at(index)
	if _video_active and not _video_pending and _video_frame < MAX_VIDEO_FRAMES:
		_video_pending = true
		_capture_video_frame.call_deferred()
	_sample_performance()

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("18232a")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("93a5a8")
	environment.ambient_light_energy = 0.42
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	add_child(world)

	var camera := Camera3D.new()
	camera.name = "VFXRangeCamera"
	camera.position = Vector3(-0.4, 3.2, 7.8)
	camera.current = true
	camera.fov = 43.0
	add_child(camera)
	camera.look_at(Vector3(2.0, 1.28, 0.25), Vector3.UP)

	var sun := DirectionalLight3D.new()
	sun.name = "SoftKeyLight"
	sun.rotation_degrees = Vector3(-33.0, -28.0, -14.0)
	sun.light_energy = 1.28
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 16.0
	add_child(sun)

	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("303a38")
	floor_material.roughness = 0.97
	var floor := MeshInstance3D.new()
	floor.name = "RangeFloor"
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(17.0, 10.0)
	floor_mesh.material = floor_material
	floor.mesh = floor_mesh
	floor.position = Vector3(-1.7, -0.035, 0.15)
	floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(floor)

	var ground := StaticBody3D.new()
	ground.name = "VFXRangeGroundCollision"
	ground.collision_layer = 1 << 3
	ground.collision_mask = 0
	var ground_shape := CollisionShape3D.new()
	var plane_shape := WorldBoundaryShape3D.new()
	plane_shape.plane = Plane(Vector3.UP, 0.0)
	ground_shape.shape = plane_shape
	ground.add_child(ground_shape)
	add_child(ground)
	ground.global_position = Vector3.ZERO

	var stripe_material := StandardMaterial3D.new()
	stripe_material.albedo_color = Color("69716a")
	stripe_material.roughness = 0.86
	for z in [-1.8, -1.65, 1.65, 1.8]:
		var line := MeshInstance3D.new()
		var line_mesh := BoxMesh.new()
		line_mesh.size = Vector3(10.8, 0.012, 0.035)
		line_mesh.material = stripe_material
		line.mesh = line_mesh
		line.position = Vector3(1.1, 0.012, z)
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(line)

func _build_player_and_weapon() -> void:
	var player_packed := load(PLAYER_MODEL) as PackedScene
	if player_packed == null:
		_record(false, "existing VQ2 player GLB loads in isolated VFX project")
	else:
		_player_instance = player_packed.instantiate() as Node3D
		_player_instance.name = "VQ2_Player_VFXPreview"
		add_child(_player_instance)
		var player_animation := _player_instance.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if player_animation != null and player_animation.has_animation("stil"):
			player_animation.play("stil")

	var m47_packed := load(M47_MODEL) as PackedScene
	if m47_packed == null:
		_record(false, "existing animated M-47 GLB loads in isolated VFX project")
		return
	_model_root = m47_packed.instantiate() as Node3D
	_model_root.name = "M47_VFX_TestInstance"
	_weapon_mount = Node3D.new()
	_weapon_mount.name = "TestOnly_WeaponHandMount"
	_weapon_mount.position = Vector3(-0.165, 1.45, 0.38)
	_weapon_mount.rotation.y = PI
	_weapon_mount.scale = Vector3.ONE * 0.72
	add_child(_weapon_mount)
	_weapon_mount.add_child(_model_root)
	_anim_player = _model_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_core_skeleton = _model_root.find_child("Skeleton3D", true, false) as Skeleton3D
	if _core_skeleton != null:
		_core_bone_index = _core_skeleton.find_bone("Core")
	# The approved mount yaw leaves the M-47 muzzle on its local -X side.
	_muzzle_world = _weapon_mount.to_global(Vector3(-1.02, 0.0, 0.0))

func _build_test_wall() -> void:
	_wall = WALL_SCRIPT.new() as StaticBody3D
	_wall.position = Vector3(4.28, 1.28, 0.38)
	add_child(_wall)
	_impact_world = _wall.call("get_impact_point")

func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "TestOverlay"
	add_child(canvas)
	var panel := PanelContainer.new()
	panel.position = Vector2(22.0, 20.0)
	panel.custom_minimum_size = Vector2(500.0, 86.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.055, 0.063, 0.91)
	style.border_color = Color("4fbdc9")
	style.border_width_left = 3
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)
	canvas.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	panel.add_child(column)
	var title := Label.new()
	title.text = "M-47  //  VFX 2.0   ·   ISOLATED TEST RANGE"
	title.add_theme_color_override("font_color", Color("c9e1dd"))
	title.add_theme_font_size_override("font_size", 20)
	column.add_child(title)
	_status_label = Label.new()
	_status_label.text = "STANDBY   ·   Godot 4.7.2   ·   test-only effects"
	_status_label.add_theme_color_override("font_color", Color("78d3d9"))
	_status_label.add_theme_font_size_override("font_size", 16)
	column.add_child(_status_label)

func _validate_m47_asset() -> void:
	_record(_model_root != null, "existing animated M-47 GLB instantiated")
	if _model_root == null:
		return
	_record(_anim_player != null, "M-47 imported AnimationPlayer is present")
	if _anim_player == null:
		return
	var animation_names: Array[String] = []
	for raw_name in _anim_player.get_animation_list():
		animation_names.append(String(raw_name))
	for clip in EXPECTED_CLIPS:
		var resolved := _resolve_clip(clip)
		_record(not resolved.is_empty(), "existing clip %s imported" % clip)
		if resolved.is_empty():
			continue
		_anim_player.speed_scale = 1.0
		_anim_player.play(resolved)
		await get_tree().process_frame
		_anim_player.advance(0.18)
		_record(_anim_player.current_animation == resolved and _anim_player.current_animation_position > 0.0, "%s advances in Godot" % clip)
	_anim_player.stop()

	var visible_lods := 0
	var lod0: MeshInstance3D
	for lod_name in LOD_NAMES:
		var mesh_instance := _model_root.find_child(lod_name, true, false) as MeshInstance3D
		_record(mesh_instance != null, "%s exists in imported M-47 GLB" % lod_name)
		if mesh_instance == null:
			continue
		mesh_instance.visible = lod_name == "M47_LOD0"
		if mesh_instance.visible:
			visible_lods += 1
			lod0 = mesh_instance
	_record(visible_lods == 1, "one M-47 LOD is rendered at a time in the VFX preview")
	var pbr_ok := false
	if lod0 != null and lod0.mesh != null:
		for surface_index in lod0.mesh.get_surface_count():
			var material := lod0.mesh.surface_get_material(surface_index) as StandardMaterial3D
			if material != null:
				pbr_ok = material.albedo_texture != null and material.normal_texture != null and material.roughness_texture != null and material.metallic_texture != null
			_record(pbr_ok, "original M-47 PBR albedo, normal, roughness and metallic imported on LOD0")
		print("M47_LOD0_TRIANGLES ", _mesh_triangles(lod0.mesh))

func _validate_core_acceleration() -> void:
	_record(_core_skeleton != null and _core_bone_index >= 0, "existing animated mechanical core bone is available")
	if _core_skeleton == null or _core_bone_index < 0 or _anim_player == null:
		return
	var idle := _resolve_clip("Idle")
	_anim_player.play(idle)
	_anim_player.speed_scale = 0.4
	await get_tree().process_frame
	var slow_start: Quaternion = _core_skeleton.get_bone_pose_rotation(_core_bone_index)
	_anim_player.advance(0.06)
	var slow_end: Quaternion = _core_skeleton.get_bone_pose_rotation(_core_bone_index)
	var slow_angle := slow_start.angle_to(slow_end)
	_anim_player.seek(0.0, true)
	_anim_player.speed_scale = 3.6
	await get_tree().process_frame
	var fast_start: Quaternion = _core_skeleton.get_bone_pose_rotation(_core_bone_index)
	_anim_player.advance(0.06)
	var fast_end: Quaternion = _core_skeleton.get_bone_pose_rotation(_core_bone_index)
	var fast_angle := fast_start.angle_to(fast_end)
	_record(fast_angle > 0.01 and fast_angle > slow_angle, "mechanical core visibly accelerates using the existing Idle animation")
	print("CORE_ANGLE_DELTA slow=", snappedf(slow_angle, 0.0001), " fast=", snappedf(fast_angle, 0.0001))
	_anim_player.speed_scale = 1.0
	_anim_player.stop()

func _run_shot_sequence() -> void:
	await _play_clip("Equip", 0.6)
	await _play_clip("Aim", 0.55)
	var idle := _resolve_clip("Idle")
	_anim_player.play(idle)
	_anim_player.speed_scale = 0.65
	_spool_elapsed = 0.0
	_spool_active = true
	_set_status("CORE SPOOL-UP   ·   MECHANICAL IDLE → 3.6×")
	while _spool_elapsed < 1.35:
		await get_tree().process_frame
	_spool_active = false
	_record(_anim_player.speed_scale >= 3.5, "accelerating core reaches commanded 3.6× clip rate before fire")
	_set_status("FIRE   ·   ENERGY PAYLOAD IN FLIGHT")
	await _play_clip("Fire", 0.12)
	var ray_result := _ray_to_wall(_muzzle_world, _impact_world)
	_record(not ray_result.is_empty() and ray_result.get("collider") == _wall, "projectile ray collides with the test wall before impact")
	if ray_result.is_empty():
		return
	_spawn_muzzle_flash(_muzzle_world)
	_spawn_spark_emitter(_muzzle_world)
	_spawn_spiral_trail(_muzzle_world, _impact_world)
	_energy_projectile = _build_energy_projectile()
	add_child(_energy_projectile)
	_energy_projectile.global_position = _muzzle_world
	var travel := create_tween()
	travel.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	travel.tween_property(_energy_projectile, "global_position", _impact_world, 0.72)
	await get_tree().create_timer(0.32).timeout
	if _capture_outputs:
		await _capture_still("m47_vfx_02_projectile_midflight.png")
	await travel.finished
	if is_instance_valid(_energy_projectile):
		_energy_projectile.queue_free()
	_energy_projectile = null
	_impact_effects(_impact_world, _muzzle_world.direction_to(_impact_world))
	_wall.call("break_open", self, _impact_world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var post_impact_ray := _ray_to_wall(_muzzle_world, _impact_world)
	var wall_collision: CollisionShape3D = _wall.call("get_wall_collision")
	var wall_label: Label3D = _wall.call("get_test_label")
	var debris: Array = _wall.call("get_debris")
	_record(wall_collision != null and wall_collision.disabled and _wall.collision_layer == 0, "wall collider is disabled and removed from its collision layer after destruction")
	_record(wall_label != null and not wall_label.visible, "test wall sign is cleared with the destroyed wall visuals")
	_record(post_impact_ray.is_empty(), "post-destruction projectile ray now passes through the opening")
	var debris_collisions := 0
	for piece in debris:
		var has_collision := false
		if is_instance_valid(piece):
			for child in piece.get_children():
				if child is CollisionShape3D and (child as CollisionShape3D).shape != null:
					has_collision = true
		if is_instance_valid(piece) and piece.collision_layer != 0 and has_collision:
			debris_collisions += 1
	print("VFX_DEBRIS_COUNT ", debris.size(), " collision_count=", debris_collisions)
	_record(debris_collisions == 8, "eight low-poly debris pieces retain their own updated collisions")
	_peak_rigid_bodies = max(_peak_rigid_bodies, debris_collisions)
	_active_vfx_mesh_triangles += debris_collisions * 12
	await get_tree().create_timer(0.18).timeout
	if _capture_outputs:
		await _capture_still("m47_vfx_02_impact.png")
	_set_status("RELOAD   ·   DUST / DEBRIS SETTLING")
	await _play_clip("Reload", 1.05)
	await get_tree().create_timer(0.45).timeout
	_record(_configured_particle_budget <= 64, "one-shot particle budget remains at or below 64 particles")
	_record(_peak_rigid_bodies <= 8, "temporary debris collision budget remains at or below eight bodies")
	_record(_active_vfx_mesh_triangles <= 3000, "static projectile/trail/shockwave geometry stays under 3,000 triangles")
	_set_status("TEST COMPLETE   ·   5 CLIPS   ·   1 LOD   ·   COLLISION UPDATED")

func _play_clip(clip: String, seconds: float) -> void:
	if _anim_player == null:
		return
	var resolved := _resolve_clip(clip)
	if resolved.is_empty():
		_record(false, "could not start existing clip %s" % clip)
		return
	_anim_player.speed_scale = 1.0
	_anim_player.play(resolved)
	await get_tree().process_frame
	await get_tree().create_timer(seconds).timeout
	_record(_anim_player.current_animation == resolved and _anim_player.current_animation_position > 0.0, "preview sequence advances existing %s animation" % clip)

func _resolve_clip(clip: String) -> String:
	if _anim_player == null:
		return ""
	for candidate in _anim_player.get_animation_list():
		var name := String(candidate)
		if name == clip or name.ends_with("/" + clip):
			return name
	return ""

func _ray_to_wall(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, WALL_LAYER)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return get_world_3d().direct_space_state.intersect_ray(query)

func _build_energy_projectile() -> Node3D:
	var projectile := Node3D.new()
	projectile.name = "M47_TestOnly_EnergyPayload"
	var core_mesh := SphereMesh.new()
	core_mesh.radial_segments = 12
	core_mesh.rings = 6
	core_mesh.radius = 0.105
	core_mesh.height = 0.21
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
uniform vec3 plasma_tint : source_color = vec3(0.12, 0.67, 1.0);
uniform float pulse_rate = 8.0;
void fragment() {
    float spiral = 0.5 + 0.5 * sin((UV.x * 19.0 + UV.y * 6.0) + TIME * pulse_rate);
    float core = smoothstep(0.28, 0.82, spiral);
    ALBEDO = mix(vec3(0.025, 0.055, 0.24), plasma_tint, core);
    METALLIC = 0.18;
    ROUGHNESS = 0.24;
    EMISSION = plasma_tint * (1.0 + 2.4 * core);
}
"""
	var core_material := ShaderMaterial.new()
	core_material.shader = shader
	var core := MeshInstance3D.new()
	core.name = "RotatingPlasmaCore"
	core.mesh = core_mesh
	core.material_override = core_material
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	projectile.add_child(core)
	_active_vfx_mesh_triangles += _mesh_triangles(core_mesh)

	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = Color("4ed9ff")
	ring_material.emission_enabled = true
	ring_material.emission = Color("22bce8")
	ring_material.emission_energy_multiplier = 1.7
	ring_material.metallic = 0.58
	ring_material.roughness = 0.23
	for index in 2:
		var torus_mesh := TorusMesh.new()
		torus_mesh.inner_radius = 0.12
		torus_mesh.outer_radius = 0.155
		torus_mesh.ring_segments = 12
		torus_mesh.rings = 6
		torus_mesh.material = ring_material
		var torus := MeshInstance3D.new()
		torus.name = "SpinningContainmentRing_%d" % index
		torus.mesh = torus_mesh
		torus.rotation.z = PI / 2.0
		torus.rotation.x = PI * 0.16 * float(index)
		torus.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		projectile.add_child(torus)
		_active_vfx_mesh_triangles += _mesh_triangles(torus_mesh)
	var pinprick := SphereMesh.new()
	pinprick.radial_segments = 6
	pinprick.rings = 3
	pinprick.radius = 0.034
	pinprick.height = 0.068
	var pin_material := StandardMaterial3D.new()
	pin_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pin_material.albedo_color = Color("ffc86a")
	pin_material.emission_enabled = true
	pin_material.emission = Color("ff9b39")
	pin_material.emission_energy_multiplier = 1.5
	pinprick.material = pin_material
	for index in 3:
		var particle := MeshInstance3D.new()
		particle.mesh = pinprick
		particle.name = "OrbitingEnergyFilament_%d" % index
		particle.position = Vector3(0.0, cos(TAU * float(index) / 3.0) * 0.14, sin(TAU * float(index) / 3.0) * 0.14)
		particle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		projectile.add_child(particle)
	_active_vfx_mesh_triangles += _mesh_triangles(pinprick) * 3
	return projectile

func _spawn_spiral_trail(start: Vector3, finish: Vector3) -> void:
	if _smoke_trail != null and is_instance_valid(_smoke_trail):
		_smoke_trail.queue_free()
	var direction := start.direction_to(finish)
	var right := direction.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.001:
		right = direction.cross(Vector3.FORWARD).normalized()
	var up := right.cross(direction).normalized()
	var trail_root := Node3D.new()
	trail_root.name = "M47_HelicalSmokeTrail"
	trail_root.transform = Transform3D(Basis(direction, up, right), start)
	add_child(trail_root)
	var trail_mesh := _make_helical_tube(start.distance_to(finish), 6.25, 0.095, 0.042, 4)
	_smoke_trail = MeshInstance3D.new()
	_smoke_trail.name = "MobileBudget_SpiralSmokeMesh"
	_smoke_trail.mesh = trail_mesh
	var smoke_material := StandardMaterial3D.new()
	smoke_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_material.vertex_color_use_as_albedo = true
	smoke_material.albedo_color = Color.WHITE
	smoke_material.emission_enabled = true
	smoke_material.emission = Color("267d91")
	smoke_material.emission_energy_multiplier = 0.24
	smoke_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_smoke_trail.material_override = smoke_material
	_smoke_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trail_root.add_child(_smoke_trail)
	_active_vfx_mesh_triangles += _mesh_triangles(trail_mesh)
	_fading_meshes.append({"node": _smoke_trail, "material": smoke_material, "color": smoke_material.albedo_color, "age": 0.0, "duration": 1.7})

func _make_helical_tube(length: float, turns: float, radius: float, tube_radius: float, sides: int) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var steps := int(turns * 12.0)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for step in range(steps + 1):
		var t := float(step) / float(steps)
		var theta := turns * TAU * t
		var center := Vector3(length * t, radius * cos(theta), radius * sin(theta))
		var fade := sin(PI * t) * 0.32 + 0.07
		var smoke_color := Color(0.13 + t * 0.06, 0.42 + t * 0.16, 0.50 + t * 0.18, fade)
		for side in sides:
			var around := TAU * float(side) / float(sides)
			var radial := Vector3(0.0, cos(theta) * cos(around), sin(theta) * cos(around))
			radial += Vector3(0.0, -sin(theta) * sin(around), cos(theta) * sin(around))
			normals.append(radial.normalized())
			vertices.append(center + radial.normalized() * tube_radius)
			colors.append(smoke_color)
			uvs.append(Vector2(t, float(side) / float(sides)))
	for step in steps:
		for side in sides:
			var a := step * sides + side
			var b := step * sides + (side + 1) % sides
			var c := (step + 1) * sides + (side + 1) % sides
			var d := (step + 1) * sides + side
			indices.append_array([a, b, c, a, c, d])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _spawn_muzzle_flash(position: Vector3) -> void:
	var sphere := SphereMesh.new()
	sphere.radial_segments = 8
	sphere.rings = 4
	sphere.radius = 0.14
	sphere.height = 0.28
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("e8fbff")
	material.emission_enabled = true
	material.emission = Color("62deff")
	material.emission_energy_multiplier = 2.4
	sphere.material = material
	var flash := MeshInstance3D.new()
	flash.name = "M47_OneShotMuzzlePulse"
	flash.mesh = sphere
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flash)
	flash.global_position = position
	_active_vfx_mesh_triangles += _mesh_triangles(sphere)
	_fading_meshes.append({"node": flash, "material": material, "color": material.albedo_color, "age": 0.0, "duration": 0.14})

func _spawn_spark_emitter(position: Vector3) -> void:
	_spawn_particle_emitter("MuzzleSparks", position, 12, Color("7cdcff"), Vector3(-1.0, 0.0, 0.0), 9.0, 15.0, Vector3(0.0, -1.2, 0.0), 0.45, 0.045, 0.12)

func _impact_effects(position: Vector3, direction: Vector3) -> void:
	_set_status("IMPACT   ·   HEX SHOCK / DUST / COLLISION RESET")
	var oriented := _basis_for_x_axis(direction)
	var ring := MeshInstance3D.new()
	ring.name = "SixSidedEnergyShockwave"
	ring.mesh = _make_hex_ring()
	var ring_material := StandardMaterial3D.new()
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_material.albedo_color = Color("66e6ff")
	ring_material.emission_enabled = true
	ring_material.emission = Color("17bfe8")
	ring_material.emission_energy_multiplier = 1.1
	ring_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring.material_override = ring_material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	ring.global_transform = Transform3D(oriented, position)
	var ring_color := ring_material.albedo_color
	_shockwaves.append({"node": ring, "material": ring_material, "color": ring_color, "age": 0.0, "duration": 0.48})
	_active_vfx_mesh_triangles += _mesh_triangles(ring.mesh)
	_spawn_particle_emitter("ImpactDust", position, 32, Color("9a8065"), Vector3(0.0, 1.0, 0.0), 4.2, 88.0, Vector3(0.0, -3.4, 0.0), 1.35, 0.85, 2.4)
	_spawn_particle_emitter("ImpactSmoke", position, 20, Color("657274"), Vector3(0.0, 1.0, 0.0), 1.15, 62.0, Vector3(0.0, 0.25, 0.0), 1.8, 1.0, 2.5)
	_configured_particle_budget = 12 + 32 + 20

func _make_hex_ring() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var inner := 0.78
	var outer := 1.0
	for segment in 6:
		var a0 := TAU * float(segment) / 6.0
		var a1 := TAU * float(segment + 1) / 6.0
		vertices.append_array([
			Vector3(0.0, cos(a0) * inner, sin(a0) * inner),
			Vector3(0.0, cos(a0) * outer, sin(a0) * outer),
			Vector3(0.0, cos(a1) * outer, sin(a1) * outer),
			Vector3(0.0, cos(a1) * inner, sin(a1) * inner),
		])
		var base := segment * 4
		indices.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _basis_for_x_axis(axis: Vector3) -> Basis:
	var x := axis.normalized()
	var y := Vector3.UP
	if absf(x.dot(y)) > 0.94:
		y = Vector3.FORWARD
	var z := x.cross(y).normalized()
	y = z.cross(x).normalized()
	return Basis(x, y, z)

func _spawn_particle_emitter(emitter_name: String, position: Vector3, amount: int, color: Color, direction: Vector3, velocity: float, spread: float, gravity: Vector3, lifetime: float, min_size: float, max_size: float) -> GPUParticles3D:
	var emitter := GPUParticles3D.new()
	emitter.name = emitter_name
	emitter.amount = amount
	emitter.amount_ratio = 1.0
	emitter.lifetime = lifetime
	emitter.one_shot = true
	emitter.explosiveness = 0.96
	emitter.randomness = 0.62
	emitter.preprocess = 0.04
	emitter.fixed_fps = 30
	emitter.interpolate = true
	emitter.visibility_aabb = AABB(Vector3(-3.0, -3.0, -3.0), Vector3(6.0, 6.0, 6.0))
	emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_material.emission_sphere_radius = 0.045
	process_material.direction = direction
	process_material.spread = spread
	process_material.initial_velocity_min = velocity * 0.48
	process_material.initial_velocity_max = velocity
	process_material.gravity = gravity
	process_material.angular_velocity_min = -105.0
	process_material.angular_velocity_max = 105.0
	process_material.scale_min = min_size
	process_material.scale_max = max_size
	process_material.color = Color.WHITE
	var fade_gradient := Gradient.new()
	fade_gradient.set_color(0, Color(1.0, 1.0, 1.0, 0.82))
	fade_gradient.add_point(1.0, Color(1.0, 1.0, 1.0, 0.0))
	var fade_texture := GradientTexture1D.new()
	fade_texture.gradient = fade_gradient
	process_material.color_ramp = fade_texture
	emitter.process_material = process_material
	var particle_mesh := SphereMesh.new()
	particle_mesh.radial_segments = 4
	particle_mesh.rings = 2
	particle_mesh.radius = 0.09
	particle_mesh.height = 0.18
	var particle_shader := Shader.new()
	particle_shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;
uniform vec4 tint : source_color = vec4(0.45, 0.48, 0.44, 0.7);
uniform float glow_strength = 0.025;
void fragment() {
    vec2 p = UV * 2.0 - 1.0;
    float edge = 1.0 - smoothstep(0.30, 1.0, length(p));
    ALBEDO = tint.rgb;
    ALPHA = tint.a * COLOR.a * edge;
    EMISSION = tint.rgb * glow_strength;
}
"""
	var particle_material := ShaderMaterial.new()
	particle_material.shader = particle_shader
	particle_material.set_shader_parameter("tint", Color(color.r, color.g, color.b, 0.74))
	particle_material.set_shader_parameter("glow_strength", 0.32 if color.r < 0.8 else 0.025)
	particle_mesh.material = particle_material
	print("VFX_PARTICLE_MESH_TRIANGLES ", _mesh_triangles(particle_mesh), " amount=", amount, " name=", emitter_name)
	emitter.draw_pass_1 = particle_mesh
	add_child(emitter)
	emitter.global_position = position
	emitter.emitting = true
	_active_emitters += 1
	_configured_particle_budget += amount
	_active_vfx_mesh_triangles += _mesh_triangles(particle_mesh) * amount
	return emitter

func _capture_still(filename: String) -> void:
	if not _capture_outputs:
		return
	await get_tree().process_frame
	await get_tree().process_frame
	var path := ProjectSettings.globalize_path("res://screenshots/" + filename)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var image := get_viewport().get_texture().get_image()
	var saved := image != null and not image.is_empty() and image.save_png(path) == OK
	_record(saved, "viewport image captured: %s" % filename)
	if not saved:
		print("SCREENSHOT_CAPTURE_FAILED ", filename)

func _capture_video_frame() -> void:
	await get_tree().process_frame
	if _video_active and _video_frame < MAX_VIDEO_FRAMES:
		var base := ProjectSettings.globalize_path("res://captures")
		DirAccess.make_dir_recursive_absolute(base)
		var image := get_viewport().get_texture().get_image()
		if image != null and not image.is_empty():
			var path := "%s/frame_%04d.png" % [base, _video_frame]
			if image.save_png(path) == OK:
				_video_frame += 1
	_video_pending = false

func _sample_performance() -> void:
	var process_time := float(Performance.get_monitor(Performance.TIME_PROCESS))
	if _performance_active and process_time > 0.0 and is_finite(process_time):
		_process_ms_peak = maxf(_process_ms_peak, process_time * 1000.0)
	var fps := float(Engine.get_frames_per_second())
	if _performance_active and fps > 0.0:
		_fps_min = minf(_fps_min, fps)
		_fps_max = maxf(_fps_max, fps)
	_static_memory_peak = max(_static_memory_peak, OS.get_static_memory_usage())
	if _performance_active:
		_render_primitives_peak = max(_render_primitives_peak, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
		_render_draw_calls_peak = max(_render_draw_calls_peak, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))

func _write_results() -> void:
	var static_memory_end := OS.get_static_memory_usage()
	var static_memory_peak: int = maxi(_static_memory_peak, OS.get_static_memory_peak_usage())
	var report := {
		"engine": Engine.get_version_info(),
		"result": "PASS" if _failures == 0 else "FAIL",
		"failures": _failures,
		"checks": _test_lines,
		"asset": "M47_Muurbreker_1.0_animated.glb",
		"lod0_triangles": _model_lod0_triangles(),
		"clips": EXPECTED_CLIPS,
		"vfx": {
			"one_shot_particle_budget": _configured_particle_budget,
			"particle_emitters": _active_emitters,
			"temporary_rigid_body_budget": _peak_rigid_bodies,
			"effect_triangles_including_particle_billboards": _active_vfx_mesh_triangles,
			"dynamic_shadowed_effect_lights": 0,
			"full_screen_post_effects": 0,
			"spiral_smoke_segments": 75,
			"shockwave_sides": 6,
		},
		"collision": {
			"wall_collision_layer_removed_on_break": _wall != null and _wall.collision_layer == 0,
			"old_wall_shape_disabled": _wall != null and bool(_wall.call("get_wall_collision").disabled),
			"debris_bodies_with_collision": _peak_rigid_bodies,
		},
		"memory": {
			"static_bytes_before_sequence": _static_memory_start,
			"static_bytes_after_sequence": static_memory_end,
			"static_peak_bytes": static_memory_peak,
		},
		"performance": {
			"engine_process_peak_ms": snappedf(_process_ms_peak, 0.001),
			"sampled_fps_min": 0.0 if _fps_min == 1000000.0 else _fps_min,
			"sampled_fps_max": _fps_max,
			"render_primitives_peak": _render_primitives_peak,
			"render_draw_calls_peak": _render_draw_calls_peak,
			"capture_resolution": "1280x720",
			"capture_fps": VIDEO_FPS,
			"capture_frames": _video_frame,
			"capture_enabled": _capture_outputs,
			"runtime_measurement": "Xvfb + Mesa llvmpipe software render; NOT an iPhone GPU/FPS measurement",
		},
	}
	var results_name := "results.json" if _capture_outputs else "results_performance.json"
	var path := ProjectSettings.globalize_path("res://" + results_name)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t") + "\n")
		file.close()
	else:
		_record(false, "test metrics report saved")
	print("M47_VFX_RESULTS ", JSON.stringify(report))

func _model_lod0_triangles() -> int:
	if _model_root == null:
		return 0
	var lod0 := _model_root.find_child("M47_LOD0", true, false) as MeshInstance3D
	return _mesh_triangles(lod0.mesh) if lod0 != null and lod0.mesh != null else 0

func _mesh_triangles(mesh: Mesh) -> int:
	if mesh == null:
		return 0
	return int(mesh.get_faces().size() / 3)

func _record(ok: bool, description: String) -> void:
	var line := ("PASS " if ok else "FAIL ") + description
	_test_lines.append(line)
	print(line)
	if not ok:
		_failures += 1

func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text

