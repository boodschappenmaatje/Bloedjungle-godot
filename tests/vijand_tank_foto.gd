extends SceneTree
## Schermafbeeldingen van de vijandelijke tank in de gamecamera (Generals-plan stap V2): hij rijdt op de speler af, staat stil en schiet een granaat op een soldaat, rookt bij
## halve levenspunten, brandt bij een kwart en ligt daarna als zwart wrak; plus de radar met de rode ruit en de tank naast een jeep (maatvergelijking).
## FOTO_DIR=/pad BJ_TOUCH=1 VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 932x430x24" godot --rendering-driver vulkan --path . -s tests/vijand_tank_foto.gd --fixed-fps 60

var main: Node
var frames := 0
var game: Node
var dir := OS.get_environment("FOTO_DIR") if OS.get_environment("FOTO_DIR") != "" else "/tmp"
var jeeps: Array = []   # de tanks (naam uit de jeepfoto behouden)
var jeep: Node
var ally: Node


func _initialize() -> void:
	load("res://scripts/data.gd").set("mcv_autodeploy", true)   # niet in de bouwwagen beginnen: het hoofdkwartier staat meteen
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	physics_frame.connect(func(): if frames > 3 and game != null: game.move = Vector2.ZERO)


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("%s/vijand_tank_%s.png" % [dir, name])
	print("foto ", name)


## De spel-reset na het laden van de wereld leegt Game.enemies: de tank zet zich er hier weer in (zoals main.gd hem uitrukt).
func _list(j: Node) -> void:
	if not game.enemies.has(j):
		game.enemies.append(j)


func _park(j: Node, pos: Vector3, rot: float) -> void:
	j.global_position = pos
	j.rotation.y = rot
	j.set_physics_process(true)


func jep_park() -> void:
	jeep.global_position = Vector3(3.2, 0, -46)
	jeep.rotation.y = PI
	jeep.set_physics_process(false)
	game.player.global_position = Vector3(0, 0, -38)


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
		GameSettings.set_value("time", "day")
	if frames >= 4 and frames < 400:
		# de bouwwagen en de opbouw van het hoofdkwartier houden de camera 26 s lang bij het hoofdkwartier: weg ermee, de camera volgt dan de speler
		for n in get_nodes_in_group("mcv_opbouw"):
			n.queue_free()
		for n in get_nodes_in_group("mcv"):
			n.queue_free()
		var cam := root.get_viewport().get_camera_3d()
		if cam != null:
			cam.set("_opbouw_weight", 0.0)
	if frames > 3 and game.state == "prep":
		game.prep_t = 1e9
	# de modellen vroeg laden (software-Vulkan houdt niet van modellen laden midden in het spel) en vastzetten
	if frames == 5:
		var cls: GDScript = load("res://scripts/vijand_tank.gd")
		for i in 3:
			var j = cls.new()
			j.route = []
			j.position = Vector3(200 + 10 * i, 0, 200)
			main.add_child(j)
			j.set_physics_process(false)
			jeeps.append(j)
		jeep = (load("res://scripts/vijand_jeep.gd") as GDScript).new()
		jeep.route = []
		jeep.position = Vector3(240, 0, 200)
		main.add_child(jeep)
		jeep.set_physics_process(false)
		var ally_script: GDScript = load("res://scripts/ally.gd")
		ally = ally_script.new()
		game.player.get_parent().add_child(ally)
		ally.global_position = Vector3(300, 0, 300)
		ally.setup(100.0, 16.0, 0)
		game.allies.append(ally)
	if frames == 30:
		game.player.global_position = Vector3(0, 0, -30)
		game.player.face = PI
		ally.global_position = Vector3(5, 0, -26)
		_park(jeeps[0], Vector3(-3, 0, -72), PI)
		_list(jeeps[0])
	if frames > 30 and frames < 330 and is_instance_valid(jeeps[0]):
		# de camera kijkt een stuk richting de jeep, zodat hij midden in beeld staat en niet achter de melding verdwijnt
		var cam2 := root.get_viewport().get_camera_3d()
		var d: Vector3 = jeeps[0].global_position - game.player.global_position
		cam2.set("_lead", Vector3(d.x, 0.0, d.z) * 0.6)
	if frames == 150:
		_shot("1_rijdt_aan")
	if frames == 215:
		_shot("2_schiet")
	if frames == 205:
		# tweede jeep: rookt bij halve levenspunten
		jeeps[0].hp = jeeps[0].max_hp * 0.4
		jeeps[0]._take(1.0, Vector3.ZERO)
	if frames == 240:
		_shot("3_rookt")
		jeeps[0].hp = jeeps[0].max_hp * 0.2
		jeeps[0]._take(1.0, Vector3.ZERO)
	if frames == 280:
		_shot("4_brandt")
		game.hit_class = "raket"
		jeeps[0].hit(900.0, Vector3(0, 0, 1), true)
		game.hit_class = ""
	if frames == 330:
		_shot("5_wrak")
		# de radar met een tweede jeep op de kaart
		_park(jeeps[1], Vector3(-14, 0, -62), PI)
		_list(jeeps[1])
		game.player.global_position = Vector3(0, 0, -30)
	if frames == 400:
		_shot("6_radar_ruit")
		# de radar uitvergroot (de rode ruit is een voertuig, de ronde stippen zijn soldaten)
		var img := root.get_viewport().get_texture().get_image().get_region(Rect2i(800, 20, 120, 130))
		img.resize(480, 520, Image.INTERPOLATE_NEAREST)
		img.save_png("%s/vijand_tank_6b_radar_uitvergroot.png" % dir)
		# maatvergelijking: de tank naast de jeep, beide stil
		jeeps[1].set_physics_process(false)
		jeeps[1].global_position = Vector3(300, 0, 300)
		jeeps[2].global_position = Vector3(-3.5, 0, -46)
		jeeps[2].rotation.y = PI
		jeeps[2].set_physics_process(false)
		jep_park()
	if frames == 440:
		_shot("7_naast_de_jeep")
	return frames > 442
