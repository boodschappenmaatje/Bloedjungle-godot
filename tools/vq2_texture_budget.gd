extends SceneTree
## Imported compressed image payload, not a physical-device VRAM/FPS measurement.
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var entries: Array = []
	var total := 0
	for family in ["painted_timber", "timber", "roof", "concrete", "canvas", "olive", "steel"]:
		for file in ["albedo.jpg", "normal.jpg", "orm.png"]:
			var path := "res://assets/textures/vq2/%s/%s" % [family, file]
			var texture := load(path) as Texture2D
			var image := texture.get_image()
			var bytes := image.get_data().size()
			total += bytes
			entries.append({"path": path, "width": image.get_width(), "height": image.get_height(), "compressed": image.is_compressed(), "image_format_enum": image.get_format(), "mipmaps": image.get_mipmap_count(), "image_payload_bytes": bytes})
	var output := FileAccess.open("res://docs/vq2/results/texture-budget.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"note": "Imported desktop compressed image payload incl mipmaps. Shared family paths reused by the three GLBs. Not measured GPU residency or mobile FPS; platform-specific ETC2 payload may differ.", "shared_payload_MiB": float(total) / 1048576.0, "textures": entries}, "  ") + "\n")
	print("VQ2 TEXTURE BUDGET: ", entries.size(), " shared images, ", snappedf(float(total) / 1048576.0, .01), " MiB imported compressed payload")
	quit()
