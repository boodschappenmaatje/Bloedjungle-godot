extends SceneTree
## Een jungleboom en een palm vallen om door een ontploffing, in de echte spelcamera: voor, tijdens het vallen en erna.
## BOOM_VAL_OUT = uitvoermap.
## BJ_TOUCH=1 xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver vulkan --path . -s tests/boom_val_foto.gd --resolution 1280x590 --fixed-fps 60
var main: Node
var game: Node
var F: GDScript
var frames := 0
var out := "/tmp/boomval"
var e: Dictionary
var spot := Vector3.ZERO
const T0 := 150
## Beeldnummers (na T0) waarop een opname wordt gemaakt
const SHOTS := [-1, 40, 80, 105, 130, 200, 330]


func _initialize() -> void:
	if OS.get_environment("BOOM_VAL_OUT") != "":
		out = OS.get_environment("BOOM_VAL_OUT")
	DirAccess.make_dir_recursive_absolute(out)
	F = load("res://scripts/foliage.gd")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	game = root.get_node("Game")


func _pick() -> Dictionary:
	var want := OS.get_environment("BOOM_VAL_KIND") if OS.get_environment("BOOM_VAL_KIND") != "" else "Boom"
	var best := {}
	var best_n := -1
	for key in F.get("_reg"):
		for en: Dictionary in F.get("_reg")[key]:
			var o: Vector3 = en["xf"].origin
			if not String(en["vn"]).begins_with(want) or absf(o.x) < 40.0 or o.z < -85.0 or o.z > -40.0:
				continue
			var n := 0   # liefst een boom met open ruimte om hem heen, zodat je hem ziet vallen
			for key2 in F.get("_reg"):
				for q: Dictionary in F.get("_reg")[key2]:
					if (q["xf"].origin - o).length() < 7.0:
						n += 1
			if best_n < 0 or n < best_n:
				best_n = n
				best = en
	return best


## Maakt een open plek rond de boom (andere bomen, struiken en varens), zodat je hem goed ziet vallen.
func _clear_around() -> void:
	var gone := Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
	for key in F.get("_reg"):
		for q: Dictionary in F.get("_reg")[key]:
			if q != e and (q["xf"].origin - spot).length() < 13.0:
				q["mm"].set_instance_transform(q["idx"], gone)
				q["far"].set_instance_transform(q["idx"], gone)
	for g in ["foliage_bush", "foliage_fern"]:
		for n: MultiMeshInstance3D in get_nodes_in_group(g):
			for i in n.multimesh.instance_count:
				if (n.multimesh.get_instance_transform(i).origin - spot).length() < 13.0:
					n.multimesh.set_instance_transform(i, gone)


func _process(_d: float) -> bool:
	frames += 1
	if frames == 3:
		main.begin()
		for m in get_nodes_in_group("menus"):
			m._show("")
		for n in root.find_children("*", "", true, false):
			if n.get_script() and String(n.get_script().resource_path).ends_with("touch_sticks.gd"):
				n.set_process(false)
	if frames == 100:
		e = _pick()
		spot = e["xf"].origin
		GameSettings.set_value("time", "day")
		game.player.global_position = spot + Vector3(1.0, 0, 3.0)
		print("boom ", e["vn"], " op ", spot)
		_clear_around()
		for c in main.find_children("*", "CanvasLayer", true, false):
			c.visible = false
	var k := frames - T0
	if SHOTS.has(k) or (k == 0 and SHOTS.has(-1)):
		pass
	if frames == T0 - 1 or (k > 0 and SHOTS.has(k)):
		root.get_viewport().get_texture().get_image().save_png(out + "/%s_%03d.png" % [e["vn"], maxi(k, 0)])
	if frames == T0:
		game.note_blast(spot + Vector3(4.0, 0, 0), 8.0)   # ontploffing rechts van de boom: hij valt naar links
	return frames > T0 + 335
