extends SceneTree
## Controleer of de meegeleverde GLB-texturen na een schone Godot-import gekoppeld blijven.

const MODELS := [
	"res://assets/tank.glb",
	"res://assets/meshy_jungle_commando.glb",
	"res://assets/meshy_m1911.glb",
]


func _initialize() -> void:
	var failed := false
	for path in MODELS:
		var scene := load(path) as PackedScene
		if scene == null:
			push_error("Model niet geladen: " + path)
			failed = true
			continue
		var root := scene.instantiate()
		var textured := _count_textured(root)
		print("TACTICAL_MATERIAL %s textured_surfaces=%d" % [path, textured])
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
					count += 1
	for child in node.get_children():
		count += _count_textured(child)
	return count
