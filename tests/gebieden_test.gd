extends SceneTree
## Test: bezette gebieden (gebieden.gd). Verdedigers verschijnen als de speler dichtbij komt, blijven op hun post,
## worden wakker als de speler in het gebied komt, tellen niet mee voor de golf, en het gebied is vrij als ze dood zijn.
## Draaien: godot --headless --path . -s tests/gebieden_test.gd --fixed-fps 60

var main: Node
var frames := 0
var fails := 0
var game
var guards: Array = []


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		push_error("GEBIEDEN TEST: " + msg)


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_dt: float) -> bool:
	frames += 1
	game = root.get_node("Game")
	if frames == 3:
		main.begin()
		game.player.global_position = Vector3(0, 0, 20)
	if frames > 3:
		game.player.hp = 100000.0
	if frames == 30:
		_check(game.gebieden.alive("woonwijk") == 0, "verdedigers verschijnen al terwijl de speler ver weg is")
		game.player.global_position = Vector3(0, 0, -80)  # bij de brug: Brugkop ligt binnen 70 m, Woonwijk ook
	if frames == 90:
		var n: int = game.gebieden.garrison_size("woonwijk", game.wave)
		_check(game.gebieden.alive("woonwijk") == n, "woonwijk heeft %d verdedigers, verwacht %d" % [game.gebieden.alive("woonwijk"), n])
		_check(game.gebieden.alive("brugkop") == game.gebieden.garrison_size("brugkop", game.wave), "brugkop niet bezet")
		_check(game.gebieden.wave_count() == 0, "verdedigers tellen mee voor de golf: %d" % game.gebieden.wave_count())
		for g in game.enemies:
			if g.zone == "woonwijk":
				guards.append(g)
				_check(g.global_position.distance_to(g.post) < 1.5, "verdediger staat niet op zijn post")
				_check(not g.awake, "verdediger is al wakker")
		_check(game.gebieden.state.brugkop.label != null, "geen getal bij het dichtstbijzijnde gebied")
		_check(game.gebieden.state.woonwijk.label == null, "ook een getal bij een ver gebied")
		# de speler loopt het gebied in
		game.player.global_position = Vector3(-30, 0, -104)
	if frames == 150:
		var awake := 0
		for g in guards:
			if g.awake:
				awake += 1
		_check(awake > 0, "niemand wordt wakker als de speler in het gebied staat")
		# weglopen: ze gaan terug naar hun post
		game.player.global_position = Vector3(60, 0, 20)
	if frames == 150 + 60 * 9:
		for g in guards:
			if is_instance_valid(g):
				_check(not g.awake, "verdediger blijft wakker als de speler weg is")
		game.player.global_position = Vector3(-30, 0, -95)
	if frames == 150 + 60 * 9 + 60 * 14:
		for g in guards:
			if is_instance_valid(g):
				_check(g.global_position.distance_to(g.post) < 4.0, "verdediger is niet teruggelopen naar zijn post (%.1f m) post %s nu %s" % [g.global_position.distance_to(g.post), g.post, g.global_position])
		for g in guards:
			if is_instance_valid(g) and not g.dead:
				g.hit(99999.0, Vector3.RIGHT, true)
	if frames == 150 + 60 * 9 + 60 * 14 + 40:
		_check(game.gebieden.alive("woonwijk") == 0, "nog verdedigers na uitschakelen")
		_check(game.gebieden.is_cleared("woonwijk"), "woonwijk is niet vrij")
	if frames == 150 + 60 * 9 + 60 * 14 + 60 * 4:
		_check(game.gebieden.state.woonwijk.label == null, "getal verdwijnt niet")
		# een golf kan beginnen en verdedigers van andere gebieden blokkeren hem niet
		main.start_wave()
	if frames == 150 + 60 * 9 + 60 * 14 + 60 * 4 + 5:
		_check(game.gebieden.wave_count() > 0 or main.queue.size() > 0, "golf start niet")
		print("GEBIEDEN TEST: %s" % ("OK" if fails == 0 else "%d FOUT" % fails))
		quit(1 if fails else 0)
		return true
	return false
