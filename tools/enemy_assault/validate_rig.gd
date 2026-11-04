extends SceneTree
var scene_path := "res://assets/enemies/assault/assault_meshy_hq2_runtime.glb"
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): scene_path = args[0]
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("Could not load Assault rig GLB as PackedScene")
		quit(1)
		return
	var root := packed.instantiate()
	var skeletons: Array[Skeleton3D] = []
	var meshes: Array[MeshInstance3D] = []
	_collect(root, skeletons, meshes)
	var ok := skeletons.size() == 1 and meshes.size() >= 2
	var skinned_count := 0
	var static_weapon_count := 0
	var body_lods := {}
	var weapon_lods := {}
	var shared_materials: Array[Material] = []
	var shared_surface_material: StandardMaterial3D
	if ok:
		ok = skeletons[0].get_bone_count() == 28
		for mesh in meshes:
			var triangles := _triangles(mesh)
			print("ASSAULT_GODOT_MESH name=", mesh.name, " skin=", mesh.skin != null, " triangles=", triangles)
			if mesh.skin != null:
				skinned_count += 1
				print("ASSAULT_SKINNED_MESH surfaces=", mesh.mesh.get_surface_count() if mesh.mesh != null else 0, " skeleton_path=", mesh.skeleton)
				ok = ok and mesh.mesh != null and mesh.mesh.get_surface_count() > 0
				if mesh.name.begins_with("Assault_Body_"):
					body_lods[mesh.name] = triangles
			elif mesh.name.begins_with("Assault_Meshy_Weapon_Mesh_"):
				static_weapon_count += 1
				weapon_lods[mesh.name] = triangles
				print("ASSAULT_STATIC_WEAPON surfaces=", mesh.mesh.get_surface_count() if mesh.mesh != null else 0)
				ok = ok and mesh.mesh != null and mesh.mesh.get_surface_count() > 0
			if mesh.mesh != null and mesh.mesh.get_surface_count() > 0:
				var material := mesh.get_active_material(0)
				if material != null and material not in shared_materials:
					shared_materials.append(material)
				if material is StandardMaterial3D:
					shared_surface_material = material
		ok = ok and skinned_count == 3 and static_weapon_count == 3 and body_lods.size() == 3 and weapon_lods.size() == 3
		ok = ok and shared_materials.size() == 1
		ok = ok and shared_surface_material != null and shared_surface_material.albedo_texture != null
		ok = ok and shared_surface_material != null and shared_surface_material.normal_enabled and shared_surface_material.normal_texture != null
		ok = ok and shared_surface_material != null and shared_surface_material.roughness_texture != null
		if shared_surface_material != null:
			print("ASSAULT_GODOT_PBR base=", shared_surface_material.albedo_texture.get_size() if shared_surface_material.albedo_texture != null else Vector2i.ZERO,
				" normal=", shared_surface_material.normal_texture.get_size() if shared_surface_material.normal_texture != null else Vector2i.ZERO,
				" roughness=", shared_surface_material.roughness_texture.get_size() if shared_surface_material.roughness_texture != null else Vector2i.ZERO,
				" shared_materials=", shared_materials.size())
	print("ASSAULT_GODOT rig_count=", skeletons.size(), " mesh_nodes=", meshes.size(), " skinned=", skinned_count, " static_weapon=", static_weapon_count, " bones=", skeletons[0].get_bone_count() if not skeletons.is_empty() else 0, " passed=", ok)
	root.free()
	quit(0 if ok else 1)
func _collect(node: Node, skeletons: Array[Skeleton3D], meshes: Array[MeshInstance3D]) -> void:
	if node is Skeleton3D: skeletons.append(node)
	if node is MeshInstance3D: meshes.append(node)
	for child in node.get_children(): _collect(child, skeletons, meshes)


func _triangles(mesh: MeshInstance3D) -> int:
	if mesh.mesh == null:
		return 0
	var total := 0
	for surface in mesh.mesh.get_surface_count():
		var arrays: Array = mesh.mesh.surface_get_arrays(surface)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		total += indices.size() / 3 if not indices.is_empty() else vertices.size() / 3
	return total
