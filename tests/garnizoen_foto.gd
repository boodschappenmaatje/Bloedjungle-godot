extends SceneTree
## Schermafbeeldingen van het garnizoen in de stad (F2, 12 nov 2026): het bezette hotel dat op jou schiet (stippen boven het dak, vuur uit
## de ramen), de grote kaart met de rode en groene randen, en je soldaten in een woonhuis met de knop ERUIT in de bevelstand.
## Op main (zonder garnizoen) maakt hij alleen de foto's met dezelfde camera, voor de voor/na-vergelijking.
## FOTO_DIR=/pad FOTO_TAG=na VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 932x430x24" godot --rendering-driver vulkan --path . -s tests/garnizoen_foto.gd --resolution 932x430 --fixed-fps 60

var main: Node
var frames := 0
var game: Node
var dir := OS.get_environment("FOTO_DIR") if OS.get_environment("FOTO_DIR") != "" else "/tmp"
var tag := OS.get_environment("FOTO_TAG") if OS.get_environment("FOTO_TAG") != "" else "na"
var gz: GDScript
var allies: Array = []
var hotel: Node3D
var wh: Node3D
const O := 100


func _initialize() -> void:
	load("res://scripts/data.gd").set("mcv_autodeploy", true)
	if ResourceLoader.exists("res://scripts/garnizoen.gd"):
		gz = load("res://scripts/garnizoen.gd")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	physics_frame.connect(func(): if frames > 3 and game != null: game.move = Vector2.ZERO)


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("%s/garnizoen_%s_%s.png" % [dir, name, tag])
	print("foto ", name)


func _huis(kind: String) -> Node3D:
	for h in get_nodes_in_group("huis"):
		if h.kind == kind:
			return h
	return null


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
		game.prep_t = 1e9
	if p != null and frames > 10:
		p.hp = 1000.0   # de speler blijft staan voor de foto's
	for o in get_nodes_in_group("mcv_opbouw"):
		o.remove_from_group("mcv_opbouw")   # de opbouw van het hoofdkwartier trekt anders de camera naar de bouwplek
	if frames == 20:
		hotel = _huis("hotel")
		wh = _huis("woonhuis")
	if frames >= 20 and frames <= O + 470 and hotel != null:
		p.global_position = hotel.to_global(Vector3(3.0, 0.0, 14.0))   # elk beeld: de start zet de speler nog bij de bouwwagen
	# het hotel schiet op jou: een paar beelden kort na elkaar (een ervan heeft vuur uit een raam)
	if frames - O in [400, 404, 408, 412, 470]:
		_shot("hotel_%d" % (frames - O))
	if frames == O + 480:
		var hud := get_first_node_in_group("hud_extra")
		if hud != null:
			hud.open_map(false)
	if frames == O + 520:
		_shot("kaart")
		var hud := get_first_node_in_group("hud_extra")
		if hud != null:
			hud._map.close_map()
		if gz == null:
			return true
		# je soldaten in het woonhuis aan de hoofdstraat
		var ally_script: GDScript = load("res://scripts/ally.gd")
		for i in 3:
			var a = ally_script.new()
			p.get_parent().add_child(a)
			a.setup(100.0, 16.0, i)
			a.global_position = wh.get_node("Garnizoen").deur() + Vector3(i - 1.0, 0, 1.5)
			game.allies.append(a)
			allies.append(a)
	if frames > O + 520 and frames <= O + 640 and wh != null:
		p.global_position = wh.to_global(Vector3(-2.0, 0.0, 15.0))
	if frames == O + 540:
		for a in allies:
			wh.get_node("Garnizoen").binnen_gaan(a)
		var stand = get_first_node_in_group("bevel_stand")
		stand.open_stand()
		var ts = get_first_node_in_group("troep_selectie")
		ts.clear()
		ts.gebouw = wh.get_node("Garnizoen")
	if frames == O + 600:
		_shot("stand_eruit")
		get_first_node_in_group("bevel_stand").close_stand()
	if frames == O + 640:
		_shot("woonhuis_bezet")
	return frames > O + 645
