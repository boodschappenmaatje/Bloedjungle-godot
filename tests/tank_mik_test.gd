extends SceneTree
## Test: de tank mikt op muurstukken van het woonhuis. Rechterstick richting huis -> koepel vergrendelt op het stuk in de lijn,
## schieten slaat dat stuk kapot. Draaien: godot --headless --path . -s tests/tank_mik_test.gd --fixed-fps 60

var main: Node
var frames := 0
var game: Node
var tank
var huis


func _initialize() -> void:
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
		huis = get_nodes_in_group("huis")[0]
		for m in get_nodes_in_group("menus"):
			m._show("")
		tank = (load("res://scenes/tank.tscn") as PackedScene).instantiate()
		main.add_child(tank)
		# 12 m voor de voorgevel, kijkend naar het noorden (-z)
		tank.global_position = Data.HUIS_POS + Vector3(-2.0, 0, 15.0)
		tank.driven = true
		game.player.driving = true
		game.player.visible = false
		game.state = "play"
	if frames > 3 and frames < 600:
		game.move = Vector2.ZERO
		# richting huis: lijn x = HUIS_POS.x - 3 (stuk M0V0 zit rond x = -3)
		var target: Vector3 = Data.HUIS_POS + Vector3(-3.0, 1.5, 3.5)
		var v: Vector3 = target - tank.global_position
		game.aim = atan2(v.x, v.z)
		game.fire = frames > 200 and not OS.has_environment('BJ_FOTO')
	if frames == 190 and OS.has_environment("BJ_FOTO"):
		root.get_viewport().get_texture().get_image().save_png("/tmp/claude-0/tank_mik.png")
		print("foto")
	if frames == 150:
		print("slot: ", tank._lock.get("name", "geen"), " staat ", tank._lock.get("staat", -1))
	if frames == 599:
		var st := {}
		for s in huis.segs:
			if s.staat > 0:
				st[s.name] = s.staat
		print("geraakt na schieten: ", st)
		print("KLAAR")
		return true
	return false
