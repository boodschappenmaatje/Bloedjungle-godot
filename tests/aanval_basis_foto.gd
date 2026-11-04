extends SceneTree
## Schermafbeeldingen van Aanvallen op de vijandbasis (stap 5a-3a): de radar met het rode vlakje (rustig en knipperend tijdens de
## Aanvallen-keuze) en je soldaten die voor het vijandelijke HK staan te schieten.
## FOTO_DIR=/pad BJ_TOUCH=1 VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 932x430x24" godot --rendering-driver vulkan --path . -s tests/aanval_basis_foto.gd --fixed-fps 60

var main: Node
var frames := 0
var game: Node
var hk: Node3D
var dir := OS.get_environment("FOTO_DIR") if OS.get_environment("FOTO_DIR") != "" else "/tmp"
var allies: Array = []


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	physics_frame.connect(func(): if frames > 3 and game != null: game.move = Vector2.ZERO)


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("%s/aanval_%s.png" % [dir, name])
	print("foto ", name)


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
	if frames > 3 and game.state == "prep":
		game.prep_t = 1e9
	if frames == 60:
		_shot("radar_rustig")
		get_first_node_in_group("team_commands").controller.pending_order = "attack"
	if frames == 75:
		_shot("radar_aanvallen")
		get_first_node_in_group("team_commands").cancel_input()
		hk = get_first_node_in_group("vijand_hk")
		game.player.global_position = hk.global_position + Vector3(0, 0, 18.0)
		game.player.face = PI
	# de soldaten vroeg maken (het model laden crasht in de software-Vulkan van de testomgeving als dat midden in het spel gebeurt)
	# en later naar het HK zetten
	if frames == 5:
		var ally_script: GDScript = load("res://scripts/ally.gd")
		for i in 6:
			var a = ally_script.new()
			game.player.get_parent().add_child(a)
			a.global_position = Vector3(30 + i, 0, 30)
			a.setup(100.0, 16.0, i)
			game.allies.append(a)
			allies.append(a)
	if frames == 90:
		var vb: GDScript = load("res://scripts/vijand_basis.gd")
		for i in allies.size():
			allies[i].global_position = vb.attack_spot(i)
			allies[i].face = PI
			allies[i].set_command("basis", vb.gate_outside())
	if frames == 330:
		_shot("soldaten_voor_hk")
		print("HK levenspunten: %.0f van %.0f" % [hk.hp, hk.HP])
		print("speler: ", game.player.global_position)
		for a in allies:
			print("soldaat ", a.idx, " ", a.global_position, " zichtbaar ", a.model.visible, " ver ", a._far, " bevel ", a.command, " in boom ", a.is_inside_tree())
	return frames > 332
