extends SceneTree
## Integration: render-only detail cannot obstruct routes or survive building clearance.
var game: Node
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	game = root.get_node("Game")
	var settings: GDScript = load("res://scripts/game_settings.gd")
	var governor: GDScript = load("res://scripts/perf_governor.gd")
	var progress: GDScript = load("res://scripts/progress.gd")
	var fol: GDScript = load("res://scripts/foliage.gd")
	var data_rules: GDScript = load("res://scripts/data.gd")
	settings.values = settings.DEFAULTS.duplicate()
	settings._loaded = true
	settings.values["sound"] = "off"
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await main.begin()
	main.set_process(false)
	for mesh: ArrayMesh in [fol.fern(),fol.bush()]:
		check(mesh.surface_get_arrays(0)[Mesh.ARRAY_TANGENT].size()>0,"Foliage PBR needs an authored tangent frame")
	var details := get_nodes_in_group("jungle_understory")
	var under: GDScript = load("res://scripts/jungle_understory.gd")
	var understory_counts := {"fern":0,"bush":0,"groundcover":0,"rosette":0,"arch":0,"red":0,"litter":0,"stone":0,"twig":0}
	for n: MultiMeshInstance3D in details:
		var kind: String = n.name.get_slice("_", 1)
		var bucket := "arch" if kind == "arch_fern" else ("red" if kind == "red_bloom" else kind)
		understory_counts[bucket] += int(n.get_meta("full"))
	var grass_tufts := 0
	for n: MultiMeshInstance3D in get_nodes_in_group("grass_3d"):
		if n.get_meta("kind") == "short" and int(n.get_meta("lod")) == 0:
			grass_tufts += int(n.get_meta("full"))
	var grass_script: GDScript = load("res://scripts/grass_field.gd")
	var short_grass_limit: int = grass_script.get_script_constant_map()["LIMIT"]["short"]
	print("VISUAL B DENSITY short_grass=%d understory=%s" % [grass_tufts, JSON.stringify(understory_counts)])
	check(grass_tufts > 11500 and grass_tufts <= short_grass_limit,"Fine grass must stay within its bounded LOD budget")
	check(understory_counts.groundcover >= 8000 and understory_counts.groundcover <= 9000,"Retain broadleaf cover within the new mobile-scatter budget")
	check(understory_counts.fern <= 2400 and understory_counts.bush >= 2000,"Keep old fern/bush coverage bounded while reallocating to new silhouettes")
	check(understory_counts.rosette >= 900 and understory_counts.rosette <= 1500,"New ribbed rosettes must appear inside their cap")
	check(understory_counts.arch >= 700 and understory_counts.arch <= 1200,"New arched fern must appear inside its cap")
	check(understory_counts.red >= 350 and understory_counts.red <= 650,"New red/brown blooms must remain sparse and readable")
	check(under.has_method("litter_mesh"),"Litter needs a corrected ground normal frame")
	if under.has_method("litter_mesh"):
		var litter: ArrayMesh = under.litter_mesh()
		check(litter.surface_get_arrays(0)[Mesh.ARRAY_NORMAL][0].is_equal_approx(Vector3(0,0,-1)),"Litter normal must face up after horizontal rotation")
		var groundcover: ArrayMesh = under.groundcover_mesh()
		check(groundcover.get_surface_count() == 1,"Groundcover must stay on one cutout surface for batching")
		check(groundcover.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() <= 320,"Low groundcover must spend its geometry budget on coverage, not near-invisible bends")
	for kind in ["rosette","arch_fern","red_bloom"]:
		var depth_mesh: ArrayMesh = under.depth_mesh(kind)
		check(depth_mesh != null and depth_mesh.get_surface_count() == 1,"Depth-pass species must remain a single batched PBR surface: "+kind)
		if depth_mesh != null:
			check(depth_mesh.get_meta("depth_lod_distances_m", []).size() == 2,"Depth-pass species needs native LOD1/LOD2 thresholds: "+kind)
			var triangles: Array = depth_mesh.get_meta("depth_lod_triangles", [])
			check(triangles.size() == 3 and triangles[0] > triangles[1] and triangles[1] > triangles[2],"Depth-pass species LOD index sets must reduce triangles at distance: "+kind)
			var depth_arrays := depth_mesh.surface_get_arrays(0)
			check(depth_arrays[Mesh.ARRAY_TANGENT].size() > 0,"PBR leaf atlas needs imported tangents: "+kind)
			check(depth_arrays[Mesh.ARRAY_COLOR].size() > 0,"Plant sway needs authored root-to-tip vertex weights: "+kind)
	check(not details.is_empty(), "Missing clustered understory in the real game level")
	check(details.any(func(n: MultiMeshInstance3D) -> bool: return n.name.begins_with("Understory_groundcover_")),"Missing fine-scale groundcover in the real game level")
	for n: MultiMeshInstance3D in details:
		check(n.multimesh.custom_aabb.size.x > 0.0 and n.multimesh.custom_aabb.size.x <= 28.0,"Detail batch needs stable cell bounds after clearing")
		check(n.multimesh.instance_count <= 360, "Unbounded detail batch")
		check(n.visibility_range_end <= 58.0, "Microdetail must distance cull")
		check(n.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Detail adds shadow cost")
		check(n.find_children("*","CollisionShape3D",true,false).is_empty(),"Detail introduces collisions")
	var meshes := details.map(func(n): return n.multimesh)
	var near_bank := 0
	var near_wall := 0
	var near_path := 0
	var checked := 0
	var sample := Vector3.INF
	# Dummy renderer cannot read GPU buffers. Use the production clearance index,
	# which holds the actual prepared transform for every MultiMesh slot.
	for cell in fol._vegetation_cells.values():
		for entry: Dictionary in cell:
			if entry.slots.is_empty() or not entry.slots[0].multimesh in meshes: continue
			var p: Vector3 = entry.world_position
			if data_rules.river_off(p.x,p.z) < 10.0: near_bank += 1
			if maxf(absf(p.x),absf(p.z)) < data_rules.COMPOUND+4.5: near_wall += 1
			if absf(p.x-data_rules.path_x(p.z)) < 10.0 and p.z < -34.0 and p.z > -86.0: near_path += 1
			check(entry.slots[0].multimesh.custom_aabb.has_point(entry.local_position),"Prepared detail outside stable bounds")
			checked += 1
			sample = p
			check(maxf(absf(p.x),absf(p.z)) > data_rules.COMPOUND+1.8,"Detail in base")
			check(not fol._in_river(p),"Detail blocks water or forest route")
			check(not (absf(p.x)<4.6 and absf(p.z)<70.0),"Detail blocks gate approach")
	check(near_bank>20 and near_wall>20 and near_path>20,"Detail budget starves banks/foundations/shoulders")
	check(checked > 1000,"Missing registered removable detail")
	if sample != Vector3.INF:
		var regions := [{"center":Vector2.ZERO,"size":Vector2(2.0,2.0)}]
		check(fol.count_clearable_in_regions(regions,sample,0.0)>0,"No clearance candidates")
		fol.clear_for_building(987654,regions,sample,0.0)
		check(fol.count_clearable_in_regions(regions,sample,0.0)==0,"New vegetation survives building clearing")
	check(fol._shadow_mat("palm").get_shader_parameter("canopy_tex") is Texture2D,"Fixed palm shadows need the existing leaf silhouette")
	var mat: ShaderMaterial = get_first_node_in_group("ground").get_meta("mat")
	for key in ["grass_surface","jungle_surface","mud_surface","moss_surface","moss_tex","gravel_tex","gravel_surface"]:
		var tex = mat.get_shader_parameter(key)
		check(tex is Texture2D,"Missing terrain PBR binding: "+key)
		if tex is Texture2D: check(tex.get_image().has_mipmaps(),"Missing terrain mips: "+key)
	for family in ["leaf","fern","palm","grass"]:
		for channel in ["color","normal"]:
			var tex: Texture2D = load("res://assets/textures/foliage/%s_%s.png" % [family,channel])
			check(tex.get_image().has_mipmaps(),"Foliage needs mipmaps: "+family+channel)
	for file in ["jungle_leaf_flower_base_color.png","jungle_leaf_flower_normal_gl.png","jungle_leaf_flower_roughness.png"]:
		var tex: Texture2D = load("res://assets/textures/foliage/depth_pass/"+file)
		check(tex != null and tex.get_image().get_width() == 1024 and tex.get_image().has_mipmaps(),"New 1K leaf PBR atlas needs mipmaps: "+file)
	var atm := get_first_node_in_group("atmosphere")
	for quality in ["low","high","ultra","high"]:
		settings.values["quality"] = quality
		atm.apply_settings()
		for n: MultiMeshInstance3D in details:
			check(n.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"Quality enabled detail shadows")
	settings.values["t_jungle"] = "off"
	atm.apply_settings()
	for n: MultiMeshInstance3D in details: check(not n.visible,"Jungle switch leaves details visible")
	print("VISUAL B TEST %s (%d failures)" % ["PASS" if failures==0 else "FAIL",failures])
	quit(0 if failures==0 else 1)
