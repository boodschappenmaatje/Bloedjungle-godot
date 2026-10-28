extends SceneTree
## Verifies the showcase mesh replaces only the bunker visuals and preserves gameplay contracts.

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error("BUNKER HQ REPLACEMENT: " + message)


func _run() -> void:
	# Running the game's main scene first registers autoload singleton names used
	# by bunker.gd, then the fixture can isolate BaseProps without altering it.
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	var world := Node3D.new()
	world.name = "BunkerReplacementFixture"
	main.add_child(world)
	var base_props := load("res://scripts/base_props.gd") as Script
	base_props.call("build", world)
	await process_frame

	var bunker := world.find_child("Bunker", true, false) as StaticBody3D
	_check(bunker != null, "existing bunker StaticBody3D is missing")
	if bunker == null:
		quit(1)
		return
	_check(bunker.collision_layer == Kit.LAYER_BUNKER, "bunker collision layer changed")
	_check(bunker.collision_mask == 0, "bunker collision mask changed")
	_check(bunker.get_script() == load("res://scripts/bunker.gd"), "bunker damage/interactions script changed")
	_check(bunker.is_processing(), "bunker damage-state FX processing was disabled")
	var shape_node := bunker.get_node_or_null("BunkerCollision") as CollisionShape3D
	_check(shape_node != null and shape_node.shape is BoxShape3D, "original solid bunker collider is missing")
	if shape_node and shape_node.shape is BoxShape3D:
		var shape := shape_node.shape as BoxShape3D
		_check(shape.size.is_equal_approx(Vector3(4.6, 2.0, 4.6)), "gameplay collision dimensions must remain 4.6 × 2 × 4.6 m")
		_check(is_equal_approx(shape_node.position.y, 1.0), "collider vertical placement changed")

	var visual := bunker.get_node_or_null("Bunker_High_Quality_Showcase") as Node3D
	_check(visual != null, "High Quality Showcase GLB is not attached as the bunker visual")
	if visual:
		_check(visual.scale.is_equal_approx(Vector3(0.547619, 0.55, 0.638889)), "visual scale no longer fits the original gameplay footprint")
		var mesh_nodes := visual.find_children("*", "MeshInstance3D", true, false)
		var triangle_count := 0
		var pbr_surfaces := 0
		var door_material_found := false
		for node in mesh_nodes:
			var mesh_instance := node as MeshInstance3D
			if mesh_instance.mesh == null:
				continue
			triangle_count += mesh_instance.mesh.get_faces().size() / 3
			for surface in mesh_instance.mesh.get_surface_count():
				var material := mesh_instance.get_active_material(surface) as StandardMaterial3D
				if material == null:
					continue
				if material.resource_name.contains("Door"):
					door_material_found = true
				if material.albedo_texture and material.normal_enabled and material.normal_texture and material.roughness_texture and material.metallic_texture:
					pbr_surfaces += 1
		_check(mesh_nodes.size() == 1, "game GLB should remain one static mesh instance")
		_check(triangle_count == 37928, "unexpected game mesh triangle count: %d" % triangle_count)
		_check(pbr_surfaces == 8, "not all 8 imported GLB material surfaces have PBR maps: %d/8" % pbr_surfaces)
		_check(door_material_found, "authored metal entrance-door material is missing")

	# Keep the legacy bunker damage contract: enemy damage still reaches the base;
	# player-fired hits continue to be ignored by this handler.
	var game := root.get_node_or_null("Game")
	_check(game != null, "Game autoload unavailable in replacement test")
	if game:
		game.state = "play"
		game.base_hp = 1000.0
		bunker.hit(100.0, Vector3.ZERO, false)
		_check(is_equal_approx(game.base_hp, 920.0), "enemy bunker-hit damage multiplier changed")
		bunker.hit(100.0, Vector3.ZERO, true)
		_check(is_equal_approx(game.base_hp, 920.0), "player-fired damage should not damage own base")

	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("BUNKER HQ REPLACEMENT PASS: GLB/PBR, entrance, collision footprint and damage contract")
		quit(0)
	else:
		quit(1)
