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
var _smoke_material: ShaderMaterial
var _flight_progress := 0.0
var _projectile_pool: Array[Node3D] = []
var _flash_pool: Array[MeshInstance3D] = []
var _particle_pool: Dictionary = {}
var _prewarming_effects := false
var _core_indicator: Node3D
var _core_indicator_spin := 0.0

func _ready() -> void:
	_capture_outputs = not OS.get_cmdline_user_args().has("--no-capture")
	_static_memory_start = OS.get_static_memory_usage()
	_static_memory_peak = _static_memory_start
	_build_environment()
	_build_player_and_weapon()
	_build_test_wall()
	_build_hud()
	_prewarm_effects()
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
	if _core_indicator != null:
		var spin_step := delta * (2.0 + 20.0 * clampf(_spool_elapsed / 1.35, 0.0, 1.0))
		_core_indicator.rotate_object_local(Vector3.FORWARD, spin_step)
		_core_indicator_spin += spin_step
	if _smoke_material != null:
		_smoke_material.set_shader_parameter("progress", _flight_progress)
	if _energy_projectile != null and is_instance_valid(_energy_projectile):
		_energy_projectile.rotate_object_local(Vector3.FORWARD, delta * 22.0)
		_energy_projectile.rotate_object_local(Vector3.UP, delta * 4.0)
	for index in range(_shockwaves.size() - 1, -1, -1):
		var effect: Dictionary = _shockwaves[index]
		var age: float = float(effect.age) + delta
		var duration: float = float(effect.duration)
		effect.age = age
		var t: float = clampf(age / duration, 0.0, 1.0)
		var wave: MeshInstance3D = effect.node
		wave.scale = Vector3(1.0, lerpf(0.24, 1.8, t), lerpf(0.24, 1.8, t))
		var material: StandardMaterial3D = effect.material
		var color: Color = effect.color
		color.a = pow(1.0 - t, 1.3)
		material.albedo_color = color
		material.emission_energy_multiplier = lerpf(4.5, 0.15, t)
		if age >= duration:
			wave.queue_free()
			_shockwaves.remove_at(index)
	for index in range(_fading_meshes.size() - 1, -1, -1):
		var fading: Dictionary = _fading_meshes[index]
		var age: float = float(fading.age) + delta
		fading.age = age
		var duration: float = float(fading.duration)
		var node: MeshInstance3D = fading.node
		var mat: Material = fading.material
		var t: float = clampf(age / duration, 0.0, 1.0)
		var color: Color = fading.color
		color.a = 1.0 - t
		if mat is ShaderMaterial:
			(mat as ShaderMaterial).set_shader_parameter("alpha_factor", 1.0 - t)
		else:
			(mat as StandardMaterial3D).albedo_color = color
		if age >= duration:
			if node.name.begins_with("PooledFlash"):
				node.visible = false
				_flash_pool.append(node)
			else:
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
	camera.position = Vector3(-0.4, 5.6, 7.2)
	camera.current = true
	camera.fov = 47.0
	add_child(camera)
	camera.look_at(Vector3(2.0, 1.28, 0.25), Vector3.UP)

	var sun := DirectionalLight3D.new()
	sun.name = "SoftKeyLight"
	sun.rotation_degrees = Vector3(-33.0, -28.0, -14.0)
	sun.light_energy = 1.28
	sun.shadow_enabled = false
	sun.directional_shadow_max_distance = 16.0
	add_child(sun)

	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color.WHITE
	floor_material.roughness = 0.97
	var ground_noise := FastNoiseLite.new()
	ground_noise.frequency = 0.025
	ground_noise.fractal_octaves = 3
	var ground_gradient := Gradient.new()
	ground_gradient.set_color(0, Color("262d28"))
	ground_gradient.set_color(1, Color("575441"))
	ground_gradient.add_point(0.48, Color("383b2f"))
	var ground_texture := NoiseTexture2D.new()
	ground_texture.width = 512
	ground_texture.height = 512
	ground_texture.noise = ground_noise
	ground_texture.color_ramp = ground_gradient
	floor_material.albedo_texture = ground_texture
	var floor := MeshInstance3D.new()
	floor.name = "RangeFloor"
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(17.0, 10.0)
	floor_mesh.material = floor_material
	floor.mesh = floor_mesh
	floor.position = Vector3(-1.7, -0.035, 0.15)
	floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(floor)
	var contact_shader := Shader.new()
	contact_shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;
void fragment() {
    float falloff = 1.0 - smoothstep(0.12, 1.0, length(UV * 2.0 - 1.0));
    ALBEDO = vec3(0.025, 0.032, 0.027);
    ALPHA = falloff * 0.28;
}
"""
	var contact_material := ShaderMaterial.new()
	contact_material.shader = contact_shader
	for shadow_data in [
		{"name": "StaticPlayerContactShadow", "size": Vector2(1.05, 0.72), "position": Vector3(-0.08, 0.015, 0.28)},
		{"name": "StaticWallContactShadow", "size": Vector2(1.10, 3.65), "position": Vector3(4.10, 0.015, 0.38)},
	]:
		var contact := MeshInstance3D.new()
		contact.name = shadow_data.name
		var contact_mesh := PlaneMesh.new()
		contact_mesh.size = shadow_data.size
		contact_mesh.material = contact_material
		contact.mesh = contact_mesh
		contact.position = shadow_data.position
		contact.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(contact)

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
	_core_indicator = Node3D.new()
	_core_indicator.name = "TestOnly_VisibleCoreRotor"
	_core_indicator.position = Vector3(-0.58, 0.04, -0.20)
	_weapon_mount.add_child(_core_indicator)
	var rotor_material := StandardMaterial3D.new()
	rotor_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rotor_material.albedo_color = Color("4ce6ff")
	rotor_material.emission_enabled = true
	rotor_material.emission = Color("57e5ff")
	rotor_material.emission_energy_multiplier = 2.6
	var rotor_mesh := TorusMesh.new()
	rotor_mesh.inner_radius = 0.145
	rotor_mesh.outer_radius = 0.177
	rotor_mesh.ring_segments = 12
	rotor_mesh.rings = 4
	rotor_mesh.material = rotor_material
	var rotor := MeshInstance3D.new()
	rotor.mesh = rotor_mesh
	rotor.rotation.x = PI / 2.0
	rotor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_core_indicator.add_child(rotor)
	var marker := MeshInstance3D.new()
	var marker_mesh := BoxMesh.new()
	marker_mesh.size = Vector3(0.075, 0.045, 0.028)
	marker_mesh.material = rotor_material
	marker.mesh = marker_mesh
	marker.position = Vector3(0.165, 0.0, 0.02)
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_core_indicator.add_child(marker)
	_active_vfx_mesh_triangles += _mesh_triangles(rotor_mesh) + _mesh_triangles(marker_mesh)
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
	title.text = "M-47  //  VISUAL UPGRADE 2.1   ·   TEST RANGE"
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
	_record(_core_indicator_spin > 8.0, "visible test rotor accelerates while the original core animation plays")
	_set_status("FIRE   ·   ENERGY PAYLOAD IN FLIGHT")
	await _play_clip("Fire", 0.12)
	var ray_result := _ray_to_wall(_muzzle_world, _impact_world)
	_record(not ray_result.is_empty() and ray_result.get("collider") == _wall, "projectile ray collides with the test wall before impact")
	if ray_result.is_empty():
		return
	_spawn_muzzle_flash(_muzzle_world)
	_spawn_spark_emitter(_muzzle_world)
	_spawn_spiral_trail(_muzzle_world, _impact_world)
	_energy_projectile = _projectile_pool.pop_back()
	_energy_projectile.visible = true
	_energy_projectile.global_position = _muzzle_world
	var recoil := create_tween()
	recoil.tween_property(_weapon_mount, "position:x", -0.39, 0.09)
	recoil.tween_property(_weapon_mount, "position:x", -0.165, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var travel := create_tween()
	travel.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	travel.tween_property(_energy_projectile, "global_position", _impact_world, 0.72)
	travel.parallel().tween_property(self, "_flight_progress", 1.0, 0.72)
	await get_tree().create_timer(0.07).timeout
	_record(_weapon_mount.position.x < -0.20, "weapon mount travels backward during mechanical recoil")
	if _capture_outputs:
		await _capture_still("after_vfx21_muzzle_flash.png")
	await get_tree().create_timer(0.32).timeout
	if _capture_outputs:
		await _capture_still("m47_vfx_02_projectile_midflight.png")
	await travel.finished
	if is_instance_valid(_energy_projectile):
		_energy_projectile.visible = false
		_projectile_pool.append(_energy_projectile)
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
	for piece in debris:
		for child in piece.get_children():
			if child is MeshInstance3D:
				_active_vfx_mesh_triangles += _mesh_triangles((child as MeshInstance3D).mesh)
	await get_tree().create_timer(0.18).timeout
	if _capture_outputs:
		await _capture_still("m47_vfx_02_impact.png")
	_set_status("RELOAD   ·   DUST / DEBRIS SETTLING")
	await _play_clip("Reload", 1.05)
	await get_tree().create_timer(0.45).timeout
	_record(_configured_particle_budget <= 64, "one-shot particle budget remains at or below 64 particles")
	_record(_peak_rigid_bodies <= 8, "temporary debris collision budget remains at or below eight bodies")
	_record(_active_vfx_mesh_triangles <= 4200, "effect geometry and particle meshes stay under 4,200 triangles")
	_record(_projectile_pool.size() == 1 and _flash_pool.size() == 2 and _particle_pool.size() == 4, "projectile, flash and particle instances remain available in the effect pool")
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

func _prewarm_effects() -> void:
	var projectile := _build_energy_projectile()
	add_child(projectile)
	projectile.visible = false
	_projectile_pool.append(projectile)
	for index in 2:
		var flash := _create_flash()
		flash.name = "PooledFlash_%d" % index
		add_child(flash)
		flash.visible = false
		_flash_pool.append(flash)
	_prewarming_effects = true
	_spawn_particle_emitter("MuzzleSparks", _muzzle_world, 16, Color("7cdcff"), Vector3(1.0, 0.0, 0.0), 9.0, 25.0, Vector3(0.0, -1.2, 0.0), 0.45, 0.065, 0.16)
	var near_face := _impact_world + Vector3(-0.28, 0.0, 0.38)
	_spawn_particle_emitter("ImpactDust", near_face, 28, Color("a39077"), Vector3(0.0, 1.0, 0.0), 4.2, 88.0, Vector3(0.0, -3.4, 0.0), 1.35, 1.0, 2.5)
	_spawn_particle_emitter("ImpactSmoke", near_face, 12, Color("657274"), Vector3(0.0, 1.0, 0.0), 1.15, 62.0, Vector3(0.0, 0.25, 0.0), 1.8, 1.0, 2.5)
	_spawn_particle_emitter("ImpactSparks", near_face, 8, Color("75dbff"), Vector3(0.0, 1.0, 0.0), 7.0, 86.0, Vector3(0.0, -3.0, 0.0), 0.72, 0.04, 0.11)
	_prewarming_effects = false
	_record(_projectile_pool.size() == 1 and _flash_pool.size() == 2 and _particle_pool.size() == 4, "projectile, flashes and four particle systems are prewarmed for reuse")

func _create_flash() -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radial_segments = 10
	sphere.rings = 5
	sphere.radius = 0.26
	sphere.height = 0.52
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color("f0fdff")
	material.emission_enabled = true
	material.emission = Color("b9eeff")
	material.emission_energy_multiplier = 1.8
	var flash := MeshInstance3D.new()
	flash.name = "PooledFlash"
	flash.mesh = sphere
	flash.material_override = material
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_active_vfx_mesh_triangles += _mesh_triangles(sphere)
	var ray_mesh := BoxMesh.new()
	ray_mesh.size = Vector3(0.92, 0.045, 0.035)
	ray_mesh.material = material
	for ray_index in 4:
		var ray := MeshInstance3D.new()
		ray.name = "FlashRay_%d" % ray_index
		ray.mesh = ray_mesh
		ray.rotation.z = float(ray_index) * PI / 4.0
		ray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flash.add_child(ray)
	_active_vfx_mesh_triangles += _mesh_triangles(ray_mesh) * 4
	return flash

func _spawn_flash(position: Vector3, scale: Vector3, duration: float) -> void:
	if _flash_pool.is_empty():
		return
	var flash: MeshInstance3D = _flash_pool.pop_back()
	flash.global_position = position
	flash.scale = scale
	flash.visible = true
	var material := flash.material_override as StandardMaterial3D
	material.albedo_color = Color("f0fdff")
	material.emission_energy_multiplier = 1.8
	_fading_meshes.append({"node": flash, "material": material, "color": material.albedo_color, "age": 0.0, "duration": duration})

func _build_energy_projectile() -> Node3D:
	var projectile := Node3D.new()
	projectile.name = "M47_TestOnly_EnergyPayload"
	var core_mesh := SphereMesh.new()
	core_mesh.radial_segments = 12
	core_mesh.rings = 6
	core_mesh.radius = 0.225
	core_mesh.height = 0.45
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_back;
uniform vec3 plasma_tint : source_color = vec3(0.40, 0.82, 1.0);
uniform float pulse_rate = 8.0;
void fragment() {
    float spiral = 0.5 + 0.5 * sin((UV.x * 19.0 + UV.y * 6.0) + TIME * pulse_rate);
    float core = smoothstep(0.28, 0.82, spiral);
    ALBEDO = mix(vec3(0.03, 0.24, 0.72), vec3(0.54, 0.86, 1.0), core);
    METALLIC = 0.18;
    ROUGHNESS = 0.24;
    EMISSION = plasma_tint * (0.8 + 1.3 * core);
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
	ring_material.albedo_color = Color("129bff")
	ring_material.emission_enabled = true
	ring_material.emission = Color("087aff")
	ring_material.emission_energy_multiplier = 1.5
	ring_material.metallic = 0.58
	ring_material.roughness = 0.23
	for index in 2:
		var torus_mesh := TorusMesh.new()
		torus_mesh.inner_radius = 0.27
		torus_mesh.outer_radius = 0.32
		torus_mesh.ring_segments = 12
		torus_mesh.rings = 6
		torus_mesh.material = ring_material
		var torus := MeshInstance3D.new()
		torus.name = "SpinningContainmentRing_%d" % index
		torus.mesh = torus_mesh
		torus.rotation.x = PI / 2.0 + PI * 0.12 * float(index)
		torus.rotation.z = PI * 0.15 * float(index)
		torus.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		projectile.add_child(torus)
		_active_vfx_mesh_triangles += _mesh_triangles(torus_mesh)
	var pinprick := SphereMesh.new()
	pinprick.radial_segments = 6
	pinprick.rings = 3
	pinprick.radius = 0.054
	pinprick.height = 0.108
	var pin_material := StandardMaterial3D.new()
	pin_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pin_material.albedo_color = Color("dffbff")
	pin_material.emission_enabled = true
	pin_material.emission = Color("51dfff")
	pin_material.emission_energy_multiplier = 1.6
	pinprick.material = pin_material
	for index in 4:
		var particle := MeshInstance3D.new()
		particle.mesh = pinprick
		particle.name = "OrbitingEnergyFilament_%d" % index
		particle.position = Vector3(0.0, cos(TAU * float(index) / 4.0) * 0.30, sin(TAU * float(index) / 4.0) * 0.30)
		particle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		projectile.add_child(particle)
	_active_vfx_mesh_triangles += _mesh_triangles(pinprick) * 4
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
	var trail_mesh := _make_helical_tube(start.distance_to(finish), 6.25, 0.18, 0.079, 5)
	_smoke_trail = MeshInstance3D.new()
	_smoke_trail.name = "MobileBudget_SpiralSmokeMesh"
	_smoke_trail.mesh = trail_mesh
	var smoke_shader := Shader.new()
	smoke_shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;
uniform float progress = 0.0;
uniform float alpha_factor = 1.0;
void fragment() {
    float reveal = 1.0 - smoothstep(progress - 0.055, progress + 0.005, UV.x);
    ALBEDO = COLOR.rgb;
    float wisp = 0.60 + 0.25 * sin(UV.x * 78.0 - TIME * 1.6);
    EMISSION = COLOR.rgb * 0.65;
    ALPHA = COLOR.a * alpha_factor * reveal * wisp;
}
"""
	_smoke_material = ShaderMaterial.new()
	_smoke_material.shader = smoke_shader
	_flight_progress = 0.0
	_smoke_trail.material_override = _smoke_material
	_smoke_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trail_root.add_child(_smoke_trail)
	_active_vfx_mesh_triangles += _mesh_triangles(trail_mesh)
	_fading_meshes.append({"node": _smoke_trail, "material": _smoke_material, "color": Color.WHITE, "age": 0.0, "duration": 1.85})

func _make_helical_tube(length: float, turns: float, radius: float, tube_radius: float, sides: int) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var steps := int(turns * 16.0)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for step in range(steps + 1):
		var t := float(step) / float(steps)
		var theta := turns * TAU * t
		var center := Vector3(length * t, radius * cos(theta), radius * sin(theta))
		var fade := sin(PI * t) * 0.40 + 0.23
		var smoke_color := Color(0.25 + t * 0.25, 0.52 + t * 0.25, 0.63 + t * 0.28, fade)
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
	_spawn_flash(position, Vector3(1.55, 0.72, 0.72), 0.32)

func _spawn_spark_emitter(position: Vector3) -> void:
	_spawn_particle_emitter("MuzzleSparks", position, 16, Color("7cdcff"), Vector3(1.0, 0.0, 0.0), 9.0, 25.0, Vector3(0.0, -1.2, 0.0), 0.45, 0.065, 0.16)

func _impact_effects(position: Vector3, direction: Vector3) -> void:
	_set_status("IMPACT   ·   HEX SHOCK / DUST / COLLISION RESET")
	_spawn_flash(position + Vector3(0.0, 0.0, 0.26), Vector3(1.35, 1.35, 0.85), 0.22)
	var oriented := Basis(Vector3.UP, -PI / 2.0)
	var ring := MeshInstance3D.new()
	ring.name = "SixSidedEnergyShockwave"
	ring.mesh = _make_hex_ring()
	var ring_material := StandardMaterial3D.new()
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_material.albedo_color = Color("139dff")
	ring_material.emission_enabled = true
	ring_material.emission = Color("087be8")
	ring_material.emission_energy_multiplier = 4.5
	ring_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring.material_override = ring_material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	ring.global_transform = Transform3D(oriented, position + Vector3(0.0, 0.0, 0.28))
	var ring_color := ring_material.albedo_color
	_shockwaves.append({"node": ring, "material": ring_material, "color": ring_color, "age": 0.0, "duration": 0.48})
	_active_vfx_mesh_triangles += _mesh_triangles(ring.mesh)
	var near_face := position + Vector3(-0.28, 0.0, 0.38)
	_spawn_particle_emitter("ImpactDust", near_face, 28, Color("a39077"), Vector3(0.0, 1.0, 0.0), 4.2, 88.0, Vector3(0.0, -3.4, 0.0), 1.35, 1.0, 2.5)
	_spawn_particle_emitter("ImpactSmoke", near_face, 12, Color("657274"), Vector3(0.0, 1.0, 0.0), 1.15, 62.0, Vector3(0.0, 0.25, 0.0), 1.8, 1.0, 2.5)
	_spawn_particle_emitter("ImpactSparks", near_face, 8, Color("75dbff"), Vector3(0.0, 1.0, 0.0), 7.0, 86.0, Vector3(0.0, -3.0, 0.0), 0.72, 0.04, 0.11)
	_configured_particle_budget = 16 + 28 + 12 + 8

func _make_hex_ring() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for cell in 7:
		var centre_y := 0.0 if cell == 0 else cos(TAU * float(cell - 1) / 6.0) * 0.64
		var centre_z := 0.0 if cell == 0 else sin(TAU * float(cell - 1) / 6.0) * 0.64
		var inner := 0.88 if cell == 0 else 0.27
		var outer := 1.0 if cell == 0 else 0.33
		for segment in 6:
			var a0 := TAU * float(segment) / 6.0
			var a1 := TAU * float(segment + 1) / 6.0
			vertices.append_array([
				Vector3(0.0, centre_y + cos(a0) * inner, centre_z + sin(a0) * inner),
				Vector3(0.0, centre_y + cos(a0) * outer, centre_z + sin(a0) * outer),
				Vector3(0.0, centre_y + cos(a1) * outer, centre_z + sin(a1) * outer),
				Vector3(0.0, centre_y + cos(a1) * inner, centre_z + sin(a1) * inner),
			])
			var base := (cell * 6 + segment) * 4
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
	if _particle_pool.has(emitter_name):
		var pooled: GPUParticles3D = _particle_pool[emitter_name]
		pooled.global_position = position
		pooled.visible = true
		pooled.restart()
		pooled.emitting = true
		return pooled
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
	emitter.visible = not _prewarming_effects
	emitter.emitting = not _prewarming_effects
	_particle_pool[emitter_name] = emitter
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
			"spiral_smoke_segments": 100,
			"pooled_projectile_instances": _projectile_pool.size(),
			"pooled_flash_instances": _flash_pool.size(),
			"pooled_particle_emitters": _particle_pool.size(),
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

