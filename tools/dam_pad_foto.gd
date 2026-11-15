extends SceneTree
## Opnames van de weg naar de dam (dambreuk stap 3a): pad, kloof, helling, kroon, geplakte C4, kraken en breken.
## DAM_OUT = uitvoermap. BJ_TOUCH=1 xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver vulkan --path . -s tools/dam_pad_foto.gd --resolution 1280x720 --fixed-fps 60
var main: Node
var game: Node
var lvl: Node3D
var out := "/tmp/dampad"
var frames := 0
var cam: Camera3D
var dam: Node
# [frame, naam, positie, kijkpunt, zichtafstand]
var shots := [
	[120, "1_pad_west", Vector3(-176, 7, -204), Vector3(-120, 1, -276), 300.0],
	[170, "2_pad_noordrand", Vector3(-112, 8, -278), Vector3(-60, 1, -296), 300.0],
	[220, "3_kloofingang", Vector3(-62, 9, -288), Vector3(-37, 3, -322), 250.0],
	[270, "4_wachters", Vector3(-48, 8, -280), Vector3(-37, 2, -314), 200.0],
	[320, "5_helling", Vector3(-8, 14, -296), Vector3(-6, 8, -326), 200.0],
	[370, "6_kroon", Vector3(-12, 24, -334), Vector3(-45, 17, -336), 200.0],
	[420, "7_c4_op_deur", Vector3(-30, 25, -326), Vector3(-37, 15, -337), 80.0],
	[470, "8_kraken", Vector3(-37, 30, -300), Vector3(-37, 12, -336), 300.0],
	[540, "9_breken", Vector3(-37, 30, -300), Vector3(-37, 10, -336), 300.0],
]

func _initialize() -> void:
	if OS.get_environment("DAM_OUT") != "":
		out = OS.get_environment("DAM_OUT")
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

func _process(_d: float) -> bool:
	frames += 1
	if frames == 3:
		Data.mcv_autodeploy = true
		main.begin()
		game = root.get_node("Game")
		lvl = main.get_node("Level")
		for m in get_nodes_in_group("menus"):
			m._show("")
		for n in root.find_children("*", "", true, false):
			if n.get_script() and String(n.get_script().resource_path).ends_with("touch_sticks.gd"):
				n.set_process(false)
	if frames == 20:
		Data.world_seed = Data.WORLD_SEED_DEFAULT
		Data._randomize_river()
		lvl.build_now()
		cam = Camera3D.new()
		cam.fov = 60
		root.add_child(cam)
	if frames > 20:
		for n in root.find_children("*", "CanvasLayer", true, false):
			(n as CanvasLayer).visible = false
		cam.make_current()
	if frames == 100:
		dam = (load("res://scripts/dam.gd") as GDScript).current
	if frames == 380 and dam != null:
		dam.plant_c4(1)
		dam.plant_c4(2)
	if frames == 440 and dam != null:
		dam.gate_hp[0] = 0.0
		dam._gate_down(0)
		dam._gate_down(1)
	for s in shots:
		if frames == (s[0] as int) - 30:
			cam.far = s[4]
			cam.global_position = s[2]
			cam.look_at(s[3])
		if frames == s[0]:
			root.get_viewport().get_texture().get_image().save_png(out + "/" + s[1] + ".png")
			print("opname ", s[1])
	return frames > (shots[-1][0] as int) + 3
