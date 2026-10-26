extends SceneTree
## Test: het spel zet nooit een eigen beeldsnelheidsgrens naast vsync (dat gaf een vaste 30 fps op de iPhone).
## Draaien: godot --headless --path . -s tests/beeldsnelheid_test.gd


func _initialize() -> void:
	var fails := 0
	var GS: GDScript = load("res://scripts/game_settings.gd")
	for hz in ["60", "120"]:
		GS.call("set_value", "hz", hz)
		Engine.max_fps = 120
		GS.call("apply_hz")
		if Engine.max_fps != 0:
			fails += 1
			push_error("FAIL beeldsnelheid: hz=%s gaf max_fps %d, verwacht 0 (geen eigen grens)" % [hz, Engine.max_fps])
	GS.call("set_value", "hz", "60")
	print("KLAAR, fouten: ", fails)
	quit(1 if fails > 0 else 0)
