class_name AirfieldPavementModules
extends Node3D
## Authored, bevelled HQ23 concrete modules with separate simplified physics proxies.

const SLAB_DEPTH := 0.22
const RUNWAY_WIDTH := AirfieldHQ23.RUNWAY_WIDTH_M
const RUNWAY_SEGMENT := 15.0
const TAXIWAY_WIDTH := AirfieldHQ23.TAXIWAY_WIDTH_M
const TAXI_COLLISION_STEP := 4.0
const APRON_SIZE := Vector2(18.0, 14.0)
const LOD0_END_M := 140.0
const LOD1_END_M := 700.0
const LOD2_END_M := 2500.0
const PSP_LIBRARY_SCENE := "res://assets/airfield_hq_v23/psp/PSP_plate_library.glb"
const RUNWAY_MODULES := [
	"res://assets/airfield_hq_v23/pavement/Airfield_Runway_Slab_HQ23_LOD0.glb",
	"res://assets/airfield_hq_v23/pavement/Airfield_Runway_Slab_HQ23_LOD1.glb",
	"res://assets/airfield_hq_v23/pavement/Airfield_Runway_Slab_HQ23_LOD2.glb",
]
const APRON_MODULES := [
	"res://assets/airfield_hq_v23/pavement/Airfield_Apron_Slab_HQ23_LOD0.glb",
	"res://assets/airfield_hq_v23/pavement/Airfield_Apron_Slab_HQ23_LOD1.glb",
	"res://assets/airfield_hq_v23/pavement/Airfield_Apron_Slab_HQ23_LOD2.glb",
]
const TAXI_MODULES := [
	"res://assets/airfield_hq_v23/pavement/Airfield_Taxiway_HQ23_Compact_LOD0.glb",
	"res://assets/airfield_hq_v23/pavement/Airfield_Taxiway_HQ23_Compact_LOD1.glb",
	"res://assets/airfield_hq_v23/pavement/Airfield_Taxiway_HQ23_Compact_LOD2.glb",
]
const PSP_PLATE_COUNT := 8
const PSP_PATCH_CENTER := Vector2(0.0, -5.25)

var _runway_meshes: Array[Mesh] = []
var _taxi_meshes: Array[Mesh] = []
var _apron_meshes: Array[Mesh] = []

func _ready() -> void:
	_runway_meshes = _load_module_meshes(RUNWAY_MODULES)
	_taxi_meshes = _load_module_meshes(TAXI_MODULES)
	_apron_meshes = _load_module_meshes(APRON_MODULES)
	_build_runway()
	_build_apron()
	_build_taxiway()

func _load_module_meshes(paths: Array) -> Array[Mesh]:
	var meshes: Array[Mesh] = []
	for path in paths:
		var packed := load(path) as PackedScene
		if packed == null:
			push_error("Missing authored concrete module: %s" % path)
			continue
		var root := packed.instantiate()
		var candidates := root.find_children("*", "MeshInstance3D", true, false)
		if root is MeshInstance3D:
			candidates.push_front(root)
		var mesh: Mesh = (candidates.front() as MeshInstance3D).mesh if not candidates.is_empty() else null
		if mesh == null:
			push_error("Authored concrete module contains no mesh: %s" % path)
		else:
			meshes.append(mesh)
		root.free()
	return meshes

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
	# Five bevelled 15 m HQ23 PBR concrete modules share one exact straight axis.
	var transforms: Array[Transform3D] = []
	for i in range(5):
		var x := AirfieldHQ23.RUNWAY_START_X + RUNWAY_SEGMENT * 0.5 + i * RUNWAY_SEGMENT
		var transform := Transform3D(Basis(Vector3.UP, PI * 0.5), AirfieldHQ23.layout_point(x, AirfieldHQ23.RUNWAY_CENTER_Z, SLAB_DEPTH * 0.5))
		transforms.append(transform)
		_collider("Runway slab collision %02d" % i, Vector3(RUNWAY_WIDTH, SLAB_DEPTH, RUNWAY_SEGMENT + 0.04), transform)
	_multimesh("Runway concrete slabs LOD0", _runway_meshes[0], transforms, 0.0, LOD0_END_M)
	_multimesh("Runway concrete slabs LOD1", _runway_meshes[1], transforms, LOD0_END_M, LOD1_END_M)
	_multimesh("Runway concrete slabs LOD2", _runway_meshes[2], transforms, LOD1_END_M, LOD2_END_M)

func _build_apron() -> void:
	# One dedicated, level parking stand for the initial single validated slot.
	var transform := Transform3D(Basis.IDENTITY, AirfieldHQ23.layout_point(AirfieldHQ23.APRON_CENTER.x, AirfieldHQ23.APRON_CENTER.y, SLAB_DEPTH * 0.5))
	_multimesh("Aircraft apron parking slab LOD0", _apron_meshes[0], [transform], 0.0, LOD0_END_M)
	_multimesh("Aircraft apron parking slab LOD1", _apron_meshes[1], [transform], LOD0_END_M, LOD1_END_M)
	_multimesh("Aircraft apron parking slab LOD2", _apron_meshes[2], [transform], LOD1_END_M, LOD2_END_M)
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
	_add_taxi_surface(_taxi_meshes[0], "Taxiway continuous PBR curve LOD0", 0.0, LOD0_END_M)
	_add_taxi_surface(_taxi_meshes[1], "Taxiway continuous PBR curve LOD1", LOD0_END_M, LOD1_END_M)
	_add_taxi_surface(_taxi_meshes[2], "Taxiway continuous PBR curve LOD2", LOD1_END_M, LOD2_END_M)
	var offset := TAXI_COLLISION_STEP * 0.5
	var index := 0
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
		_collider("Taxiway slab collision %02d" % index, Vector3(TAXIWAY_WIDTH, SLAB_DEPTH, TAXI_COLLISION_STEP + 0.15), transform)
		index += 1
		offset += TAXI_COLLISION_STEP

func _add_taxi_surface(mesh: Mesh, label: String, range_begin: float, range_end: float) -> void:
	var surface := MeshInstance3D.new()
	surface.name = label
	surface.mesh = mesh
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	surface.visibility_range_begin = range_begin
	surface.visibility_range_end = range_end
	surface.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	add_child(surface)
