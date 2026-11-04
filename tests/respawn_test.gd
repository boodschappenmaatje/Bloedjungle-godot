extends SceneTree
## Test van terugkomen na sneuvelen (Generals-plan, stap 2d).
## godot --headless --path . -s tests/respawn_test.gd --fixed-fps 60

var main: Node
var frames := 0
var fails := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FOUT ") + name)
	if not ok:
		fails += 1


func _bm() -> Node:
	for c in main.get_node("Hud").get_children():
		if c.has_method("_enter") and c.has_method("_exit") and c.get("_ui") != null:
			return c
	return null


func _process(_d: float) -> bool:
	frames += 1
	var g = root.get_node("Game")
	var p = g.player
	if frames == 2:
		main.get_node("Hud/Sticks").set_process(false)
	if frames == 4:
		main.begin()
	if frames == 8:
		g.state = "play"
		p.global_position = Vector3(5, 0, -12)
		p.hit(99999.0, Vector3.FORWARD, false)
		_check("speler is dood", p.dead)
		_check("geen game over", g.state == "play")
		_check("wachttijd 8 s", is_equal_approx(p.respawn_t, 8.0))
		var bm: Node = _bm()
		_check("bouwscherm mag open tijdens het wachten", bm != null)
		if bm:
			bm._enter()
			_check("bouwmodus is aan", g.build_mode)
			bm._exit()
		p.respawn_t = 0.05
	if frames == 14:
		_check("terug in leven", not p.dead)
		_check("vol leven", is_equal_approx(p.hp, g.max_hp()))
		_check("terug bij de bunker", p.global_position.distance_to(p.home) < 0.01)
		var hp0: float = p.hp
		p.hit(30.0, Vector3.FORWARD, false)
		_check("even onkwetsbaar na terugkomen", is_equal_approx(p.hp, hp0))
		p.shield_t = 0.0
		p.hit(30.0, Vector3.FORWARD, false)
		_check("daarna weer kwetsbaar", p.hp < hp0)
		# bouwen kan altijd, ook tijdens een aanvalsgroep (Dennis, 4 nov), maar niet als het spel voorbij is
		var bm2: Node = _bm()
		if bm2:
			bm2._enter()
			_check("bouwscherm mag open tijdens een groep als je leeft", g.build_mode)
			g.state = "over"
			bm2._process(0.1)
			_check("bouwscherm dicht als het spel voorbij is", not g.build_mode)
			g.state = "play"
		print("klaar, fouten: ", fails)
		quit(1 if fails > 0 else 0)
	return false
