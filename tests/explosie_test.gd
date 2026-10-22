extends SceneTree
## Test: explosie-afwerking. Weggeslingerde vijanden, een brandend vat met lont, het wrak, de kettingreactie met
## kleinere vuurballen en de limiet op gelijktijdige vuurballen. Draaien: godot --headless --path . -s tests/explosie_test.gd

var main: Node
var frames := 0
var fails := 0
var e1: Node
var e2: Node
var v1: Node
var v2: Node
var start1 := Vector3.ZERO
var wrecks_before := 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		push_error("EXPLOSIE TEST: " + msg)


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _barrel(pos: Vector3) -> Node:
	var b: Node = load("res://scripts/barrel.gd").new()
	b.spot = pos
	b.position = pos
	main.add_child(b)
	root.get_node("Game").barrels.append(b)
	return b


func _enemy(pos: Vector3) -> Node:
	var e: Node = load("res://scenes/enemy.tscn").instantiate()
	e.call("setup", "rifle", 1)
	e.position = pos
	main.add_child(e)
	return e


func _wreck_count() -> int:
	var fx: Script = load("res://scripts/fx.gd")
	var meshes: Array = [fx.call("_chunk", "Wrak1"), fx.call("_chunk", "Wrak2")]
	var n := 0
	for c in main.get_children():
		if c is MeshInstance3D and meshes.has((c as MeshInstance3D).mesh):
			n += 1
	return n


func _process(_dt: float) -> bool:
	frames += 1
	var game = root.get_node("Game")
	if frames == 3:
		main.begin()
	if frames == 8:
		# 1. animatie bestaat en duurt ~1,33 s
		var probe: Node = _enemy(Vector3(-40, 0, 50))
		var len_: float = probe.get("model").clip_length("explosie_dood")
		_check(absf(len_ - 1.333) < 0.1, "explosie_dood duurt %f s" % len_)
		probe.queue_free()
		# 2. brandend vat: een pistoolschot (26 van 40) zet hem in brand en hij ontploft na enkele seconden vanzelf
		v1 = _barrel(Vector3(30, 0, 40))
		v1.call("hit", 26.0, Vector3.RIGHT, true)
		_check(v1.get("burning") and not v1.get("lit"), "geraakt vat gaat niet branden of ontploft meteen")
		_check(v1.get("_flame") != null and is_instance_valid(v1.get("_flame")), "brandend vat heeft geen vlam")
		# 3. vijand dicht bij een vat dat ontploft vliegt weg met de explosie-animatie
		v2 = _barrel(Vector3(-30, 0, 40))
		e1 = _enemy(Vector3(-28, 0, 40))
		e1.set("hp", 1.0)
		start1 = e1.global_position
		e2 = _enemy(Vector3(-40, 0, 52))  # ver weg: gewoon dood-animatie niet nodig, blijft heel
		wrecks_before = _wreck_count()
		v2.call("ignite", 0.0)
	if frames == 14:
		_check(bool(e1.get("dead")), "vijand bij het vat is niet gestorven")
		_check(str(e1.get("model").get("current")) == "explosie_dood", "vijand speelt '%s' in plaats van explosie_dood" % str(e1.get("model").get("current")))
		_check(float(e2.get("hp")) == float(e2.get("max_hp")), "vijand ver weg raakte gewond")
		_check(_wreck_count() > wrecks_before, "ontploft vat laat geen wrak achter")
	if frames == 80:  # ~0,9 s later: weggeslingerd en geland
		var d: Vector3 = e1.global_position - start1
		_check(Vector2(d.x, d.z).length() > 2.0, "vijand is maar %.1f m weggeslingerd" % Vector2(d.x, d.z).length())
		_check(d.x > 0.0, "vijand vloog naar de explosie toe in plaats van ervan af (dx %.1f)" % d.x)
		_check(absf(e1.global_position.y) < 0.2, "vijand hangt nog in de lucht (y %.2f)" % e1.global_position.y)
		_check(is_instance_valid(v1) and not v1.get("lit"), "brandend vat ontploft al na 1 seconde")
	if frames == 300:
		# 4. het brandende vat is door zijn lont ontploft (na 2,6 tot 3,6 s)
		_check(not is_instance_valid(v1) or v1.is_queued_for_deletion() or v1.get("lit"), "brandend vat ontploft niet vanzelf")
	if frames == 302:
		# 4b. een vijand net buiten de straal schrikt (stilstaan) en zoekt dekking; een zware soldaat niet
		var near: Node = _enemy(Vector3(60, 0, 60))
		var heavy: Node = load("res://scenes/enemy.tscn").instantiate()
		heavy.call("setup", "heavy", 1)
		heavy.position = Vector3(60, 0, 62)
		main.add_child(heavy)
		var gm = root.get_node("Game")
		near.set("cover_cd", 0.0)
		gm.call("note_blast", Vector3(60, 0, 52), 5.5)  # 8 m en 10 m van de knal: buiten de straal, binnen het schrikbereik
		_check(float(near.get("stun_t")) > 0.0, "vijand net buiten de straal schrikt niet")
		_check(float(heavy.get("stun_t")) == 0.0, "zware soldaat laat zich toch storen")
		_check(str(near.get("model").get("current")) == "geraakt", "geschrokken vijand speelt geen schrikanimatie")
	if frames == 305:
		# 5. kettingreactie: een vat dat door een ander wordt aangestoken is 'chained'
		var a: Node = _barrel(Vector3(10, 0, 60))
		var b: Node = _barrel(Vector3(12, 0, 60))
		a.call("ignite", 0.0)
		_check(b.get("lit"), "buurvat is niet aangestoken")
		_check(b.get("chained"), "buurvat telt niet als kettingreactie")
		# 6. limiet op gelijktijdige vuurballen
		var fx: Script = load("res://scripts/fx.gd")
		for i in 8:
			fx.call("explosion", main, Vector3(0, 0, 70 + i), 1.0)
		_check(int(fx.get("_fireballs_live")) <= int(fx.get("MAX_FIREBALLS")), "meer dan het maximum aan vuurballen tegelijk (%d)" % int(fx.get("_fireballs_live")))
		if fails == 0:
			print("EXPLOSIE TEST PASS: wegvliegen, brandend vat met lont, wrak, ketting en vuurballimiet")
		quit(1 if fails > 0 else 0)
	return false
