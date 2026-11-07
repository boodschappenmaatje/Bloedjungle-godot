class_name JungleUnderstory
## Render-only depth pass. Reuses shipped meshes/materials and the building-clearance index.
## A separate RNG leaves every existing tree, rock, collider and route unchanged.
const CELL := 24.0
const CAPS := {"fern":2178,"bush":2737,"groundcover":14500,"rosette":1900,"arch_fern":1450,"red_bloom":850,"litter":15000,"stone":1900,"twig":700}
static var _depth_lod_meshes: Dictionary = {}
static var _depth_source_meshes: Dictionary = {}


static func _depth_key(kind: String, variant: int) -> String:
	return "%s:%d" % [kind, variant]


static func depth_mesh(kind: String, variant: int = 0) -> ArrayMesh:
	var key := _depth_key(kind, variant)
	if not _depth_lod_meshes.has(key):
		_load_depth_assets()
	return _depth_lod_meshes.get(key)


static func _load_depth_assets() -> void:
	if not _depth_lod_meshes.is_empty(): return
	var packed := load("res://assets/jungle_depth_foliage.glb") as PackedScene
	if packed == null: return
	var root := packed.instantiate()
	for node: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		for kind in ["rosette", "arch_fern", "red_bloom"]:
			for variant in 3:
				for lod in 3:
					if node.name == "HQ_%s_V%d_LOD%d" % [kind, variant, lod]:
						var key := _depth_key(kind, variant)
						if not _depth_source_meshes.has(key): _depth_source_meshes[key] = [null, null, null]
						var source_meshes: Array = _depth_source_meshes[key]
						source_meshes[lod] = node.mesh
						_depth_source_meshes[key] = source_meshes
	root.free()
	for kind in ["rosette", "arch_fern", "red_bloom"]:
		for variant in 3:
			var key := _depth_key(kind, variant)
			var sources: Array = _depth_source_meshes.get(key, [])
			if sources.size() == 3 and sources.all(func(mesh): return mesh is Mesh):
				_depth_lod_meshes[key] = _merge_native_lods(sources, kind, variant)


static func _merge_native_lods(sources: Array, kind: String, variant: int) -> ArrayMesh:
	var arrays_by_lod: Array = []
	for source: Mesh in sources:
		if source.get_surface_count() != 1: return null
		arrays_by_lod.append(source.surface_get_arrays(0))
	var merged: Array = arrays_by_lod[0].duplicate()
	var base_indices: PackedInt32Array = arrays_by_lod[0][Mesh.ARRAY_INDEX]
	var lod_indices: Dictionary = {}
	var triangle_counts := [base_indices.size() / 3]
	for lod in [1, 2]:
		var source_arrays: Array = arrays_by_lod[lod]
		var source_vertices: PackedVector3Array = source_arrays[Mesh.ARRAY_VERTEX]
		var offset: int = merged[Mesh.ARRAY_VERTEX].size()
		for attribute in range(Mesh.ARRAY_MAX):
			if attribute == Mesh.ARRAY_INDEX or merged[attribute] == null: continue
			merged[attribute].append_array(source_arrays[attribute])
		var indices: PackedInt32Array = source_arrays[Mesh.ARRAY_INDEX].duplicate()
		for i in indices.size(): indices[i] += offset
		lod_indices[20.0 if lod == 1 else 48.0] = indices
		triangle_counts.append(indices.size() / 3)
	merged[Mesh.ARRAY_INDEX] = base_indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, merged, [], lod_indices)
	result.surface_set_material(0, Foliage.material("depth_%s" % kind))
	result.resource_name = "JungleDepth_%s_V%d_LOD0_1_2" % [kind, variant]
	result.set_meta("depth_lod_distances_m", [20.0, 48.0])
	result.set_meta("depth_lod_triangles", triangle_counts)
	return result

static func allowed(p: Vector3) -> bool:
	return GrassField._allowed(p) and not (p.x > Data.COMPOUND and p.x < Data.COMPOUND+11.5 and absf(p.z)<23.0)

static func _colony_offset(rng: RandomNumberGenerator, radius: float, aspect: float, yaw: float) -> Vector2:
	var angle := rng.randf() * TAU
	var radial := sqrt(rng.randf()) * radius
	return Vector2(cos(angle) * radial * aspect, sin(angle) * radial).rotated(yaw)

static func _colony_species(primary: String, rng: RandomNumberGenerator) -> String:
	# Keep the group visually coherent, but mix adjacent understory shapes so
	# the same-mesh circles stop reading as repeated dark fans from the camera.
	var roll := rng.randf()
	if roll < 0.56: return primary
	if roll < 0.82:
		return "arch_fern" if primary == "rosette" else "rosette"
	return "red_bloom" if primary != "red_bloom" else "rosette"

static func litter_mesh() -> ArrayMesh:
	# Three small, curved fallen blades replace the generic crossed grass cards.
	# The shared PBR atlas gives them a subdued oxide/leaf-litter surface.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var atlas_min := Vector2(0.52,0.52)
	var atlas_span := Vector2(0.46,0.46)
	# The same three leaves remain one cheap instanced mesh; scale them enough
	# to read as scattered litter from the normal game camera.
	var leaf_lengths: Array[float] = [0.46,0.39,0.53]
	var leaf_widths: Array[float] = [0.125,0.105,0.145]
	for leaf_index in 3:
		var yaw := TAU * leaf_index / 3.0 + 0.31 * leaf_index
		var direction := Vector3(cos(yaw),0.0,sin(yaw))
		var side := Vector3(-direction.z,0.0,direction.x)
		# Broad, irregular fallen leaves read as close ground detail from the
		# fixed combat camera; the mesh still uses the same three leaves/triangles.
		var length_: float = leaf_lengths[leaf_index]
		var width_: float = leaf_widths[leaf_index]
		var rows: Array[Array] = []
		for row in 4:
			var t := float(row) / 3.0
			var center: Vector3 = direction * length_ * t
			center.y = 0.004 + 0.026 * sin(t * PI) + 0.008 * sin(t * TAU + leaf_index)
			var taper := maxf(0.035, sin(t * PI) ** 0.78)
			var points: Array[Vector3] = []
			for q in [-1.0,0.0,1.0]:
				var point: Vector3 = center + side * float(q) * width_ * taper
				point.y += (1.0-absf(q)) * width_ * 0.12
				points.append(point)
			rows.append(points)
		for row in 3:
			var u0 := float(row) / 3.0
			var u1 := float(row + 1) / 3.0
			for col in 2:
				var v0 := float(col) / 2.0
				var v1 := float(col + 1) / 2.0
				var a: Vector3 = rows[row][col]
				var b: Vector3 = rows[row][col + 1]
				var c: Vector3 = rows[row + 1][col]
				var d: Vector3 = rows[row + 1][col + 1]
				for vertex_data in [[a,Vector2(u0,v0)],[b,Vector2(u0,v1)],[c,Vector2(u1,v0)],
						[b,Vector2(u0,v1)],[d,Vector2(u1,v1)],[c,Vector2(u1,v0)]]:
					st.set_normal(Vector3.UP)
					st.set_uv(atlas_min + Vector2(vertex_data[1].x,vertex_data[1].y) * atlas_span)
					st.set_color(Color(0.92,0.82,0.68))
					st.add_vertex(vertex_data[0])
	st.generate_tangents()
	var mesh := st.commit()
	mesh.surface_set_material(0,Foliage.material("depth_leaf"))
	return mesh

static func groundcover_mesh() -> ArrayMesh:
	return understory_variant_mesh("groundcover", 0)

static func understory_variant_mesh(kind: String, variant: int) -> ArrayMesh:
	if kind == "fern": return depth_mesh("arch_fern", variant % 3)
	if kind == "bush": return depth_mesh("rosette", variant % 3)
	# A few inexpensive silhouettes break the single-mesh repetition in the shipped scatter.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7301 + variant * 97 + (101 if kind == "fern" else (202 if kind == "bush" else 303))
	var fern := kind == "fern"
	var groundcover := kind == "groundcover"
	var count := (8 + variant * 2) if fern else ((7 + variant) if groundcover else (13 + variant * 3))
	var palette_base: Array[Color] = [Color(0.52,0.59,0.41), Color(0.47,0.55,0.39), Color(0.55,0.60,0.42)]
	var palette_tip: Array[Color] = [Color(0.72,0.75,0.55), Color(0.68,0.71,0.53), Color(0.76,0.72,0.52)]
	var base: Color = palette_base[variant]
	var tip: Color = palette_tip[variant]
	for k in count:
		var yaw := TAU * k / count + rng.randf_range(-0.24, 0.24)
		var origin := Vector3(cos(yaw), rng.randf_range(0.0,0.16), sin(yaw)) * rng.randf_range(0.0,0.24)
		# Ground rosettes are broad and low so they read as leafy understory at the game camera,
		# while the taller fern silhouettes remain sparse and never replace the existing grass LODs.
		var length_ := rng.randf_range(0.62,0.86) if groundcover else (rng.randf_range(0.70,1.02) if fern else rng.randf_range(0.62,1.02))
		var width_ := rng.randf_range(0.11,0.18) if groundcover else (rng.randf_range(0.14,0.24) if fern else rng.randf_range(0.20,0.34))
		var rise := rng.randf_range(0.19,0.34) if groundcover else (rng.randf_range(0.30,0.56) if fern else rng.randf_range(0.14,0.46))
		var droop := rng.randf_range(0.08,0.20) if groundcover else (rng.randf_range(0.28,0.55) if fern else rng.randf_range(0.12,0.38))
		# Low groundcover has no useful extra silhouette from three bends at game distance.
		# Two segments keep its leaf shape while reserving the same triangle budget for more clumps.
		Foliage._frond(st, origin, yaw, length_, width_, rise, droop, base, tip, 2 if groundcover else 3)
	st.generate_tangents()
	var mesh := st.commit()
	if groundcover:
		# Use the shared leaf quadrant from the depth-pass atlas so low plants
		# receive the same OpenGL normal and per-pixel roughness as the authored
		# rosette/fern assets, without adding another material or texture set.
		var surface_arrays: Array = mesh.surface_get_arrays(0)
		var uv: PackedVector2Array = surface_arrays[Mesh.ARRAY_TEX_UV]
		for i in uv.size():
			uv[i] = Vector2(0.02,0.52) + uv[i] * Vector2(0.46,0.46)
		surface_arrays[Mesh.ARRAY_TEX_UV] = uv
		var pbr_mesh := ArrayMesh.new()
		pbr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,surface_arrays)
		pbr_mesh.surface_set_material(0,Foliage.material("depth_leaf"))
		pbr_mesh.resource_name = "Groundcover_PBR_Low"
		return pbr_mesh
	mesh.surface_set_material(0,Foliage.material("fern" if fern else "leaf"))
	return mesh

static func spawn(parent: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261106
	var fill_rng := RandomNumberGenerator.new()
	fill_rng.seed = 20261108
	var candidates: Array[Vector3] = []
	# Most detail belongs in the playable forest, not thinly across the 440 m world.
	# Seeded colonies leave gaps and vary plant density over several metres.
	for colony in 480:
		var center := Vector3(rng.randf_range(-70.0,70.0),0.012,rng.randf_range(-85.0,-33.0))
		var radius := rng.randf_range(2.5,5.0)
		for i in 50:
			var angle := rng.randf()*TAU
			var r := sqrt(rng.randf())*radius
			candidates.append(center+Vector3(cos(angle)*r,0,sin(angle)*r))
	# Layered rings at existing trunks/rocks, broken up into asymmetric colonies.
	for anchor in Foliage.trees:
		for i in (18 if anchor.y < -30.0 and anchor.y > -100.0 else 4):
			var a := rng.randf()*TAU
			var r := rng.randf_range(0.6,4.8)
			candidates.append(Vector3(anchor.x+cos(a)*r,0.012,anchor.y+sin(a)*r))
	# Shoulder colonies outside the existing clear corridor. Never plant the road itself.
	for i in 1000:
		var z := rng.randf_range(-86.0,-34.0)
		var side := -1.0 if rng.randf()<0.5 else 1.0
		candidates.append(Vector3(Data.path_x(z)+side*rng.randf_range(3.5,10.0),0.012,z))
	# Bank shelves and low foundation fringes use the same acceptance rules.
	for i in 650:
		var x := rng.randf_range(-72.0,72.0)
		candidates.append(Vector3(x,0.012,Data.river_z(x)+rng.randf_range(5.0,10.0)))
	for i in 450:
		var side := rng.randi_range(0,3)
		var p := Vector3(rng.randf_range(-Data.COMPOUND,Data.COMPOUND),0.012,Data.COMPOUND+rng.randf_range(2.0,4.2))
		p = Basis(Vector3.UP,side*PI*0.5)*p
		candidates.append(p)
	# Readable understory colonies along both shoulders: one dominant species per
	# colony gives the real camera recognizable plant groups instead of a thin,
	# uniformly mixed scatter. The road and firing corridor stay clear.
	var colony_positions: Array[Vector3] = []
	var colony_kinds := PackedStringArray()
	# Reassign part of the existing stone budget to the worn trail shoulders. Small
	# stones break the dark ribbon into an aggregate path while remaining render-only.
	for i in 350:
		var z := fill_rng.randf_range(-86.0,-34.0)
		var side := -1.0 if fill_rng.randf()<0.5 else 1.0
		var p := Vector3(Data.path_x(z)+side*fill_rng.randf_range(1.55,2.65),0.012,z)
		if not allowed(p): continue
		colony_positions.append(p)
		colony_kinds.append("stone")
	for cluster in 68:
		var z := rng.randf_range(-86.0,-34.0)
		var side := -1.0 if rng.randf()<0.5 else 1.0
		var center := Vector3(Data.path_x(z)+side*rng.randf_range(4.0,8.5),0.012,z)
		var choice := rng.randf()
		var primary := "rosette" if choice<0.44 else ("arch_fern" if choice<0.80 else "red_bloom")
		# Spread the same instances over looser, asymmetric colonies so nearby
		# silhouettes read as plants with individual spacing rather than one fan.
		var radius := rng.randf_range(2.5,3.9)
		var axis := rng.randf_range(0.0,TAU)
		var aspect := rng.randf_range(0.48,0.88)
		for i in rng.randi_range(14,21):
			var offset := _colony_offset(rng,radius,aspect,axis)
			var p := center+Vector3(offset.x,0,offset.y)
			if absf(p.x-Data.path_x(p.z))<3.2 or not allowed(p): continue
			colony_positions.append(p)
			colony_kinds.append(_colony_species(primary,rng))
	# Ferns and broad leaves also gather on the two shelves beside moving water.
	for cluster in 28:
		var x := rng.randf_range(-66.0,66.0)
		var side := -1.0 if rng.randf()<0.5 else 1.0
		var center := Vector3(x,0.012,Data.river_z(x)+side*rng.randf_range(4.0,7.2))
		var primary := "arch_fern" if rng.randf()<0.56 else "rosette"
		var radius := rng.randf_range(2.2,3.3)
		var axis := rng.randf_range(0.0,TAU)
		var aspect := rng.randf_range(0.48,0.88)
		for i in rng.randi_range(10,16):
			var offset := _colony_offset(rng,radius,aspect,axis)
			var p := center+Vector3(offset.x,0,offset.y)
			if not allowed(p): continue
			colony_positions.append(p)
			colony_kinds.append(_colony_species(primary,rng))
	# Fine groundcover and fallen leaves fill the playable floor between the larger
	# rosette/fern groups. Their centres are jittered and clustered; the firing road,
	# base approach, build clearances and river stay open under the same acceptance rules.
	for cluster in 300:
		var center := Vector3(fill_rng.randf_range(-38.0,42.0),0.012,fill_rng.randf_range(-79.0,-38.0))
		var radius := fill_rng.randf_range(1.2,2.8)
		for i in 30:
			var angle := fill_rng.randf()*TAU
			var r := sqrt(fill_rng.randf())*radius
			var p := center+Vector3(cos(angle)*r,0,sin(angle)*r)
			if absf(p.x-Data.path_x(p.z))<2.8 or not allowed(p): continue
			colony_positions.append(p)
			colony_kinds.append("groundcover")
	# Reassign the same small-group budget across the playable entry field instead
	# of concentrating it on one trail side. Keep the route and a clear player pocket.
	for cluster in 120:
		var center := Vector3(fill_rng.randf_range(-8.0,30.0),0.012,fill_rng.randf_range(-80.0,-36.0))
		var radius := fill_rng.randf_range(2.2,3.4)
		var roll := fill_rng.randf()
		var species := "groundcover" if roll<0.65 else ("rosette" if roll<0.85 else ("arch_fern" if roll<0.97 else "red_bloom"))
		for i in 10:
			var angle := fill_rng.randf()*TAU
			var r := sqrt(fill_rng.randf())*radius
			var p := center+Vector3(cos(angle)*r,0,sin(angle)*r)
			if absf(p.x-Data.path_x(p.z))<5.2 or Vector2(p.x-7.0,p.z+57.0).length()<5.0 or not allowed(p): continue
			colony_positions.append(p)
			colony_kinds.append(_colony_species(species,fill_rng))
	# Reserve a small litter budget for the camera-facing floor before the broad fill.
	for cluster in 75:
		var center := Vector3(fill_rng.randf_range(-32.0,36.0),0.012,fill_rng.randf_range(-78.0,-39.0))
		var radius := fill_rng.randf_range(0.9,2.0)
		for i in fill_rng.randi_range(10,18):
			var angle := fill_rng.randf()*TAU
			var r := sqrt(fill_rng.randf())*radius
			var p := center+Vector3(cos(angle)*r,0,sin(angle)*r)
			if absf(p.x-Data.path_x(p.z))<3.0 or not allowed(p): continue
			colony_positions.append(p)
			colony_kinds.append("litter")
	# Fine leaf litter follows the same eastern trail-side floor, breaking the
	# green surface into small warm leaf clusters while leaving the route open.
	for cluster in 55:
		var z := fill_rng.randf_range(-74.0,-44.0)
		var center := Vector3(Data.path_x(z)+fill_rng.randf_range(9.0,16.0),0.012,z)
		var radius := fill_rng.randf_range(1.0,1.8)
		for i in fill_rng.randi_range(9,16):
			var angle := fill_rng.randf()*TAU
			var r := sqrt(fill_rng.randf())*radius
			var p := center+Vector3(cos(angle)*r,0,sin(angle)*r)
			if absf(p.x-Data.path_x(p.z))<4.5 or not allowed(p): continue
			colony_positions.append(p)
			colony_kinds.append("litter")
	for cluster in 1200:
		var center := Vector3(fill_rng.randf_range(-62.0,62.0),0.012,fill_rng.randf_range(-86.0,-34.0))
		var radius := fill_rng.randf_range(0.8,2.6)
		for i in 28:
			var angle := fill_rng.randf()*TAU
			var r := sqrt(fill_rng.randf())*radius
			var p := center+Vector3(cos(angle)*r,0,sin(angle)*r)
			if not allowed(p): continue
			colony_positions.append(p)
			colony_kinds.append("litter")
	# Prioritize low detail inside the playable camera area instead of spreading
	# the whole budget over the distant map. Tall sightlines and the roadway stay clear.
	for cluster in 160:
		var center := Vector3(fill_rng.randf_range(-30.0,34.0),0.012,fill_rng.randf_range(-77.0,-40.0))
		var radius := fill_rng.randf_range(1.0,2.1)
		var axis := fill_rng.randf_range(0.0,TAU)
		var aspect := fill_rng.randf_range(0.42,0.82)
		var roll := fill_rng.randf()
		var species := "groundcover" if roll<0.70 else ("rosette" if roll<0.86 else ("arch_fern" if roll<0.97 else "red_bloom"))
		for i in fill_rng.randi_range(11,13):
			var offset := _colony_offset(fill_rng,radius,aspect,axis)
			var p := center+Vector3(offset.x,0,offset.y)
			if absf(p.x-Data.path_x(p.z))<3.3 or not allowed(p): continue
			colony_positions.append(p)
			colony_kinds.append(_colony_species(species,fill_rng))
	# Interleave habitat sources before caps; anchors cannot consume the whole budget.
	for i in range(candidates.size()-1,0,-1):
		var j := rng.randi_range(0,i)
		var swap := candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = swap
	var groups := {}
	var counts := {"fern":0,"bush":0,"groundcover":0,"rosette":0,"arch_fern":0,"red_bloom":0,"litter":0,"stone":0,"twig":0}
	for i in colony_positions.size(): _add_candidate(groups,counts,rng,colony_positions[i],colony_kinds[i])
	for p in candidates: _add_candidate(groups,counts,rng,p)
	var twig := CylinderMesh.new()
	twig.top_radius=0.28
	twig.bottom_radius=0.4
	twig.height=1.0
	twig.radial_segments=8
	twig.rings=1
	# Reuse the existing three-card mesh for flat litter, rather than 22 complete leaves.
	var litter := litter_mesh()
	var meshes := {"fern":[understory_variant_mesh("fern",0),understory_variant_mesh("fern",1),understory_variant_mesh("fern",2)],
		"bush":[understory_variant_mesh("bush",0),understory_variant_mesh("bush",1),understory_variant_mesh("bush",2)],
		"groundcover":[understory_variant_mesh("groundcover",0),understory_variant_mesh("groundcover",1),understory_variant_mesh("groundcover",2)],
		"rosette":[depth_mesh("rosette",0),depth_mesh("rosette",1),depth_mesh("rosette",2)],
		"arch_fern":[depth_mesh("arch_fern",0),depth_mesh("arch_fern",1),depth_mesh("arch_fern",2)],
		"red_bloom":[depth_mesh("red_bloom",0),depth_mesh("red_bloom",1),depth_mesh("red_bloom",2)],
		"litter":litter,"stone":Foliage.jungle_mesh("Rots2"),"twig":twig}
	var stone := Kit.rock().duplicate() as StandardMaterial3D
	stone.vertex_color_use_as_albedo=true
	for key in groups:
		var data: Dictionary = groups[key]
		var material_kind := "depth_arch_fern" if data.kind=="fern" else ("depth_rosette" if data.kind=="bush" else "depth_%s" % data.kind)
		var mat: Material = stone if data.kind=="stone" else (Kit.photo("nature/tree_bark",1.5,Color(0.48,0.4,0.3)) if data.kind=="twig" else (Foliage.material(material_kind) if data.kind in ["fern","bush","rosette","arch_fern","red_bloom"] else null))
		var mesh: Mesh = meshes[data.kind][int(data.variant)] if data.kind in ["fern","bush","groundcover","rosette","arch_fern","red_bloom"] else meshes[data.kind]
		var n := Kit.scatter(parent,mesh,mat,data.xf,data.col,false)
		# Cleared slots move below the world; never let that alter the cell culling center.
		n.multimesh.custom_aabb = AABB(Vector3(data.cell.x*CELL-2.0,-0.5,data.cell.y*CELL-2.0),Vector3(CELL+4.0,4.0,CELL+4.0))
		n.name="Understory_"+key
		n.add_to_group("jungle_understory")
		# Existing density, governor and diagnostic switches operate on this group.
		n.add_to_group("foliage_grass")
		n.set_meta("full",data.xf.size())
		n.visibility_range_end=76.0 if data.kind in ["rosette","arch_fern","red_bloom"] else (48.0 if data.kind in ["litter","stone","twig"] else 58.0)
		n.extra_cull_margin=1.5  # leaf spread plus the existing 1.1 m actor push
		for i in data.xf.size():
			Foliage._register_vegetation({"kind":"grass","xf":data.xf[i],"slots":[{"multimesh":n.multimesh,"index":i}],"shapes":[]})


static func _add_candidate(groups: Dictionary, counts: Dictionary, rng: RandomNumberGenerator, p: Vector3, forced_kind := "") -> void:
	if not allowed(p): return
	var kind := forced_kind
	if kind.is_empty():
		var roll := rng.randf()
		# Reallocate a small part of repeated cards and ground litter to the three
		# authored PBR silhouettes while keeping the overall scatter bounded.
		kind = "fern" if roll<0.08 else ("bush" if roll<0.18 else ("groundcover" if roll<0.46 else ("rosette" if roll<0.55 else ("arch_fern" if roll<0.64 else ("red_bloom" if roll<0.70 else ("litter" if roll<0.85 else ("stone" if roll<0.97 else "twig")))))))
	if counts[kind]>=CAPS[kind]: return
	var variant := rng.randi_range(0,2) if kind in ["fern","bush","groundcover","rosette","arch_fern","red_bloom"] else 0
	var cell := Vector2i(floori(p.x/CELL),floori(p.z/CELL))
	var key := "%s_%d_%d_%d" % [kind,variant,cell.x,cell.y]
	if not groups.has(key): groups[key] = {"kind":kind,"variant":variant,"cell":cell,"xf":[],"col":[]}
	if groups[key].xf.size()>=(900 if kind=="litter" else (480 if kind=="groundcover" else 360)): return
	# The photographed Poly Haven plants are authored at 0.53–0.64 m tall.
	# Keep their leaves below actor height, but avoid the previous quarter-scale
	# silhouettes that disappeared into the open grass at the combat camera.
	# The authored per-species multipliers keep the tallest fern below ~1 m.
	var s := rng.randf_range(1.35,1.80) if kind in ["rosette","arch_fern","red_bloom"] else rng.randf_range(0.40,0.86)
	var size_ := Vector3(s*rng.randf_range(0.78,1.12),s*rng.randf_range(0.62,1.02),s*rng.randf_range(0.82,1.18))
	if kind=="bush": size_ *= 0.72
	if kind=="groundcover":
		# Broader, flatter mats make the low understory read at the top-down game
		# camera without reaching the soldier silhouette or creating a new LOD.
		var footprint := rng.randf_range(1.18,1.48)
		size_ = Vector3(s*footprint,s*rng.randf_range(0.92,1.12),s*footprint)
	if kind=="rosette": size_ *= rng.randf_range(0.70,0.90)
	if kind=="arch_fern": size_ *= rng.randf_range(0.64,0.84)
	if kind=="red_bloom": size_ *= rng.randf_range(0.72,0.92)
	# Fallen blades need roughly half-metre tips to resolve from the game camera;
	# keep them on the ground and spend the existing litter budget at this scale.
	if kind=="litter": size_=Vector3.ONE*rng.randf_range(0.78,1.38)
	if kind=="stone": size_=Vector3.ONE*rng.randf_range(0.22,0.48)
	if kind=="twig": size_=Vector3(0.045+0.025*s,rng.randf_range(0.35,0.85),0.045+0.025*s)
	var tilt := rng.randf_range(0.06,0.20) if kind in ["rosette","arch_fern","red_bloom","groundcover"] else 0.0
	var basis := Basis.from_euler(Vector3(rng.randf_range(-tilt,tilt),rng.randf()*TAU,rng.randf_range(-tilt,tilt)))
	if kind=="twig": basis *= Basis(Vector3.RIGHT,PI*0.5)
	groups[key].xf.append(Transform3D(basis * Basis.from_scale(size_),p))
	var shade := rng.randf_range(0.78,1.12)
	if kind=="litter":
		var leaf_tones: Array[Color] = [Color(0.90,0.69,0.40),Color(0.72,0.51,0.29),Color(0.82,0.76,0.48)]
		groups[key].col.append(leaf_tones[rng.randi_range(0,leaf_tones.size()-1)]*shade)
	elif kind in ["bush","fern","groundcover","rosette","arch_fern"]:
		# Repeated clumps keep their shared MultiMesh material, but mature, shaded
		# and sun-touched leaves now carry restrained olive/bronze instance tones.
		var leaf_tones = [Color(0.91,0.94,0.79),Color(0.82,0.89,0.72),Color(0.88,0.85,0.65),Color(0.74,0.85,0.70)]
		if kind in ["rosette","arch_fern"]:
			leaf_tones = [Color(0.96,0.97,0.92),Color(0.90,0.95,0.88),Color(0.94,0.90,0.81),Color(0.86,0.92,0.84)]
		groups[key].col.append(leaf_tones[rng.randi_range(0,leaf_tones.size()-1)]*shade)
	elif kind=="red_bloom":
		groups[key].col.append(Color(0.93,0.96,0.87)*shade)
	else:
		groups[key].col.append(Color(shade,shade,shade))
	counts[kind]+=1
