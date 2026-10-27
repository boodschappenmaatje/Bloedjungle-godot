extends SceneTree


func _initialize() -> void:
	var textures: Array = []
	var total := 0
	for name in ["albedo.jpg", "normal.png", "orm.png"]:
		var tex: Texture2D = load("res://assets/textures/grass_2k/" + name)
		var image := tex.get_image()
		var bytes := image.get_data_size()
		total += bytes
		textures.append({"file": name, "width": image.get_width(), "height": image.get_height(),
			"format": image.get_format(), "compressed": image.is_compressed(),
			"mipmaps": image.get_mipmap_count(), "image_payload_bytes": bytes})
	var result := {"textures": textures, "total_image_payload_bytes": total,
		"total_image_payload_mib": float(total)/1048576.0,
		"note": "Imported desktop image payload including mipmaps, shared by all grass. Not measured iPhone resident VRAM or total GPU memory."}
	var out := FileAccess.open("res://docs/grass/texture-budget.json", FileAccess.WRITE)
	out.store_string(JSON.stringify(result, "\t")+"\n")
	print("GRASS TEXTURE PAYLOAD MiB ", result.total_image_payload_mib)
	quit()
