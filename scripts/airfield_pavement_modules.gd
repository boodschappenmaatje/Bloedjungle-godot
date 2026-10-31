class_name AirfieldPavementModules
extends Node3D
## Separate, repeatable concrete paving layer for the 2.3 buildable complex.
## Shared meshes/materials keep renderer submissions low; simple per-tile shapes provide joins.

const SLAB_DEPTH := 0.22
const RUNWAY_WIDTH := 38.0
const RUNWAY_SEGMENT := 15.0
const TAXIWAY_WIDTH := 18.4
const TAXI_SEGMENT := 8.0
const APRON_TILE := 14.0

var _concrete: StandardMaterial3D
var _runway_mesh: BoxMesh
var _taxi_mesh: BoxMesh
var _apron_mesh: BoxMesh

func _ready() -> void:
	_build_material()
	_build_runway()
	_build_apron()
	_build_taxiway()

func _build_material() -> void:
	_concrete = StandardMaterial3D.new()
	_concrete.albedo_color = Color("b8b6ad")
	_concrete.albedo_texture = load("res://assets/airfield_hq_v22/runtime/Bloedjungle_Airfield_HQ_2_2_LOD0_concrete_floor_01_diff_2k.jpg")
	_concrete.normal_enabled = true
	_concrete.normal_texture = load("res://assets/airfield_hq_v22/runtime/Bloedjungle_Airfield_HQ_2_2_LOD0_concrete_floor_01_nor_gl_2k.jpg")
	_concrete.roughness = 0.88
	_concrete.uv1_scale = Vector3(6.0, 6.0, 6.0)
	_runway_mesh = _make_mesh(Vector3(RUNWAY_WIDTH, SLAB_DEPTH, RUNWAY_SEGMENT - 0.06))
	_taxi_mesh = _make_mesh(Vector3(TAXIWAY_WIDTH, SLAB_DEPTH, TAXI_SEGMENT - 0.3))
	_apron_mesh = _make_mesh(Vector3(APRON_TILE - 0.06, SLAB_DEPTH, APRON_TILE - 0.06))

func _make_mesh(dimensions: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	mesh.material = _concrete
	return mesh

func _multimesh(name: String, mesh: Mesh, transforms: Array[Transform3D]) -> void:
	if transforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = name
	instance.multimesh = mm
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)

func _collider(name: String, dimensions: Vector3, transform: Transform3D) -> void:
	var body := StaticBody3D.new()
	body.name = name
	body.collision_layer = Kit.LAYER_GROUND
	body.collision_mask = 0
	body.transform = transform
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	shape_node.shape = shape
	body.add_child(shape_node)
	add_child(body)

func _build_runway() -> void:
	# Six culling batches, each 150 m long; concrete expansion joints remain 15 m apart.
	for chunk_index in range(6):
		var transforms: Array[Transform3D] = []
		for local_index in range(10):
			var i := chunk_index * 10 + local_index
			var z := -107.5 - i * RUNWAY_SEGMENT
			var transform := Transform3D(Basis.IDENTITY, Vector3(0, SLAB_DEPTH * 0.5, z))
			transforms.append(transform)
			_collider("Runway slab collision %02d" % i, Vector3(RUNWAY_WIDTH, SLAB_DEPTH, RUNWAY_SEGMENT - 0.06), transform)
		_multimesh("Runway concrete segment %02d" % chunk_index, _runway_mesh, transforms)

func _build_apron() -> void:
	var transforms: Array[Transform3D] = []
	var index := 0
	# A 112 × 98 m apron, separate from runway and taxiway material systems.
	for x_index in range(8):
		for z_index in range(7):
			var x := -49.0 + x_index * APRON_TILE
			var z := -30.0 + z_index * APRON_TILE
			var position := Vector3(x, SLAB_DEPTH * 0.5, z)
			var transform := Transform3D(Basis.IDENTITY, position)
			transforms.append(transform)
			_collider("Apron slab collision %02d" % index, Vector3(APRON_TILE - 0.06, SLAB_DEPTH, APRON_TILE - 0.06), transform)
			index += 1
	_multimesh("Apron concrete slabs", _apron_mesh, transforms)

func _build_taxiway() -> void:
	var integration := get_parent().get_node_or_null("AirfieldFlightIntegration") as AirfieldFlightIntegration
	if integration == null or integration.taxi_route == null or integration.taxi_route.curve == null:
		return
	var curve := integration.taxi_route.curve
	var length := curve.get_baked_length()
	var transforms: Array[Transform3D] = []
	var offset := TAXI_SEGMENT * 0.5
	var index := 0
	var batch := 0
	while offset < length:
		var local_position := curve.sample_baked(offset)
		var before := curve.sample_baked(maxf(0.0, offset - 0.5))
		var after := curve.sample_baked(minf(length, offset + 0.5))
		var direction := after - before
		direction.y = 0.0
		var yaw := atan2(direction.x, direction.z)
		var basis := Basis(Vector3.UP, yaw)
		var position := Vector3(local_position.x, SLAB_DEPTH * 0.5, local_position.z)
		var transform := Transform3D(basis, position)
		transforms.append(transform)
		_collider("Taxiway slab collision %02d" % index, Vector3(TAXIWAY_WIDTH, SLAB_DEPTH, TAXI_SEGMENT - 0.3), transform)
		index += 1
		if transforms.size() >= 16:
			_multimesh("Curved taxiway concrete segment %02d" % batch, _taxi_mesh, transforms)
			batch += 1
			transforms = []
		offset += TAXI_SEGMENT - 0.3
	_multimesh("Curved taxiway concrete segment %02d" % batch, _taxi_mesh, transforms)
