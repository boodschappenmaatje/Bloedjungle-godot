extends SceneTree
## Test: via de stalen buitentrap langs de oostmuur loop je het dak van het magazijn op (voor de sluipschutter), het schuine dak
## volgt de nok, het dak blijft zichtbaar als je erop staat, een granaat van het dak blijft op het dak, en als het dak instort val je naar beneden.
## Draaien: godot --headless --path . -s tests/magazijn_dak_test.gd --fixed-fps 60

var main: Node
var game: Node
var h
var frames := 0
var move := Vector2.ZERO
var fouten := 0
var top_y := 0.0
var granaat = null
var granaat_laag := 99.0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	physics_frame.connect(func() -> void:
		if frames > 3 and game:
			game.move = move
		if granaat != null and is_instance_valid(granaat) and not granaat.is_queued_for_deletion():
			granaat_laag = minf(granaat_laag, h.to_local(granaat.global_position).y)
	)


func _check(ok: bool, label: String) -> void:
	print(("OK: " if ok else "FOUT: ") + label)
	if not ok:
		fouten += 1


func _lp() -> Vector3:
	return h.to_local(game.player.global_position)


func _process(_d: float) -> bool:
	frames += 1
	var t := frames - 3
	if t == 0:
		main.begin()
		game = root.get_node("Game")
		for n in root.find_children("*", "", true, false):
			if n.get_script() and String(n.get_script().resource_path).ends_with("touch_sticks.gd"):
				n.set_process(false)
		h = get_nodes_in_group("magazijn")[0]
		# de wereld ligt hier niet gedraaid: lokaal = wereld min de plek
		_check(absf(h.rotation.y) < 0.01, "magazijn staat recht (test gaat uit van lokaal = wereld)")
		# naast de voet van de trap, buiten het gebouw
		game.player.global_position = h.to_global(Vector3(6.75, 0.0, 4.6))
		game.player.position.y = 0.0
		move = Vector2(0.0, -1.0)   # naar achter (-Z): de trap op
	if t > 0 and t < 400 and move.y < 0.0:
		var p := _lp()
		top_y = maxf(top_y, game.player.position.y - h.position.y)
		if p.z < -3.0:
			move = Vector2(-1.0, 0.0)   # boven op het bordes: naar het westen het dak op
	if t > 0 and move.x < 0.0 and _lp().x < 2.0 and t < 600:
		move = Vector2.ZERO
		var p := _lp()
		var y: float = game.player.position.y - h.position.y
		_check(top_y > 4.9, "de trap brengt je tot de dakrand (%.2f m)" % top_y)
		_check(absf(y - (4.96 + (6.18 - absf(p.x)) * 0.082)) < 0.08, "je loopt over het schuine dak naar de nok (y %.2f bij x %.2f)" % [y, p.x])
		_check(h._inside == 1, "het gebouw weet dat je op het dak staat")
		_check(h._dak.visible, "het dak blijft zichtbaar als je erop staat")
		# granaat vanaf het dak: blijft op het dak
		granaat = load("res://scripts/grenade.gd").throw_from(h.get_parent(), game.player.global_position + Vector3(0, 1.6, 0), PI * 0.5, 11.0, game.player.global_position)
		t = 600
		frames = 603
	if t == 700:
		_check(granaat_laag > 4.9, "granaat van het dak blijft op het dak (laagste %.2f m)" % granaat_laag)
		if is_instance_valid(granaat):
			granaat.queue_free()  # klaar met de granaat: zijn puin mag de val-test hieronder niet beïnvloeden
		# het gat in het kapotte dak: daar zak je door
		h._roof_state(1)
		_check(h._floor_local(Vector3(-1.0, 5.4, 0.0), 5.4) < 1.0, "door het gat in het kapotte dak val je naar binnen")
		_check(h._floor_local(Vector3(3.5, 5.4, 0.0), 5.4) > 4.9, "naast het gat draagt het kapotte dak nog")
		game.player.global_position = h.to_global(Vector3(3.5, 5.2, 0.0))
		game.player.position.y = h.position.y + 5.2
	if t == 720:
		h._roof_state(2)
	if t == 840:
		var y: float = game.player.position.y - h.position.y
		_check(y < 0.5, "dak ingestort: je valt naar de vloer (y %.2f)" % y)
		_check(h._floor_local(Vector3(6.75, 0.0, 0.0), 0.0) < 1.0, "de trap leidt nergens meer heen na het instorten van het dak")
		print("MAGAZIJN_DAK_TEST fouten=", fouten)
		quit(1 if fouten > 0 else 0)
		return true
	return false
