extends SceneTree
## Schermafbeeldingen van troepenbevel (11 nov 2026): radar, grote kaart met keuze en bevel, en de bevelstand in het spel.
## FOTO_DIR=/pad FOTO_TAG=liggend BJ_TOUCH=1 VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 932x430x24" godot --rendering-driver vulkan --path . -s tests/troepenbevel_foto.gd --resolution 932x430 --fixed-fps 60
## OUD=1: alleen de radar en de kaart zoals ze op main zijn (zelfde camera en licht), voor de voor/na-vergelijking.

var main: Node
var frames := 0
var game: Node
var dir := OS.get_environment("FOTO_DIR") if OS.get_environment("FOTO_DIR") != "" else "/tmp"
var tag := OS.get_environment("FOTO_TAG") if OS.get_environment("FOTO_TAG") != "" else "liggend"
var oud := OS.get_environment("OUD") == "1"
var allies: Array = []


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	physics_frame.connect(func(): if frames > 3 and game != null: game.move = Vector2.ZERO)


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("%s/bevel_%s_%s.png" % [dir, name, tag])
	print("foto ", name)


func _process(_d: float) -> bool:
	frames += 1
	game = root.get_node("Game")
	var hud := get_first_node_in_group("hud_extra")
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
		var kinds := ["geweer", "geweer", "geweer", "raket", "raket", "sluip", "hospik", "geweer"]
		for i in kinds.size():
			var a = ally_script.new()
			a.kind = kinds[i]
			game.player.get_parent().add_child(a)
			a.setup(100.0, 16.0, i)
			allies.append(a)
	if frames == 12:
		for i in allies.size():
			allies[i].global_position = game.player.global_position + Vector3(-6.0 + float(i % 4) * 2.2, 0.0, 4.0 + float(i / 4) * 2.4)
			if not game.allies.has(allies[i]):
				game.allies.append(allies[i])
	# de luchtfoto heeft ruim 20 beelden nodig
	if frames == 130 or frames == 250:
		for i in allies.size():
			allies[i].global_position = game.player.global_position + Vector3(-6.0 + float(i % 4) * 2.2, 0.0, 4.0 + float(i / 4) * 2.4)
			if not game.allies.has(allies[i]):
				game.allies.append(allies[i])   # begin() en de bouwwagen wissen de lijst nog een keer
	if frames == 140:
		_shot("radar")
		hud.open_map(false)
	if frames == 160:
		_shot("kaart_overzicht")
		if oud:
			return true
		var ts = get_first_node_in_group("troep_selectie")
		ts.select(allies.slice(0, 4))
		hud._map.queue_redraw()
	if frames == 175:
		_shot("kaart_gekozen")
		var ts = get_first_node_in_group("troep_selectie")
		ts.issue("move", game.player.global_position + Vector3(-30.0, 0.0, -40.0))
	if frames == 185:
		_shot("kaart_bevel")
		hud._map._zoom_to(2.6, hud._map.to_screen(game.player.global_position), hud._map.map_rect())
	if frames == 200:
		_shot("kaart_zoom")
		hud._map.close_map()
		var ts = get_first_node_in_group("troep_selectie")
		ts.clear()
		for i in allies.size():
			allies[i].global_position = game.player.global_position + Vector3(-6.0 + float(i % 4) * 2.2, 0.0, 4.0 + float(i / 4) * 2.4)
			allies[i].set_command("follow", Vector3.ZERO)
		get_first_node_in_group("bevel_stand").open_stand()
	if frames == 260:
		_shot("stand_open")
		var ts = get_first_node_in_group("troep_selectie")
		ts.select(allies.slice(0, 5))
	if frames == 270:
		_shot("stand_gekozen")
		var ts = get_first_node_in_group("troep_selectie")
		ts.issue("move", game.player.global_position + Vector3(8.0, 0.0, -6.0))
	if frames == 274:
		_shot("stand_bevel")
		get_first_node_in_group("bevel_stand").close_stand()
	if frames == 280:
		_shot("na_bevel_in_spel")
	return frames > 282
