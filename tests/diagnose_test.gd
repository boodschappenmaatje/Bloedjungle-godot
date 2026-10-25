extends SceneTree
## Test: de Test-schakelaars in Instellingen (atmosphere.gd _apply_diagnose) zetten onderdelen uit en weer aan.
## Draaien: godot --headless --path . -s tests/diagnose_test.gd --fixed-fps 60

var main: Node
var frames := 0
var fails := 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		push_error("DIAGNOSE TEST FAIL: " + msg)


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_d: float) -> bool:
	frames += 1
	if frames == 3:
		main.begin()
	if frames == 20:
		var atm = get_nodes_in_group("atmosphere")[0]
		var palms := get_nodes_in_group("foliage_palm")
		var stad: Node3D = main.find_child("Stad", true, false)
		_check(palms.size() > 0 and stad != null, "geen jungle of stad")
		for k in ["t_sun", "t_jungle", "t_stad", "t_post"]:
			GameSettings.set_value(k, "off")
		atm.apply_settings()
		_check(not atm._sun.shadow_enabled, "zon-schaduw staat nog aan")
		_check(not (palms[0] as Node3D).visible, "jungle staat nog aan")
		_check(not stad.visible, "stad staat nog aan")
		_check(not atm._env.fog_enabled and not atm._env.glow_enabled, "nabewerking staat nog aan")
		for k in ["t_sun", "t_jungle", "t_stad", "t_post"]:
			GameSettings.set_value(k, "on")
		atm.apply_settings()
		_check(atm._sun.shadow_enabled, "zon-schaduw komt niet terug")
		_check((palms[0] as Node3D).visible and stad.visible and atm._env.fog_enabled, "onderdelen komen niet terug")
		print("DIAGNOSE TEST ", "OK" if fails == 0 else "%d FOUT" % fails)
		quit(1 if fails else 0)
	return false
