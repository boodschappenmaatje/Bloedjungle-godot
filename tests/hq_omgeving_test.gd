extends SceneTree
## Test: het hoofdkwartier in de laatste uitvoering (kniemuur onder de ramen is er, helderheid, camonet) en het voorplein
## (model, botsblokken, nachtlichten, vrije weg vanaf de deur).
## Draaien: godot --headless --path . -s tests/hq_omgeving_test.gd --fixed-fps 60

var failures: Array[String] = []
var main: Node
var game: Node


func _initialize() -> void:
	OS.set_environment("BJ_TOUCH", "1")
	root.size = Vector2i(932, 430)
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	print(("OK   " if ok else "FOUT ") + message)
	if not ok:
		failures.append(message)
		push_error("HQ OMGEVING TEST: " + message)


func _frames(n: int) -> void:
	for _i in n:
		await process_frame


## Aantal grote verticale driehoeken (> 1 m2) tussen hoogte y0 en y1 in een mesh: de muren van de bovenverdieping.
func _big_walls(mi: MeshInstance3D, y0: float, y1: float) -> int:
	var n := 0
	var mesh := mi.mesh
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		for t in range(0, idx.size(), 3):
			var a := v[idx[t]]
			var b := v[idx[t + 1]]
			var c := v[idx[t + 2]]
			var nrm := (b - a).cross(c - a)
			var area := nrm.length() * 0.5
			if area < 1.0:
				continue
			if absf(nrm.normalized().y) > 0.3:
				continue
			if minf(a.y, minf(b.y, c.y)) >= y0 and maxf(a.y, maxf(b.y, c.y)) <= y1:
				n += 1
	return n


func _run() -> void:
	# 1. het hoofdkwartier zelf: de kniemuur (rond hoogte 2,87 tot 3,62) moet er zijn
	var hq_scene: PackedScene = load("res://assets/hoofdkwartier.glb")
	var hq_model: Node = hq_scene.instantiate()
	root.add_child(hq_model)
	var romp := hq_model.find_child("Romp", true, false) as MeshInstance3D
	_check(romp != null, "hoofdkwartier.glb heeft een Romp")
	if romp != null:
		var walls := _big_walls(romp, 2.8, 3.7)
		_check(walls >= 8, "kniemuur onder de ramen is er: %d grote muurdriehoeken (minimaal 8, vier wanden)" % walls)
	var tris := 0
	for mi in hq_model.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).mesh
		if m == null:
			continue
		for s in m.get_surface_count():
			var arr := m.surface_get_arrays(s)
			tris += (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	_check(tris >= 40000, "hoofdkwartier houdt de eis van minimaal 40.000 driehoeken (%d, alle onderdelen inclusief niveau- en schadelagen)" % tris)
	hq_model.queue_free()
	# 2. het voorplein in het spel
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	game = root.get_node("Game")
	await _frames(3)
	main.get_node("Hud/Sticks").set_process(false)
	await main.call("begin")
	await _frames(4)
	var env: Node = null
	for n in get_nodes_in_group("hq_omgeving"):
		env = n
	_check(env != null, "voorplein staat in het spel (groep hq_omgeving)")
	if env == null:
		_finish()
		return
	var bodies := 0
	for c in env.get_children():
		if c is StaticBody3D:
			bodies += 1
	var blocks: Array = (env.get_script() as GDScript).get_script_constant_map()["BLOCKS"]
	_check(bodies == blocks.size(), "elk botsblok is er: %d van %d" % [bodies, blocks.size()])
	var meshes := 0
	var env_tris := 0
	for mi in env.find_children("*", "MeshInstance3D", true, false):
		meshes += 1
		var m := (mi as MeshInstance3D).mesh
		for s in m.get_surface_count():
			env_tris += ((m.surface_get_arrays(s)[Mesh.ARRAY_INDEX]) as PackedInt32Array).size() / 3
	_check(meshes >= 6, "voorplein heeft zijn onderdelen: %d meshes, %d driehoeken" % [meshes, env_tris])
	# vrije weg: vanaf de deur recht naar voren (x = 1,3) tot aan de afzetblokken mag niets de weg versperren
	var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
	var wall_layer: int = (load("res://scripts/kit.gd") as GDScript).get_script_constant_map()["LAYER_WALL"]
	var q := PhysicsRayQueryParameters3D.create(Vector3(1.3, 0.5, 3.0), Vector3(1.3, 0.5, 9.0), wall_layer)
	var hit: Dictionary = space.intersect_ray(q)
	_check(hit.is_empty(), "de weg vanaf de deur naar het voorplein is vrij")
	var q2 := PhysicsRayQueryParameters3D.create(Vector3(-3.0, 0.5, 5.0), Vector3(-3.0, 0.5, 9.0), wall_layer)
	_check(not space.intersect_ray(q2).is_empty(), "een afzetblok houdt kogels en mensen tegen")
	# nachtlichten
	GameSettings.set_value("time", "night")
	await _frames(40)
	var lights_on := 0
	for l in env.find_children("Mastlicht*", "OmniLight3D", true, false):
		if (l as OmniLight3D).visible:
			lights_on += 1
	_check(lights_on == 2, "beide lichtmasten branden 's nachts (%d)" % lights_on)
	GameSettings.set_value("time", "day")
	await _frames(40)
	lights_on = 0
	for l in env.find_children("Mastlicht*", "OmniLight3D", true, false):
		if (l as OmniLight3D).visible:
			lights_on += 1
	_check(lights_on == 0, "de lichtmasten zijn overdag uit (%d)" % lights_on)
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("TEST OK")
		quit(0)
	else:
		print("TEST MISLUKT: %d fouten" % failures.size())
		quit(1)
