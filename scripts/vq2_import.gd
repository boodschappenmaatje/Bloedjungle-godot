@tool
extends EditorScenePostImport
## Keep standalone/browser GLBs self contained, but share one photographic PBR
## texture set per family in Godot instead of decoding a copy for every GLB.


func _post_import(scene: Node) -> Object:
	for node: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		for surface in node.mesh.get_surface_count():
			var material := node.mesh.surface_get_material(surface) as StandardMaterial3D
			if material != null and material.resource_name == "Slagboomverf":
				# eigen rood-wit verf van de slagboom (bron/wachtpost): ingebedde afbeeldingen worden bij import weggegooid, dus uit assets laden
				var sp := "res://assets/textures/slagboom/"
				material.albedo_texture = load(sp + "albedo.jpg")
				material.normal_enabled = true
				material.normal_texture = load(sp + "normal.jpg")
				material.roughness_texture = load(sp + "orm.png")
				material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
				material.metallic_texture = material.roughness_texture
				material.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
				material.roughness = 1.0
				material.metallic = 1.0
				continue
			if material == null or not material.resource_name.begins_with("VQ2_"):
				continue
			for family in ["painted_timber", "timber", "roof", "concrete", "canvas", "olive", "steel"]:
				if material.resource_name == "VQ2_" + family or material.resource_name.begins_with("VQ2_" + family + "_"):
					var path := "res://assets/textures/vq2/%s/" % family
					material.albedo_texture = load(path + "albedo.jpg")
					material.normal_enabled = true
					material.normal_texture = load(path + "normal.jpg")
					material.roughness_texture = load(path + "orm.png")
					material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
					material.metallic_texture = material.roughness_texture
					material.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
					material.roughness = 1.0
					material.metallic = 1.0
					if material.resource_name.ends_with("_gebrand"):
						material.albedo_color = Color(0.3, 0.28, 0.27)   # zwartgeblakerd (de tint zit in Blender in een node en gaat niet mee in de glb)
					break
	return scene
