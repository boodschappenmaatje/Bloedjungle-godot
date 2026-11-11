extends SceneTree
## Rijden moet vloeiend zijn (11 november 2026, opname van Dennis: "hij hapert een beetje").
##
## Oorzaak: de jeep en de tank reden per natuurkundige tik (60 per seconde) terwijl de camera per beeld volgt
## (op de iPhone ca. 90 beelden per seconde). Een beeld met een tik en een beeld zonder tik wisselen elkaar dan af:
## de jeep staat soms stil en maakt soms een dubbele stap, en de camera met zijn zachte volging trilt mee.
##
## Deze test laat de motor met een vast beeldtempo draaien dat NIET bij de natuurkundige tik past (89 beelden per seconde,
## zoals de overlay op de iPhone) en meet per beeld hoever de voertuigen rijden en waar ze op het scherm staan.
##
## godot --headless --path . --script tests/rijden_vloeiend_test.gd --fixed-fps 89

var fails := 0


func _check(label: String, yes: bool) -> void:
	print(("OK " if yes else "FOUT ") + label)
	if not yes:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## Rijdt `secs` seconden rechtdoor en meet per beeld: de afgelegde afstand en de plek op het scherm t.o.v. de camera.
func _meet(vehicle: Node3D, cam: Camera3D, game: Node, secs: float) -> Dictionary:
	var fps: float = Engine.get_frames_per_second()
	var steps: Array = []     # afstand per beeld (m)
	var scr: Array = []       # schermplek van het voertuig (px)
	var last: Vector3 = vehicle.global_position
	var n := int(secs * 89.0)
	for i in n:
		await process_frame
		var pos: Vector3 = vehicle.global_position
		var flat := Vector3(pos.x - last.x, 0.0, pos.z - last.z)
		steps.append(flat.length())
		scr.append(cam.unproject_position(pos))
		last = pos
	# de eerste 2,4 seconden optrekken en de camera laten volgen telt niet mee
	var skip := int(2.4 * 89.0)
	var d: Array = steps.slice(skip)
	var mean := 0.0
	for x in d:
		mean += x
	mean /= maxf(1.0, float(d.size()))
	var var_sum := 0.0
	for x in d:
		var_sum += (x - mean) * (x - mean)
	var cv: float = sqrt(var_sum / maxf(1.0, float(d.size()))) / maxf(mean, 0.0001)
	# trilling op het scherm: tweede verschil van de schermplek (px per beeld per beeld)
	var s: Array = scr.slice(skip)
	var jit := 0.0
	var cnt := 0
	for i in range(2, s.size()):
		var a: Vector2 = s[i - 2]
		var b: Vector2 = s[i - 1]
		var c: Vector2 = s[i]
		jit += ((c - b) - (b - a)).length_squared()
		cnt += 1
	var rms: float = sqrt(jit / maxf(1.0, float(cnt)))
	return {"cv": cv, "mean": mean, "rms": rms, "n": d.size(), "speed": float(vehicle.get("_speed"))}


func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	main.begin()
	await _frames(12)
	var game = root.get_node("Game")
	game.state = "play"
	var player = game.player
	var cam: Camera3D = main.get_node("Camera")
	# de aanraakbediening zet Game.move elk beeld terug op nul: uit, dan sturen wij
	for n in root.find_children("*", "", true, false):
		if n.get_script() and String(n.get_script().resource_path).ends_with("touch_sticks.gd"):
			n.set_process(false)
			n.set_process_input(false)
			n.set_process_unhandled_input(false)

	for kind in ["jeep", "tank"]:
		var v = load("res://scenes/%s.tscn" % kind).instantiate()
		main.add_child(v)
		v.global_position = Vector3(100.0, 0.0, -10.0)   # open veld: 45 m vrij naar -z
		player.global_position = v.global_position
		await _frames(3)
		v._toggle()
		_check("%s: bestuurd" % kind, v.driven)
		cam.snap_to_player()
		game.move = Vector2(0.0, -1.0)    # rechtdoor naar -z (de neus van het voertuig)
		var r: Dictionary = await _meet(v, cam, game, 3.7)
		print("%s: beeldtempo %.0f, stap/beeld gemiddeld %.4f m, spreiding %.3f, trilling op scherm %.3f px" % [kind, Engine.get_frames_per_second(), r.mean, r.cv, r.rms])
		_check("%s: rijdt echt (stap per beeld > 0,05 m)" % kind, r.mean > 0.05)
		# vroeger (per natuurkundige tik) was de spreiding 0,70 en de trilling 0,3 tot 0,4 px: het ene beeld een stap, het volgende niets
		_check("%s: elk beeld dezelfde stap (spreiding < 0,02)" % kind, r.cv < 0.02)
		_check("%s: schermplek trilt niet (< 0,05 px per beeld per beeld)" % kind, r.rms < 0.05)
		_check("%s: afstand per beeld = snelheid x beeldtijd (%.4f m, verwacht %.4f m)" % [kind, r.mean, r.speed / 89.0], absf(r.mean - r.speed / 89.0) < 0.03 * r.speed / 89.0)
		# een beeldsprong (app terug uit de achtergrond) wordt gekapt op 1/30 s: hij rijdt niet door een muur heen
		v._process(0.5)
		_check("%s: beeldsprong van 0,5 s wordt gekapt op 1/30 s" % kind, absf(float(v.get("_stap_k")) - (1.0 / 30.0) / 0.5) < 0.001)
		game.move = Vector2.ZERO
		v._toggle()
		v.queue_free()
		await _frames(3)

	print("klaar, fouten: ", fails)
	quit(1 if fails > 0 else 0)
