class_name M2PreviewFx
extends RefCounted
## Standalone M2 .50 cal visual prototype. Never wired into production weapons.
## Shares the canonical Fx soft falloff and uses bounded reusable visual nodes.

const FLASH_LIMIT := 18
const SMOKE_LIMIT := 16
const LIGHT_LIMIT := 2
const FLASH_DURATION := 0.055

static var _flashes: Array[Node3D] = []
static var _smokes: Array[MeshInstance3D] = []
static var _flash_count := 0
static var _smoke_count := 0
static var _light_count := 0
static var _flash_meshes: Array[ArrayMesh] = []
static var _smoke_mesh: QuadMesh


static func counts() -> Dictionary:
	return {
		"m2_flash_live": _flash_count,
		"m2_flash_pooled": _flashes.size(),
		"m2_smoke_live": _smoke_count,
		"m2_smoke_pooled": _smokes.size(),
		"m2_lights": _light_count
	}


static func fire(parent: Node3D, position_world: Vector3, angle: float, profile: int, shot_number: int) -> void:
	_flash(parent, position_world, angle, shot_number)
	if profile > 0 and shot_number % (4 if profile == 1 else 2) == 0:
		_smoke(parent, position_world, angle)


static func _mesh_for_variant(variant: int) -> ArrayMesh:
	while _flash_meshes.size() <= variant:
		_flash_meshes.append(null)
	if _flash_meshes[variant] != null:
		return _flash_meshes[variant]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seed := RandomNumberGenerator.new()
	seed.seed = 77021 + variant * 1103
	var length := 1.05 * seed.randf_range(0.88, 1.12)
	var width := 0.28 * seed.randf_range(0.85, 1.12)
	var core := Color(1.0, 0.97, 0.79, 1.0)
	var edge := Color(1.0, 0.59, 0.12, 0.84)
	var tip := Color(0.97, 0.20, 0.02, 0.0)
	# Two crossing flame planes retain volume from the game's top-down view.
	for plane in 2:
		for side in [-1.0, 1.0]:
			var root := Vector3(0.0, 0.0, 0.0)
			var wing := Vector3(side * width, 0.04, length * 0.20) if plane == 0 else Vector3(0.0, side * width, length * 0.20)
			var end := Vector3(side * width * 0.18, 0.04, length) if plane == 0 else Vector3(0.0, side * width * 0.18, length)
			_triangle(st, root, core, wing, edge, end, tip)
			var hot_wing := Vector3(side * width * 0.27, 0.045, length * 0.18) if plane == 0 else Vector3(0.0, side * width * 0.27, length * 0.18)
			var hot_end := Vector3(0.0, 0.05, length * 0.56)
			_triangle(st, root, core, hot_wing, core, hot_end, Color(1.0, 0.82, 0.34, 0.0))
	var created := st.commit()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = false
	created.surface_set_material(0, mat)
	_flash_meshes[variant] = created
	return created


static func _triangle(st: SurfaceTool, a: Vector3, ac: Color, b: Vector3, bc: Color, c: Vector3, cc: Color) -> void:
	st.set_color(ac)
	st.add_vertex(a)
	st.set_color(bc)
	st.add_vertex(b)
	st.set_color(cc)
	st.add_vertex(c)


static func _flash(parent: Node3D, origin: Vector3, angle: float, shot: int) -> void:
	if _flash_count >= FLASH_LIMIT:
		return
	var holder: Node3D = null
	while not _flashes.is_empty() and holder == null:
		var candidate: Node3D = _flashes.pop_back()
		if is_instance_valid(candidate):
			holder = candidate
	if holder == null:
		holder = Node3D.new()
		holder.name = "PooledM2Flash"
		var flame := MeshInstance3D.new()
		flame.name = "CrossPlaneFlash"
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(flame)
		holder.tree_exiting.connect(_on_flash_destroyed.bind(holder))
	if holder.get_parent() != parent:
		if holder.get_parent() != null:
			holder.reparent(parent)
		else:
			parent.add_child(holder)
	var previous: Tween = holder.get_meta("vfx_tween", null)
	if previous != null and previous.is_valid():
		previous.kill()
	holder.set_meta("vfx_active", true)
	holder.visible = true
	holder.global_position = origin
	holder.rotation.y = angle
	var flame_mesh := holder.get_node("CrossPlaneFlash") as MeshInstance3D
	flame_mesh.mesh = _mesh_for_variant(shot % 4)
	flame_mesh.transparency = 0.0
	flame_mesh.scale = Vector3.ONE * (0.92 + 0.04 * float(shot % 5))
	_flash_count += 1
	var light := holder.get_node_or_null("ShortWarmLight") as OmniLight3D
	if light == null and _light_count < LIGHT_LIMIT:
		light = OmniLight3D.new()
		light.name = "ShortWarmLight"
		light.shadow_enabled = false
		light.light_color = Color(1.0, 0.72, 0.39)
		light.omni_range = 4.0
		holder.add_child(light)
		_light_count += 1
	if light != null:
		light.visible = true
		light.light_energy = 0.9
	var tw := holder.create_tween()
	tw.tween_property(flame_mesh, "transparency", 1.0, FLASH_DURATION)
	tw.parallel().tween_property(flame_mesh, "scale", Vector3.ONE * 0.37, FLASH_DURATION)
	if light != null:
		tw.parallel().tween_property(light, "light_energy", 0.0, FLASH_DURATION)
	tw.tween_callback(_release_flash.bind(holder))
	holder.set_meta("vfx_tween", tw)


static func _release_flash(holder: Node3D) -> void:
	if not is_instance_valid(holder) or not holder.get_meta("vfx_active", false):
		return
	holder.set_meta("vfx_active", false)
	holder.visible = false
	_flash_count = maxi(0, _flash_count - 1)
	_flashes.append(holder)


static func _on_flash_destroyed(holder: Node3D) -> void:
	_flashes.erase(holder)
	if holder.get_meta("vfx_active", false):
		_flash_count = maxi(0, _flash_count - 1)
	if holder.has_node("ShortWarmLight"):
		_light_count = maxi(0, _light_count - 1)


static func _smoke(parent: Node3D, origin: Vector3, angle: float) -> void:
	if _smoke_count >= SMOKE_LIMIT:
		return
	if _smoke_mesh == null:
		_smoke_mesh = QuadMesh.new()
		_smoke_mesh.size = Vector2.ONE
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.albedo_texture = Fx.soft()
		mat.albedo_color = Color(0.48, 0.46, 0.42, 0.18)
		_smoke_mesh.material = mat
	var smoke: MeshInstance3D = null
	while not _smokes.is_empty() and smoke == null:
		var candidate: MeshInstance3D = _smokes.pop_back()
		if is_instance_valid(candidate):
			smoke = candidate
	if smoke == null:
		smoke = MeshInstance3D.new()
		smoke.name = "PooledM2Smoke"
		smoke.mesh = _smoke_mesh
		smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		smoke.tree_exiting.connect(_on_smoke_destroyed.bind(smoke))
	if smoke.get_parent() != parent:
		if smoke.get_parent() != null:
			smoke.reparent(parent)
		else:
			parent.add_child(smoke)
	var old: Tween = smoke.get_meta("vfx_tween", null)
	if old != null and old.is_valid():
		old.kill()
	smoke.set_meta("vfx_active", true)
	smoke.visible = true
	smoke.global_position = origin
	smoke.transparency = 0.0
	smoke.scale = Vector3.ONE * 0.20
	_smoke_count += 1
	var displacement := Vector3(-sin(angle) * 0.15, 0.25, -cos(angle) * 0.15)
	var tw := smoke.create_tween()
	tw.tween_property(smoke, "scale", Vector3.ONE * 0.62, 0.32)
	tw.parallel().tween_property(smoke, "transparency", 1.0, 0.32)
	tw.parallel().tween_property(smoke, "global_position", origin + displacement, 0.32)
	tw.tween_callback(_release_smoke.bind(smoke))
	smoke.set_meta("vfx_tween", tw)


static func _release_smoke(smoke: MeshInstance3D) -> void:
	if not is_instance_valid(smoke) or not smoke.get_meta("vfx_active", false):
		return
	smoke.set_meta("vfx_active", false)
	smoke.visible = false
	_smoke_count = maxi(0, _smoke_count - 1)
	_smokes.append(smoke)


static func _on_smoke_destroyed(smoke: MeshInstance3D) -> void:
	_smokes.erase(smoke)
	if smoke.get_meta("vfx_active", false):
		_smoke_count = maxi(0, _smoke_count - 1)
