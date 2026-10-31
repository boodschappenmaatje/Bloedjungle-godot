class_name AirfieldPavementModules
extends Node3D
## Separate, repeatable concrete paving layer for the 2.3 buildable complex.
## Shared meshes/materials keep renderer submissions low; simple per-tile shapes provide joins.

const SLAB_DEPTH := 0.22
const RUNWAY_WIDTH := AirfieldHQ23.RUNWAY_WIDTH_M
const RUNWAY_SEGMENT := 15.0
const TAXIWAY_WIDTH := 18.4
const TAXI_SEGMENT := 8.0
const APRON_SIZE := Vector2(18.0, 14.0)
const LOD0_END_M := 140.0
const LOD1_END_M := 700.0
const LOD2_END_M := 2500.0
const PSP_LIBRARY_SCENE := "res://assets/airfield_hq_v23/psp/PSP_plate_library.glb"
const PSP_PLATE_COUNT := 8
const PSP_PATCH_CENTER := Vector2(0.0, -5.25)

var _concrete: StandardMaterial3D
var _concrete_flat: StandardMaterial3D
var _joint_material: StandardMaterial3D
var _runway_mesh: BoxMesh
var _runway_mesh_lod1: BoxMesh
var _runway_mesh_lod2: PlaneMesh
var _taxi_mesh: BoxMesh
var _taxi_mesh_lod1: BoxMesh
var _taxi_mesh_lod2: PlaneMesh
var _apron_mesh: BoxMesh
var _apron_mesh_lod1: BoxMesh
var _apron_mesh_lod2: PlaneMesh

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
	_concrete_flat = StandardMaterial3D.new()
	_concrete_flat.albedo_color = Color("b8b6ad")
	_concrete_flat.roughness = 0.92
	_joint_material = StandardMaterial3D.new()
	_joint_material.albedo_color = Color("66635c")
	_joint_material.roughness = 0.96
	_runway_mesh = _make_mesh(Vector3(RUNWAY_WIDTH, SLAB_DEPTH, RUNWAY_SEGMENT))
	_runway_mesh_lod1 = _make_mesh(Vector3(RUNWAY_WIDTH, SLAB_DEPTH, RUNWAY_SEGMENT), _concrete_flat)
	_runway_mesh_lod2 = _make_plane(Vector2(RUNWAY_WIDTH, RUNWAY_SEGMENT))
	_taxi_mesh = _make_mesh(Vector3(TAXIWAY_WIDTH, SLAB_DEPTH, TAXI_SEGMENT - 0.3))
	_taxi_mesh_lod1 = _make_mesh(Vector3(TAXIWAY_WIDTH, SLAB_DEPTH, TAXI_SEGMENT - 0.3), _concrete_flat)
	_taxi_mesh_lod2 = _make_plane(Vector2(TAXIWAY_WIDTH, TAXI_SEGMENT))
	_apron_mesh = _make_mesh(Vector3(APRON_SIZE.x - 0.06, SLAB_DEPTH, APRON_SIZE.y - 0.06))
	_apron_mesh_lod1 = _make_mesh(Vector3(APRON_SIZE.x - 0.06, SLAB_DEPTH, APRON_SIZE.y - 0.06), _concrete_flat)
	_apron_mesh_lod2 = _make_plane(APRON_SIZE)

func _make_mesh(dimensions: Vector3, material: StandardMaterial3D = null) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	mesh.material = _concrete if material == null else material
	return mesh

func _make_plane(dimensions: Vector2) -> PlaneMesh:
	var mesh := PlaneMesh.new()
	mesh.size = dimensions
	mesh.material = _concrete_flat
	return mesh

func _multimesh(name: String, mesh: Mesh, transforms: Array[Transform3D], range_begin: float, range_end: float, plane_offset_y: float = 0.0) -> void:
	if transforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		var transform := transforms[i]
		transform.origin.y += plane_offset_y
		mm.set_instance_transform(i, transform)
	var instance := MultiMeshInstance3D.new()
	instance.name = name
	instance.multimesh = mm
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.visibility_range_begin = range_begin
	instance.visibility_range_end = range_end
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
	# Five real 15 m concrete slabs form the exact 75 × 18 m strip. The field
	# stays beside the unchanged HQ2.2 structures; joints meet without open gaps.
	var transforms: Array[Transform3D] = []
	var joint_transforms: Array[Transform3D] = []
	for i in range(5):
		var x := AirfieldHQ23.RUNWAY_START_X + RUNWAY_SEGMENT * 0.5 + i * RUNWAY_SEGMENT
		var transform := Transform3D(Basis(Vector3.UP, PI * 0.5), AirfieldHQ23.layout_point(x, AirfieldHQ23.RUNWAY_CENTER_Z, SLAB_DEPTH * 0.5))
		transforms.append(transform)
		_collider("Runway slab collision %02d" % i, Vector3(RUNWAY_WIDTH, SLAB_DEPTH, RUNWAY_SEGMENT + 0.04), transform)
		if i > 0:
			var joint_x := AirfieldHQ23.RUNWAY_START_X + float(i) * RUNWAY_SEGMENT
			joint_transforms.append(Transform3D(Basis.IDENTITY, AirfieldHQ23.layout_point(joint_x, AirfieldHQ23.RUNWAY_CENTER_Z, SLAB_DEPTH - 0.004)))
	_multimesh("Runway concrete slabs LOD0", _runway_mesh, transforms, 0.0, LOD0_END_M)
	_multimesh("Runway concrete slabs LOD1", _runway_mesh_lod1, transforms, LOD0_END_M, LOD1_END_M)
	_multimesh("Runway concrete slabs LOD2", _runway_mesh_lod2, transforms, LOD1_END_M, LOD2_END_M, SLAB_DEPTH * 0.5)
	var runway_joint_mesh := BoxMesh.new()
	runway_joint_mesh.size = Vector3(0.035, 0.006, RUNWAY_WIDTH)
	runway_joint_mesh.material = _joint_material
	_multimesh("Runway recessed expansion joints", runway_joint_mesh, joint_transforms, 0.0, LOD0_END_M)

func _build_apron() -> void:
	# One dedicated, level parking stand for the initial single validated slot.
	var transform := Transform3D(Basis.IDENTITY, AirfieldHQ23.layout_point(AirfieldHQ23.APRON_CENTER.x, AirfieldHQ23.APRON_CENTER.y, SLAB_DEPTH * 0.5))
	_multimesh("Aircraft apron parking slab LOD0", _apron_mesh, [transform], 0.0, LOD0_END_M)
	_multimesh("Aircraft apron parking slab LOD1", _apron_mesh_lod1, [transform], LOD0_END_M, LOD1_END_M)
	_multimesh("Aircraft apron parking slab LOD2", _apron_mesh_lod2, [transform], LOD1_END_M, LOD2_END_M, SLAB_DEPTH * 0.5)
	_collider("Aircraft apron parking collision", Vector3(APRON_SIZE.x, SLAB_DEPTH, APRON_SIZE.y), transform)
	_build_psp_apron_patch()

func _build_psp_apron_patch() -> void:
	# Eight historical PSP plates form one small temporary surfacing patch at
	# the back edge of the existing apron. It adds no terrain area or collision.
	var packed := load(PSP_LIBRARY_SCENE) as PackedScene
	if packed == null:
		push_warning("PSP library could not be loaded; apron remains usable without its optional temporary strip.")
		return
	var library := packed.instantiate()
	var lod_meshes := {}
	for node in library.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		if mesh_node.name.begins_with("PSP_Plate_LOD0_"):
			lod_meshes[0] = mesh_node.mesh
		elif mesh_node.name.begins_with("PSP_Plate_LOD1_"):
			lod_meshes[1] = mesh_node.mesh
		elif mesh_node.name.begins_with("PSP_Plate_LOD2_"):
			lod_meshes[2] = mesh_node.mesh
	library.free()
	if lod_meshes.size() != 3:
		push_warning("PSP library is missing one or more LOD meshes; optional apron strip skipped.")
		return
	var transforms: Array[Transform3D] = []
	var origin := AirfieldHQ23.layout_point(
		AirfieldHQ23.APRON_CENTER.x + PSP_PATCH_CENTER.x,
		AirfieldHQ23.APRON_CENTER.y + PSP_PATCH_CENTER.y,
		SLAB_DEPTH + 0.004
	)
	var plate_width := 0.381
	for index in PSP_PLATE_COUNT:
		var x := (float(index) - float(PSP_PLATE_COUNT - 1) * 0.5) * plate_width
		transforms.append(Transform3D(Basis.IDENTITY, origin + Vector3(x, 0.0, 0.0)))
	_multimesh("Historic PSP apron patch LOD0", lod_meshes[0], transforms, 0.0, LOD0_END_M)
	_multimesh("Historic PSP apron patch LOD1", lod_meshes[1], transforms, LOD0_END_M, LOD1_END_M)
	_multimesh("Historic PSP apron patch LOD2", lod_meshes[2], transforms, LOD1_END_M, LOD2_END_M)

func _build_taxiway() -> void:
	var integration := get_parent().get_node_or_null("AirfieldFlightIntegration") as AirfieldFlightIntegration
	if integration == null or integration.taxi_route == null or integration.taxi_route.curve == null:
		return
	var curve := integration.taxi_route.curve
	var length := curve.get_baked_length()
	var transforms: Array[Transform3D] = []
	var joint_transforms: Array[Transform3D] = []
	var joint_distance := TAXI_SEGMENT - 0.3
	while joint_distance < length:
		var joint_position := curve.sample_baked(joint_distance)
		var joint_before := curve.sample_baked(maxf(0.0, joint_distance - 0.5))
		var joint_after := curve.sample_baked(minf(length, joint_distance + 0.5))
		var joint_direction := joint_after - joint_before
		joint_direction.y = 0.0
		var joint_yaw := atan2(joint_direction.x, joint_direction.z)
		joint_transforms.append(Transform3D(Basis(Vector3.UP, joint_yaw), Vector3(joint_position.x, SLAB_DEPTH - 0.004, joint_position.z)))
		joint_distance += TAXI_SEGMENT - 0.3
	var offset := TAXI_SEGMENT * 0.5
	var index := 0
	var batch := 0
	while offset < length + TAXI_SEGMENT * 0.5:
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
		_collider("Taxiway slab collision %02d" % index, Vector3(TAXIWAY_WIDTH, SLAB_DEPTH, TAXI_SEGMENT - 0.08), transform)
		index += 1
		if transforms.size() >= 16:
			_flush_taxi_batch(batch, transforms)
			batch += 1
			transforms = []
		offset += TAXI_SEGMENT - 0.3
	_flush_taxi_batch(batch, transforms)
	var taxi_joint_mesh := BoxMesh.new()
	taxi_joint_mesh.size = Vector3(0.035, 0.006, TAXIWAY_WIDTH)
	taxi_joint_mesh.material = _joint_material
	_multimesh("Taxiway recessed module joints", taxi_joint_mesh, joint_transforms, 0.0, LOD0_END_M)

func _flush_taxi_batch(batch: int, transforms: Array[Transform3D]) -> void:
	_multimesh("Curved taxiway concrete segment %02d LOD0" % batch, _taxi_mesh, transforms, 0.0, LOD0_END_M)
	_multimesh("Curved taxiway concrete segment %02d LOD1" % batch, _taxi_mesh_lod1, transforms, LOD0_END_M, LOD1_END_M)
	_multimesh("Curved taxiway concrete segment %02d LOD2" % batch, _taxi_mesh_lod2, transforms, LOD1_END_M, LOD2_END_M, SLAB_DEPTH * 0.5)
