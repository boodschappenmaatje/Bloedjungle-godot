extends SceneTree
## Test: de FPS-keuzes 30/60/90/120 (Instellingen > Beeldsnelheid). Het doel mag nooit boven de keuze liggen, het scherm
## kan het doel verlagen, en bij een scherm dat zijn snelheid niet meldt (iPhone via Xogot: -1) werkt het spel naar 60
## tot het echt boven de gevraagde snelheid komt. Er is geen eigen beeldsnelheidsgrens (Engine.max_fps = 0).
## Draaien: godot --headless --path . -s tests/fps_keuze_test.gd

var fails := 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		push_error("FPS TEST: " + msg)


func _initialize() -> void:
	var gs: Script = load("res://scripts/game_settings.gd")
	gs.call("get_value", "hz")  # laadt de instellingen
	var values: Dictionary = gs.get("values")
	var reported := DisplayServer.screen_get_refresh_rate()
	for hz in [30, 60, 90, 120]:
		values["hz"] = str(hz)
		gs.set("observed_peak", 60.0)
		var t: float = gs.call("target_fps")
		_check(t <= float(hz), "doel %f ligt boven de keuze %d" % [t, hz])
		_check(t >= 30.0, "doel %f onder 30" % t)
		if reported <= 0.0:
			# scherm meldt niets: tot 60 gewoon de keuze, daarboven 60 totdat het spel echt snel genoeg gaat
			var expected := float(hz) if hz <= 60 else 60.0
			_check(t == expected, "onbekend scherm, keuze %d: doel %f in plaats van %f" % [hz, t, expected])
			if hz > 60:
				gs.set("observed_peak", float(hz))
				_check(float(gs.call("target_fps")) == float(hz), "keuze %d wordt niet gehaald terwijl het spel dat tempo draait" % hz)
	gs.call("apply_hz")
	_check(Engine.max_fps == 0, "er staat een eigen beeldsnelheidsgrens (%d)" % Engine.max_fps)
	var rows: Array = load("res://scripts/pause_menu.gd").get("ROWS")
	var hz_opts: Array = []
	for r in rows:
		if r[0] == "hz":
			hz_opts = (r[2] as Array).map(func(o): return o[0])
	_check(hz_opts == ["30", "60", "90", "120"], "menu biedt %s aan" % str(hz_opts))
	if fails == 0:
		print("FPS TEST PASS: 30/60/90/120 als doel, nooit boven de keuze, geen eigen grens")
	quit(1 if fails > 0 else 0)
