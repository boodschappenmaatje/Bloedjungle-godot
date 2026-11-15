class_name Stuwmeer
extends RefCounted
## Het water achter de dam (dambreuk stap 2). Peil Bergland.LAKE_Y; de vorm volgt het terrein: alles wat vanuit het bekken
## lager ligt dan het peil en voor de dam ligt, loopt vol (vloedvulling over een raster van 4 m). Geen botsing, geen
## schaduw; de diepte zit in de vertexkleur voor de watershader.

const CELL := 4.0
const X0 := -300.0
const X1 := 140.0
const Z0 := -660.0
const DEPTH_MAX := 12.0


## Tekent het meer in `parent`; geeft het MeshInstance3D terug (null als er geen water komt).
static func build(parent: Node3D) -> MeshInstance3D:
	var mesh := build_mesh()
	if mesh == null:
		return null
	var mi := MeshInstance3D.new()
	mi.name = "Stuwmeer"
	mi.mesh = mesh
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/stuwmeer.gdshader")
	m.set_shader_parameter("noise", Kit.noise_tex(0.05, 31))
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	parent.add_child(mi)
	return mi


static func z_limit() -> float:
	return Bergland.DAM_Z - 2.5   # binnen de dam (de voorkant ligt op z = DAM_Z - 3,1)


## Raster van hoogtes (rij-voor-rij) en de gevulde punten; (nx, nz, hs, wet).
static func fill() -> Dictionary:
	var nx := int((X1 - X0) / CELL) + 1
	var nz := int((z_limit() - Z0) / CELL) + 1
	var hs := PackedFloat32Array()
	hs.resize(nx * nz)
	for j in nz:
		for i in nx:
			hs[j * nx + i] = Bergland.height(X0 + i * CELL, Z0 + j * CELL)
	var wet := PackedByteArray()
	wet.resize(nx * nz)
	var si := int((Bergland.BASIN.x - X0) / CELL)
	var sj := int((Bergland.BASIN.y - Z0) / CELL)
	var stack: Array = []
	if hs[sj * nx + si] < Bergland.LAKE_Y:
		stack.append(sj * nx + si)
		wet[sj * nx + si] = 1
	while not stack.is_empty():
		var k: int = stack.pop_back()
		var i := k % nx
		var j := k / nx
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var a: int = i + d.x
			var b: int = j + d.y
			if a < 0 or b < 0 or a >= nx or b >= nz:
				continue
			var q := b * nx + a
			if wet[q] == 0 and hs[q] < Bergland.LAKE_Y:
				wet[q] = 1
				stack.append(q)
	return {"nx": nx, "nz": nz, "hs": hs, "wet": wet}


static func build_mesh() -> ArrayMesh:
	var f := fill()
	var nx: int = f["nx"]
	var nz: int = f["nz"]
	var hs: PackedFloat32Array = f["hs"]
	var wet: PackedByteArray = f["wet"]
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	var map := {}
	for j in nz - 1:
		for i in nx - 1:
			var c := [j * nx + i, j * nx + i + 1, (j + 1) * nx + i + 1, (j + 1) * nx + i]
			if not (wet[c[0]] == 1 or wet[c[1]] == 1 or wet[c[2]] == 1 or wet[c[3]] == 1):
				continue
			var q := []
			for k in c:
				if not map.has(k):
					map[k] = verts.size()
					var depth := clampf(Bergland.LAKE_Y - hs[k], 0.0, DEPTH_MAX) if wet[k] == 1 else 0.0
					verts.append(Vector3(X0 + (k % nx) * CELL, Bergland.LAKE_Y, Z0 + (k / nx) * CELL))
					norms.append(Vector3.UP)
					cols.append(Color(depth / DEPTH_MAX, 0.0, 0.0, 1.0))
				q.append(map[k])
			idx.append_array(PackedInt32Array([q[0], q[2], q[1], q[0], q[3], q[2]]))
	if verts.is_empty():
		return null
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	am.custom_aabb = AABB(Vector3(X0, Bergland.LAKE_Y - 1.0, Z0), Vector3(X1 - X0, 2.0, z_limit() - Z0))
	return am
