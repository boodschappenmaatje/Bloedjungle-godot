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
	check(under.has_method("litter_mesh"),"Litter needs a corrected ground normal frame")
	if under.has_method("litter_mesh"):
		var litter: ArrayMesh = under.litter_mesh()
		check(litter.surface_get_arrays(0)[Mesh.ARRAY_NORMAL][0].is_equal_approx(Vector3(0,0,-1)),"Litter normal must face up after horizontal rotation")
	check(not details.is_empty(), "Missing clustered understory in the real game level")
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
	for key in ["grass_surface","jungle_surface","mud_surface","moss_surface","moss_tex"]:
		var tex = mat.get_shader_parameter(key)
		check(tex is Texture2D,"Missing terrain PBR binding: "+key)
		if tex is Texture2D: check(tex.get_image().has_mipmaps(),"Missing terrain mips: "+key)
	for family in ["leaf","fern","palm","grass"]:
		for channel in ["color","normal"]:
			var tex: Texture2D = load("res://assets/textures/foliage/%s_%s.png" % [family,channel])
			check(tex.get_image().has_mipmaps(),"Foliage needs mipmaps: "+family+channel)
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
