extends SceneTree
## Test: PerfGovernor bij een tempo dat niet door tekenen komt. Beeldsnelheid vastgezet op 20 fps (kan nooit sneller, ook niet met
## minder pixels): de resolutie zakt een paar stappen, merkt dat het niets oplevert, springt terug naar de gekozen stand en de
## kwaliteitstrap blijft op 0 (platform-limiet). Duurt ~25 s echte tijd.
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
	if secs > 25.0:
		var A: GDScript = load("res://scripts/atmosphere.gd")
		var tier: int = A.get("tier")
		var scale := root.get_viewport().scaling_3d_scale
		print("na %.0f s: resolutie %.2f, trap %d, fps %d, staat %s" % [secs, scale, tier, Engine.get_frames_per_second(), root.get_node("Game").state])
		var P: GDScript = load("res://scripts/perf_governor.gd")
		if scale < 0.95:
			fails += 1
			push_error("KWALITEIT REGEL: resolutie bleef laag (%.2f) terwijl minder pixels niets oplevert" % scale)
		if tier != 0:
			fails += 1
			push_error("KWALITEIT REGEL: verwacht trap 0 bij een platform-limiet, kreeg %d" % tier)
		if not P.get("platform_limited"):
			fails += 1
			push_error("KWALITEIT REGEL: platform-limiet niet herkend")
		print("KLAAR, fouten: ", fails)
		quit(1 if fails > 0 else 0)
		return true
	return false
