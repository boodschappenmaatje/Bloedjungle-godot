extends SceneTree
## Test van de testoptie "Test: start bij groep…" in het hoofdmenu (10 nov 2026): het blad met 12 groepknoppen, een start bij groep 6
## (de eerste groep die uitrukt is groep 6 met een tank, korte rust), dat zo'n testspel de beste groep niet ophoogt, en dat START MISSIE weer gewoon bij groep 1 begint.
## godot --headless --path . --script tests/test_groep_test.gd --fixed-fps 60

var fails := 0
var main: Node
var G: Node
var P: GDScript
var _watchdog := 0


func _initialize() -> void:
	root.size = Vector2i(932, 430)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main   # het menu start het spel via get_tree().current_scene
	call_deferred("_run")


func _process(_d: float) -> bool:
	_watchdog += 1
	if _watchdog > 6000:
		push_error("Testgroeptest hangt")
		quit(99)
	return false


func _check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FOUT ") + name)
	if not ok:
		fails += 1


func _frames(n: int) -> void:
	for _i in n:
		await process_frame


func _menu() -> Node:
	return get_first_node_in_group("menus")


func _run() -> void:
	G = root.get_node("Game")
	P = load("res://scripts/progress.gd")
	await _frames(2)
	main.get_node("Hud/Sticks").set_process(false)
	var menu := _menu()
	_check("het hoofdmenu heeft een testblad", menu._sheets.has("test"))
	var knoppen := 0
	var tekst := ""
	for b in menu._sheets["test"].find_children("*", "Button", true, false):
		if String(b.text).begins_with("Groep "):
			knoppen += 1
			if String(b.text).begins_with("Groep 6\n"):
				tekst = b.text
	_check("12 groepknoppen (%d)" % knoppen, knoppen == 12)
	_check("knop groep 6 noemt de tank: %s" % tekst.replace("\n", " / "), tekst.contains("tank"))
	_check("groep 3 brengt een jeep: %s" % menu.groep_inhoud(3), menu.groep_inhoud(3).contains("jeep"))
	_check("groep 1 zonder voertuig: %s" % menu.groep_inhoud(1), not menu.groep_inhoud(1).contains("+"))

	var best0: int = P.stats.bestWave
	menu._start_test(6)
	await _frames(40)
	_check("testgroep staat op 6", P.test_groep == 6)
	_check("spel staat in prep (%s)" % G.state, G.state == "prep")
	_check("teller staat op 5, dus de eerste groep wordt 6 (%d)" % G.wave, G.wave == 5)
	_check("korte rust van 20 s (%.1f)" % G.prep_t, G.prep_t <= P.TEST_RUST + 0.01 and G.prep_t > 10.0)
	main.start_wave()
	_check("de eerste groep die uitrukt is groep 6 (%d)" % G.wave, G.wave == 6)
	var tank := false
	for q in main.queue:
		if q is Dictionary and q.get("voertuig", false) and q.kind == "tank":
			tank = true
	_check("groep 6 heeft een tank in de wachtrij", tank)
	main._wave_cleared()
	_check("testspel hoogt beste groep niet op (%d -> %d)" % [best0, P.stats.bestWave], P.stats.bestWave == best0)

	# gewoon spel: START MISSIE zet de test uit
	menu._start_game()
	await _frames(40)
	_check("START MISSIE zet de test uit", P.test_groep == 0)
	_check("gewoon spel: teller op 0 (%d)" % G.wave, G.wave == 0)
	_check("gewoon spel: lange rust (%.0f s)" % G.prep_t, G.prep_t > 500.0)

	print("testgroep klaar, fouten: %d" % fails)
	quit(1 if fails > 0 else 0)
