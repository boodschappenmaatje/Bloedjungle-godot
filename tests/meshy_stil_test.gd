extends SceneTree
## Meshy-speler: na rennen, lopen of sprinten moet stil de hele houding terugzetten (benen en armen), niet alleen romp en hoofd.
## Draaien: godot --headless --path . -s tests/meshy_stil_test.gd --fixed-fps 60

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("MESHY STIL TEST: " + message)


func _bones(m: SoldierModel) -> Dictionary:
	var skel: Skeleton3D = m.find_children("*", "Skeleton3D", true, false)[0]
	var d := {}
	for n in ["mixamorig_LeftUpLeg", "mixamorig_RightUpLeg", "mixamorig_LeftLeg", "mixamorig_RightLeg", "mixamorig_LeftFoot", "mixamorig_RightFoot", "mixamorig_LeftArm", "mixamorig_RightArm"]:
		d[n] = skel.get_bone_pose_rotation(skel.find_bone(n))
	return d


func _run() -> void:
	GameSettings.values["soldaat"] = "meshy"
	var vers := SoldierModel.new()
	root.add_child(vers)
	vers.setup(Color("4b5a2c"), "m1911", "speler:uniform")
	_check(vers.meshy_player, "Meshy-speler niet geladen")
	for _i in 30:
		vers.play("stil")
		await process_frame
	var rust := _bones(vers)
	var idle: Animation = vers.anim.get_animation("stil")
	var skel: Skeleton3D = vers.find_children("*", "Skeleton3D", true, false)[0]
	_check(idle.get_track_count() >= skel.get_bone_count(), "stil heeft maar %d sporen voor %d botten" % [idle.get_track_count(), skel.get_bone_count()])
	for loop in ["rennen", "lopen", "sprinten"]:
		var m := SoldierModel.new()
		root.add_child(m)
		m.setup(Color("4b5a2c"), "m1911", "speler:uniform")
		for _i in 40:
			m.play(loop, 0.2, 1.0)
			await process_frame
		var onderweg := _bones(m)
		var verschil_onderweg := 0.0
		for n in rust:
			verschil_onderweg = maxf(verschil_onderweg, (rust[n] as Quaternion).angle_to(onderweg[n]))
		_check(verschil_onderweg > 0.3, "%s: lijkt niet op bewegen (%.2f rad)" % [loop, verschil_onderweg])
		for _i in 90:
			m.play("stil")
			await process_frame
		var daarna := _bones(m)
		for n in rust:
			var d: float = (rust[n] as Quaternion).angle_to(daarna[n])
			_check(d < 0.12, "%s -> stil: %s staat %.2f rad van de rusthouding (blijft hangen)" % [loop, n, d])
		m.queue_free()
	# NVIDIA-bewegingen op het Meshy-skelet: opzij, achteruit en afremmen
	_check(vers.nv, "NVIDIA-bewegingen staan niet aan voor de Meshy-speler")
	for n in ["zij_links", "zij_rechts", "terug", "draai_links", "draai_rechts", "stoppen"]:
		_check(vers.anim.has_animation(n), "clip %s ontbreekt" % n)
	for r in [[1.4, "zij_links"], [-1.4, "zij_rechts"], [2.5, "terug"]]:
		var m := SoldierModel.new()
		root.add_child(m)
		m.setup(Color("4b5a2c"), "m1911", "speler:uniform")
		for _i in 40:
			_check(m.play_nv_move(r[0], 2.0), "play_nv_move(%s) deed niets" % r[0])
			await process_frame
		_check(m.current == r[1], "rel %s: speelt %s, verwacht %s" % [r[0], m.current, r[1]])
		var beweging := _bones(m)
		var v := 0.0
		for n in rust:
			v = maxf(v, (rust[n] as Quaternion).angle_to(beweging[n]))
		_check(v > 0.25, "%s: lijkt niet op bewegen (%.2f rad)" % [r[1], v])
		for _i in 150:
			m.play("stil")
			await process_frame
		var rust2 := _bones(m)
		for n in rust:
			var d: float = (rust[n] as Quaternion).angle_to(rust2[n])
			_check(d < 0.12, "%s -> stil: %s staat %.2f rad van de rusthouding" % [r[1], n, d])
		_check(m.current == "stil", "%s -> stil: huidige clip is %s" % [r[1], m.current])
		m.queue_free()
	vers.queue_free()
	if failures.is_empty():
		print("MESHY STIL TEST OK: na rennen, lopen, sprinten, opzij en achteruit staat de Meshy-speler weer in de rusthouding")
	quit(1 if not failures.is_empty() else 0)
