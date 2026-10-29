extends SceneTree
## Test: de Meshy-munitiekist (assets/munitiekist_meshy.glb) laadt in Godot met 1K-PBR, echte maat en pivot onder.
## Draaien: godot --headless --path . -s tests/munitiekist_meshy_test.gd
var fails := 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		push_error("MUNITIEKIST TEST FAIL: " + msg)


func _initialize() -> void:
	var scene: PackedScene = load("res://assets/munitiekist_meshy.glb")
	_check(scene != null, "glb laadt niet")
	if scene == null:
		quit(1)
		return
	var kist := scene.instantiate()
	root.add_child(kist)
	var mi := kist.find_child("Munitiekist", true, false) as MeshInstance3D
	_check(mi != null, "knoop Munitiekist ontbreekt")
	if mi:
		var mesh := mi.mesh
		var tris := 0
		for s in mesh.get_surface_count():
			tris += mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX].size() / 3
		_check(mesh.get_surface_count() == 1, "verwacht 1 surface, kreeg %d" % mesh.get_surface_count())
		_check(tris > 1000 and tris <= 3000, "driehoeken buiten budget: %d" % tris)
		var aabb := mesh.get_aabb()
		_check(absf(aabb.size.x - 0.70) < 0.01, "lengte is geen 70 cm: %.3f" % aabb.size.x)
		_check(absf(aabb.position.y) < 0.005, "onderkant niet op de grond: %.3f" % aabb.position.y)
		_check(absf(aabb.get_center().x) < 0.01 and absf(aabb.get_center().z) < 0.01, "pivot niet in het midden")
		var mat := mesh.surface_get_material(0) as StandardMaterial3D
		_check(mat != null, "geen StandardMaterial3D")
		if mat:
			_check(mat.albedo_texture != null and mat.albedo_texture.get_width() == 1024, "albedo niet 1K")
			_check(mat.normal_enabled and mat.normal_texture != null, "geen normal map")
			_check(mat.roughness_texture != null and mat.metallic_texture != null, "geen ruwheid/metallic-map")
			_check(mat.cull_mode == BaseMaterial3D.CULL_BACK, "kist hoort niet dubbelzijdig")
		print("MUNITIEKIST tris=%d aabb=%s" % [tris, str(aabb)])
	print("MUNITIEKIST TEST ", "OK" if fails == 0 else "FAILED (%d)" % fails)
	quit(0 if fails == 0 else 1)
