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
		cam.global_position = Vector3(40.0 + 15.0, 15.0, 35.3 + 15.0)
		cam.look_at(Vector3(40.0, 1.5, 35.3), Vector3.UP)
		cam.make_current()
		for c in main.get_children():
			if c is CanvasLayer:
				c.visible = false
	# na deploy_now: 1,3 s container omhoog, ~4,3 s wegrijden (container zakt vanaf 45 %), clip 6 s, dan 35 s bouwen, dan 4 s container weg
	var na := fr - 70
	var sec := float(na) / 60.0
	var BEGIN := 1.3 + 4.3 + 6.0 + 0.3    # s tot de bouw begint
	var lijst := [
		[0.9, "01_tillen"], [3.0, "02_wegrijden"], [5.2, "03_zakken"], [6.6, "04_staat"], [8.5, "05_poten_neer"], [10.8, "06_panelen"],
		[BEGIN + 1.0, "07_kraan_op"], [BEGIN + 4.5, "08_voorplein"], [BEGIN + 7.5, "09_pakken"], [BEGIN + 10.0, "10_zwenken"], [BEGIN + 11.2, "11_plaatsen"],
		[BEGIN + 18.0, "12_laag4"], [BEGIN + 26.0, "13_laag7"], [BEGIN + 33.0, "14_afwerking"], [BEGIN + 37.5, "15_klaar"], [BEGIN + 40.5, "16_container_zakt"], [BEGIN + 44.0, "17_weg"],
	]
	if cam != null and sec > 4.0 and cam.global_position.y > 10.0 and sec < BEGIN - 1.0:
		pass
	for e in lijst:
		if na == int(float(e[0]) * 60.0):
			_shot(String(e[1]))
	if na == int((BEGIN + 44.5) * 60.0):
		quit()
	return false
