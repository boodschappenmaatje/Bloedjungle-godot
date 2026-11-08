extends SceneTree
## Schermafbeeldingen van de MCV-bouwwagen: rijden, wegrijden na het uitklappen, de clip Uitklappen en het hoofdkwartier in aanbouw.
## FOTO_DIR=/pad BJ_TOUCH=1 VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 932x430x24" godot --rendering-driver vulkan --path . -s tests/mcv_wagen_foto.gd --fixed-fps 60

var main: Node
var frames := 0
var game: Node
var mcv: Node
var dir := OS.get_environment("FOTO_DIR") if OS.get_environment("FOTO_DIR") != "" else "/tmp"
var t0 := 0
var cam: Camera3D


func _initialize() -> void:
	load("res://scripts/data.gd").set("mcv_mode", true)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	physics_frame.connect(func(): if frames > 3 and game != null: game.move = Vector2.ZERO)


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("%s/mcv_%s.png" % [dir, name])
	print("foto ", name)


func _process(_d: float) -> bool:
	frames += 1
	game = root.get_node("Game")
	if frames == 4:
		main.begin()
		for n in root.find_children("*", "", true, false):
			if n.get_script() and String(n.get_script().resource_path).ends_with("touch_sticks.gd"):
				n.set_process(false)
		for m in get_nodes_in_group("menus"):
			m._show("")
		GameSettings.set_value("time", "day")
	if frames > 3 and game.state == "prep" and game.mcv_deployed:
		game.prep_t = 1e9
	if mcv == null and frames > 14 and not get_nodes_in_group("mcv").is_empty():
		mcv = get_nodes_in_group("mcv")[0]
		mcv.global_position = Vector3(40.0, 0.0, 40.0)
		mcv.rotation.y = 0.0
		t0 = frames
		print("wagen gevonden op beeld ", frames)
	if mcv == null:
		return false
	if cam != null:
		cam.make_current()
	var fr := frames - t0
	if fr == 60:
		_shot("1_wagen")
	if fr == 70:
		mcv.deploy_now()
		game.player.global_position = Vector3(40.0, 0.0, 34.0)
		cam = Camera3D.new()
		main.add_child(cam)
		cam.fov = 42.0
		cam.global_position = Vector3(40.0 + 17.0, 20.0, 35.0 + 15.0)
		cam.look_at(Vector3(40.0, 1.0, 35.5), Vector3.UP)
		cam.make_current()
		for c in main.get_children():
			if c is CanvasLayer:
				c.visible = false
	# wagen rijdt 4 s weg, klaptuit (6 s: poten t=2, panelen 1,8-4,2, mast 3,6, schotel 4,9), dan 20 s bouwen
	var na := fr - 70
	if na == 150:
		_shot("2_wegrijden")
	if na == 60 * 4 + 60 * 5 + 30:
		cam.global_position = Vector3(40.0 + 6.5, 4.2, 30.4 + 6.5)
		cam.look_at(Vector3(40.0, 1.6, 30.4), Vector3.UP)
	if na == 60 * 4 + 60 * 6 + 50:
		_shot("10_wagen_nah")
		quit()
	if na == 60 * 4 + 60 * 2 + 20:
		_shot("3_poten_neer")
	if na == 60 * 4 + 60 * 4 + 20:
		_shot("4_panelen_open")
	if na == 60 * 4 + 60 * 6 + 60 * 3:
		_shot("5_fundering")
	if na == 60 * 4 + 60 * 6 + 60 * 9:
		_shot("6_wanden")
	if na == 60 * 4 + 60 * 6 + 60 * 14:
		_shot("7_dak")
	if na == 60 * 4 + 60 * 6 + 60 * 18:
		_shot("8_afwerking")
	if na == 60 * 4 + 60 * 6 + 60 * 22:
		_shot("9_klaar")
		quit()
	return false
