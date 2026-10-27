extends SceneTree
## Exact old Foliage.grass mesh, with equivalent portable PBR alpha-cut material.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var foliage: GDScript = load("res://scripts/foliage.gd")
	var parent := Node3D.new()
	parent.name = "OriginalGrassCards"
	var mat := StandardMaterial3D.new()
	mat.resource_name = "OriginalGrassCard"
	mat.albedo_texture = LeafTex.get_tex("grass")
	mat.albedo_color = Color(0.82, 0.86, 0.74)
	mat.vertex_color_use_as_albedo = true
	mat.normal_enabled = true
	mat.normal_texture = LeafTex.get_normal("grass")
	mat.roughness = 0.58
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.35
	for variant in 4:
		var node := MeshInstance3D.new()
		node.name = "LegacyGrass_%02d" % (variant+1)
		var original: ArrayMesh = foliage.grass()
		var arrays := original.surface_get_arrays(0)
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		for i in colors.size():
			colors[i].a = 1.0 # original alpha is wind weight, not material transparency
		arrays[Mesh.ARRAY_COLOR] = colors
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, mat)
		node.mesh = mesh
		node.position.x = (variant-1.5)*0.85
		parent.add_child(node)
		node.owner = parent
	var gltf := GLTFDocument.new()
	var state := GLTFState.new()
	var error := gltf.append_from_scene(parent, state)
	if error == OK:
		error = gltf.write_to_filesystem(state, "res://assets/grass/grass_baseline.glb")
	print("GRASS BASELINE EXPORT ", error)
	parent.free()
	quit(0 if error == OK else 1)
