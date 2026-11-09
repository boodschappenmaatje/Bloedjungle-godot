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
	if fr == 61:
		cam = Camera3D.new()
		main.add_child(cam)
		cam.fov = 40.0
		cam.global_position = Vector3(40.0 + 7.5, 4.8, 40.0 - 4.5)
		cam.look_at(Vector3(40.0, 2.4, 40.0 - 1.4), Vector3.UP)
		cam.make_current()
	if fr == 64:
		_shot("0_transport")
	if fr == 70:
		if cam != null:
			cam.queue_free()
		mcv.deploy_now()
		game.player.global_position = Vector3(40.0, 0.0, 34.0)
		cam = Camera3D.new()
		main.add_child(cam)
		cam.fov = 42.0
		cam.global_position = Vector3(44.0 + 16.0, 17.0, 38.0 + 16.0)
		cam.look_at(Vector3(44.0, 1.0, 36.0), Vector3.UP)
		cam.make_current()
		for c in main.get_children():
			if c is CanvasLayer:
				c.visible = false
	# na deploy_now: 1,3 s container omhoog, ~4,3 s wegrijden (container zakt vanaf 45 %), clip 6 s, dan 35 s bouwen, dan 4 s container weg
	var na := fr - 70
	var sec := float(na) / 60.0
	var BEGIN := 1.8 + 14.9 + 6.0 + 0.4    # s tot de bouw begint
	var lijst := [
		[1.0, "01_kantelen"], [2.4, "02_glijden"], [3.2, "03_glijden2"], [4.0, "04_achterrand"], [4.8, "05_voorkant_neer"], [8.5, "06_bocht"], [13.0, "07_keren"], [17.5, "07b_achteruit"], [BEGIN - 1.0, "07c_geparkeerd"],
		[BEGIN + 0.9, "08_stempels"], [BEGIN + 2.4, "08b_banden_af"], [BEGIN + 4.0, "08c_giek_op"], [BEGIN + 6.4, "09_pakken"], [BEGIN + 7.2, "10_hijsen"], [BEGIN + 8.4, "11_zwenken"], [BEGIN + 9.4, "12_boven_hk"], [BEGIN + 10.5, "13_geplaatst"],
		[BEGIN + 16.5, "14_laag3"], [BEGIN + 23.5, "15_laag6"], [BEGIN + 33.0, "16_afwerking"], [BEGIN + 38.0, "17_klaar"], [BEGIN + 40.5, "18_container_zakt"], [BEGIN + 43.5, "19_kraan_terug"], [BEGIN + 47.0, "20_vertrek"], [BEGIN + 51.0, "21_uit_beeld"],
	]
	if na == int((BEGIN - 0.5) * 60.0):
		cam.global_position = Vector3(44.0 + 12.0, 13.0, 39.0 + 12.0)
		cam.look_at(Vector3(44.0, 2.5, 39.0), Vector3.UP)
	for e in lijst:
		if na == int(float(e[0]) * 60.0):
			_shot(String(e[1]))
	if na == int((BEGIN + 56.0) * 60.0):
		quit()
	return false
