extends SceneTree
## Schermafbeeldingen van de vijandaanval ZOALS HIJ NU IS (voor de keuzekaart "slimme vijandaanval", 12 nov 2026):
## de grote kaart met de vaste routes van de volgende groep, een groep die in een rij over de brug komt, en de groep die recht op het HK afloopt.
## FOTO_DIR=/pad VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 932x430x24" godot --rendering-driver vulkan --path . -s tests/aanval_ai_nu_foto.gd --resolution 932x430 --fixed-fps 60

var main: Node
var frames := 0
var game: Node
var dir := OS.get_environment("FOTO_DIR") if OS.get_environment("FOTO_DIR") != "" else "/tmp"
var foes: Array = []
const N := 9


func _initialize() -> void:
	load("res://scripts/data.gd").set("mcv_autodeploy", true)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	physics_frame.connect(func(): if frames > 3 and game != null: game.move = Vector2.ZERO)


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("%s/nu_%s.png" % [dir, name])
	print("foto ", name)


func _zet(i: int, at: Vector3, path: Array, aan: bool) -> void:
	var e = foes[i]
	e.global_position = at
	e.path = path
	e.path_i = 0
	e.set_physics_process(aan)
	e.visible = true


func _process(_d: float) -> bool:
	frames += 1
	game = root.get_node("Game")
	var p = game.player
	if frames == 3:
		main.begin()
		for n in root.find_children("*", "", true, false):
			if n.get_script() and String(n.get_script().resource_path).ends_with("touch_sticks.gd"):
				n.set_process(false)
		for m in get_nodes_in_group("menus"):
			m._show("")
		GameSettings.set_value("time", "day")
	if frames > 3 and game.state == "prep":
		game.prep_t = 540.0
	if p != null and frames > 10:
		p.hp = 1000.0
	for o in get_nodes_in_group("mcv_opbouw"):
		o.remove_from_group("mcv_opbouw")
	# vijanden vroeg maken (modellen laden midden in het spel crasht soms in software-Vulkan) en stil wegzetten
	if frames == 6:
		var kinds := ["assault", "knife", "assault", "heavy", "knife", "assault", "rocket", "knife", "assault"]
		for i in N:
			main._spawn({"kind": kinds[i], "n": 4, "routes": ["brug"]})
		for e in game.enemies:
			if not e.is_in_group("vijand_voertuig"):
				foes.append(e)
		for i in foes.size():
			_zet(i, Vector3(60 + i * 2.0, 0, -200), [], false)
		print("vijanden klaar: ", foes.size())
	# 1: de grote kaart met de routes die de volgende groep loopt
	if frames == 40:
		game.routes = ["brug", "wijk"]
		var hud := get_first_node_in_group("hud_extra")
		if hud != null:
			hud.open_map(false)
	if frames == 90:
		_shot("kaart_routes")
		var hud := get_first_node_in_group("hud_extra")
		if hud != null and hud._map != null:
			hud._map.close_map()
	# 2: de groep komt in een rij uit de Hoofdstraat over de brug
	if frames == 100:
		for i in foes.size():
			var r: Array = AanvalRoutes.path_for("brug")
			_zet(i, Vector3(randf_range(-1.5, 1.5), 0, -97.0 - i * 2.0), [r[r.size() - 1]], true)
		p.global_position = Vector3(3, 0, -80)
		p.face = PI
	if frames > 100 and frames < 260:
		p.global_position = Vector3(3, 0, -80)
	if frames == 170:
		_shot("groep_brug")
	# 3: ze lopen recht op het hoofdkwartier af en slaan op wat in de weg staat
	if frames == 270:
		for i in foes.size():
			_zet(i, Vector3(randf_range(-3, 3), 0, -30.0 - i * 1.6), [], true)
		p.global_position = Vector3(9, 0, -16)
		p.face = PI
	if frames > 270 and frames < 520:
		p.global_position = Vector3(9, 0, -16)
	if frames == 400:
		var levend := 0
		for e in foes:
			if is_instance_valid(e) and not e.dead:
				levend += 1
		print("levend: ", levend)
		_shot("recht_op_hk")
	return frames > 405
