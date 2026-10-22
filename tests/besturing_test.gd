extends SceneTree
## Test van de besturing: handmatig herladen, sprint (met uithoudingsvermogen), ontwijkrol (onkwetsbaar,
## cooldown) en handgranaten. Draaien: godot --headless --path . -s tests/besturing_test.gd --fixed-fps 60

var failures: Array[String] = []
var main: Node
var game: Node
var player: Node3D


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("BESTURING TEST: " + message)


func _frames(n: int) -> void:
	for _i in n:
		await physics_frame


## Loopt n frames naar rechts en geeft de afgelegde afstand terug.
func _walk(frames: int) -> float:
	var x0 := player.global_position.x
	game.set("move", Vector2(1, 0))
	await _frames(frames)
	game.set("move", Vector2.ZERO)
	return player.global_position.x - x0


func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	game = root.get_node("Game")
	for _i in 3:
		await process_frame
	main.get_node("Hud/Sticks").set_process(false)  # de test bestuurt, niet de sticks
	await main.call("begin")
	for _i in 3:
		await process_frame
	player = game.get("player")
	_check(player != null, "geen speler")
	if player == null:
		quit(1)
		return
	player.global_position = Vector3(0, 0, 40)  # open terrein, ver van muren en bunker
	await _frames(5)

	# ---- herladen ----
	player.set("ammo", 2)
	player.call("request_reload")
	_check(float(player.get("reload_t")) > 0.0, "handmatig herladen start niet")
	await _frames(120)
	var mag: int = game.wstat(player.get("weapon")).mag
	_check(int(player.get("ammo")) == mag, "magazijn is na het herladen niet vol (%d i.p.v. %d)" % [int(player.get("ammo")), mag])

	# ---- lopen en sprinten ----
	player.global_position = Vector3(-30, 0, 40)
	await _frames(3)
	var walk := await _walk(30)
	player.global_position = Vector3(-30, 0, 40)
	await _frames(3)
	player.call("toggle_sprint")
	_check(bool(player.get("sprint_on")), "sprint gaat niet aan")
	var run := await _walk(30)
	_check(run > walk * 1.3, "sprint is niet merkbaar sneller (%.2f t.o.v. %.2f m)" % [run, walk])
	_check(float(player.get("stamina")) < 1.0, "sprint kost geen uithoudingsvermogen")
	game.set("fire", true)
	game.set("move", Vector2(1, 0))
	await _frames(3)
	_check(not bool(player.get("sprinting")), "hij sprint nog terwijl hij schiet")
	game.set("fire", false)
	game.set("move", Vector2.ZERO)
	player.call("toggle_sprint")
	await _frames(90)
	_check(float(player.get("stamina")) > 0.95, "uithoudingsvermogen herstelt niet")

	# ---- ontwijkrol ----
	player.global_position = Vector3(0, 0, 40)
	await _frames(3)
	var hp0: float = player.get("hp")
	var x0 := player.global_position.x
	game.set("move", Vector2(1, 0))
	player.call("request_dodge")
	_check(float(player.get("dodge_t")) > 0.0, "ontwijkrol start niet")
	player.call("hit", 30.0, Vector3.RIGHT, false)
	_check(float(player.get("hp")) == hp0, "hij is niet onkwetsbaar tijdens de rol")
	await _frames(10)
	_check(player.global_position.x - x0 > 1.0, "de rol verplaatst hem niet")
	_check(absf(player.get("model").rotation.x) > 0.01, "de rolanimatie draait het model niet")
	var cd: float = player.get("dodge_cd")
	player.call("request_dodge")
	_check(float(player.get("dodge_cd")) <= cd, "tweede rol kan meteen weer (cooldown werkt niet)")
	await _frames(40)
	_check(float(player.get("dodge_t")) == 0.0, "rol stopt niet")
	_check(absf(player.get("model").rotation.x) < 0.001, "model blijft na de rol gekanteld")
	player.call("hit", 30.0, Vector3.RIGHT, false)
	_check(float(player.get("hp")) < hp0, "na de rol kan hij weer geraakt worden")
	game.set("move", Vector2.ZERO)
	player.set("hp", game.max_hp())

	# ---- granaat ----
	var gr0: int = game.get("grenades")
	_check(gr0 == 3, "begin niet met 3 granaten (%d)" % gr0)
	player.global_position = Vector3(0, 0, 40)
	player.set("face", 0.0)
	await _frames(3)
	player.call("throw_grenade")
	_check(int(game.get("grenades")) == gr0 - 1, "granaat gaat niet uit de voorraad")
	var found := 0
	for n in main.get_children():
		if n.get_script() != null and n.get_script().resource_path == "res://scripts/grenade.gd":
			found += 1
	_check(found == 1, "geen granaat in de lucht (%d)" % found)
	await _frames(150)
	found = 0
	for n in main.get_children():
		if n.get_script() != null and n.get_script().resource_path == "res://scripts/grenade.gd":
			found += 1
	_check(found == 0, "granaat ontploft niet")
	game.set("grenades", 0)
	player.call("throw_grenade")
	_check(int(game.get("grenades")) == 0, "hij gooit zonder granaten")

	# ---- toetsen ----
	var ev := InputEventKey.new()
	ev.keycode = KEY_R
	ev.pressed = true
	player.set("ammo", 1)
	player.call("_unhandled_key_input", ev)
	_check(float(player.get("reload_t")) > 0.0, "toets R herlaadt niet")

	main.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty():
		print("BESTURING TEST PASS: herladen, sprint, ontwijkrol, granaat en toetsen")
		quit(0)
	else:
		quit(1)
