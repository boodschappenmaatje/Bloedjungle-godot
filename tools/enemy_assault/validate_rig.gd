extends SceneTree
var scene_path := "res://source_assets/enemy_assault/rig_test/enemy_assault_body_rigged_garand_test.glb"
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
	var ok := skeletons.size() == 1 and meshes.size() >= 1
	if ok:
		ok = skeletons[0].get_bone_count() == 28
		for mesh in meshes:
			if mesh.skin != null and mesh.mesh != null:
				print("ASSAULT_MESH vertices=", mesh.mesh.get_surface_count() > 0, " skin=", mesh.skin != null, " skeleton_path=", mesh.skeleton)
				ok = ok and mesh.skin != null and mesh.mesh.get_surface_count() > 0
	print("ASSAULT_GODOT rig_count=", skeletons.size(), " mesh_nodes=", meshes.size(), " bones=", skeletons[0].get_bone_count() if not skeletons.is_empty() else 0, " passed=", ok)
	root.free()
	quit(0 if ok else 1)
func _collect(node: Node, skeletons: Array[Skeleton3D], meshes: Array[MeshInstance3D]) -> void:
	if node is Skeleton3D: skeletons.append(node)
	if node is MeshInstance3D: meshes.append(node)
	for child in node.get_children(): _collect(child, skeletons, meshes)
