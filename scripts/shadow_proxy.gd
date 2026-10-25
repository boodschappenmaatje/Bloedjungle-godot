class_name ShadowProxy
extends RefCounted
## Eén samengevoegde schaduwvorm in plaats van de schaduw van tientallen losse stukjes (gebouwen, geparkeerde voertuigen).
## Elk stukje kost in de schaduwkaart een eigen tekenopdracht; de samengevoegde vorm heeft precies dezelfde driehoeken, dus
## dezelfde schaduw, maar één opdracht. Wie iets verandert aan het model (schade, deuren, instappen) zet hem uit met set_on(false):
## dan werpen de losse stukjes weer zelf.

static var _cache := {}   # sleutel -> {mesh, n}
var node: MeshInstance3D
var parts: Array[MeshInstance3D] = []


## host = node waarin de vorm komt (zelfde ruimte als het model), root = model, key = soort (voor het geheugen),
## skip = nodes (en hun kinderen) die hun eigen schaduw houden. Geeft null als er te weinig stukjes zijn.
static func make(host: Node3D, root: Node, key: String, skip: Array, min_parts := 8) -> ShadowProxy:
	var list: Array[MeshInstance3D] = []
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or not mi.is_visible_in_tree() or mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON:
			continue
		if mi.skin != null or skip.any(func(n): return n is Node and (n == mi or (n as Node).is_ancestor_of(mi))):
			continue
		if _ok(mi):
			list.append(mi)
	if list.size() < min_parts:
		return null
	var c: Dictionary = _cache.get(key, {})
	if c.is_empty() or int(c.n) != list.size():
		c = {"mesh": _merge(host, list), "n": list.size()}
		_cache[key] = c
	var p := ShadowProxy.new()
	p.node = MeshInstance3D.new()
	p.node.name = "Schaduw"
	p.node.mesh = c.mesh
	p.node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	host.add_child(p.node)
	p.parts = list
	return p


func set_on(on: bool) -> void:
	set_mode(1 if on else 2)


## 0 = geen schaduw, 1 = de samengevoegde vorm, 2 = de losse stukjes.
func set_mode(mode: int) -> void:
	node.visible = mode == 1
	for mi in parts:
		if is_instance_valid(mi):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if mode == 2 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Alleen stukjes waarvan elk vlak een gewoon, dicht materiaal heeft: uitgeknipte delen (hekwerk, blad), eigen shaders of
## doorzichtig materiaal blijven hun eigen schaduw tekenen.
static func _ok(mi: MeshInstance3D) -> bool:
	for i in mi.mesh.get_surface_count():
		if mi.mesh.surface_get_primitive_type(i) != Mesh.PRIMITIVE_TRIANGLES:
			return false
		var m := mi.get_active_material(i)
		if m == null:
			continue
		if not (m is BaseMaterial3D):
			return false
		var b := m as BaseMaterial3D
		if b.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA:
			continue
		if b.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or b.cull_mode == BaseMaterial3D.CULL_FRONT \
				or b.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED or b.grow or b.use_point_size:
			return false
	return true


## Alle dichte vlakken samen, in de ruimte van host: één vlak voor enkelzijdig en één voor dubbelzijdig materiaal.
static func _merge(host: Node3D, list: Array[MeshInstance3D]) -> ArrayMesh:
	var inv := host.global_transform.affine_inverse()
	var buckets := [[PackedVector3Array(), PackedVector3Array(), PackedInt32Array()], [PackedVector3Array(), PackedVector3Array(), PackedInt32Array()]]
	for mi in list:
		var xf: Transform3D = inv * mi.global_transform
		var nb := xf.basis.inverse().transposed()
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i) as BaseMaterial3D
			if m != null and m.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA:
				continue
			var two := m != null and m.cull_mode == BaseMaterial3D.CULL_DISABLED
			var bk: Array = buckets[1 if two else 0]
			var arr := mi.mesh.surface_get_arrays(i)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var nrm = arr[Mesh.ARRAY_NORMAL]
			var idx = arr[Mesh.ARRAY_INDEX]
			var base: int = (bk[0] as PackedVector3Array).size()
			for j in v.size():
				bk[0].append(xf * v[j])
				bk[1].append((nb * (nrm[j] as Vector3)).normalized() if nrm != null and j < nrm.size() else Vector3.UP)
			if idx != null and (idx as PackedInt32Array).size() > 0:
				for k in idx:
					bk[2].append(base + int(k))
			else:
				for k in v.size():
					bk[2].append(base + k)
	var out := ArrayMesh.new()
	for b in 2:
		var bk: Array = buckets[b]
		if (bk[2] as PackedInt32Array).is_empty():
			continue
		var a := []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = bk[0]
		a[Mesh.ARRAY_NORMAL] = bk[1]
		a[Mesh.ARRAY_INDEX] = bk[2]
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		if b == 1:
			var two_mat := StandardMaterial3D.new()
			two_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			out.surface_set_material(out.get_surface_count() - 1, two_mat)
	return out
