extends SceneTree
## Opnames van de dam en het stuwmeer (dambreuk stap 2): vaste camera's, zelfde licht, vaste wereld-seed, zonder HUD.
## DAM_OUT = uitvoermap. Draai op main (voor) en op de branch (na):
## BJ_TOUCH=1 xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver vulkan --path . -s tools/dam_foto.gd --resolution 1280x720 --fixed-fps 60
var main: Node
var game: Node
var lvl: Node3D
var out := "/tmp/dam"
var frames := 0
var cam: Camera3D
# [frame, naam, positie, kijkpunt, zichtafstand]
var shots := [
	[200, "1_dam_van_voren", Vector3(-30, 14, -280), Vector3(-37, 9, -336), 300.0],
	[240, "2_dam_tactisch", Vector3(-37, 60, -255), Vector3(-37, 6, -336), 400.0],
	[280, "3_dam_ooghoogte", Vector3(-20, 3.0, -300), Vector3(-37, 9, -336), 200.0],
	[320, "4_stuwmeer_boven", Vector3(-37, 55, -300), Vector3(-45, 12, -440), 700.0],
	[360, "5_dam_van_het_meer", Vector3(-30, 24, -400), Vector3(-37, 10, -336), 500.0],
	[400, "6_kloof_uit_het_zuiden", Vector3(-37, 20, -150), Vector3(-37, 10, -336), 500.0],
	[440, "7_meer_overzicht", Vector3(-48, 130, -330), Vector3(-48, 5, -470), 900.0],
	[480, "8_dam_dichtbij", Vector3(-10, 9, -318), Vector3(-37, 10, -336), 120.0],
	[520, "9_landhoofd_west", Vector3(-100, 30, -300), Vector3(-67, 10, -336), 200.0],
	[560, "10_landhoofd_oost", Vector3(40, 30, -300), Vector3(-8, 10, -336), 200.0],
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
		cam.fov = 55
		root.add_child(cam)
	if frames > 20:
		for n in root.find_children("*", "CanvasLayer", true, false):
			(n as CanvasLayer).visible = false
		cam.make_current()
	for s in shots:
		if frames == (s[0] as int) - 30:
			cam.far = s[4]
			cam.global_position = s[2]
			cam.look_at(s[3])
		if frames == s[0]:
			root.get_viewport().get_texture().get_image().save_png(out + "/" + s[1] + ".png")
			print("opname ", s[1])
	return frames > (shots[-1][0] as int) + 3
