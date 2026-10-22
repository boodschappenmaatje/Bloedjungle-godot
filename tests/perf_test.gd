extends SceneTree
## Test: prestatiemodus. Statistieken, piekdetectie met de gebeurtenis die eraan voorafging, en het tellen van kogels.
## Draaien: godot --headless --path . -s tests/perf_test.gd

var fails := 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		push_error("PERF TEST: " + msg)


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame  # in _initialize() staat de wortel nog niet in de boom
	var script: Script = load("res://scripts/perf_monitor.gd")
	# 1. statistieken: 95 beelden van 10 ms en 5 van 40 ms
	var s := PackedFloat32Array()
	for i in 95:
		s.append(10.0)
	for i in 5:
		s.append(40.0)
	var st: Dictionary = script.call("stats_of", s)
	_check(absf(st.avg - 11.5) < 0.01, "gemiddelde klopt niet: %f" % st.avg)
	_check(st.worst == 40.0 and st.p95 == 40.0, "p95 of slechtste klopt niet: %f / %f" % [st.p95, st.worst])
	_check(script.call("stats_of", PackedFloat32Array())["avg"] == 0.0, "lege reeks geeft geen nul")
	# 2. gebeurtenissen: dezelfde binnen 400 ms worden samengevoegd
	script.set("notes", [])
	script.call("note", "vijand gespawnd")
	script.call("note", "vijand gespawnd")
	script.call("note", "vijand gespawnd")
	var notes: Array = script.get("notes")
	_check(notes.size() == 1 and notes[0].n == 3, "gebeurtenissen worden niet samengevoegd")
	# 3. een piek na het opstarten wordt vastgelegd met de gebeurtenis ervoor; een gewoon beeld niet
	OS.delay_msec(4300)  # de eerste vier seconden tellen niet mee (laden)
	root.get_node("Game").state = "play"
	var mon: Control = script.new()
	root.add_child(mon)
	script.call("note", "golf 1 begint")
	mon.call("record_frame", 16.0)
	_check(mon.get("spikes").size() == 0, "een normaal beeld is als piek gemeld")
	mon.call("record_frame", 60.0)
	var spikes: Array = mon.get("spikes")
	_check(spikes.size() == 1, "de piek is niet vastgelegd")
	if spikes.size() == 1:
		_check(absf(spikes[0].ms - 60.0) < 0.01 and str(spikes[0].after) == "golf 1 begint", "piek mist de gebeurtenis ervoor: '%s'" % str(spikes[0].after))
	# 4. kogels worden geteld en weer afgetrokken
	var b: Script = load("res://scripts/bullet.gd")
	var before: int = script.get("bullets_live")
	var holder := Node3D.new()
	root.add_child(holder)
	b.call("fire", holder, Vector3.ZERO, 0.0, 10.0, 0.0, 5.0, true)
	_check(int(script.get("bullets_live")) == before + 1, "kogel wordt niet geteld")
	holder.queue_free()
	await process_frame
	await process_frame
	_check(int(script.get("bullets_live")) == before, "kogel wordt niet afgetrokken")
	if fails == 0:
		print("PERF TEST PASS: statistieken, pieken met oorzaak en kogeltelling")
	quit(1 if fails > 0 else 0)
