extends SceneTree
## Test: automatische kwaliteitstrap (Atmosphere.step_down): elke trap zet meer uit, trap 0 is weer de gekozen grafiek,
## en een nieuwe grafiekkeuze zet de trap terug. Draaien: godot --headless --path . -s tests/kwaliteit_test.gd --fixed-fps 60

var main: Node
var frames := 0
var fails := 0


func _initialize() -> void:
	GameSettings.set_value("quality", "ultra")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		push_error("KWALITEIT TEST: " + msg)


func _process(_d: float) -> bool:
	frames += 1
	if frames == 3:
		main.begin()
	if frames == 10:
		var A: GDScript = load("res://scripts/atmosphere.gd")   # dynamisch: het script gebruikt autoloads die bij het compileren van dit testbestand nog niet bestaan
		var atm: Node = get_first_node_in_group("atmosphere")
		var env: Environment = atm.get("_env")
		var sun: DirectionalLight3D = atm.get("_sun")
		A.set("tier", 0)
		atm.apply_settings()
		_check(env.glow_enabled, "ultra: gloed hoort aan")
		_check(sun.shadow_enabled, "ultra: zonschaduw hoort aan")
		var dist0 := sun.directional_shadow_max_distance
		_check(atm.step_down(), "trap 1")
		_check(not env.glow_enabled and sun.directional_shadow_mode == DirectionalLight3D.SHADOW_ORTHOGONAL, "trap 1: gloed uit, 1 schaduwlaag")
		_check(atm.step_down(), "trap 2")
		_check(sun.directional_shadow_max_distance <= 28.0 and dist0 > 28.0, "trap 2: schaduwafstand korter")
		_check(atm.step_down() and atm.step_down(), "trap 3 en 4")
		_check(not sun.shadow_enabled, "trap 4: zonschaduw uit")
		_check(not atm.step_down() and A.get("tier") == A.get("TIER_MAX"), "geen trap 5")
		# opnieuw toepassen houdt de trap vast (menu openen/sluiten verandert niets)
		atm.apply_settings()
		_check(not sun.shadow_enabled, "trap blijft na apply_settings")
		# nieuwe grafiekkeuze: terug naar het begin
		GameSettings.set_value("quality", "high")
	if frames == 14:
		_check(load("res://scripts/atmosphere.gd").get("tier") == 0, "trap terug op 0 na nieuwe grafiekkeuze")
		print("KLAAR, fouten: ", fails)
		quit(1 if fails > 0 else 0)
	return false
