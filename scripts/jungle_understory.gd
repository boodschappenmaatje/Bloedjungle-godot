class_name JungleUnderstory
## Render-only depth pass. Reuses shipped meshes/materials and the building-clearance index.
## A separate RNG leaves every existing tree, rock, collider and route unchanged.
const CELL := 24.0
const CAPS := {"fern":3300,"bush":4100,"groundcover":11000,"litter":5400,"stone":1900,"twig":700}

static func allowed(p: Vector3) -> bool:
	return GrassField._allowed(p) and not (p.x > Data.COMPOUND and p.x < Data.COMPOUND+11.5 and absf(p.z)<23.0)

static func litter_mesh() -> ArrayMesh:
	# Same shipped card vertices/UVs, with a ground-facing frame after +90° X rotation.
	var arrays := Foliage.grass().surface_get_arrays(0)
	var normals := PackedVector3Array()
	normals.resize(arrays[Mesh.ARRAY_VERTEX].size())
	normals.fill(Vector3(0,0,-1))
	arrays[Mesh.ARRAY_NORMAL] = normals
	var corrected := ArrayMesh.new()
	corrected.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var surface := SurfaceTool.new()
	surface.create_from(corrected,0)
	surface.generate_tangents()
	var mesh := surface.commit()
	mesh.surface_set_material(0,Foliage.material("leaf"))
	return mesh

static func groundcover_mesh() -> ArrayMesh:
	return understory_variant_mesh("groundcover", 0)

static func understory_variant_mesh(kind: String, variant: int) -> ArrayMesh:
	# A few inexpensive silhouettes break the single-mesh repetition in the shipped scatter.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7301 + variant * 97 + (101 if kind == "fern" else (202 if kind == "bush" else 303))
	var fern := kind == "fern"
	var groundcover := kind == "groundcover"
	var count := (8 + variant * 2) if fern else ((9 + variant * 2) if groundcover else (13 + variant * 3))
	var palette_base: Array[Color] = [Color(0.68,0.77,0.4), Color(0.59,0.71,0.36), Color(0.72,0.79,0.42)]
	var palette_tip: Array[Color] = [Color(0.95,0.99,0.62), Color(0.98,0.96,0.58), Color(0.88,0.96,0.61)]
	var base: Color = palette_base[variant]
	var tip: Color = palette_tip[variant]
	for k in count:
		var yaw := TAU * k / count + rng.randf_range(-0.24, 0.24)
		var origin := Vector3(cos(yaw), rng.randf_range(0.0,0.16), sin(yaw)) * rng.randf_range(0.0,0.24)
		# Ground rosettes are broad and low so they read as leafy understory at the game camera,
		# while the taller fern silhouettes remain sparse and never replace the existing grass LODs.
		var length_ := rng.randf_range(0.9,1.3) if groundcover else (rng.randf_range(0.82,1.22) if fern else rng.randf_range(0.72,1.22))
		var width_ := rng.randf_range(0.34,0.48) if groundcover else (rng.randf_range(0.18,0.31) if fern else rng.randf_range(0.26,0.42))
		var rise := rng.randf_range(0.2,0.38) if groundcover else (rng.randf_range(0.42,0.78) if fern else rng.randf_range(0.18,0.62))
		var droop := rng.randf_range(0.03,0.14) if groundcover else (rng.randf_range(0.38,0.78) if fern else rng.randf_range(0.16,0.5))
		# Low groundcover has no useful extra silhouette from three bends at game distance.
		# Two segments keep its leaf shape while reserving the same triangle budget for more clumps.
		Foliage._frond(st, origin, yaw, length_, width_, rise, droop, base, tip, 2 if groundcover else 3)
	st.generate_tangents()
	var mesh := st.commit()
	mesh.surface_set_material(0, Foliage.material("fern" if fern else "leaf"))
	return mesh

static func spawn(parent: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261106
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
	# Interleave habitat sources before caps; anchors cannot consume the whole budget.
	for i in range(candidates.size()-1,0,-1):
		var j := rng.randi_range(0,i)
		var swap := candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = swap
	var groups := {}
	var counts := {"fern":0,"bush":0,"groundcover":0,"litter":0,"stone":0,"twig":0}
	for p in candidates:
		if not allowed(p): continue
		var roll := rng.randf()
		# Move part of the capped detail budget from small litter and tall fans to readable low rosettes.
		# The existing cell MultiMeshes, route clearances and draw-pass structure remain unchanged.
		var kind := "fern" if roll<0.13 else ("bush" if roll<0.29 else ("groundcover" if roll<0.72 else ("litter" if roll<0.88 else ("stone" if roll<0.985 else "twig"))))
		if counts[kind]>=CAPS[kind]: continue
		var variant := rng.randi_range(0,2) if kind in ["fern","bush","groundcover"] else 0
		var cell := Vector2i(floori(p.x/CELL),floori(p.z/CELL))
		var key := "%s_%d_%d_%d" % [kind,variant,cell.x,cell.y]
		if not groups.has(key): groups[key] = {"kind":kind,"cell":cell,"xf":[],"col":[]}
		if groups[key].xf.size()>=360: continue
		var s := rng.randf_range(0.5,1.18)
		var size_ := Vector3(s,s*rng.randf_range(0.65,1.1),s)
		if kind=="bush": size_ *= 0.78
		if kind=="groundcover": size_ *= 1.38
		if kind=="litter": size_=Vector3(s*0.65,s*0.65,0.025)
		if kind=="stone": size_=Vector3.ONE*rng.randf_range(0.12,0.32)
		if kind=="twig": size_=Vector3(0.035,rng.randf_range(0.35,0.85),0.035)
		var basis := Basis(Vector3.UP,rng.randf()*TAU)
		if kind in ["twig","litter"]: basis *= Basis(Vector3.RIGHT,PI*0.5)
		groups[key].xf.append(Transform3D(basis * Basis.from_scale(size_),p))
		var shade := rng.randf_range(0.78,1.12)
		groups[key].col.append(Color(shade,shade,shade) if kind!="litter" else Color(shade*0.7,shade*0.56,shade*0.32))
		counts[kind]+=1
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
		"litter":litter,"stone":Foliage.jungle_mesh("Rots2"),"twig":twig}
	var stone := Kit.rock().duplicate() as StandardMaterial3D
	stone.vertex_color_use_as_albedo=true
	for key in groups:
		var data: Dictionary = groups[key]
		var mat: Material = stone if data.kind=="stone" else (Kit.photo("nature/tree_bark",1.5,Color(0.48,0.4,0.3)) if data.kind=="twig" else null)
		var mesh: Mesh = meshes[data.kind][int(key.split("_")[1])] if data.kind in ["fern","bush","groundcover"] else meshes[data.kind]
		var n := Kit.scatter(parent,mesh,mat,data.xf,data.col,false)
		# Cleared slots move below the world; never let that alter the cell culling center.
		n.multimesh.custom_aabb = AABB(Vector3(data.cell.x*CELL-2.0,-0.5,data.cell.y*CELL-2.0),Vector3(CELL+4.0,4.0,CELL+4.0))
		n.name="Understory_"+key
		n.add_to_group("jungle_understory")
		# Existing density, governor and diagnostic switches operate on this group.
		n.add_to_group("foliage_grass")
		n.set_meta("full",data.xf.size())
		n.visibility_range_end=48.0 if data.kind in ["litter","stone","twig"] else 58.0
		n.extra_cull_margin=1.5  # leaf spread plus the existing 1.1 m actor push
		for i in data.xf.size():
			Foliage._register_vegetation({"kind":"grass","xf":data.xf[i],"slots":[{"multimesh":n.multimesh,"index":i}],"shapes":[]})
