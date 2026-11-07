extends Node
## Integration: render-only detail cannot obstruct routes or survive building clearance.
var game: Node
var failures := 0
func _ready() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	game = get_tree().root.get_node("Game")
	var settings: GDScript = load("res://scripts/game_settings.gd")
	var governor: GDScript = load("res://scripts/perf_governor.gd")
	var progress: GDScript = load("res://scripts/progress.gd")
	var fol: GDScript = load("res://scripts/foliage.gd")
	var data_rules: GDScript = load("res://scripts/data.gd")
	settings.values = settings.DEFAULTS.duplicate()
	settings._loaded = true
	settings.values["sound"] = "off"
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await main.begin()
	main.set_process(false)
	for mesh: ArrayMesh in [fol.fern(),fol.bush()]:
		check(mesh.surface_get_arrays(0)[Mesh.ARRAY_TANGENT].size()>0,"Foliage PBR needs an authored tangent frame")
	var details := get_tree().get_nodes_in_group("jungle_understory")
	Foliage.update_depth_shadow_batches((main.get_node("Camera") as Camera3D).global_position,1.0,true)
	var under: GDScript = load("res://scripts/jungle_understory.gd")
	var understory_counts := {"fern":0,"bush":0,"groundcover":0,"rosette":0,"arch":0,"red":0,"litter":0,"stone":0,"twig":0}
	for n: MultiMeshInstance3D in details:
		var kind: String = n.name.get_slice("_", 1)
		var bucket := "arch" if kind == "arch_fern" else ("red" if kind == "red_bloom" else kind)
		understory_counts[bucket] += int(n.get_meta("full"))
	var grass_tufts := 0
	for n: MultiMeshInstance3D in get_tree().get_nodes_in_group("grass_3d"):
		if n.get_meta("kind") == "short" and int(n.get_meta("lod")) == 0:
			grass_tufts += int(n.get_meta("full"))
	var grass_script: GDScript = load("res://scripts/grass_field.gd")
	var short_grass_limit: int = grass_script.get_script_constant_map()["LIMIT"]["short"]
	print("VISUAL B DENSITY short_grass=%d understory=%s" % [grass_tufts, JSON.stringify(understory_counts)])
	check(grass_tufts >= 22000 and grass_tufts <= short_grass_limit,"Fine grass must fill the bounded playable-floor LOD budget")
	check(understory_counts.groundcover >= 10000 and understory_counts.groundcover <= 14500,"Groundcover stays within its existing budget after camera-focused placement")
	check(understory_counts.fern <= 2178 and understory_counts.bush >= 2000 and understory_counts.bush <= 2737,"Ferns and bushes stay at or below their previously captured instance counts")
	check(understory_counts.rosette >= 1700 and understory_counts.rosette <= 1900,"New ribbed rosettes must appear inside their cap")
	check(understory_counts.arch >= 1300 and understory_counts.arch <= 1450,"New arched fern must appear inside its cap")
	check(understory_counts.red >= 750 and understory_counts.red <= 850,"New red/bronze blooms must remain bounded and readable")
	check(understory_counts.litter >= 12500 and understory_counts.litter <= 15000,"Leaf litter must materially break up exposed soil without exceeding its mobile cap")
	check(understory_counts.stone >= 1700 and understory_counts.stone <= 1900,"The pebble detail pass must reuse, not grow, the existing stone instance budget")
	check(under.has_method("litter_mesh"),"Litter needs a corrected ground normal frame")
	if under.has_method("litter_mesh"):
		var litter: ArrayMesh = under.litter_mesh()
		var litter_normal: Vector3 = litter.surface_get_arrays(0)[Mesh.ARRAY_NORMAL][0]
		check(litter_normal.dot(Vector3.UP) >= 0.999,"Ground litter leaves must use an upward tangent frame")
		check(litter.surface_get_arrays(0)[Mesh.ARRAY_TANGENT].size()>0,"Ground litter PBR needs a generated tangent frame")
		var litter_uv: PackedVector2Array = litter.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
		var litter_uv_valid := not litter_uv.is_empty()
		for uv in litter_uv:
			litter_uv_valid = litter_uv_valid and uv.x >= 0.034 and uv.x <= 0.981 and uv.y >= 0.034 and uv.y <= 0.506
		check(litter_uv_valid,"Fallen leaves must sample opaque broad-leaf regions of the scanned PBR atlas")
		var rosette_source := Image.load_from_file(ProjectSettings.globalize_path("res://assets/textures/foliage/polyhaven/rosette_base_color.png"))
		for uv in [Vector2(0.25,0.14),Vector2(0.74,0.13),Vector2(0.43,0.415)]:
			var texel := rosette_source.get_pixel(roundi(uv.x*(rosette_source.get_width()-1)),roundi(uv.y*(rosette_source.get_height()-1)))
			check(texel.a >= 0.95,"Leaf litter UVs must resolve to photographed PBR leaf pixels, not transparent atlas gaps")
		check(litter.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() == 108,"Scanned leaf litter must retain its bounded three-leaf geometry budget")
		check(litter.surface_get_material(0) == Foliage.material("depth_litter"),"Fallen leaves must use the shared scanned PBR material")
		check(Foliage.material("depth_litter").get_shader_parameter("wind") == 0.0,"Fallen leaves must remain grounded when gameplay wind is enabled")
		check(Foliage.material("depth_litter").get_shader_parameter("foliage_grade").x >= 2.5,"Dark scanned leaves need a bounded warm lift for ground readability")
		fol.set_wind(true)
		check(Foliage.material("depth_litter").get_shader_parameter("wind") == 0.0,"Global wind changes must not animate leaves lying on the ground")
		fol.set_wind(false)
		var groundcover: ArrayMesh = under.groundcover_mesh()
		check(groundcover.get_surface_count() == 1,"Scanned groundcover must stay on one cutout surface for batching")
		check(groundcover.surface_get_material(0) == Foliage.material("depth_microcover"),"Existing groundcover instances must use scanned Poly Haven PBR")
		var groundcover_lods: Array = groundcover.get_meta("depth_lod_triangles", [])
		check(groundcover_lods.size() == 3 and groundcover_lods[0] <= 320 and groundcover_lods[1] <= 160 and groundcover_lods[2] <= 80,
			"Scanned microcover must keep a mobile-first three-level triangle budget")
		check(groundcover.get_meta("depth_lod_distances_m", []) == [8.0,22.0],"Small floor plants must switch to cheap native LODs early")
	for kind in ["rosette","arch_fern","microcover","red_bloom"]:
		for variant in 3:
			var depth_variant_mesh: ArrayMesh = under.depth_mesh(kind,variant)
			var label := "%s variant %d" % [kind,variant]
			check(depth_variant_mesh != null and depth_variant_mesh.get_surface_count() == 1,"Depth-pass species must remain one batched PBR surface: "+label)
			if depth_variant_mesh != null:
				var expected_lod_1 := 8.0 if kind == "microcover" else 20.0
				var expected_lod_2 := 22.0 if kind == "microcover" else 48.0
				check(depth_variant_mesh.get_meta("depth_lod_distances_m", []) == [expected_lod_1,expected_lod_2],"Depth-pass species needs useful native LOD thresholds: "+label)
				check(depth_variant_mesh.get_aabb().size.y <= 0.9,"Understory species must stay below actor-hiding height: "+label)
				var triangles: Array = depth_variant_mesh.get_meta("depth_lod_triangles", [])
				check(triangles.size() == 3 and triangles[0] > triangles[1] and triangles[1] > triangles[2],"Source foliage LODs must reduce triangles at distance: "+label)
				var depth_arrays := depth_variant_mesh.surface_get_arrays(0)
				check(depth_arrays[Mesh.ARRAY_TANGENT].size() > 0,"PBR leaf surfaces need imported tangents: "+label)
				check(depth_arrays[Mesh.ARRAY_COLOR].size() > 0,"Plant sway needs authored root-to-tip vertex weights: "+label)
				check(Foliage.material("depth_"+kind).shader.resource_path.ends_with("foliage_depth_pbr.gdshader"),"Scanned plants need the dedicated mobile PBR shader: "+label)
				check(Foliage.material("depth_"+kind).shader.code.contains("diffuse_burley"),"Scanned plants must use standard Burley response: "+label)
				var height_factor := 0.84 if kind == "arch_fern" else (0.90 if kind == "rosette" else 0.92)
				check(depth_variant_mesh.get_aabb().size.y * 1.80 * 1.02 * height_factor <= 1.05,"Combat-camera plant scale must remain below actor-obscuring height: "+label)
	check(not details.is_empty(), "Missing clustered understory in the real game level")
	check(details.any(func(n: MultiMeshInstance3D) -> bool: return n.name.begins_with("Understory_groundcover_")),"Missing fine-scale groundcover in the real game level")
	for n: MultiMeshInstance3D in details:
		check(n.multimesh.custom_aabb.size.x > 0.0 and n.multimesh.custom_aabb.size.x <= 28.0,"Detail batch needs stable cell bounds after clearing")
		check(n.multimesh.instance_count <= (900 if n.name.begins_with("Understory_litter_") else (480 if n.name.begins_with("Understory_groundcover_") else 360)), "Unbounded detail batch")
		check(n.visibility_range_end <= 76.0, "Microdetail must distance cull")
		if not n.is_in_group("understory_pbr_shadow_candidate"):
			check(n.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Non-PBR microdetail stays shadowless")
		check(n.find_children("*","CollisionShape3D",true,false).is_empty(),"Detail introduces collisions")
	var meshes := details.map(func(n): return n.multimesh)
	var detail_meshes := meshes.duplicate()
	for n: MultiMeshInstance3D in get_tree().get_nodes_in_group("grass_3d"):
		if n.get_meta("kind") == "short" and int(n.get_meta("lod")) == 0:
			meshes.append(n.multimesh)
	var near_bank := 0
	var near_wall := 0
	var near_path := 0
	var near_authored := {"rosette":0,"arch_fern":0,"red_bloom":0}
	var near_camera_cover := {"short":0,"groundcover":0,"litter":0}
	var visible_camera_cover := {"short":0,"groundcover":0,"litter":0}
	var authored_batches := {}
	var camera_cover_batches := {}
	var stone_batches := {}
	for n: MultiMeshInstance3D in details:
		for kind in ["groundcover","litter"]:
			if n.name.begins_with("Understory_"+kind+"_"):
				camera_cover_batches[n.multimesh.get_instance_id()] = kind
		for kind in near_authored.keys():
			if n.name.begins_with("Understory_"+kind+"_"):
				authored_batches[n.multimesh.get_instance_id()] = kind
		if n.name.begins_with("Understory_stone_"):
			stone_batches[n.multimesh.get_instance_id()] = true
	for n: MultiMeshInstance3D in get_tree().get_nodes_in_group("grass_3d"):
		if n.get_meta("kind") == "short" and int(n.get_meta("lod")) == 0:
			camera_cover_batches[n.multimesh.get_instance_id()] = "short"
	var checked := 0
	var small_path_pebbles := 0
	var visible_floor_pebbles := 0
	var visible_floor_twigs := 0
	var sample := Vector3.INF
	# Dummy renderer cannot read GPU buffers. Use the production clearance index,
	# which holds the actual prepared transform for every MultiMesh slot.
	for cell in fol._vegetation_cells.values():
		for entry: Dictionary in cell:
			if entry.slots.is_empty() or not entry.slots[0].multimesh in meshes: continue
			var p: Vector3 = entry.world_position
			var batch_id: int = entry.slots[0].multimesh.get_instance_id()
			var path_pebble: bool = stone_batches.has(batch_id) and entry.get("visual_role","") == "trail_edge_pebble" and absf(p.x-data_rules.path_x(p.z)) >= 3.4 and absf(p.x-data_rules.path_x(p.z)) < 5.6 and entry.xf.basis.get_scale().x < 0.20
			if path_pebble:
				small_path_pebbles += 1
				check(entry.shapes.is_empty(),"Trail pebbles must remain render-only and have no collisions")
			if p.x >= -17.0 and p.x <= 31.0 and p.z >= -77.0 and p.z <= -48.0:
				if entry.get("visual_role","") == "forest_floor_pebble": visible_floor_pebbles += 1
				if entry.get("visual_role","") == "forest_floor_twig": visible_floor_twigs += 1
			var authored_kind: String = authored_batches.get(entry.slots[0].multimesh.get_instance_id(),"")
			if not authored_kind.is_empty() and Vector2(p.x-7.0,p.z+57.0).length() < 30.0:
				near_authored[authored_kind] += 1
			var cover_kind: String = camera_cover_batches.get(batch_id,"")
			if Vector2(p.x-7.0,p.z+57.0).length() < 26.0 and absf(p.x-data_rules.path_x(p.z)) > 2.8:
				if near_camera_cover.has(cover_kind): near_camera_cover[cover_kind] += 1
			if p.x >= -17.0 and p.x <= 31.0 and p.z >= -75.0 and p.z <= -49.0:
				if visible_camera_cover.has(cover_kind): visible_camera_cover[cover_kind] += 1
			if data_rules.river_off(p.x,p.z) < 10.0: near_bank += 1
			if maxf(absf(p.x),absf(p.z)) < data_rules.COMPOUND+4.5: near_wall += 1
			if absf(p.x-data_rules.path_x(p.z)) < 10.0 and p.z < -34.0 and p.z > -86.0: near_path += 1
			if entry.slots[0].multimesh in detail_meshes:
				check(entry.slots[0].multimesh.custom_aabb.has_point(entry.local_position),"Prepared detail outside stable bounds")
			checked += 1
			sample = p
			check(maxf(absf(p.x),absf(p.z)) > data_rules.COMPOUND+1.8,"Detail in base")
			check(path_pebble or not fol._in_river(p),"Detail blocks water or forest route")
			check(not (absf(p.x)<4.6 and absf(p.z)<70.0),"Detail blocks gate approach")
	check(near_bank>20 and near_wall>20 and near_path>20,"Detail budget starves banks/foundations/shoulders")
	print("VISUAL B CAMERA PLANTS ",JSON.stringify(near_authored))
	print("VISUAL B CAMERA FLOOR ",JSON.stringify(near_camera_cover))
	print("VISUAL B VISIBLE CAMERA FLOOR ",JSON.stringify(visible_camera_cover))
	print("VISUAL B SMALL PATH PEBBLES ",small_path_pebbles)
	print("VISUAL B CAMERA DEBRIS stones=%d twigs=%d" % [visible_floor_pebbles,visible_floor_twigs])
	check(small_path_pebbles >= 250,"The existing stone budget needs small, render-only gravel accents along the trail")
	check(visible_floor_pebbles >= 160 and visible_floor_twigs >= 55,"The fixed combat-camera opening needs bounded low rock and branch breakup")
	check(near_camera_cover.short >= 3000 and near_camera_cover.groundcover >= 4500 and near_camera_cover.litter >= 3700,
		"The camera neighborhood needs existing low cover and leaf litter while leaving the trail readable")
	check(visible_camera_cover.short >= 6000 and visible_camera_cover.groundcover >= 3200 and visible_camera_cover.litter >= 1700,
		"The fixed main-camera footprint needs visible ground detail, not only nearby detail outside the screen")
	check(near_authored.rosette>=600 and near_authored.arch_fern>=450 and near_authored.red_bloom>=200,
		"New high-detail plant colonies must read in the real bospad camera area")
	check(checked > 1000,"Missing registered removable detail")
	if sample != Vector3.INF:
		var regions := [{"center":Vector2.ZERO,"size":Vector2(2.0,2.0)}]
		check(fol.count_clearable_in_regions(regions,sample,0.0)>0,"No clearance candidates")
		fol.clear_for_building(987654,regions,sample,0.0)
		check(fol.count_clearable_in_regions(regions,sample,0.0)==0,"New vegetation survives building clearing")
	check(fol._shadow_mat("palm").get_shader_parameter("canopy_tex") is Texture2D,"Fixed palm shadows need the existing leaf silhouette")
	var mat: ShaderMaterial = get_tree().get_first_node_in_group("ground").get_meta("mat")
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
	for file in ["rosette_base_color.png","rosette_normal_gl.png","rosette_roughness.png","arch_fern_base_color.png","arch_fern_normal_gl.png","arch_fern_roughness.png","shrub_base_color.png","shrub_normal_gl.png","shrub_roughness.png"]:
		var tex: Texture2D = load("res://assets/textures/foliage/polyhaven/"+file)
		check(tex != null and tex.get_image().get_width() == 1024 and tex.get_image().has_mipmaps(),"Poly Haven runtime PBR maps need 1K mipmapped cutout textures: "+file)
	# Inspect the source PNG rather than the VRAM-compressed imported texture.
	# Reading individual pixels from the imported GPU format can stall the headless
	# renderer; a coarse source-image sample verifies the same packed AO channel.
	var shrub_image := Image.load_from_file(ProjectSettings.globalize_path("res://assets/textures/foliage/polyhaven/shrub_roughness.png"))
	var sampled_ao := 0
	check(shrub_image != null,"Could not read the source Poly Haven ARM map")
	if shrub_image != null:
		for y in range(0,shrub_image.get_height(),32):
			for x in range(0,shrub_image.get_width(),32):
				if shrub_image.get_pixel(x,y).g < 0.85: sampled_ao += 1
	check(sampled_ao > 50,"Poly Haven ARM ambient occlusion is packed alongside roughness for red-bloom leaves")
	check(Foliage.material("depth_red_bloom").shader.get_code().contains("surface.g"),"PBR foliage shader must consume packed AO without another texture sampler")
	check(Foliage.material("depth_rosette").get_shader_parameter("roughness_floor") <= 0.35,
		"Scanned anthurium leaves must retain their measured soft gloss instead of a global matte clamp")
	check(Foliage.material("depth_rosette").get_shader_parameter("foliage_saturation") <= 0.85,
		"Scanned foliage should keep a restrained olive palette instead of bright lime green")
	check(Foliage.material("depth_arch_fern").get_shader_parameter("roughness_floor") >= 0.58,
		"Scanned fern leaves must keep their naturally matte response")
	check(Foliage.material("depth_rosette").get_shader_parameter("nrm_depth") >= 0.78,
		"Broad scanned leaves need visible vein relief at the gameplay camera")
	var atm := get_tree().get_first_node_in_group("atmosphere")
	for quality in ["low","high","ultra","high"]:
		settings.values["quality"] = quality
		atm.apply_settings()
		Foliage.update_depth_shadow_batches((main.get_node("Camera") as Camera3D).global_position,1.0,true)
		for n: MultiMeshInstance3D in details:
			if quality == "low" or quality == "high" and Atmosphere.tier > 0:
				check(n.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"Low or governed quality enables detail shadows")
	var shadow_batches := details.filter(func(n: MultiMeshInstance3D) -> bool: return n.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	check(shadow_batches.size() <= Foliage.DEPTH_SHADOW_BATCH_LIMIT,"PBR plant shadows exceed the near-field mobile budget")
	check(shadow_batches.all(func(n: MultiMeshInstance3D) -> bool: return n.is_in_group("understory_pbr_shadow_candidate")),"Only PBR plant batches may cast near-field detail shadows")
	settings.values["t_jungle"] = "off"
	atm.apply_settings()
	for n: MultiMeshInstance3D in details: check(not n.visible,"Jungle switch leaves details visible")
	print("VISUAL B TEST %s (%d failures)" % ["PASS" if failures==0 else "FAIL",failures])
	get_tree().quit(0 if failures==0 else 1)
