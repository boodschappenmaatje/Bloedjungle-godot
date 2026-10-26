extends SceneTree
## Test: de kwaliteitstrap in PerfGovernor. Beeldsnelheid vastgezet op 20 fps (kan nooit sneller): de resolutie zakt naar 50%,
## daarna gaat er per ~4 s een onderdeel uit, en na twee trappen zonder winst stopt het (trap 2). Duurt ~30 s echte tijd.
## Draaien: godot --headless --path . -s tests/kwaliteit_regel_test.gd   (zonder --fixed-fps)

var main: Node
var t0 := 0
var fails := 0


func _initialize() -> void:
	GameSettings.set_value("quality", "ultra")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	Engine.max_fps = 20


func _process(_d: float) -> bool:
	Engine.max_fps = 20   # GameSettings.apply_hz zet hem steeds weer op 60
	if t0 == 0:
		t0 = Time.get_ticks_msec()
		main.begin()
		return false
	var secs := (Time.get_ticks_msec() - t0) / 1000.0
	if secs > 40.0:
		var A: GDScript = load("res://scripts/atmosphere.gd")
		var tier: int = A.get("tier")
		var scale := root.get_viewport().scaling_3d_scale
		print("na %.0f s: resolutie %.2f, trap %d, fps %d, staat %s" % [secs, scale, tier, Engine.get_frames_per_second(), root.get_node("Game").state])
		if scale > 0.51:
			fails += 1
			push_error("KWALITEIT REGEL: resolutie zakte niet naar 50%")
		if tier != 2:
			fails += 1
			push_error("KWALITEIT REGEL: verwacht trap 2 (twee trappen, dan stoppen zonder winst), kreeg %d" % tier)
		print("KLAAR, fouten: ", fails)
		quit(1 if fails > 0 else 0)
		return true
	return false
