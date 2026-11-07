extends StaticBody3D

const WALL_LAYER := 1 << 7
const DEBRIS_LAYER := 1 << 5
const GROUND_LAYER := 1 << 3

var _collision_shape: CollisionShape3D
var _test_label: Label3D
var _visuals: Array[MeshInstance3D] = []
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
	concrete.albedo_color = Color("68706f")
	concrete.roughness = 0.94
	concrete.metallic = 0.04
	concrete.normal_enabled = false
	var edge := StandardMaterial3D.new()
	edge.albedo_color = Color("313a3a")
	edge.roughness = 0.82
	edge.metallic = 0.48
	var hazard := StandardMaterial3D.new()
	hazard.albedo_color = Color("d1a044")
	hazard.roughness = 0.77
	hazard.metallic = 0.18

	# A modular concrete test panel with dark steel seams and small hazard edges.
	_add_box("Foundation", Vector3(0.68, 0.24, 3.8), Vector3(0.0, -1.22, 0.0), edge)
	_add_box("TopCap", Vector3(0.66, 0.18, 3.72), Vector3(0.0, 1.22, 0.0), edge)
	for row in 2:
		for column in 4:
			var size := Vector3(0.51, 1.0, 0.84)
			var position := Vector3(0.0, -0.59 + float(row) * 1.02, -1.29 + float(column) * 0.86)
			_add_box("Concrete_%d_%d" % [row, column], size, position, concrete)
	for z_sign in [-1.0, 1.0]:
		_add_box("SteelPier_%s" % str(z_sign), Vector3(0.58, 2.42, 0.16), Vector3(0.0, 0.0, z_sign * 1.73), edge)
		_add_box("HazardEdge_%s" % str(z_sign), Vector3(0.59, 0.08, 0.2), Vector3(0.0, 1.05, z_sign * 1.73), hazard)

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

func _add_box(box_name: String, size: Vector3, position: Vector3, material: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = box_name
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	mesh_instance.mesh = box
	mesh_instance.position = position
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mesh_instance)
	_visuals.append(mesh_instance)

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
		var mesh := BoxMesh.new()
		mesh.size = size
		mesh.material = material
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = mesh
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(mesh_instance)
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size * 0.92
		shape.shape = box_shape
		body.add_child(shape)
		debris_parent.add_child(body)
		var side := -1.0 if index % 2 == 0 else 1.0
		body.global_position = impact_point + Vector3(0.08, rng.randf_range(-0.46, 0.52), side * rng.randf_range(0.12, 0.56))
		var impulse := Vector3(rng.randf_range(0.7, 2.3), rng.randf_range(1.3, 3.9), rng.randf_range(-2.1, 2.1))
		body.apply_central_impulse(impulse)
		body.apply_torque_impulse(Vector3(rng.randf_range(-0.45, 0.45), rng.randf_range(-0.45, 0.45), rng.randf_range(-0.45, 0.45)))
		_debris.append(body)
	print("TEST_WALL_DEBRIS_SPAWNED ", _debris.size())
