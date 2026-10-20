extends SceneTree
## Build reusable Godot 4 PBR materials from the approved texture triplets.

func _initialize() -> void:
	var count := 0
	for group in ["terrain", "buildings", "nature"]:
		var parent: String = "res://assets/textures/" + group
		if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(parent)):
			continue
		for folder in DirAccess.get_directories_at(parent):
			var base: String = parent.path_join(folder)
			var output: String = base.path_join("material.tres")
			if ResourceLoader.exists(output):
				continue
			var color := load(base.path_join("base_color.jpg")) as Texture2D
			var normal := load(base.path_join("normal_gl.jpg")) as Texture2D
			var roughness := load(base.path_join("roughness.jpg")) as Texture2D
			if color == null or normal == null or roughness == null:
				printerr("Incomplete texture set: ", base)
				quit(1)
				return
			var material := StandardMaterial3D.new()
			material.resource_name = folder
			material.albedo_texture = color
			material.normal_enabled = true
			material.normal_texture = normal
			material.roughness = 1.0
			material.roughness_texture = roughness
			material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
			var error := ResourceSaver.save(material, output)
			if error != OK:
				printerr("Could not save ", output, ": ", error)
				quit(1)
				return
			count += 1
	print("Created ", count, " Godot PBR materials")
	quit()
