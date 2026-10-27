@tool
extends EditorScenePostImport
## Browser GLBs are self-contained. Godot shares exactly one external 2K PBR set.


func _post_import(scene: Node) -> Object:
	var mat := StandardMaterial3D.new()
	mat.resource_name = "VQ2_Grass_2K"
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = load("res://assets/textures/grass_2k/albedo.jpg")
	mat.normal_enabled = true
	mat.normal_texture = load("res://assets/textures/grass_2k/normal.png")
	mat.normal_scale = 0.35
	mat.roughness_texture = load("res://assets/textures/grass_2k/orm.png")
	mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	mat.roughness = 1.0
	mat.ao_enabled = true
	mat.ao_texture = mat.roughness_texture
	for mesh: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			mesh.mesh.surface_set_material(surface, mat)
	return scene
