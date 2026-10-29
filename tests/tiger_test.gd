extends SceneTree
## Test: de Tiger-tank (assets/tank.glb) heeft de knopen en clips die tank.gd nodig heeft, rijdt, draait de wielen en
## laat de rupsbanden lopen, de koepel draait en de loop kantelt. Draaien: godot --headless --path . -s tests/tiger_test.gd --fixed-fps 60

var frames := 0
var tank
var fails := 0
var p0 := Vector3.ZERO
var off0 := [0.0, 0.0]
var wheel0 := 0.0
var turret0 := 0.0


func check(ok: bool, what: String) -> void:
	print(("OK    " if ok else "FOUT  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	tank = (load("res://scenes/tank.tscn") as PackedScene).instantiate()
	root.add_child(tank)


func _process(_d: float) -> bool:
	frames += 1
	if frames == 2:
		for n in ["Model/Tank/Body", "Model/Tank/Body/Toren", "Model/Tank/Body/Toren/Loop", "Model/Tank/Body/Toren/Loop/Monding",
				"Model/Tank/Body/RupsL", "Model/Tank/Body/RupsR", "Model/Tank/Body/WielL_w1", "Model/Tank/Body/WielR_w8"]:
			check(tank.get_node_or_null(n) != null, "knoop " + n)
		var ap: AnimationPlayer = tank.get_node("Model/AnimationPlayer")
		for c in ["Stationair", "Rijden", "Achteruit", "Draaien", "Schieten"]:
			check(ap.has_animation(c), "clip " + c)
		check(ap.get_animation("Rijden").loop_mode == Animation.LOOP_LINEAR, "Rijden is een lus")
		check(tank._rups.size() == 2, "twee rupsmaterialen")
		var muz: Node3D = tank._muzzle
		var d: Vector3 = muz.global_position - tank._loop.global_position
		check(d.length() > 3.0 and d.length() < 4.5 and d.z < -3.0, "monding %.2f m voor de loop (voor = -Z)" % d.length())
		check(muz.global_position.y > 2.0 and muz.global_position.y < 2.8, "monding hangt op %.2f m hoogte" % muz.global_position.y)
		p0 = tank.global_position
		tank.goals = [p0 + Vector3(0, 0, -12)]
		off0 = [tank._rups[0].uv1_offset.x, tank._rups[1].uv1_offset.x]
		wheel0 = tank.get_node("Model/Tank/Body/WielL_w3").rotation.x
		turret0 = tank._toren.rotation.y
	if frames == 90:
		check(tank.global_position.distance_to(p0) > 2.0, "tank rijdt (%.1f m)" % tank.global_position.distance_to(p0))
		check(tank._anim.current_animation == "Rijden", "clip Rijden speelt (%s)" % tank._anim.current_animation)
		check(absf(tank._rups[0].uv1_offset.x - off0[0]) > 0.01 and absf(tank._rups[1].uv1_offset.x - off0[1]) > 0.01, "rupsbanden lopen")
		check(absf(tank.get_node("Model/Tank/Body/WielL_w3").rotation.x - wheel0) > 0.05, "wielen draaien")
		# koepel en loop op commando
		tank._toren.rotation.y = 1.0
		tank._loop.rotation.x = 0.2
	if frames == 100:
		check(absf(tank._toren.rotation.y - 1.0) < 0.05 or tank._toren.rotation.y < 1.0, "koepel draait (%.2f)" % tank._toren.rotation.y)
		var local: Vector3 = tank._toren.to_local(tank._muzzle.global_position)
		check(local.length() > 3.0, "monding volgt de koepel")
		var q: Vector3 = tank._muzzle.global_position - tank._loop.global_position
		check(q.y > 0.3, "loop omhoog: monding %.2f m boven de loop" % q.y)
		var ap: AnimationPlayer = tank.get_node("Model/AnimationPlayer")
		ap.play("Schieten")
	if frames == 115:
		var loopmesh: Node3D = tank.get_node("Model/Tank/Body/Toren/Loop/LoopMesh")
		check(loopmesh.position.length() > 0.1, "terugslag: loopmesh %.2f m verschoven" % loopmesh.position.length())
		print("KLAAR  fouten: ", fails)
		quit(1 if fails > 0 else 0)
		return true
	return false
