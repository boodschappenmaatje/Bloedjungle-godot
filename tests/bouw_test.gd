extends SceneTree
## Test van de bouwmodus: kazerne, muur en zandzakken neerzetten, draaien, verkopen, rekruut opleiden.
## godot --headless --path . -s tests/bouw_test.gd --fixed-fps 60

var main: Node
var frames := 0
var kz: Variant


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_d: float) -> bool:
	frames += 1
	var g = root.get_node("Game")
	if frames == 2:
		main.get_node("Hud/Sticks").set_process(false)
	if frames == 4:
		main.begin()
		g.player.global_position = Vector3(-6, 0, -9)
	if frames == 8:
		var bm = main.get_node("Hud").get_children().filter(func(n): return n is BuildMode)[0]
		bm._enter()
		print("bouwmodus: ", g.build_mode)
		var b = g.builds
		print("kazerne op de muur: ", b.can_place("kazerne", Vector3(0, 0, 14), 0.0), " (false verwacht)")
		print("kazerne in de poort: ", b.can_place("kazerne", Vector3(0, 0, 11), 0.0), " (false verwacht)")
		print("kazerne in de tuin: ", b.can_place("kazerne", Vector3(-6, 0, -8), PI), " (true verwacht)")
		print("muur buiten: ", b.can_place("muur", Vector3(-20, 0, -20), 0.0), " (true verwacht)")
		print("muur op muurlijn: ", b.can_place("muur", Vector3(-8, 0, 14), 0.0), " (false verwacht)")
		kz = b.place("kazerne", Vector3(-6, 0, -8), PI)
		print("kazerne gebouwd: ", kz != null, " tegoed ", g.build_credit, " punten ", g.points)
		print("tweede kazerne: ", b.can_place("kazerne", Vector3(6, 0, 8), 0.0), " full ", b.full("kazerne"))
		g.points = 5000
		var m1 = b.place("muur", Vector3(-20, 0, -20), 0.0)
		var m2 = b.place("muur", Vector3(-17, 0, -20), 0.0)
		var z1 = b.place("zandzak", Vector3(-20, 0, -18), 0.0)
		print("stukken: ", m1 != null, m2 != null, z1 != null, " op elkaar: ", b.can_place("muur", Vector3(-20, 0, -20), 0.0))
		print("draaien: ", b.turn(m1), " verkoopwaarde ", b.sell_value(m1))
		var cr: int = g.build_credit
		b.sell(m1)
		print("verkocht: tegoed ", cr, " -> ", g.build_credit, " gebouwen ", g.buildings.size())
		g.player.global_position = b.door_of(kz)
		b.recruit(kz)
		b.recruit(kz)
		b.recruit(kz)
		print("in wachtrij: ", kz.queue, " (2 verwacht) punten ", g.points)
		bm._exit()
	if frames == 12:
		main.start_wave()
	if frames > 12 and frames % 300 == 0:
		print("t ", frames / 60, " soldaten ", g.builds.soldiers_alive(), " wachtrij ", kz.queue, " t ", kz.train_t, " allies ", g.allies.size())
	if frames == 12 + 60 * 25:
		print("soldaten: ", g.builds.soldiers_alive(), " (2 verwacht)")
		print("EINDE bouwen")
		return true
	return false
