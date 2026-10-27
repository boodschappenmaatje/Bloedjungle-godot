extends SceneTree
## Test: de echte tank, bestuurd, rijdt tegen een palm en velt hem; een jungleboom (te zwaar? nee: tank velt die ook).
## Draaien: godot --headless --path . -s tests/boom_val_tank_test.gd --fixed-fps 60

var main: Node
var game: Node
var F: GDScript
var tank
var frames := 0
var fails := 0
var e: Dictionary
var t_hit := -1


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		push_error("BOOM VAL TANK TEST FAIL: " + msg)


func _initialize() -> void:
	F = load("res://scripts/foliage.gd")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_d: float) -> bool:
	frames += 1
	game = root.get_node("Game")
	if frames == 3:
		main.begin()
		for n in root.find_children("*", "", true, false):
			if n.get_script() and String(n.get_script().resource_path).ends_with("touch_sticks.gd"):
				n.set_process(false)
		for m in get_nodes_in_group("menus"):
			m._show("")
	if frames == 100:
		for key in F.get("_reg"):
			for en: Dictionary in F.get("_reg")[key]:
				if e.is_empty() and not String(en["vn"]).begins_with("Boom"):
					e = en
		var o: Vector3 = e["xf"].origin
		tank = (load("res://scenes/tank.tscn") as PackedScene).instantiate()
		main.add_child(tank)
		tank.global_position = o + Vector3(-9, 0, 0)
		tank.rotation.y = -PI / 2.0   # kijkt naar +x
		tank.driven = true
		game.player.driving = true
		game.player.visible = false
		game.state = "play"
		print("palm ", o, " tank ", tank.global_position)
	if frames > 100 and frames < 400:
		game.move = Vector2(1, 0)
		if t_hit < 0 and e["felled"]:
			t_hit = frames
			print("gevelde palm na ", frames - 100, " beelden, tank op ", tank.global_position, " snelheid ", tank.get("_speed"))
	if frames == 401:
		# stilstaand en een stam binnen de romp (zoals bij draaien): ook die gaat plat
		var f: Dictionary = {}
		for key in F.get("_reg"):
			for en: Dictionary in F.get("_reg")[key]:
				if f.is_empty() and not en["felled"] and (en["xf"].origin - tank.global_position).length() > 40.0:
					f = en
		tank.global_position = f["xf"].origin + Vector3(1.0, 0, 0.5)
		game.move = Vector2.ZERO
		e = f
	if frames == 406:
		_check(e["felled"], "stam in de romp van een stilstaande tank gaat plat")
		print("BOOM VAL TANK TEST ", "OK" if fails == 0 else "%d FOUT(EN)" % fails)
		quit(1 if fails > 0 else 0)
		return true
	if frames == 400:
		_check(e["felled"], "de tank velt de palm op zijn pad (tank op " + str(tank.global_position) + ")")
	return false
