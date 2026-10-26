extends SceneTree
## Meet wat de iPhone per beeld moet doen op een paar plekken (basis, stadsrand, straat bij de bus, plein):
## draw calls, objecten en driehoeken (zicht + schaduw), lichten met schaduw, deeltjes, scriptnodes en CPU-tijd.
## Draaien (lavapipe, Mobile-renderer zoals op de iPhone):
##   BJ_INSTANT=1 xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver vulkan --rendering-method mobile \
##     --path . -s tools/fps_meting.gd --resolution 1434x660
## BJ_QUALITY=ultra|high|low kiest de grafiekstand (standaard ultra), BJ_SPOTS=stad,plein beperkt de plekken.

var main: Node
var frames := 0
var spots := {
	"basis": Vector3(0, 0, 4),
	"stadsrand": Vector3(0, 0, -96),
	"straat_bus": Vector3(30, 0, -101),
	"plein": Vector3(0, 0, -135),
	"woonwijk": Vector3(-24, 0, -126),
}
var order: Array = []
var idx := -1
var wait := 0
var acc := {}
var busy := false


func _initialize() -> void:
	GameSettings.set_value("quality", OS.get_environment("BJ_QUALITY") if OS.has_environment("BJ_QUALITY") else "ultra")
	GameSettings.set_value("treeshadow", OS.get_environment("BJ_TREESHADOW") if OS.has_environment("BJ_TREESHADOW") else "real")
	GameSettings.set_value("wind", "on")
	if OS.has_environment("BJ_BUILDSHADOW"):
		GameSettings.set_value("buildshadow", OS.get_environment("BJ_BUILDSHADOW"))
	order = spots.keys()
	if OS.has_environment("BJ_SPOTS"):
		order = Array(OS.get_environment("BJ_SPOTS").split(","))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_d: float) -> bool:
	frames += 1
	if busy:
		return false
	if frames == 3:
		main.begin()
		for m in get_nodes_in_group("menus"):
			m._show("")
	if frames < 90:
		return false
	if frames == 90:
		if OS.has_environment("BJ_SHADOW_DIST"):
			for l in _all(root, "DirectionalLight3D"):
				(l as DirectionalLight3D).directional_shadow_max_distance = float(OS.get_environment("BJ_SHADOW_DIST"))
		if OS.has_environment("BJ_NO_STAD_SHADOW"):
			for g in _all(root.find_child("Stad", true, false), "GeometryInstance3D"):
				(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
		for n in get_nodes_in_group("touch_sticks"):
			n.set_process(false)
		_next()
		return false
	wait += 1
	if wait > 20:
		_sample()
	if wait >= 40:
		_report()
		if OS.has_environment("BJ_BREAKDOWN"):
			_breakdown()
		if OS.has_environment("BJ_BISECT"):
			busy = true
			_bisect()
			return false
		if not _next():
			return true
	return false


func _next() -> bool:
	idx += 1
	if idx >= order.size():
		return false
	var p: Vector3 = spots[order[idx]]
	var g = root.get_node("Game")
	g.player.global_position = p
	g.player.velocity = Vector3.ZERO
	wait = 0
	acc = {}
	return true


func _add(k: String, v: float) -> void:
	acc[k] = acc.get(k, 0.0) + v


func _sample() -> void:
	var vp := root.get_viewport()
	var V := Viewport.RENDER_INFO_TYPE_VISIBLE
	var S := Viewport.RENDER_INFO_TYPE_SHADOW
	_add("n", 1)
	_add("draw", vp.get_render_info(V, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME))
	_add("obj", vp.get_render_info(V, Viewport.RENDER_INFO_OBJECTS_IN_FRAME))
	_add("tri", vp.get_render_info(V, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME))
	_add("sdraw", vp.get_render_info(S, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME))
	_add("sobj", vp.get_render_info(S, Viewport.RENDER_INFO_OBJECTS_IN_FRAME))
	_add("stri", vp.get_render_info(S, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME))
	_add("pdraw", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	_add("pobj", Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	_add("ptri", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	_add("proc", Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	_add("phys", Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	_add("rcpu", RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))


func _report() -> void:
	if OS.has_environment("BJ_SHOT"):
		root.get_viewport().get_texture().get_image().save_png(OS.get_environment("BJ_SHOT") + "/" + String(order[idx]) + ".png")
	var n: float = maxf(1.0, acc.get("n", 1.0))
	var lights := 0
	var shadow_lights := 0
	for l in _all(root, "Light3D"):
		if (l as Light3D).is_visible_in_tree() and not (l is DirectionalLight3D):
			lights += 1
			if (l as Light3D).shadow_enabled:
				shadow_lights += 1
	var parts := 0
	for g in _all(root, "GPUParticles3D"):
		if (g as GPUParticles3D).emitting and (g as GPUParticles3D).is_visible_in_tree():
			parts += 1
	var proc := 0
	var phys := 0
	for x in _all(root, "Node"):
		if x.is_processing():
			proc += 1
		if x.is_physics_processing():
			phys += 1
	print("PLEK %-11s draw %4d obj %4d tri %6dk | schaduw draw %4d obj %4d tri %6dk | lichten %d (schaduw %d) deeltjes %d | _process %d _physics %d | script %.2f ms fysica %.2f ms render-cpu %.2f ms | overlay-teller: draw %d obj %d tri %dk | nodes %d" % [
		order[idx], acc.draw / n, acc.obj / n, acc.tri / n / 1000.0, acc.sdraw / n, acc.sobj / n, acc.stri / n / 1000.0,
		lights, shadow_lights, parts, proc, phys, acc.proc / n, acc.phys / n, acc.rcpu / n, acc.pdraw / n, acc.pobj / n, acc.ptri / n / 1000.0, Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])


func _all(n: Node, cls: String) -> Array:
	var out: Array = []
	if n.is_class(cls):
		out.append(n)
	for c in n.get_children():
		out.append_array(_all(c, cls))
	return out


## Zet per script de verwerking van die nodes even uit en meet hoeveel scripttijd dat scheelt.
func _bisect() -> void:
	var by := {}
	for x in _all(root, "Node"):
		if x == root or not (x.is_processing() or x.is_physics_processing()):
			continue
		var sc: Script = x.get_script()
		var key: String = sc.resource_path.get_file() if sc else x.get_class()
		if not by.has(key):
			by[key] = []
		by[key].append(x)
	var base := await _measure(30)
	print("  basis beeld %.2f ms" % base)
	for key in by:
		for x in by[key]:
			x.set_meta("_pp", [x.is_processing(), x.is_physics_processing()])
			x.set_process(false)
			x.set_physics_process(false)
		var t := await _measure(30)
		for x in by[key]:
			var pp: Array = x.get_meta("_pp")
			x.set_process(pp[0])
			x.set_physics_process(pp[1])
		print("  zonder %-24s (%3d nodes) beeld %.2f ms  (scheelt %.2f)" % [key, by[key].size(), t, base - t])
	busy = false
	if not _next():
		quit()


func _measure(n: int) -> float:
	# echte tijd per beeld (headless: geen wachten op het scherm), mediaan tegen uitschieters
	await process_frame
	await process_frame
	var ts := []
	var t0 := Time.get_ticks_usec()
	for i in n:
		await process_frame
		var t1 := Time.get_ticks_usec()
		ts.append((t1 - t0) / 1000.0)
		t0 = t1
	ts.sort()
	return ts[ts.size() / 2]


## Telt zichtbare mesh-vlakken (= draw calls) per soort: in beeld en binnen de schaduwafstand, en hoeveel daarvan schaduw werpen.
func _breakdown() -> void:
	var cam := root.get_viewport().get_camera_3d()
	var stad: Node = root.find_child("Stad", true, false)
	var rows := {}
	for gi in _all(root, "GeometryInstance3D"):
		var g := gi as GeometryInstance3D
		if not g.is_visible_in_tree():
			continue
		var surf := 1
		if g is MeshInstance3D:
			var m := (g as MeshInstance3D).mesh
			if m == null:
				continue
			surf = m.get_surface_count()
		elif g is MultiMeshInstance3D:
			var mm := (g as MultiMeshInstance3D).multimesh
			if mm == null or mm.mesh == null or mm.visible_instance_count == 0:
				continue
			surf = mm.mesh.get_surface_count()
		var aabb := g.global_transform * g.get_aabb()
		var c := aabb.get_center()
		var d := cam.global_position.distance_to(c)
		if g.visibility_range_end > 0.0 and d > g.visibility_range_end + g.visibility_range_end_margin:
			continue
		var key := _cat(g, stad)
		if not rows.has(key):
			rows[key] = [0, 0, 0, 0]
		var r: Array = rows[key]
		var inview := cam.is_position_in_frustum(c) or aabb.size.length() > 30.0
		var caster := g.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if inview:
			r[0] += surf
		if caster and d < 90.0:
			r[1] += surf
			if g is MeshInstance3D and (g as MeshInstance3D).mesh:
				r[2] += (g as MeshInstance3D).mesh.get_faces().size() / 3
		r[3] += 1
	var keys := rows.keys()
	keys.sort_custom(func(a, b): return rows[a][1] > rows[b][1])
	print("  soort                         in beeld | schaduwwerpers <90m (driehoeken)")
	for k in keys.slice(0, 28):
		print("  %-30s %5d | %5d (%dk)" % [k, rows[k][0], rows[k][1], rows[k][2] / 1000])


func _cat(n: Node, stad: Node) -> String:
	var path: Array = []
	var x := n
	while x != null and x != root:
		path.push_front(x)
		x = x.get_parent()
	for i in path.size():
		if path[i] == stad and i + 1 < path.size():
			var top: Node = path[i + 1]
			var sc: Script = top.get_script()
			var kind := String(top.get("kind")) if sc and "kind" in top else (sc.resource_path.get_file().get_basename() if sc else String(top.name).rstrip("0123456789"))
			var sub := ""
			if i + 2 < path.size():
				sub = String(path[i + 2].name).rstrip("0123456789_")
			return "stad/" + kind + ("/" + sub if kind in ["woonhuis", "winkel", "kerk", "hotel", "magazijn", "benzine"] else "")
	if path.size() > 2:
		return String(path[1].name) + "/" + String(path[2].name).rstrip("0123456789@")
	return String(n.name)
