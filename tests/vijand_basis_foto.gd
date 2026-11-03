extends SceneTree
## Schermafbeeldingen van de vijandelijke basis van blokken (stap 5a-1): overzicht schuin, recht van boven, en de gamecamera bij de poort.
## FOTO_DIR=/pad xvfb-run -a -s "-screen 0 932x430x24" godot --rendering-driver vulkan --path . -s tests/vijand_basis_foto.gd --fixed-fps 60

var main: Node
var frames := 0
var game: Node
var cam: Camera3D
var dir := OS.get_environment("FOTO_DIR") if OS.get_environment("FOTO_DIR") != "" else "/tmp"


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	physics_frame.connect(func(): if frames > 3 and game != null: game.move = Vector2.ZERO)


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("%s/vijandbasis_%s.png" % [dir, name])
	print("foto ", name)


func _process(_d: float) -> bool:
	frames += 1
	game = root.get_node("Game")
	var p: Vector3 = load("res://scripts/data.gd").VIJAND_POS
	if frames == 2:
		# de patrouille laadt soldaatmodellen via load() midden in het spel; dat crasht in de software-Vulkan van de sandbox (niet in het spel zelf)
		for n in main.get_children():
			if n.get_script() and String(n.get_script().resource_path).ends_with("patrouille.gd"):
				n.queue_free()
	if frames == 3:
		main.begin()
		for n in root.find_children("*", "", true, false):
			if n.get_script() and String(n.get_script().resource_path).ends_with("touch_sticks.gd"):
				n.set_process(false)
		for m in get_nodes_in_group("menus"):
			m._show("")
	if frames > 3 and game.state == "prep":
		game.prep_t = 1e9
	if frames == 100:
		# gamecamera: de speler bij de poort van de vijand
		game.player.global_position = p + Vector3(0, 0, 36.0)
		game.player.face = PI
	if frames == 220:
		_shot("poort_gamecam")
		cam = Camera3D.new()
		cam.far = 600.0
		root.add_child(cam)
		cam.global_position = p + Vector3(-12.0, 62.0, 70.0)
		cam.look_at(p + Vector3(0, 0, -4.0))
		cam.make_current()
	if frames == 300:
		_shot("overzicht_schuin")
		cam.global_position = p + Vector3(0, 95.0, 0.5)
		cam.look_at(p)
	if frames == 380:
		_shot("recht_van_boven")
		cam.global_position = p + Vector3(0, 30.0, 16.0)
		cam.look_at(p + Vector3(0, 0, -13.0))
	if frames == 460:
		_shot("hoofdkwartier")
		return true
	return false
