extends SceneTree
## Import/scene/material regression for the isolated native iPhone bunker asset test.

var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error("BUNKER ASSET TEST: " + message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load("res://scenes/bunker_asset_test.tscn") as PackedScene
	check(packed != null, "test zone scene did not import")
	if packed == null:
		quit(1)
		return
	var zone := packed.instantiate()
	root.add_child(zone)
	for _i in 120:
		if zone.get("bunker") != null:
			break
		await process_frame
	var bunker: Node3D = zone.get("bunker")
	check(bunker != null, "bunker GLB failed to instantiate")
	if bunker != null:
		var mesh_count := 0
		var triangles := 0
		var material_surfaces := 0
		var complete_pbr := 0
		var bounds := AABB()
		var has_bounds := false
		for node in bunker.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := node as MeshInstance3D
			if mesh_instance.mesh == null:
				continue
			mesh_count += 1
			triangles += mesh_instance.mesh.get_faces().size() / 3
			var item_bounds: AABB = mesh_instance.get_aabb() * (bunker.global_transform.affine_inverse() * mesh_instance.global_transform)
			bounds = item_bounds if not has_bounds else bounds.merge(item_bounds)
			has_bounds = true
			for i in mesh_instance.mesh.get_surface_count():
				material_surfaces += 1
				var material := mesh_instance.get_active_material(i)
				check(material is StandardMaterial3D, "surface %d does not import as StandardMaterial3D" % i)
				if material is StandardMaterial3D:
					var m := material as StandardMaterial3D
					if m.albedo_texture and m.normal_texture and m.roughness_texture and m.metallic_texture and m.ao_texture and m.emission_texture:
						complete_pbr += 1
		check(mesh_count > 0, "no renderable meshes")
		check(absf(float(triangles) - 37928.0) <= 4.0, "triangle count differs from GLB report: %d" % triangles)
		check(material_surfaces > 0 and complete_pbr == material_surfaces, "not all imported surfaces include base color, normal, ORM, AO and emission")
		check(has_bounds and bounds.size.x > 8.0 and bounds.size.x < 8.8, "unexpected bunker width: %s" % bounds.size)
		check(has_bounds and bounds.size.y > 4.5 and bounds.size.y < 5.2, "unexpected bunker height: %s" % bounds.size)
		check(has_bounds and bounds.size.z > 6.8 and bounds.size.z < 7.6, "unexpected bunker length: %s" % bounds.size)
		check(zone.get_node_or_null("AssetTestCamera") != null, "test camera missing")
		print("BUNKER_ASSET_AUDIT {\"meshes\":%d,\"triangles\":%d,\"surfaces\":%d,\"pbr_surfaces\":%d,\"size\":[%.3f,%.3f,%.3f]}" % [mesh_count, triangles, material_surfaces, complete_pbr, bounds.size.x, bounds.size.y, bounds.size.z])
	zone.queue_free()
	await process_frame
	if failures.is_empty():
		print("BUNKER ASSET TEST PASS: imported GLB, Godot PBR materials, dimensions and camera")
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: ", failure)
		quit(1)
