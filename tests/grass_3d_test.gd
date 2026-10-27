extends SceneTree
## Real Blender meshes, shared 2K import, LOD exclusivity and no gameplay concealment.
var fails: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	if not ok:
		fails.append(message)
		push_error("GRASS TEST FAIL: " + message)


func _run() -> void:
	GameSettings._load()
	GameSettings.values = GameSettings.DEFAULTS.duplicate()
	load("res://scripts/perf_governor.gd").set("paused", true)
	var grass: GDScript = load("res://scripts/grass_field.gd")
	var foliage: GDScript = load("res://scripts/foliage.gd")
	var last_normal: Texture2D
	for kind in ["short", "medium", "tall"]:
		var previous := 999999
		for lod in 3:
			var meshes: Array = grass.meshes(kind, lod)
			check(meshes.size() == 4, kind + " four variants missing")
			var triangles := 0
			for mesh: ArrayMesh in meshes:
				check(mesh.get_surface_count() == 1, "extra draw surfaces")
				var arrays := mesh.surface_get_arrays(0)
				triangles += mesh.surface_get_array_index_len(0)/3
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
				check(vertices.size() == colors.size(), "wind vertex weights missing")
				var roots := 0
				var tip_max := 0.0
				for i in vertices.size():
					if vertices[i].y < 0.0001:
						roots += 1
						check(colors[i].a < .001, "root is not fixed during wind")
					tip_max = maxf(tip_max, colors[i].a)
				check(roots > 4 and tip_max > .99, "root/tip weight range")
				var bounds := mesh.get_aabb()
				var limits: Array = {"short": [.10,.26], "medium": [.35,.66], "tall": [.9,1.41]}[kind]
				check(bounds.size.y > limits[0] and bounds.size.y <= limits[1], "wrong metres/height " + kind)
				var mat: StandardMaterial3D = mesh.surface_get_material(0)
				for tex in [mat.albedo_texture, mat.normal_texture, mat.roughness_texture]:
					check(tex != null and tex.get_width() == 2048 and tex.get_height() == 2048, "real 2K PBR map missing")
					check(tex.resource_path.begins_with("res://assets/textures/grass_2k/"), "embedded texture duplicated in Godot")
				if last_normal:
					check(last_normal == mat.normal_texture, "normal texture not shared across all nine libraries")
				last_normal = mat.normal_texture
			check(triangles < previous, "LOD does not reduce real triangles")
			previous = triangles
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await main.begin()
	main.set_process(false)
	await physics_frame
	var field: Node = get_first_node_in_group("grass_fields")
	check(field != null, "grass not integrated into actual game world")
	for kind in grass.KINDS:
		check(field.counts[kind] > 100 and field.counts[kind] <= grass.LIMIT[kind], "grass population out of bounds")
	check(field.find_children("*", "CollisionObject3D", true, false).is_empty(), "grass blocks walking, driving or shots")
	check(field.find_children("*", "CollisionShape3D", true, false).is_empty(), "unexpected grass colliders")
	var cam: Camera3D = main.get_node("Camera")
	cam.set_process(false)
	cam.global_position = Vector3(-12,24,-26)
	field._update_lods()
	for batch: Dictionary in field.batches:
		var visible := 0
		for i in 3:
			var node: MultiMeshInstance3D = batch.nodes[i]
			if node.visible: visible += 1
			if i == 0 and batch.kind == "tall":
				for n in node.multimesh.instance_count:
					# Dummy rendering does not retain MultiMesh transform readback.
					# Always check the actual CPU inputs; check GPU transport in the GL run.
					var pos: Vector3 = batch.positions[n]
					check(not grass.zone_at(pos).is_empty(), "tall grass outside defined safe visual zone")
					if DisplayServer.get_name() != "headless":
						check(node.multimesh.get_instance_transform(n).origin.is_equal_approx(pos), "GPU instance transform differs from prepared grass position")
		check(visible <= 1, "overlapping LODs")
	cam.global_position = Vector3(300,200,300)
	field._update_lods()
	for batch: Dictionary in field.batches:
		for node in batch.nodes: check(not node.visible, "far grass did not cull")
	foliage.set_wind(true)
	check(grass.material().get_shader_parameter("wind") == 1.0, "existing wind switch not connected")
	foliage.set_wind(false)
	check(grass.material().get_shader_parameter("wind") == 0.0, "wind cannot stop")
	check(grass.ZONE_DATA.get_meta("concealment_active") == false, "unapproved AI concealment enabled")
	check(grass.zone_at(Vector3.ZERO).is_empty(), "high grass in base")
	for z in range(-85,-31):
		check(grass.zone_at(Vector3(Data.path_x(z),0,z)).is_empty(), "high grass blocks forest route")
	# Independent recreation of the original foliage RNG sequence, including skipped grass.
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var expected := PackedVector2Array()
	var sets := {"palm": [190,18.5,90.0,.85,1.6,.1], "bush": [320,16.5,80.0,.8,1.8,.05], "fern": [300,15.8,70.0,.8,1.7,.04], "grass": [1400,15.2,62.0,.8,1.8,0.0], "rock": [45,18.0,75.0,.7,2.2,.15]}
	for kind in sets:
		var c: Array = sets[kind]
		var xf: Array = []
		var colors: Array = []
		foliage._scatter(rng,c[0],c[1],c[2],xf,colors,c[3],c[4],c[5])
		foliage._strip(rng,kind,xf.size()+foliage.STRIP_EXTRA[kind],xf,colors,c[3],c[4],c[5])
		if kind in ["palm","rock"]:
			for t in xf: expected.append(Vector2(t.origin.x,t.origin.z))
	check(expected == foliage.trees, "existing palm/rock positions changed")
	await main._warm_up()
	check(get_nodes_in_group("grass_fields").size() == 1, "warm-up added a second field")
	check(not main.find_children("GrassPreview", "Node3D", true, false).is_empty(), "grass warm-up preview not rendered before cleanup")
	await process_frame
	await process_frame
	check(main.find_children("GrassPreview", "Node3D", true, false).is_empty(), "warm-up preview leaked into gameplay")
	print("GRASS 3D TEST ", "PASS" if fails.is_empty() else "FAIL", ": 12 Blender tufts, 3 LODs, 2K shared maps, pinned roots, zones, foliage RNG and gameplay preserved")
	quit(0 if fails.is_empty() else 1)
