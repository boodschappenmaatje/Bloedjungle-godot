extends SceneTree
## Test: de generator staat in de basis met botsing, valt uit door kogels of een ontploffing, dan is de stroom (Game.power) weg
## en zijn de zwaailampen uit; repareren zet alles terug. Draaien: godot --headless --path . -s tests/generator_test.gd --fixed-fps 60

var main: Node
var game: Node
var frames := 0
var fails := 0
var gen: Node


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		push_error("GENERATOR TEST FAIL: " + msg)


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
		for m in get_nodes_in_group("menus"):
			m._show("")
		game.prep_t = 9999.0
	if frames == 20:
		for n in main.get_children():
			if n.get_script() and String(n.get_script().resource_path).ends_with("generator.gd"):
				gen = n
		_check(gen != null, "de generator bestaat")
		_check(game.power, "de stroom is aan")
		_check(gen.model != null and gen.model.visible and not gen.wreck.visible, "heel model zichtbaar, wrak verborgen")
		_check(gen.model.find_child("Ventilator", true, false) != null, "ventilator in het model")
		var fan: AnimationPlayer = gen.model.find_child("AnimationPlayer", true, false)
		_check(fan != null and fan.is_playing() and fan.current_animation == "Draaien", "de ventilator draait")
		_check(gen._sound != null and gen._sound.stream != null, "de generator heeft geluid")
		_check(not game.builds.can_place("garage", gen.mid(), 0.0), "geen garage op de generator")
		_check(game.generator_cost() == 0, "heel = geen reparatiekosten")
		_check(game.gates.list[0].beacons[0].light.light_energy > 0.0, "zwaailamp heeft een lamp")
		var bk: Dictionary = game.gates.list[0].beacons[0]
		_check(bk.kap.emission_energy_multiplier > 0.0, "zwaailamp brandt met stroom (%.1f)" % bk.kap.emission_energy_multiplier)
		var hp0: float = gen.hp
		game.hit_src = "soldaat"
		gen.body.call("hit", 20.0, Vector3.RIGHT, true)
		_check(is_equal_approx(gen.hp, hp0), "kogels van soldaten beschadigen de generator niet")
		game.hit_src = "speler"
		gen.body.call("hit", 20.0, Vector3.RIGHT, true)
		_check(gen.hp < hp0, "jouw kogels beschadigen de generator")
		gen.body.call("hit", 20.0, Vector3.RIGHT, false)
		for i in 30:
			gen.body.call("hit", 20.0, Vector3.RIGHT, true)
		_check(gen.down, "de generator gaat kapot")
	if frames == 21:
		_check(not game.power, "stroom weg als de generator kapot is")
		_check(gen.wreck.visible and not gen.model.visible, "wrak zichtbaar")
		_check((gen.body.get_child(0) as CollisionShape3D).disabled, "wrak heeft geen botsing")
		_check(game.generator_cost() >= 400, "repareren kost punten (%d)" % game.generator_cost())
		var bk: Dictionary = game.gates.list[0].beacons[0]
		_check(bk.kap.emission_energy_multiplier == 0.0 and not bk.light.visible, "zwaailampen zijn uit zonder stroom")
		gen.repair()
	if frames == 22:
		_check(game.power and not gen.down and gen.model.visible and not gen.wreck.visible, "repareren zet alles terug")
		_check(game.generator_cost() == 0, "na repareren geen kosten")
		var bk: Dictionary = game.gates.list[0].beacons[0]
		_check(bk.kap.emission_energy_multiplier > 0.0, "zwaailamp brandt weer")
		# explosie ernaast
		(load("res://scripts/generator.gd") as GDScript).call("blast", gen.mid() + Vector3(2, 0, 0), 6.0, 500.0)
		_check(gen.down and not game.power, "een ontploffing slaat de generator kapot")
		print("GENERATOR TEST ", "OK" if fails == 0 else "%d FOUT(EN)" % fails)
		quit(1 if fails > 0 else 0)
		return true
	return false
