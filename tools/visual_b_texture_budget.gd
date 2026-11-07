extends SceneTree
func _initialize() -> void:
	var report := {}
	var total := 0
	for family in ["grass","jungle_ground","dry_earth","mud","moss","gravel_rock"]:
		var tex: Texture2D = load("res://assets/textures/terrain/surfaces/"+family+".png")
		var im := tex.get_image()
		var size_ := im.get_data().size()
		total += size_
		report[family] = {"width":im.get_width(),"height":im.get_height(),"mipmaps":im.has_mipmaps(),"format":im.get_format(),"bytes_with_mips":size_}
	report["total_bytes_with_mips"] = total
	print(JSON.stringify(report,"\t"))
	quit()
