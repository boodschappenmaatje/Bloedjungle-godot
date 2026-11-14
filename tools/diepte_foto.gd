extends SceneTree
## Voor/na-opnames voor de dambreuk-stap 1 (diepte): vier vaste camera's, zelfde licht, vaste wereld-seed, zonder HUD.
## DIEPTE_OUT = uitvoermap. Draai op main (voor) en op de branch (na):
## BJ_TOUCH=1 xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver vulkan --path . -s tools/diepte_foto.gd --resolution 1280x720 --fixed-fps 60
var main: Node
var game: Node
var lvl: Node3D
var out := "/tmp/diepte"
var frames := 0
var cam: Camera3D
# [frame, naam, positie, kijkpunt, zichtafstand]
var shots := [
	[200, "1_overzicht_rivier_stad", Vector3(-75, 38, -30), Vector3(5, 0, -112), 220.0],
	[240, "2_noord_kloof", Vector3(-36, 70, -140), Vector3(-36, 8, -380), 400.0],
	[280, "3_ooghoogte_thirdperson", Vector3(-30, 2.2, -78), Vector3(10, 4.0, -160), 60.0],
	[320, "4_oostrand_rivier", Vector3(150, 45, -40), Vector3(270, 0, -92), 220.0],
	[360, "5_vlucht_hoog", Vector3(0, 140, 160), Vector3(0, 0, -120), 600.0],
]

func _initialize() -> void:
	if OS.get_environment("DIEPTE_OUT") != "":
		out = OS.get_environment("DIEPTE_OUT")
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
