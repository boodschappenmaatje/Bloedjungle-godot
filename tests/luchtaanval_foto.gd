extends SceneTree
## Schermafbeeldingen van Luchtaanval (P-47) en Parachutisten (E2, 12 nov 2026) met de gamecamera.
## FOTO_DIR=/pad xvfb-run -a -s "-screen 0 932x430x24" godot --rendering-driver opengl3 --path . -s tests/luchtaanval_foto.gd --resolution 932x430 --fixed-fps 60

var main: Node
var frames := 0
var game: Node
var dir := OS.get_environment("FOTO_DIR") if OS.get_environment("FOTO_DIR") != "" else "/tmp"
var Rg: GDScript
var shots := {}
const O := 120       # de start zet de speler nog bij de bouwwagen: tot dan elk beeld terugzetten
const T0 := O + 40   # frame waarop de luchtaanval start
const T1 := T0 + 330 # frame waarop de parachutisten starten


func _initialize() -> void:
	OS.set_environment("BJ_TOUCH", "1")
	load("res://scripts/data.gd").set("mcv_autodeploy", true)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	Rg = load("res://scripts/rang.gd")
	physics_frame.connect(func(): if frames > 3 and game != null: game.move = Vector2.ZERO)


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("%s/lucht_%s.png" % [dir, name])
	print("foto ", name)


func _enemy(at: Vector3) -> void:
	var e: Node = load("res://scenes/enemy.tscn").instantiate()
	e.call("setup", "rifle", 1)
	main.add_child(e)
	e.global_position = at
	game.enemies.append(e)


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
		p.hp = 1000.0
	for o in get_nodes_in_group("mcv_opbouw"):
		o.remove_from_group("mcv_opbouw")
	if frames >= 20 and frames <= T1 + 400 and p != null:
		p.global_position = Vector3(20, 0, 40)
	if frames == 20:
		game.krachten = {"luchtaanval": 3, "parachutisten": 3}
		game.kracht_cd.clear()
		for e in game.enemies.duplicate():
			if is_instance_valid(e):
				e.queue_free()
		game.enemies.clear()
		game.state = "play"
		for i in 3:
			_enemy(Vector3(20.0 + float(i) * 2.0 - 3.0, 0, 18.0 + float(i) * 4.0))
	if frames == T0:
		game.state = "play"
		Rg.gebruik("luchtaanval", main, Vector3(20, 0, 22), Vector3(0, 0, -1))
	for pair in [[T0 + 90, "aanvlucht_1"], [T0 + 120, "aanvlucht_2"], [T0 + 135, "aanvlucht_3"], [T0 + 150, "aanvlucht_4"], [T0 + 165, "aanvlucht_5"], [T0 + 200, "aanvlucht_6"]]:
		if frames == pair[0]:
			_shot(pair[1])
	if frames == T1:
		game.state = "play"
		game.kracht_cd.clear()
		Rg.gebruik("parachutisten", main, Vector3(20, 0, 20), Vector3(0, 0, -1))
	for pair in [[T1 + 140, "para_1"], [T1 + 175, "para_2"], [T1 + 215, "para_3"], [T1 + 255, "para_4"], [T1 + 300, "para_5"], [T1 + 380, "para_6"]]:
		if frames == pair[0]:
			_shot(pair[1])
	if frames == T1 + 390:
		quit(0)
	return false
