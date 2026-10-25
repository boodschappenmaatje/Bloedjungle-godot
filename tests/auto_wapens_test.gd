extends SceneTree
## Test: alle andere wapens die een auto of bus kunnen raken, via hun eigen schietcode: granaat, jeep-MG, tankkanon,
## Apache-kanon (schuin van boven), wachttoren, bondgenoot, schutter op de legertruck, vijandelijke kogels en raketten.
## Plus de verhouding: een kogel doet weinig, een explosief veel.
## Draaien: godot --headless --path . -s tests/auto_wapens_test.gd --fixed-fps 60

var failures := 0
var game
var main: Node
var B


func _initialize() -> void:
	call_deferred("_run")


func _check(name: String, ok: bool) -> void:
	print(("OK    " if ok else "FAIL  ") + name)
	if not ok:
		failures += 1


func _frames(n: int) -> void:
	for _i in n:
		await process_frame


func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	game = root.get_node("Game")
	B = load("res://scripts/bullet.gd")
	await _frames(3)
	await main.call("begin")
	await _frames(3)
	for n in root.find_children("*", "", true, false):
		if n.get_script() and String(n.get_script().resource_path).ends_with("touch_sticks.gd"):
			n.set_process(false)
	var Stad = load("res://scripts/stad.gd")
	Stad.current.set_items(Stad.from_lines([["auto", 0, -96, 1, 0], ["bus", 40, -96, 1, 0], ["auto", -40, -96, 0, 1]]))
	var targets: Array = []
	for d in Stad.current.items:
		targets.append(d.node)
	await _frames(2)
	game.player.global_position = Vector3(0, 0, -60)   # uit de buurt

	for target: Node3D in targets:
		var label := "bus" if String(target.get_script().resource_path).ends_with("bus.gd") else ("auto" if target.scale.x > 0 else "gespiegelde auto")
		var c: Vector3 = target.global_position

		# vijandelijke kogels (soldaat, 1,4-1,6 m hoog) vanaf 9 m
		await _shots(target, label + ": vijandelijke kogel", func() -> void:
			for i in 6:
				B.fire(main, c + Vector3(-2.0, 1.5, 9.0), atan2(2.0, -9.0), 34.0, 7.0, 1.1, false))
		# vijandelijke raket
		await _shots(target, label + ": vijandelijke raket", func() -> void:
			B.fire_rocket(main, c + Vector3(9.0, 1.4, 4.0), atan2(-9.0, -4.0), 55.0, 1.4), 80)
		# bondgenoot (Thompson op schouderhoogte)
		await _shots(target, label + ": bondgenoot", func() -> void:
			for i in 4:
				B.fire(main, c + Vector3(6.0, 1.6, 0.0), -PI / 2.0, 70.0, 18.0, 0.6, true, false))
		# schutter op de legertruck (hoog, over_wall)
		await _shots(target, label + ": schutter op de legertruck", func() -> void:
			for i in 4:
				B.fire(main, c + Vector3(0.0, 2.3, -10.0), 0.0, 70.0, 22.0, 0.6, true, true))
		# wachttoren: schiet van 5,3 m en zakt naar schouderhoogte (defenses._shoot)
		await _shots(target, label + ": wachttoren", func() -> void:
			for i in 4:
				game.defs._shoot(c + Vector3(-14.0, 0, 0.0), PI / 2.0, 20.0, 60.0, 0.6, 5.3, 14.0))
		# Apache: van 9 m hoog schuin omlaag naar een punt op de auto (apache.gd)
		await _shots(target, label + ": Apache-kanon", func() -> void:
			for i in 4:
				var from := c + Vector3(0.0, 8.4, 11.0)
				var to := c + Vector3(randf_range(-0.4, 0.4), 1.0, randf_range(-0.4, 0.4)) - from
				var hd := Vector2(to.x, to.z).length()
				B.fire(main, from, atan2(to.x, to.z), 95.0, 30.0, hd / 95.0 * 1.3, true, true, 0, 0.0, 0.0, to.y / maxf(hd, 0.1)))
		# jeep-MG via jeep.gd zelf
		var jeep: Node3D = load("res://scenes/jeep.tscn").instantiate()
		main.add_child(jeep)
		jeep.global_position = c + Vector3(0, 0, 12.0)
		await _frames(2)
		jeep.set_physics_process(false)
		await _shots(target, label + ": jeep-MG", func() -> void:
			for i in 5:
				var m: Vector3 = jeep._monding.global_position
				jeep._shoot(atan2(c.x - m.x, c.z - m.z)))
		jeep.queue_free()
		# tankkanon via tank.gd: koepel naar de auto, granaat valt waar de loop iets raakt
		var tank: Node3D = load("res://scenes/tank.tscn").instantiate()
		main.add_child(tank)
		tank.global_position = c + Vector3(14.0, 0, 0.0)
		tank.rotation.y = atan2(1.0, 0.0)   # loop (-Z) wijst naar -x, naar de auto
		await _frames(2)
		tank.set_physics_process(false)
		tank._toren.rotation.y = 0.0
		tank._lock = {}
		await _frames(1)
		var aimp: Vector3 = tank._aim_point()
		_check(label + ": tank mikt op de carrosserie, niet erachter (%.1f m ervan af)" % target.blast_dist(Vector3(aimp.x, 1.0, aimp.z)), target.blast_dist(Vector3(aimp.x, 1.0, aimp.z)) < 0.3)
		await _shots(target, label + ": tankkanon", func() -> void:
			tank._shoot(tank._aim_point()), 60)
		tank.queue_free()
		# granaat van de speler rond de worpafstand (11 m; van dichterbij gaat de boog over een auto heen, zoals echt)
		for gd in [9.0, 11.0, 13.0]:
			await _shots(target, label + ": granaat van %.1f m" % gd, func() -> void:
				var p = game.player
				p.global_position = c + Vector3(0, 0, gd)
				p.face = PI
				p.rotation.y = PI
				p.grenade_cd = 0.0
				game.grenades = 3
				p.throw_grenade(), 200)
		game.player.global_position = Vector3(0, 0, -60)

	# verhouding: kogel tegen explosief
	var car: Node3D = targets[0]
	_heal(car)
	car.hit(26.0, Vector3.RIGHT, true)
	var bullet_dmg: float = car.HP - car.hp
	_heal(car)
	game.note_blast(car.global_position + Vector3(0, 0.5, 2.5), 4.8)
	var blast_dmg: float = car.HP - car.hp
	_check("pistoolkogel doet %.0f, raketontploffing ernaast %.0f (kogel < 5%% van explosief)" % [bullet_dmg, blast_dmg], bullet_dmg > 0.0 and bullet_dmg < blast_dmg * 0.05)
	print("AUTO WAPENS TEST KLAAR, fouten: ", failures)
	quit(1 if failures > 0 else 0)


func _heal(t: Node3D) -> void:
	t.hp = t.HP
	t.burning = false
	t._fuse = 0.0


func _shots(target: Node3D, name: String, shoot: Callable, wait := 40) -> void:
	_heal(target)
	var hp0: float = target.hp
	shoot.call()
	await _frames(wait)
	var lost: float = hp0 - target.hp
	_check("%s raakt (%.0f hp schade)" % [name, lost], lost > 0.5)
	_heal(target)
