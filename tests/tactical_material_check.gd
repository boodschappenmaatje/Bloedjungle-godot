extends SceneTree
## Controleer of de meegeleverde GLB-texturen na een schone Godot-import gekoppeld blijven.

const MODELS := [
	"res://assets/tank.glb",
	"res://assets/meshy_jungle_commando.glb",
	"res://assets/meshy_m1911.glb",
	"res://assets/soldaat_vq2.glb",
]
var _first_texture: Texture2D


func _initialize() -> void:
	var failed := false
	for path in MODELS:
		_first_texture = null
		var scene := load(path) as PackedScene
		if scene == null:
			push_error("Model niet geladen: " + path)
			failed = true
			continue
		var root := scene.instantiate()
		var textured := _count_textured(root)
		print("TACTICAL_MATERIAL %s textured_surfaces=%d" % [path, textured])
		if _first_texture != null:
			var image := _first_texture.get_image()
			if image != null:
				if image.is_compressed():
					image.decompress()
				image.resize(1, 1)
				print("TACTICAL_ALBEDO %s average=%s" % [path, image.get_pixel(0, 0)])
		if textured == 0:
			push_error("Ingebedde texturen ontbreken: " + path)
			failed = true
		root.free()
	quit(1 if failed else 0)


func _count_textured(node: Node) -> int:
	var count := 0
	if node is MeshInstance3D:
		var mesh := (node as MeshInstance3D).mesh
		if mesh != null:
			for surface in mesh.get_surface_count():
				var raw := (node as MeshInstance3D).get_active_material(surface)
				var material := raw as BaseMaterial3D
				if material != null and material.albedo_texture != null:
					if _first_texture == null:
						_first_texture = material.albedo_texture
					count += 1
	for child in node.get_children():
		count += _count_textured(child)
	return count
