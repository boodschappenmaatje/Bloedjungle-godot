extends SceneTree
## Test: speler, soldaten, vijanden en voertuigen vullen de pushers-lijst van de struiken, varens en het gras; de lijst is
## leeg als niemand in de buurt is of als buigen uit staat (bouwmodus).
## Draaien: godot --headless --path . -s tests/struiken_buigen_test.gd --fixed-fps 60

var main: Node
var game: Node
var F: GDScript   # niet via class_name: dit testscript wordt gecompileerd voordat de autoloads er zijn
var frames := 0
var fails := 0
var fake: Node3D


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		push_error("STRUIKEN TEST FAIL: " + msg)


func _list(kind: String) -> PackedVector4Array:
	return F.get("_mats")[kind].get_shader_parameter("pushers")


func _initialize() -> void:
	F = load("res://scripts/foliage.gd")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	game = root.get_node("Game")


func _process(_d: float) -> bool:
	frames += 1
	if frames == 3:
		main.begin()
	if frames == 150:
		var p: Node3D = game.player
		p.global_position = Vector3(45, 0, -60)
		fake = Node3D.new()
		fake.add_to_group("voertuigen")
		main.add_child(fake)
		fake.global_position = Vector3(48, 0, -60)
		F.call("update_pushers", p, self)
		for k in ["leaf", "fern", "palm"]:
			_check(F.get("_mats").has(k), "materiaal " + k + " bestaat niet")
			var l := _list(k)
			_check(l.size() == 8, k + ": lijst heeft 8 plekken")
			_check(l[0].w > 0.0 and absf(l[0].x - 45.0) < 0.01 and absf(l[0].y + 60.0) < 0.01, k + ": speler staat vooraan in de lijst: " + str(l[0]))
			_check(l[1].w > 0.0 and absf(l[1].x - 48.0) < 0.01 and l[1].z > 1.5, k + ": voertuig met grote straal als tweede: " + str(l[1]))
			_check(l[2].w == 0.0, k + ": rest is leeg")
		_check(not F.get("_mats").has("bark") or not F.get("_mats")["bark"].get_shader_parameter("pushers") is PackedVector4Array or _list("bark")[0].w == 0.0, "stam buigt niet")
		var gm = (load("res://scripts/grass_field.gd") as GDScript).get("_material")
		if gm:
			_check((gm.get_shader_parameter("pushers") as PackedVector4Array)[0].w > 0.0, "gras krijgt dezelfde lijst")
		fake.global_position = Vector3(45 + 40, 0, -60)   # ver weg: buiten bereik
		F.call("update_pushers", p, self)
		_check(_list("leaf")[1].w == 0.0, "voertuig buiten bereik buigt niets")
		F.call("update_pushers", p, self, false)
		_check(_list("leaf")[0].w == 0.0, "met buigen uit blijft de lijst leeg")
		F.set("push_enabled", false)
		F.call("update_pushers", p, self)
		_check(_list("leaf")[0].w == 0.0, "push_enabled = false: lijst leeg")
		F.set("push_enabled", true)
		print("STRUIKEN TEST ", "OK" if fails == 0 else "%d FOUT(EN)" % fails)
		quit(1 if fails > 0 else 0)
		return true
	return false
