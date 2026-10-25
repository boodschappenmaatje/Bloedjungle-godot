extends SceneTree
## Meet of alles vooraf klaargezet is: telt hoeveel shader-pipelines Godot nog moet compileren nádat het laadscherm weg is,
## per plek (stad, plein, ...) en per effect (vuur, explosie, wrak, hulzen, ...). Elke nieuwe compilatie kan een hapering zijn.
## Draaien (zonder BJ_INSTANT, dan loopt het echte laadscherm met warm-up):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver vulkan --rendering-method mobile --path . -s tools/warmup_meting.gd --resolution 1434x660

var main: Node
var frames := 0
var busy := false


func _initialize() -> void:
	GameSettings.set_value("quality", OS.get_environment("BJ_QUALITY") if OS.has_environment("BJ_QUALITY") else "ultra")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_d: float) -> bool:
	frames += 1
	if frames == 3:
		busy = true
		_run()
	return false


func _compiles() -> int:
	var n := 0
	for k in [RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS, RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_MESH,
			RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE, RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW,
			RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION]:
		n += RenderingServer.get_rendering_info(k)
	return n


func _detail() -> String:
	return "canvas %d mesh %d surface %d draw %d specialisatie %d" % [
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_MESH),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION)]


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _step(label: String, f: Callable, wait := 30) -> void:
	var before := _compiles()
	var d0 := _detail()
	f.call()
	await _frames(wait)
	var after := _compiles()
	print("WARM %-28s nieuwe compilaties: %d" % [label, after - before] + ("" if after == before else "   (%s -> %s)" % [d0, _detail()]))


func _run() -> void:
	var t0 := Time.get_ticks_msec()
	await main.begin()
	print("WARM laden klaar na %.1f s, compilaties tot nu: %d (%s)" % [(Time.get_ticks_msec() - t0) / 1000.0, _compiles(), _detail()])
	for m in get_nodes_in_group("menus"):
		m._show("")
	for n in get_nodes_in_group("touch_sticks"):
		n.set_process(false)
	await _frames(30)
	var base := _compiles()
	var g = root.get_node("Game")
	var p: Node3D = g.player
	var fx: GDScript = load("res://scripts/fx.gd")
	await _step("eerste beelden in de basis", func(): pass)
	for spot in [["stadsrand", Vector3(0, 0, -96)], ["straat bij de bus", Vector3(30, 0, -101)], ["plein", Vector3(0, 0, -135)], ["woonwijk", Vector3(-24, 0, -126)], ["industriestraat", Vector3(50, 0, -120)]]:
		await _step("naar " + spot[0], func(): p.global_position = spot[1])
	var at: Vector3 = p.global_position + Vector3(0, 0, -4)
	await _step("lamp in de stad", func():
		var l := OmniLight3D.new()
		l.omni_range = 15.0
		main.add_child(l)
		l.global_position = at + Vector3.UP)
	await _step("brandplek in de stad", func(): fx.call("decal", main, Vector3(at.x, 0, at.z), Vector3.UP, "scorch", 3.6, 80.0))
	await _step("vuurbal", func(): fx.call("_fireball", main, at, 1.0))
	await _step("brokstukken", func(): fx.call("_debris", main, at, 1.0, fx.get("CHUNKS_GROUND")))
	await _step("krater", func(): fx.call("crater", main, at, 1.0))
	await _step("explosie", func(): fx.call("explosion", main, at, 1.0))
	await _step("vuur met licht", func(): fx.call("flame", main, at + Vector3(2, 0, 0), 1.5, true))
	await _step("gloeiende vonken", func(): fx.call("embers", main, at + Vector3(-2, 0, 0)))
	await _step("vonk", func(): fx.call("spark", main, at, Vector3.UP))
	await _step("huls", func(): fx.call("casing", main, p.global_position + Vector3.UP))
	await _step("raketstart", func(): fx.call("rocket_launch", main, p.global_position + Vector3.UP, 0.0))
	await _step("wrak (vat)", func(): fx.call("wreck", main, at))
	for kind in ["woonhuis", "winkel", "hotel", "kerk", "benzine", "magazijn"]:
		await _step("ruïne " + kind, func():
			for h in get_nodes_in_group(kind):
				if h.global_position.distance_to(p.global_position) < 200.0:
					p.global_position = h.global_position + Vector3(0, 0, 9)
					for c in h.find_children("*", "Node3D", true, false):
						(c as Node3D).visible = true
					break)
	for grp in ["auto", "bus"]:
		await _step("wrak " + grp, func():
			for v in get_nodes_in_group(grp):
				if v.has_method("_make_wreck"):
					p.global_position = v.global_position + Vector3(0, 0, 6)
					v.call("_make_wreck", true)
					break)
	print("WARM totaal na het laden: %d nieuwe compilaties" % (_compiles() - base))
	quit()
