extends SceneTree
## Struiken en varens buigen voor de speler, in de echte spelcamera: links (voor) staat buigen uit, rechts (na) aan.
## STRUIKEN_OUT = uitvoermap.
## BJ_TOUCH=1 xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver vulkan --path . -s tests/struiken_foto.gd --resolution 1280x590 --fixed-fps 60
var main: Node
var game: Node
var F: GDScript
var frames := 0
var out := "/tmp/struikenfoto"
var spot := Vector3.ZERO


func _initialize() -> void:
	if OS.get_environment("STRUIKEN_OUT") != "":
		out = OS.get_environment("STRUIKEN_OUT")
	DirAccess.make_dir_recursive_absolute(out)
	F = load("res://scripts/foliage.gd")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	game = root.get_node("Game")


func _pick_spot() -> void:
	var pts: Array[Vector3] = []
	for g in ["foliage_bush", "foliage_fern"]:
		for n: MultiMeshInstance3D in get_nodes_in_group(g):
			for i in n.multimesh.instance_count:
				var o := n.multimesh.get_instance_transform(i).origin
				if absf(o.x) > 36.0 or absf(o.z) > 36.0:
					if o.z > -80.0 and o.z < -36.0:
						pts.append(o)
	var best := -1
	var best_n := 0
	for i in range(0, pts.size(), 3):
		var c := 0
		for q in pts:
			if pts[i].distance_to(q) < 2.2:
				c += 1
		if c > best_n:
			best_n = c
			best = i
	spot = pts[best]
	print("plek ", spot, " struiken binnen 2,2 m: ", best_n)


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
		_pick_spot()
		GameSettings.set_value("time", "day")
		game.player.global_position = spot
		F.set("push_enabled", false)
	if frames == 200:
		root.get_viewport().get_texture().get_image().save_png(out + "/voor.png")
		F.set("push_enabled", true)
	if frames == 240:
		root.get_viewport().get_texture().get_image().save_png(out + "/na.png")
		game.player.global_position = spot + Vector3(1.6, 0, 0.6)   # een stap verder: het blad veert terug
	if frames == 330:
		root.get_viewport().get_texture().get_image().save_png(out + "/stap_verder.png")
	return frames > 335
