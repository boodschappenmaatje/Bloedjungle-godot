extends SceneTree
## Automatische test zonder scherm: speelt golf 1 en 2 met een "bot" die naar de dichtstbijzijnde
## vijand richt en schiet. Draaien: godot --headless --path godot -s tests/smoke_test.gd

var main: Node
var frames := 0
var inside_seen := 0
var log_t := 0.0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	frames += 1
	var game = root.get_node("Game")
	if frames == 2:
		main.get_node("Hud/Sticks").set_process(false)  # de bot bestuurt, niet de sticks
	if frames == 5:
		main.start_wave()
	var p = game.player
	# bot: richt op de dichtstbijzijnde vijand en schiet
	var best = null
	var bd := INF
	for e in game.enemies:
		var d: float = e.global_position.distance_to(p.global_position)
		if d < bd:
			bd = d
			best = e
		if absf(e.global_position.x) < 13.5 and absf(e.global_position.z) < 13.5:
			inside_seen += 1
	if best and bd < 25.0:
		var v: Vector3 = best.global_position - p.global_position
		game.aim = atan2(v.x, v.z)
		game.fire = true
	else:
		game.aim = NAN
		game.fire = false
	log_t += delta
	if log_t > 5.0:
		log_t = 0.0
		for e in game.enemies.slice(0, 3):
			print("   ", e.type, " ", e.global_position.snapped(Vector3.ONE * 0.1), " v=", e.velocity.length())
		print("t=%.0fs state=%s golf=%d vijanden=%d kills=%d punten=%d speler=%.0f bunker=%.0f binnen=%d" % [frames / 60.0, game.state, game.wave, game.enemies.size(), game.kills, game.points, p.hp, game.base_hp, inside_seen])
	if game.state == "over" or game.wave >= 3 or frames > 60 * 150:
		print("EINDE: ", game.state, " golf ", game.wave, " kills ", game.kills)
		return true
	return false
