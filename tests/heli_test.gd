extends SceneTree
## Test: de heli landt buiten het platform alleen op open grond en kan daar weer opstijgen. Draaien: godot --headless --path . -s tests/heli_test.gd --fixed-fps 60

var main: Node
var game: Node
var frames := 0
var heli: Apache
var pad: Dictionary
var hp0 := 0.0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_d: float) -> bool:
	frames += 1
	game = root.get_node("Game")
	if frames == 3:
		main.begin()
		game.points = 5000
		var r = game.builds.place("helipad", Vector3(-12, 0, 20), 0.0)
		pad = r if r is Dictionary else game.buildings.back()
		game.builds.buy_heli(pad)
		heli = pad.heli
		print("heli: ", heli != null)
	if frames == 3 + 60 * 8 and heli:
		heli.global_position = Vector3(0, 7, -20)
		heli._board(game.player)
		heli._spool = 0.0
	if frames == 3 + 60 * 10:
		print("vliegt: ", heli.mode == Apache.Mode.FLY)
		# boven water
		heli.global_position = Vector3(10, 7, Data.river_z(10.0))
		print("water: '", heli._no_landing(), "'")
		var tr: Vector2 = Foliage.trees[0]
		heli.global_position = Vector3(tr.x, 7, tr.y)
		print("boom: '", heli._no_landing(), "' bomen: ", Foliage.trees.size())
		# open plek zoeken
		var found := false
		for i in 400:
			var x := -60.0 + (i % 20) * 6.0
			var z := -70.0 + (i / 20) * 6.0
			heli.global_position = Vector3(x, 7, z)
			if heli._no_landing() == "":
				found = true
				break
		print("open plek gevonden: ", found, " bij ", heli.global_position)
		heli._btn_what = "landhier"
		heli._press()
		print("mode na landen-knop (3 = FREE): ", heli.mode)
	if frames == 3 + 60 * 20:
		print("op de grond (4 = GROUND): ", heli.mode, " y ", heli.global_position.y, " speler zichtbaar ", game.player.visible)
		game.player.global_position = heli.global_position + Vector3(2, 0, 0)
		heli._update_button(game.player, true)
		print("knop: ", heli._btn_what)
		heli._press()
		print("weer in de lucht (1 = FLY): ", heli.mode)
	if frames == 3 + 60 * 24:
		print("hoogte ", heli.global_position.y)
		# een vijand in de richtcirkel
		heli.global_position.y = 7.0
		heli.rotation.y = 0.0
		main._spawn("rifle")
		var e = game.enemies[0] if game.enemies.size() > 0 else null
		print("vijand: ", e != null)
		if e:
			e.global_position = heli._ring_center()
			hp0 = e.hp
			heli.driven = true
			heli.mode = Apache.Mode.FLY
			heli._spool = 0.0
			game.player.driving = true
			for n in main.find_children("*", "", true, false):
				if n is TouchSticks:
					n.set_process(false)
					n.set_physics_process(false)
	if frames > 3 + 60 * 24 and frames < 3 + 60 * 27:
		game.aim = PI
		game.fire = true
		game.move = Vector2.ZERO
		if game.enemies.size() > 0:
			game.enemies[0].global_position = heli._ring_center()
			game.enemies[0].velocity = Vector3.ZERO
	if frames == 3 + 60 * 27:
		print("hp nu: ", game.enemies[0].hp if game.enemies.size() > 0 else -1, " ring zichtbaar: ", heli._ring.visible, " vijanden over: ", game.enemies.size(), " kills ", game.kills, " hp0 ", hp0)
		quit()
	return false
