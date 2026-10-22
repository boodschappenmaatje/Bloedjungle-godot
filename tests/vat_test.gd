extends SceneTree
## Test: explosieve vaten. Een kogel laat een vat ontploffen, vijanden in de straal raken gewond en naburige vaten gaan mee.
## Draaien: godot --headless --path . -s tests/vat_test.gd

var main: Node
var frames := 0
var fails := 0
var e1: Node
var e2: Node
var v1: Node
var v2: Node
var far: Node
var hp1 := 0.0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		push_error("VAT TEST: " + msg)


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _spawn_enemy(pos: Vector3) -> Node:
	var e: Node = load("res://scenes/enemy.tscn").instantiate()
	e.call("setup", "rifle", 1)
	e.position = pos
	main.add_child(e)
	return e


func _process(_dt: float) -> bool:
	frames += 1
	var game = root.get_node("Game")
	if frames == 3:
		main.begin()
	if frames == 8:
		var n: int = game.barrels.size()
		_check(n >= 10, "te weinig vaten op de kaart (%d)" % n)
		for b in game.barrels:
			_check(absf(b.position.x) > 6.0 and b.position.z > -22.0, "vat staat op een verkeerde plek: %s" % str(b.position))
		# vat 1 en 2 vlak bij elkaar, vat 3 ver weg
		var barrel_script: Script = load("res://scripts/barrel.gd")
		v1 = barrel_script.new()
		v1.spot = Vector3(10, 0, 40)
		v1.position = v1.spot
		main.add_child(v1)
		v2 = barrel_script.new()
		v2.spot = Vector3(12, 0, 40)
		v2.position = v2.spot
		main.add_child(v2)
		far = barrel_script.new()
		far.spot = Vector3(40, 0, 60)
		far.position = far.spot
		main.add_child(far)
		game.barrels.append_array([v1, v2, far])
		e1 = _spawn_enemy(Vector3(10, 0, 42))
		e2 = _spawn_enemy(Vector3(30, 0, 30))
		hp1 = e1.hp
		# een echte kogel op schouderhoogte moet het vat raken (niet eroverheen vliegen)
		var bullet_script: Script = load("res://scripts/bullet.gd")
		bullet_script.call("fire", main, Vector3(10, 1.35, 36), 0.0, 75.0, 500.0, 1.0, true)
		v1.call("hit", 10.0, Vector3.RIGHT, true)
		_check(is_instance_valid(v1) and not v1.lit, "een zwak schot laat het vat al ontploffen")
	if frames == 40:
		_check(not is_instance_valid(v1) or v1.is_queued_for_deletion(), "vat 1 is niet ontploft")
		_check(not is_instance_valid(v2) or v2.is_queued_for_deletion(), "naburig vat ging niet mee (kettingreactie)")
		_check(is_instance_valid(far) and not far.is_queued_for_deletion(), "ver vat is ten onrechte ontploft")
		_check(e1.hp < hp1 or e1.dead, "vijand naast het vat raakte niet gewond")
		_check(e2.hp == e2.max_hp, "vijand ver weg raakte gewond")
		_check(float(e1.get("alert_t")) > 0.0 or e1.dead, "vijanden worden niet gewaarschuwd")
		_check(not game.barrels.has(v1), "vat staat nog in de lijst")
		# nieuwe golf: opgeblazen vaten komen terug
		var real: Node = game.barrels[0]
		real.call("ignite", 0.0)
		var before: int = game.barrels.size()
		_check(before == game.barrels.size() and not game.barrels.has(real), "opgeblazen vat staat nog in de lijst")
		load("res://scripts/barrel.gd").call("populate", main)
		_check(game.barrels.size() > before, "vaten komen niet terug (%d -> %d)" % [before, game.barrels.size()])
		if fails == 0:
			print("VAT TEST PASS: ontploffing, schade, kettingreactie en terugkeer")
		quit(1 if fails > 0 else 0)
	return false
