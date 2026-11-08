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
		cam.global_position = Vector3(40.0 + 17.0, 21.0, 40.0 + 11.0)
		cam.look_at(Vector3(40.0, 1.2, 35.0), Vector3.UP)
		cam.make_current()
		for c in main.get_children():
			if c is CanvasLayer:
				c.visible = false
	if fr == 70 + 90:
		_shot("2_wegrijden")
	if fr == 70 + 330:
		_shot("3_uitklappen_midden")
	if fr == 70 + 480:
		_shot("4_uitgeklapt")
	if fr == 70 + 481:
		main.find_child("Opbouw", true, false)._t = 3.5 + 11.0   # spoel door: het gebouw staat halverwege
	if fr == 70 + 520:
		_shot("5_gebouw_half")
		main.find_child("Opbouw", true, false).maak_klaar()
	if fr == 70 + 560:
		_shot("6_gebouw_klaar")
		quit()
	return false
