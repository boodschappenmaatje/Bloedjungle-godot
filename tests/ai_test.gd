extends SceneTree
## Test: groepsgedrag van de vijanden (dekking zoeken, flankeren, terugtrekken en helpen, gespreid aanvallen).
## Draaien: godot --headless --path . -s tests/ai_test.gd

var main: Node
var frames := 0
var fails := 0
var a: Node
var b: Node
var c: Node
var d: Node


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		push_error("AI TEST: " + msg)


func _spawn(kind: String, pos: Vector3) -> Node:
	var e: Node = load("res://scenes/enemy.tscn").instantiate()
	e.call("setup", kind, 1)
	e.position = pos
	main.add_child(e)
	return e


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_dt: float) -> bool:
	frames += 1
	var game = root.get_node("Game")
	if frames == 3:
		main.begin()
		game.build_credit = 5000
		game.builds.place("muur", Vector3(-8, 0, -14), 0.0)
		game.player.global_position = Vector3(-8, 0, -4)
		# 1. spreiding: schutters nemen om beurten de noord- en zuidpoort
		var zs := {}
		for i in 8:
			var e := _spawn("rifle", Vector3(50, 0, 50 + i))
			zs[signf(e.get("gate_z"))] = true
			e.queue_free()
		_check(zs.size() == 2, "schutters kiezen niet allebei de poorten")
		# 2. dekking: een geraakte schutter loopt naar een plek achter het gebouw
		a = _spawn("rifle", Vector3(-4, 0, -16))
		a.set("gate_z", 0.0)
		a.set("role", "assault")
		a.set("cover_cd", 0.0)
		a.call("hit", 20.0, Vector3.DOWN, true)
		# 3. terugtrekken en helpen
		b = _spawn("rifle", Vector3(20, 0, -3))
		b.set("role", "assault")
		b.set("gate_z", 0.0)
		c = _spawn("knife", Vector3(26, 0, -3))
		b.call("hit", b.get("max_hp") * 0.72, Vector3.RIGHT, true)  # hp onder 30 procent
		# 4. flankeren
		d = _spawn("rifle", Vector3(-8, 0, 8))
		d.set("role", "flank")
		d.set("gate_z", 0.0)
	if frames == 12:
		_check(str(a.get("mode")) == "cover", "geraakte schutter zoekt geen dekking (mode=%s)" % str(a.get("mode")))
		_check(str(b.get("mode")) == "retreat", "zwaar gewonde schutter trekt zich niet terug (mode=%s)" % str(b.get("mode")))
		_check(float(c.get("alert_t")) > 0.0, "de buurman wordt niet gewaarschuwd")
		_check(float(d.get("flank_left")) < 7.0, "flankeerder loopt niet om")
		d.call("hit", 9999.0, Vector3.RIGHT, true)
	if frames == 14:
		print("modes: ", a.get("mode"), " ", b.get("mode"), " flank_left ", d.get("flank_left"))
		if fails == 0:
			print("AI TEST PASS: dekking, terugtrekken met hulp, flankeren en gespreid aanvallen")
		quit(1 if fails > 0 else 0)
	return false
