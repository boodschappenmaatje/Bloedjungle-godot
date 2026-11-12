extends SceneTree
## Test: Luchtaanval (P-47) en Parachutisten (generaalsrang E2). De P-47 vliegt echt over een strook met een vijand erin en laat bommen vallen;
## acht parachutisten springen, landen en staan als eigen soldaten op HOUD. Draaien: godot --headless --path . -s tests/luchtaanval_test.gd --fixed-fps 60

var failures: Array[String] = []
var main: Node
var game: Node
var Rg: GDScript


func _initialize() -> void:
	OS.set_environment("BJ_TOUCH", "1")
	root.size = Vector2i(932, 430)
	call_deferred("_run")


func _check(message: String, ok: bool) -> void:
	print(("OK   " if ok else "FOUT ") + message)
	if not ok:
		failures.append(message)
		push_error("LUCHTAANVAL TEST: " + message)


func _frames(n: int) -> void:
	for _i in n:
		await process_frame


func _enemy(at: Vector3) -> Node:
	var e: Node = load("res://scenes/enemy.tscn").instantiate()
	e.call("setup", "rifle", 1)
	main.add_child(e)
	e.global_position = at
	return e


func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	game = root.get_node("Game")
	Rg = load("res://scripts/rang.gd")
	await _frames(3)
	main.get_node("Hud/Sticks").set_process(false)
	await main.call("begin")
	await _frames(3)
	game.player.global_position = Vector3(0, 0, 60)
	for e in game.enemies.duplicate():
		if is_instance_valid(e):
			e.queue_free()
	game.enemies.clear()
	game.state = "play"
	game.krachten = {"luchtaanval": 3, "parachutisten": 3}
	game.kracht_cd.clear()

	# ---- luchtaanval niveau 3: twee toestellen, strook van 30 m, een vijand in het midden en een erbuiten
	var strook := Vector3(0, 0, 0)
	var binnen := _enemy(Vector3(1.0, 0, 3.0))
	var ver := _enemy(Vector3(40.0, 0, 3.0))
	game.enemies.append(binnen)
	game.enemies.append(ver)
	var hp_ver: float = float(ver.hp)
	_check("luchtaanval gebruiken lukt en zet de afkoeling (niveau 3: 70 s)", Rg.gebruik("luchtaanval", main, strook, Vector3(0, 0, -1)) and not Rg.klaar("luchtaanval") and is_equal_approx(Rg.afkoeling("luchtaanval"), 70.0))
	var planes := 0
	for c in main.get_children():
		if c.get_script() != null and String(c.get_script().resource_path).ends_with("luchtaanval.gd"):
			planes += 1
	_check("niveau 3: twee toestellen (%d)" % planes, planes == 2)
	var dood := false
	for _i in 900:   # 15 s
		await process_frame
		if not is_instance_valid(binnen) or binnen.get("dead") == true:
			dood = true
	_check("de vijand in de strook is geraakt en gesneuveld", dood)
	_check("een vijand ver van de strook blijft heel (hp %.0f van %.0f)" % [float(ver.hp), hp_ver], is_instance_valid(ver) and float(ver.hp) >= hp_ver - 0.01)
	var rest := 0
	for c in main.get_children():
		if c.get_script() != null and String(c.get_script().resource_path).ends_with("luchtaanval.gd"):
			rest += 1
	_check("na de aanval ruimen de toestellen zichzelf op (%d over)" % rest, rest == 0)

	# ---- parachutisten niveau 3: acht man
	var voor: int = game.allies.size()
	game.points = 0
	game.state = "play"
	_check("parachutisten gebruiken", Rg.gebruik("parachutisten", main, Vector3(0, 0, 20), Vector3(0, 0, -1)))
	await _frames(240)
	_check("na 4 s zijn de eerste springers uit het toestel (%d)" % (game.allies.size() - voor), game.allies.size() > voor and game.allies.size() <= voor + 8)
	for _i in 1500:   # 25 s
		await process_frame
	_check("acht nieuwe soldaten (%d -> %d)" % [voor, game.allies.size()], game.allies.size() == voor + 8)
	var geland := 0
	var hold := 0
	var soorten := {}
	for a in game.allies:
		if is_instance_valid(a) and a.global_position.distance_to(Vector3(0, 0, 20)) < 14.0:
			if absf(a.global_position.y) < 0.2 and a.top_level == false:
				geland += 1
			if a.command == "hold":
				hold += 1
			soorten[String(a.kind)] = int(soorten.get(String(a.kind), 0)) + 1
	_check("alle acht staan op de grond binnen 14 m van het doel (%d)" % geland, geland == 8)
	_check("alle acht staan op HOUD (%d)" % hold, hold == 8)
	_check("de soorten: raket, sluipschutter en hospik zitten erbij (%s)" % str(soorten), soorten.has("raket") and soorten.has("sluipschutter") and soorten.has("hospik"))
	var chutes := 0
	for c in main.get_children():
		if c.get_script() != null and String(c.get_script().resource_path).ends_with("parachutisten.gd"):
			chutes += 1
	_check("het droptoestel ruimt zichzelf op (%d)" % chutes, chutes == 0)

	print("klaar, fouten: ", failures.size())
	quit(1 if failures.size() > 0 else 0)
