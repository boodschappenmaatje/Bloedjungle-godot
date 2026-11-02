extends SceneTree
## Kazerne HQ2 minimal import/geometry/PBR/collision gate.
## Run after copying the REAL GLB into assets/kazerne_hq2.glb:
## godot --headless --path . --import
## godot --headless --path . --script res://tests/kazerne_hq2_test.gd
##
## This does not claim native iPhone FPS or a visually approved in-game render.

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, msg: String) -> void:
	if not ok:
		push_error("KAZERNE_HQ2_TEST_FAIL: " + msg)
		failures.append(msg)


func _run() -> void:
	var asset := "res://assets/kazerne_hq2.glb"
	check(ResourceLoader.exists(asset), "missing the actual user-approved Meshy game GLB")
	if not ResourceLoader.exists(asset):
		quit(1)
		return
	var packed := load(asset) as PackedScene
	check(packed != null, "HQ2 is not a valid Godot imported PackedScene")
	if packed == null:
		quit(1)
		return

	var scene: Node3D = packed.instantiate()
	root.add_child(scene)
	var meshes: Array = scene.find_children("*", "MeshInstance3D", true, false)
	check(meshes.size() > 0, "no imported mesh")
	var triangles := 0
	var pbr_surfaces := 0
	var coords_min := Vector3(INF, INF, INF)
	var coords_max := Vector3(-INF, -INF, -INF)
	for mi: MeshInstance3D in meshes:
		if mi.mesh == null:
			check(false, "imported MeshInstance3D lacks geometry")
			continue
		for surface in mi.mesh.get_surface_count():
			triangles += mi.mesh.surface_get_array_index_len(surface) / 3
			var material := mi.get_active_material(surface) as StandardMaterial3D
			if material != null and material.albedo_texture != null \
					and material.normal_texture != null and material.roughness_texture != null:
				pbr_surfaces += 1
		var aabb := mi.get_aabb()
		for x in [aabb.position.x, aabb.end.x]:
			for y in [aabb.position.y, aabb.end.y]:
				for z in [aabb.position.z, aabb.end.z]:
					var p := mi.to_global(Vector3(x, y, z))
					coords_min = coords_min.min(p)
					coords_max = coords_max.max(p)
	check(triangles >= 40000, "less than the approved 40k triangle minimum")
	check(pbr_surfaces > 0, "2K PBR material maps were not imported")
	var dims := coords_max - coords_min
	check(dims.distance_to(Vector3(6.4, 3.5, 4.8)) < 0.12, "HQ2 geometry must be 6.4 × 3.5 × 4.8 meters, got " + str(dims))
	check(absf(coords_min.y) < 0.05, "HQ2 must have ground level Y=0")

	var builds := Buildings.new()
	var b: StaticBody3D = builds.make_node("kazerne")
	check(b != null, "runtime build node missing HQ2")
	if b != null:
		var collider := b.get_child(0) as CollisionShape3D
		check(collider != null and collider.shape is BoxShape3D, "missing collision box")
		if collider != null and collider.shape is BoxShape3D:
			check((collider.shape as BoxShape3D).size.is_equal_approx(Vector3(6.4, 3.5, 4.8)), "incorrect collider dimensions")
		check(b.find_child("Kazerne_HQ2_Meshy", true, false) != null, "HQ2 model missing from runtime node")
		var door := builds.door_of({"at": Vector3.ZERO, "yaw": 0.0})
		check(door.z > 3.25, "unit spawn intersects barracks front wall")
		b.free()
	builds.free()
	scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("KAZERNE_HQ2_TEST_PASS: GLB/PBR/geometry, footprint, collision and +Z spawn. Native iPhone FPS NOT TESTED.")
		quit(0)
	else:
		print("KAZERNE_HQ2_TEST_FAIL_COUNT: ", failures.size())
		quit(1)
