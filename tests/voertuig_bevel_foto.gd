extends SceneTree
## Schermafbeeldingen van het voertuigbevel (11 nov 2026): jeep en tank in de bevelstand (ring, naam en levensbalk, knop VOERTUIGEN), het bevel, de grote kaart en het rijden zelf.
## FOTO_DIR=/pad FOTO_TAG=liggend BJ_TOUCH=1 VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 932x430x24" godot --rendering-driver vulkan --path . -s tests/voertuig_bevel_foto.gd --resolution 932x430 --fixed-fps 60

var main: Node
var frames := 0
var game: Node
var dir := OS.get_environment("FOTO_DIR") if OS.get_environment("FOTO_DIR") != "" else "/tmp"
var tag := OS.get_environment("FOTO_TAG") if OS.get_environment("FOTO_TAG") != "" else "liggend"
var allies: Array = []
var jeep: Node
var tank: Node
var jeep2: Node


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	physics_frame.connect(func(): if frames > 3 and game != null: game.move = Vector2.ZERO)


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("%s/voertuigbevel_%s_%s.png" % [dir, name, tag])
	print("foto ", name)


func _place() -> void:
	var p: Vector3 = game.player.global_position
	jeep.global_position = p + Vector3(-8.0, 0.0, -8.0)
	jeep.rotation.y = 0.0
	tank.global_position = p + Vector3(8.0, 0.0, -10.0)
	tank.rotation.y = 0.0
	jeep2.global_position = p + Vector3(-14.0, 0.0, -2.0)
	jeep2.rotation.y = 0.0
	for i in allies.size():
		allies[i].global_position = p + Vector3(-4.0 + float(i % 3) * 2.2, 0.0, 3.0 + float(i / 3) * 2.4)
		if not game.allies.has(allies[i]):
			game.allies.append(allies[i])


func _process(_d: float) -> bool:
	frames += 1
	game = root.get_node("Game")
	var hud := get_first_node_in_group("hud_extra")
	var ts = get_first_node_in_group("troep_selectie")
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
	if frames == 8:
		var ally_script: GDScript = load("res://scripts/ally.gd")
		var kinds := ["geweer", "geweer", "raket", "sluip"]
		for i in kinds.size():
			var a = ally_script.new()
			a.kind = kinds[i]
			game.player.get_parent().add_child(a)
			a.setup(100.0, 16.0, i)
			allies.append(a)
		jeep = load("res://scenes/jeep.tscn").instantiate()
		main.add_child(jeep)
		jeep2 = load("res://scenes/jeep.tscn").instantiate()
		main.add_child(jeep2)
		tank = load("res://scenes/tank.tscn").instantiate()
		main.add_child(tank)
	if frames == 12 or frames == 130 or frames == 240:
		_place()
	if frames == 140:
		hud.open_map(false)
	if frames == 165:
		_shot("kaart_overzicht")
		ts.select_vehicles()
		hud._map.queue_redraw()
	if frames == 180:
		_shot("kaart_voertuigen_gekozen")
		ts.issue("move", game.player.global_position + Vector3(-30.0, 0.0, -50.0))
	if frames == 190:
		_shot("kaart_bevel")
		jeep.get_node("Bestuurder").vast = true   # het gele teken
	if frames == 195:
		_shot("kaart_vast")
		jeep.get_node("Bestuurder").vast = false
		hud._map.close_map()
		ts.clear()
		for n in [jeep, jeep2, tank]:
			n.get_node("Bestuurder").set_command("hold", Vector3.ZERO)
		_place()
		get_first_node_in_group("bevel_stand").open_stand()
	if frames == 260:
		_place()
		_shot("stand_open")
		ts.select([jeep.get_node("Bestuurder")])
	if frames == 266:
		_shot("stand_jeep_gekozen")
		ts.select_vehicles()
	if frames == 272:
		_shot("stand_voertuigen_gekozen")
		ts.select_all()
	if frames == 278:
		_shot("stand_alles_gekozen")
		ts.select_vehicles()
		ts.issue("move", game.player.global_position + Vector3(0.0, 0.0, -30.0))
	if frames == 284:
		_shot("stand_bevel")
		get_first_node_in_group("bevel_stand").close_stand()
	if frames == 330:
		_shot("rijden_1")
	if frames == 420:
		_shot("rijden_2")
	if frames == 540:
		_shot("rijden_3")
	return frames > 545
