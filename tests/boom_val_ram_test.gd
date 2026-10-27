extends SceneTree
## Test: een voertuig dat hard genoeg tegen een stam rijdt velt de boom (van het voertuig af, zonder stam met botsing);
## te langzaam of niet tegen een boom doet niets. Draaien: godot --headless --path . -s tests/boom_val_ram_test.gd --fixed-fps 60

var main: Node
var game: Node
var F: GDScript   # niet via class_name: dit testscript wordt gecompileerd voordat de autoloads er zijn
var frames := 0
var fails := 0
var e: Dictionary
var car: CharacterBody3D
var spot := Vector3.ZERO


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		push_error("BOOM VAL RAM TEST FAIL: " + msg)


func _initialize() -> void:
	F = load("res://scripts/foliage.gd")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	game = root.get_node("Game")


func _spawn(at: Vector3) -> void:
	if car != null:
		car.free()
	car = CharacterBody3D.new()
	car.collision_layer = 0
	car.collision_mask = 128
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(1.8, 1.0, 3.6)
	cs.shape = b
	cs.position.y = 0.6
	car.add_child(cs)
	main.add_child(car)
	car.global_position = at


func _drive(speed: float, min_speed: float, frames_n: int) -> void:
	for i in frames_n:
		car.velocity = Vector3(speed, 0, 0)
		car.move_and_slide()
		F.call("ram", car, speed, min_speed)


func _process(_d: float) -> bool:
	frames += 1
	if frames == 3:
		main.begin()
	if frames == 100:
		for key in F.get("_reg"):
			for en: Dictionary in F.get("_reg")[key]:
				if e.is_empty() and not String(en["vn"]).begins_with("Boom"):
					e = en
		spot = e["xf"].origin
		# te langzaam: niets
		_spawn(spot + Vector3(-6, 0, 0))
		_drive(3.0, 6.0, 120)
		_check(not e["felled"], "te langzaam velt niets")
	if frames == 101:
		# voldoende snelheid: de palm valt, van het voertuig af (+x)
		_spawn(spot + Vector3(-6, 0, 0))
	if frames == 102:
		_drive(8.0, 6.0, 120)
		_check(e["felled"], "voertuig op 8 m/s velt de palm")
	if frames == 110:
		var dir := Vector3.ZERO
		for n in F.get("_root").get_children():
			if n.get_script() and String(n.get_script().resource_path).ends_with("boom_val.gd"):
				dir = n.get("_dir")
				_check(n.get("_solid") == false, "stam van een geramde boom heeft geen botsing")
		_check(dir.x > 0.9, "valt van het voertuig af (+x): " + str(dir))
		print("BOOM VAL RAM TEST ", "OK" if fails == 0 else "%d FOUT(EN)" % fails)
		quit(1 if fails > 0 else 0)
		return true
	return false
