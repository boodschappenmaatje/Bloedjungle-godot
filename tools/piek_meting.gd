extends SceneTree
## Meet de pieken uit Dennis' prestatie-overlay na: explosies, een auto die ontploft en een huis dat helemaal gesloopt
## wordt (veel puin). Per gebeurtenis: hoe lang het beeld duurde (CPU), hoeveel shader-pipelines er nog gemaakt werden,
## en hoeveel objecten/draw calls/nodes er daarna in de wereld bij komen.
## Draaien (lavapipe, Mobile-renderer zoals op de iPhone):
##   BJ_INSTANT=1 xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver vulkan --rendering-method mobile \
##     --path . -s tools/piek_meting.gd --resolution 1434x660
## Alleen CPU (snel, geen tekenen): godot --headless --path . -s tools/piek_meting.gd

var main: Node
var frames := 0
var spot := Vector3(-24, 0, -126)   # woonwijk
# klassen pas na het laden opzoeken: bij het compileren van dit script bestaan de autoloads nog niet
var FX: GDScript
var WH: GDScript
var AUTO: GDScript
var BARREL: GDScript


func _initialize() -> void:
	GameSettings.set_value("quality", OS.get_environment("BJ_QUALITY") if OS.has_environment("BJ_QUALITY") else "high")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_d: float) -> bool:
	frames += 1
	if frames == 3:
		main.begin()
		for m in get_nodes_in_group("menus"):
			m._show("")
	if frames == 60:
		for n in get_nodes_in_group("touch_sticks"):
			n.set_process(false)
		_run()
	return false


func _counts() -> Dictionary:
	var vp := root.get_viewport()
	return {"draw": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"obj": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"tri": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"pipe": main.call("_pipeline_compiles"),
		"pd": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW),
		"ps": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION),
		"proc": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"phys": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0}


## De echte duur van de komende n beelden (ms), na een gebeurtenis die cb uitvoert in hetzelfde beeld.
func _event(label: String, cb: Callable, n := 20) -> void:
	var c0 := _counts()
	var t0 := Time.get_ticks_usec()
	cb.call()
	var t_call := (Time.get_ticks_usec() - t0) / 1000.0
	var ts: Array = []
	var last := Time.get_ticks_usec()
	for i in n:
		await process_frame
		var now := Time.get_ticks_usec()
		ts.append(snappedf((now - last) / 1000.0, 0.1))
		last = now
	var c1 := _counts()
	print("GEBEURTENIS %-28s aanroep %.1f ms · beelden %s · pipelines +%d (bij tekenen %d, specialisatie %d) · nodes %+d · draw %d→%d · obj %d→%d" % [
		label, t_call, str(ts.slice(0, 8)), int(c1.pipe - c0.pipe), int(c1.pd - c0.pd), int(c1.ps - c0.ps), int(c1.nodes - c0.nodes), c0.draw, c1.draw, c0.obj, c1.obj])


func _steady(label: String, n := 30) -> void:
	var ts: Array = []
	var last := Time.get_ticks_usec()
	var acc := {"draw": 0.0, "obj": 0.0, "proc": 0.0, "phys": 0.0}
	for i in n:
		await process_frame
		var now := Time.get_ticks_usec()
		ts.append((now - last) / 1000.0)
		last = now
		var c := _counts()
		for k in acc:
			acc[k] += float(c[k])
	ts.sort()
	var parts := 0
	var emit := 0
	var st: Array = [root]
	var scripts := {}
	while st.size():
		var x: Node = st.pop_back()
		st.append_array(x.get_children())
		if x is CPUParticles3D:
			parts += 1
			if (x as CPUParticles3D).emitting:
				emit += 1
				var pa := x.get_parent()
				var ps: Script = pa.get_script() if pa else null
				var pk := "%s/%s a%d" % [(ps.resource_path.get_file() if ps else pa.get_class()), String(x.name).rstrip("0123456789").replace("@", ""), (x as CPUParticles3D).amount]
				scripts["P " + pk] = scripts.get("P " + pk, 0) + 1
		if x.is_processing() or x.is_physics_processing():
			var sc: Script = x.get_script()
			var k: String = sc.resource_path.get_file() if sc else x.get_class()
			scripts[k] = scripts.get(k, 0) + 1
	var top := []
	for k in scripts:
		top.append([scripts[k], k])
	top.sort_custom(func(a, b): return a[0] > b[0])
	print("     tweens %d · deeltjes %d (aan %d) · _process-nodes %s" % [get_processed_tweens().size(), parts, emit, str(top.slice(0, 14))])
	print("RUST %-30s beeld mediaan %.1f ms · draw %.0f · obj %.0f · nodes %d · script %.2f ms · fysica %.2f ms" % [
		label, ts[ts.size() / 2], acc.draw / n, acc.obj / n, Performance.get_monitor(Performance.OBJECT_NODE_COUNT), acc.proc / n, acc.phys / n])


func _boom(at: Vector3) -> void:
	# zoals grenade.gd _explode
	var t0 := Time.get_ticks_usec()
	FX.explosion(main, at, 1.1)
	var t1 := Time.get_ticks_usec()
	root.get_node("Game").note_blast(at, 5.0)
	BARREL.catch_blast(at, 5.0)
	var t2 := Time.get_ticks_usec()
	WH.blast_all(at, 5.0, 220.0)
	var t3 := Time.get_ticks_usec()
	print("   delen: Fx.explosion %.1f ms · auto/vat/kraan %.1f ms · huizen %.1f ms" % [(t1 - t0) / 1000.0, (t2 - t1) / 1000.0, (t3 - t2) / 1000.0])


func _run() -> void:
	FX = load("res://scripts/fx.gd")
	WH = load("res://scripts/woonhuis.gd")
	AUTO = load("res://scripts/auto.gd")
	BARREL = load("res://scripts/barrel.gd")
	var g = root.get_node("Game")
	g.player.global_position = spot
	for i in 40:
		await process_frame
	await _steady("woonwijk voor")
	await _event("explosie", func(): _boom(spot + Vector3(6, 0, 6)))
	await _event("explosie (2e)", func(): _boom(spot + Vector3(-6, 0, 6)))
	await _event("explosie x2 tegelijk", func():
		_boom(spot + Vector3(6, 0, -6))
		_boom(spot + Vector3(-6, 0, -6)))
	# auto: de dichtstbijzijnde hele auto
	var best: Node3D = null
	for a in AUTO.all:
		if is_instance_valid(a) and not a.exploded and (best == null or a.global_position.distance_to(spot) < best.global_position.distance_to(spot)):
			best = a
	if best:
		g.player.global_position = best.global_position + Vector3(0, 0, 8)
		for i in 20:
			await process_frame
		await _event("auto ontploft", func(): best.explode(), 30)
		await _event("auto ontploft (2e)", func():
			for a in AUTO.all:
				if is_instance_valid(a) and not a.exploded and a != best:
					a.explode()
					return, 30)
	# een huis helemaal slopen
	var house: Node3D = null
	for h in WH.all:
		if house == null or h.global_position.distance_to(spot) < house.global_position.distance_to(spot):
			house = h
	if house:
		g.player.global_position = house.global_position + Vector3(0, 0, 14)
		for i in 20:
			await process_frame
		await _steady("bij huis heel")
		if OS.has_environment("BJ_BISECT"):
			await _bisect()
		for k in 8:
			var at: Vector3 = house.global_position + Vector3(randf_range(-4, 4), 1.0, randf_range(-4, 4))
			await _event("sloop %d (%s)" % [k, house.get("soort")], func(): _boom(at), 10)
		for i in 30:
			await process_frame
		await _steady("na sloop")
		for i in 400:
			await process_frame
		await _steady("na sloop +7 s")
	quit()


## Welke soort node kost de scripttijd? Per soort (script of klasse) de verwerking even uit en de scripttijd vergelijken.
func _bisect() -> void:
	var by := {}
	var st: Array = [root]
	while st.size():
		var x: Node = st.pop_back()
		st.append_array(x.get_children())
		if not (x.is_processing() or x.is_physics_processing() or x.is_processing_internal()):
			continue
		var sc: Script = x.get_script()
		var key: String = sc.resource_path.get_file() if sc else x.get_class()
		if not by.has(key):
			by[key] = []
		by[key].append(x)
	var rows := []
	for key in by:
		var b1 := await _proc_ms(15)
		for x in by[key]:
			x.set_meta("_pp", [x.is_processing(), x.is_physics_processing(), x.is_processing_internal()])
			x.set_process(false)
			x.set_physics_process(false)
			x.set_process_internal(false)
		var t := await _proc_ms(15)
		for x in by[key]:
			var pp: Array = x.get_meta("_pp")
			x.set_process(pp[0])
			x.set_physics_process(pp[1])
			x.set_process_internal(pp[2])
		var b2 := await _proc_ms(15)
		rows.append([(b1 + b2) * 0.5 - t, key, by[key].size(), b1, b2])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	for r in rows.slice(0, 14):
		print("  zonder %-28s (%4d nodes) scheelt %.2f ms  (basis %.1f/%.1f)" % [r[1], r[2], r[0], r[3], r[4]])


func _proc_ms(n: int) -> float:
	await process_frame
	var acc := 0.0
	for i in n:
		await process_frame
		acc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0 + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	return acc / n
