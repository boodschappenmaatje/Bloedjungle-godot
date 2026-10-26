extends SceneTree
## Test: de diagnose-run (scripts/diagnose.gd) loopt alle fasen door, schrijft een rapport, zet zichzelf uit en zet alles
## terug zoals het was (zichtbaarheid, resolutie, schaduw, mist).
## Draaien: godot --headless --path . -s tests/diagnoserun_test.gd   (zonder --fixed-fps; duurt ~40 s echte tijd)

var main: Node
var t0 := 0
var fails := 0
var before := {}


func _snapshot() -> Dictionary:
	var vp := root.get_viewport()
	var procs := 0
	for n in root.find_children("*", "Node", true, false):
		if n.is_processing():
			procs += 1
	var atm: Node = get_first_node_in_group("atmosphere")
	var layers := 0
	for n in root.find_children("*", "CanvasLayer", true, false):
		if n.visible:
			layers += 1
	return {"scale": vp.scaling_3d_scale, "sun": atm._sun.shadow_enabled, "fog": atm._env.fog_enabled, "procs": procs, "layers": layers, "disable3d": vp.disable_3d}


func _initialize() -> void:
	var PM: GDScript = load("res://scripts/perf_monitor.gd")
	PM.set("report_dir", "user://test_prestatie")
	GameSettings.set_value("diag", "on")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_d: float) -> bool:
	if t0 == 0:
		t0 = Time.get_ticks_msec()
		main.begin()
		return false
	var secs := (Time.get_ticks_msec() - t0) / 1000.0
	if secs < 5.0:
		before = _snapshot()
		return false
	var found := ""
	for f in DirAccess.get_files_at("user://test_prestatie"):
		if f.begins_with("diagnose_"):
			found = f
	if found == "" and secs < 120.0:
		return false
	if found == "":
		fails += 1
		push_error("FAIL diagnose: na %.0f s nog geen rapport" % secs)
	else:
		var body := FileAccess.get_file_as_string("user://test_prestatie/" + found)
		for need in ["basis (alles aan)", "zon-schaduw uit", "jungle onzichtbaar", "HUD en menu's uit", "kaal beeld", "Grootste winst"]:
			if not body.contains(need):
				fails += 1
				push_error("FAIL diagnose: rapport mist '%s'" % need)
		await create_timer(1.0).timeout
		var after := _snapshot()
		for k in ["scale", "sun", "fog", "layers", "disable3d"]:
			if after[k] != before[k]:
				fails += 1
				push_error("FAIL diagnose: %s niet teruggezet (%s -> %s)" % [k, before[k], after[k]])
		if GameSettings.get_value("diag") != "off":
			fails += 1
			push_error("FAIL diagnose: instelling staat nog aan")
	print("KLAAR, fouten: ", fails)
	quit(1 if fails > 0 else 0)
	return true
