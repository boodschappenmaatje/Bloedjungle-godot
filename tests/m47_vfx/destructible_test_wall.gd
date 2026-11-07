extends StaticBody3D

const WALL_LAYER := 1 << 7
const DEBRIS_LAYER := 1 << 5
const GROUND_LAYER := 1 << 3

var _collision_shape: CollisionShape3D
var _test_label: Label3D
var _visuals: Array[MeshInstance3D] = []
var _fracture_visuals: Array[Node3D] = []
var _debris: Array[RigidBody3D] = []
var _destroyed := false

func _ready() -> void:
	name = "M47_VFX_TEST_Wall"
	collision_layer = WALL_LAYER
	collision_mask = 0
	_build_panel()

func get_impact_point() -> Vector3:
	return global_position + Vector3(0.0, 0.12, 0.0)

func get_wall_collision() -> CollisionShape3D:
	return _collision_shape

func get_test_label() -> Label3D:
	return _test_label

func get_debris() -> Array[RigidBody3D]:
	return _debris

func is_destroyed() -> bool:
	return _destroyed

func break_open(debris_parent: Node3D, impact_point: Vector3) -> void:
	if _destroyed:
		return
	_destroyed = true
	collision_layer = 0
	collision_mask = 0
	_collision_shape.set_deferred("disabled", true)
	for visual in _visuals:
		visual.visible = false
	for visual in _fracture_visuals:
		visual.visible = true
	if _test_label != null:
		_test_label.visible = false
	_spawn_debris(debris_parent, impact_point)

func _build_panel() -> void:
	_collision_shape = CollisionShape3D.new()
	_collision_shape.name = "UpdatedTestWallCollision"
	var wall_shape := BoxShape3D.new()
	wall_shape.size = Vector3(0.52, 2.55, 3.55)
	_collision_shape.shape = wall_shape
	add_child(_collision_shape)

	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color("b4aa98")
	concrete.albedo_texture = load("res://wall_concrete_albedo.jpg") as Texture2D
	concrete.roughness = 0.94
	concrete.metallic = 0.04
	concrete.normal_enabled = true
	concrete.normal_texture = load("res://wall_concrete_normal.jpg") as Texture2D
	concrete.normal_scale = 1.35
	var fracture := StandardMaterial3D.new()
	fracture.albedo_color = Color("8d806c")
	fracture.roughness = 0.98
	var edge := StandardMaterial3D.new()
	edge.albedo_color = Color("313a3a")
	edge.roughness = 0.82
	edge.metallic = 0.48
	var hazard := StandardMaterial3D.new()
	hazard.albedo_color = Color("d1a044")
	hazard.roughness = 0.77
	hazard.metallic = 0.18

	# Keep the structural frame after the centre slab opens. Only the slab is removed.
	_add_box("Foundation", Vector3(0.68, 0.24, 3.8), Vector3(0.0, -1.22, 0.0), edge, false)
	_add_box("TopCap", Vector3(0.66, 0.18, 3.72), Vector3(0.0, 1.22, 0.0), edge, false)
	_add_box("ContinuousConcreteSlab", Vector3(0.51, 2.30, 3.30), Vector3.ZERO, concrete)
	for seam_z in [-1.05, -0.14, 0.88]:
		_add_box("FineScoredJoint", Vector3(0.016, 2.23, 0.013), Vector3(-0.264, 0.0, seam_z), edge)
	for z_sign in [-1.0, 1.0]:
		_add_box("SteelPier_%s" % str(z_sign), Vector3(0.58, 2.42, 0.16), Vector3(0.0, 0.0, z_sign * 1.73), edge, false)
		_add_box("HazardEdge_%s" % str(z_sign), Vector3(0.59, 0.08, 0.2), Vector3(0.0, 1.05, z_sign * 1.73), hazard, false)
	var rim_rng := RandomNumberGenerator.new()
	rim_rng.seed = 470022
	for index in 8:
		var rim := MeshInstance3D.new()
		rim.name = "JaggedFractureRim_%02d" % index
		rim.mesh = _make_shard_mesh(Vector3(rim_rng.randf_range(0.24, 0.42), rim_rng.randf_range(0.32, 0.60), rim_rng.randf_range(0.38, 0.70)))
		rim.material_override = fracture
		rim.position = Vector3(-0.11, (0.91 if index < 4 else -0.90) + rim_rng.randf_range(-0.13, 0.13), -1.25 + float(index % 4) * 0.82 + rim_rng.randf_range(-0.17, 0.17))
		rim.rotation.x = rim_rng.randf_range(-PI, PI)
		rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rim.visible = false
		add_child(rim)
		_fracture_visuals.append(rim)
	var rubble_mesh := _make_shard_mesh(Vector3(0.25, 0.24, 0.34))
	rubble_mesh.surface_set_material(0, fracture)
	var rubble_instances := MultiMesh.new()
	rubble_instances.transform_format = MultiMesh.TRANSFORM_3D
	rubble_instances.mesh = rubble_mesh
	rubble_instances.instance_count = 18
	var rubble_rng := RandomNumberGenerator.new()
	rubble_rng.seed = 470021
	for index in 18:
		var rotation := Basis(Vector3.UP, rubble_rng.randf_range(-PI, PI))
		var size_scale := rubble_rng.randf_range(0.65, 2.2)
		var offset := Vector3(rubble_rng.randf_range(-1.05, -0.30), -1.13, rubble_rng.randf_range(-1.48, 1.48))
		rubble_instances.set_instance_transform(index, Transform3D(rotation.scaled(Vector3.ONE * size_scale), offset))
	var rubble_pile := MultiMeshInstance3D.new()
	rubble_pile.name = "PersistentBrokenWallRubble"
	rubble_pile.multimesh = rubble_instances
	rubble_pile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rubble_pile.visible = false
	add_child(rubble_pile)
	_fracture_visuals.append(rubble_pile)

	_test_label = Label3D.new()
	_test_label.name = "TestRangeLabel"
	_test_label.text = "M-47  /  IMPACT TEST"
	_test_label.font_size = 34
	_test_label.pixel_size = 0.0035
	_test_label.modulate = Color("d9e2df")
	_test_label.outline_size = 5
	_test_label.outline_modulate = Color("172124")
	_test_label.position = Vector3(-0.36, 1.08, 0.0)
	_test_label.rotation.y = -PI / 2.0
	add_child(_test_label)

func _add_box(box_name: String, size: Vector3, position: Vector3, material: Material, breaks: bool = true) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = box_name
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	mesh_instance.mesh = box
	mesh_instance.position = position
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mesh_instance)
	if breaks:
		_visuals.append(mesh_instance)

func _make_shard_mesh(size: Vector3) -> ArrayMesh:
	var points := PackedVector3Array([
		Vector3(-size.x * 0.5, -size.y * 0.5, -size.z * 0.5),
		Vector3(size.x * 0.5, -size.y * 0.44, size.z * 0.48),
		Vector3(-size.x * 0.42, size.y * 0.5, size.z * 0.22),
		Vector3(size.x * 0.44, size.y * 0.18, -size.z * 0.5),
	])
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in [[0, 1, 2], [0, 3, 1], [1, 3, 2], [0, 2, 3]]:
		for point_index in face:
			surface.add_vertex(points[point_index])
	surface.generate_normals()
	return surface.commit()

func _spawn_debris(debris_parent: Node3D, impact_point: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 470020
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("747a73")
	material.roughness = 0.98
	material.metallic = 0.02
	for index in 8:
		var size := Vector3(rng.randf_range(0.17, 0.30), rng.randf_range(0.16, 0.34), rng.randf_range(0.18, 0.36))
		var body := RigidBody3D.new()
		body.name = "TestWallDebris_%02d" % index
		body.mass = 0.72
		body.linear_damp = 0.35
		body.angular_damp = 0.55
		body.collision_layer = DEBRIS_LAYER
		body.collision_mask = GROUND_LAYER
		var mesh := _make_shard_mesh(size)
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = mesh
		mesh_instance.material_override = material
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(mesh_instance)
		var shape := CollisionShape3D.new()
		var convex_shape := ConvexPolygonShape3D.new()
		convex_shape.points = PackedVector3Array([
			Vector3(-size.x * 0.5, -size.y * 0.5, -size.z * 0.5),
			Vector3(size.x * 0.5, -size.y * 0.44, size.z * 0.48),
			Vector3(-size.x * 0.42, size.y * 0.5, size.z * 0.22),
			Vector3(size.x * 0.44, size.y * 0.18, -size.z * 0.5),
		])
		shape.shape = convex_shape
		body.add_child(shape)
		debris_parent.add_child(body)
		var side := -1.0 if index % 2 == 0 else 1.0
		body.global_position = impact_point + Vector3(0.08, rng.randf_range(-0.46, 0.52), side * rng.randf_range(0.12, 0.56))
		var impulse := Vector3(rng.randf_range(0.7, 2.3), rng.randf_range(1.3, 3.9), rng.randf_range(-2.1, 2.1))
		body.apply_central_impulse(impulse)
		body.apply_torque_impulse(Vector3(rng.randf_range(-0.45, 0.45), rng.randf_range(-0.45, 0.45), rng.randf_range(-0.45, 0.45)))
		_debris.append(body)
	print("TEST_WALL_DEBRIS_SPAWNED ", _debris.size())
