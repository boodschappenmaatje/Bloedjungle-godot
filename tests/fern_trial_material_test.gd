extends Node
## Focused asset/import/material gate; intentionally does not build the game world.

var failures := 0

func _ready() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func run() -> void:
	var manifest_text := FileAccess.get_file_as_string("res://bron/jungle_foliage_depth/fern_trial_manifest.json")
	var manifest: Dictionary = JSON.parse_string(manifest_text)
	check(not manifest.is_empty(), "Fern trial manifest must import and parse")
	var packed := load("res://assets/jungle_fern_trial.glb") as PackedScene
	check(packed != null, "Standalone fern trial GLB must import as a PackedScene")
	if packed == null:
		finish()
		return
	var root := packed.instantiate()
	var counts: Array[int] = []
	for lod in 3:
		var mesh_instance := root.find_child("HQ_fern_trial_LOD%d" % lod, true, false) as MeshInstance3D
		check(mesh_instance != null and mesh_instance.mesh != null, "Fern trial LOD%d node must import" % lod)
		if mesh_instance == null or mesh_instance.mesh == null:
			counts.append(0)
			continue
		check(mesh_instance.mesh.get_surface_count() == 1, "Each fern trial LOD must remain one material surface")
		var arrays: Array = mesh_instance.mesh.surface_get_arrays(0)
		var triangles := (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		counts.append(triangles)
		check((arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array).size() > 0, "Fern leaves need imported UVs")
		check((arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array).size() > 0, "Fern leaves need imported normals")
		check((arrays[Mesh.ARRAY_TANGENT] as PackedFloat32Array).size() > 0, "Fern PBR needs imported tangent frames")
		check((arrays[Mesh.ARRAY_COLOR] as PackedColorArray).size() > 0, "Fern sway weights must remain in vertex colors")
		check(mesh_instance.mesh.get_aabb().size.y <= 0.70, "Trial fern must remain below the actor visibility budget")
	root.free()
	var declared_counts: Array = manifest.geometry.triangles_lod0_lod1_lod2
	check(declared_counts.size() == counts.size(), "Blender receipt must declare every fern trial LOD")
	for lod in mini(counts.size(), declared_counts.size()):
		check(int(declared_counts[lod]) == counts[lod], "Fern trial LOD%d triangles must match the Blender receipt" % lod)
	check(counts.size() == 3 and counts[0] > counts[1] and counts[1] > counts[2], "LOD0/1/2 must reduce geometry monotonically")
	check(manifest.geometry.surfaces_per_lod == 1 and manifest.geometry.collisions == 0, "Trial is a single-surface, render-only asset")
	var merged := JungleUnderstory.fern_trial_mesh()
	check(merged != null and merged.get_surface_count() == 1, "The Godot trial mesh must merge its three native LODs into one surface")
	if merged != null:
		check(merged.get_meta("depth_lod_triangles", []) == counts, "Godot native LOD arrays must preserve the three exported triangle budgets")
		check(merged.get_meta("depth_lod_distances_m", []) == [20.0, 48.0], "Trial fern uses the established distance culling thresholds")
	var material: ShaderMaterial = Foliage.material("depth_arch_fern")
	check(material.shader.resource_path.ends_with("foliage_depth_pbr.gdshader"), "Trial fern uses the shared mobile PBR foliage shader")
	check(material.shader.code.contains("leaf.a < cut") and material.shader.code.contains("discard"), "Leaves use alpha cutout rather than blended transparency")
	var base := material.get_shader_parameter("tex") as Texture2D
	var normal := material.get_shader_parameter("nrm") as Texture2D
	var roughness := material.get_shader_parameter("rough_tex") as Texture2D
	for texture in [base, normal, roughness]:
		check(texture != null and texture.get_width() == 1024 and texture.get_height() == 1024, "The reused fern PBR maps must remain 1K")
	check(material.get_shader_parameter("cut") >= 0.4, "Foliage alpha threshold keeps transparent overdraw bounded")
	var imported_root := (load("res://assets/jungle_fern_trial.glb") as PackedScene).instantiate()
	check(imported_root.find_children("*", "StaticBody3D", true, false).is_empty(), "Trial fern must not introduce collisions")
	imported_root.free()
	if failures == 0:
		print("FERN TRIAL MATERIAL PASS triangles=%s maps=3x1024 alpha=cutout collisions=0" % [str(counts)])
	finish()

func finish() -> void:
	if failures > 0:
		push_error("FERN TRIAL MATERIAL FAIL failures=%d" % failures)
		get_tree().quit(1)
	else:
		get_tree().quit(0)
