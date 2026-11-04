extends SceneTree
## Schermafbeeldingen van het vijandelijke hoofdkwartier (stap 5a-2): heel (gamecamera en schuin), beschadigd met rook en vuur, en gesloopt.
## FOTO_DIR=/pad xvfb-run -a -s "-screen 0 932x430x24" godot --rendering-driver vulkan --path . -s tests/vijand_hk_foto.gd --fixed-fps 60

var main: Node
var frames := 0
var game: Node
var cam: Camera3D
var hk: Node3D
var dir := OS.get_environment("FOTO_DIR") if OS.get_environment("FOTO_DIR") != "" else "/tmp"


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	physics_frame.connect(func(): if frames > 3 and game != null: game.move = Vector2.ZERO)


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("%s/vijandhk_%s.png" % [dir, name])
	print("foto ", name)


func _look(from: Vector3, to: Vector3) -> void:
	cam.global_position = from
	cam.look_at(to)


func _process(_d: float) -> bool:
	frames += 1
	game = root.get_node("Game")
	if frames == 2:
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
		hk = get_first_node_in_group("vijand_hk")
		var p: Vector3 = hk.global_position
		# gamecamera: de speler vlak voor het hoofdkwartier
		game.player.global_position = p + Vector3(0, 0, 13.0)
		game.player.face = PI
	if frames == 220:
		_shot("gamecam_voor")
		cam = Camera3D.new()
		cam.far = 600.0
		root.add_child(cam)
		cam.make_current()
		_look(hk.global_position + Vector3(-5.0, 6.0, 17.0), hk.global_position + Vector3(0, 3.0, 0))
	if frames == 300:
		_shot("heel_voor")
		_look(hk.global_position + Vector3(16.0, 11.0, 14.0), hk.global_position + Vector3(0, 2.5, 0))
	if frames == 380:
		_shot("heel_schuin")
		# 55% levenspunten: rook; daarna 25%: vuur
		hk.hp = hk.HP * 0.62
		hk.damage(hk.HP * 0.05, "explosive")
	if frames == 500:
		_shot("beschadigd_rook")
		hk.damage(hk.HP * 0.30, "explosive")
	if frames == 620:
		_shot("beschadigd_vuur")
		hk.damage(hk.HP, "explosive")
	if frames == 650:
		_shot("instorting")
	if frames == 760:
		_look(hk.global_position + Vector3(16.0, 9.0, 14.0), hk.global_position + Vector3(0, 0.5, 0))
	if frames == 800:
		_shot("wrak")
		return true
	return false
