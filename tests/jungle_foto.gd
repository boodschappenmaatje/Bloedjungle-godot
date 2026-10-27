extends SceneTree
## Jungle in de echte spelcamera: de speler staat tussen de bomen op drie plekken (JUNGLE_OUT = uitvoermap).
## BJ_TOUCH=1 xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver vulkan --path . -s tests/jungle_foto.gd --resolution 1280x590 --fixed-fps 60
var main: Node
var game: Node
var frames := 0
var out := "/tmp/junglefoto"
var spots: Array[Vector2] = []


func _initialize() -> void:
	if OS.get_environment("JUNGLE_OUT") != "":
		out = OS.get_environment("JUNGLE_OUT")
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	game = root.get_node("Game")


func _pick_spots() -> void:
	var trees: PackedVector2Array = (load("res://scripts/foliage.gd") as GDScript).get("trees")
	var best: Array = []
	for p in trees:
		if absf(p.x) < 36.0 and absf(p.y) < 36.0:
			continue
		var n := 0
		for q in trees:
			if p.distance_to(q) < 9.0:
				n += 1
		best.append([n, p])
	best.sort_custom(func(a, b): return a[0] > b[0])
	for b in best:
		var ok := true
		for s in spots:
			if s.distance_to(b[1]) < 25.0:
				ok = false
		if ok:
			spots.append(b[1])
		if spots.size() >= 3:
			break


func _process(_d: float) -> bool:
	frames += 1
	if frames == 3:
		main.begin()
		for m in get_nodes_in_group("menus"):
			m._show("")
		for n in root.find_children("*", "", true, false):
			if n.get_script() and String(n.get_script().resource_path).ends_with("touch_sticks.gd"):
				n.set_process(false)
	if frames == 120:
		_pick_spots()
		print("plekken ", spots)
	var k := frames - 130
	if k >= 0 and k % 40 == 0 and k / 40 < spots.size():
		var s: Vector2 = spots[k / 40]
		game.player.global_position = Vector3(s.x, 0.0, s.y)
	if k >= 30 and (k - 30) % 40 == 0 and (k - 30) / 40 < spots.size():
		root.get_viewport().get_texture().get_image().save_png("%s/jungle_%d.png" % [out, (k - 30) / 40])
	return frames > 130 + 40 * 3 + 5
