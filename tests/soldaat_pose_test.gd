extends SceneTree
## Controleert SoldierPose op het VQ2-mannetje: de benen draaien naar de looprichting terwijl de romp naar voren blijft kijken,
## de benen keren terug naar 0 buiten het lopen en een treffer duwt de romp mee in de richting van de kogel.
## Draaien: godot --headless --path . -s tests/soldaat_pose_test.gd --fixed-fps 60

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("SOLDAAT POSE TEST: " + message)


var _snap := {}   # bonenaam -> positie na de laatste verwerking van SoldierPose (de eindpose die ook getekend wordt)


func _on_processed(m: SoldierModel) -> void:
	var skel: Skeleton3D = m.find_children("*", "Skeleton3D", true, false)[0]
	for i in skel.get_bone_count():
		_snap[skel.get_bone_name(i)] = skel.global_transform * skel.get_bone_global_pose(i).origin


func _bone_pos(_m: SoldierModel, name: String) -> Vector3:
	return _snap[name]


func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z).normalized()


func _run() -> void:
	GameSettings.values["soldaat"] = "vq2"
	var m := SoldierModel.new()
	root.add_child(m)
	m.setup(Color("4b5a2c"), "garand", "speler:uniform")   # kijkt naar +Z (rotation.y = 0)
	_check(m.pose != null, "VQ2-mannetje heeft geen SoldierPose")
	m.pose.modification_processed.connect(_on_processed.bind(m))
	m.play("lopen", 0.0)
	for _i in 10:
		await process_frame
	var base_sh := _flat(_bone_pos(m, "DEF-shoulderR") - _bone_pos(m, "DEF-shoulderL"))
	var base_toe := _flat(_bone_pos(m, "DEF-toeL") - _bone_pos(m, "DEF-footL"))
	_check(base_toe.dot(Vector2(0, 1)) > 0.8, "zonder draaiing wijzen de voeten niet vooruit: %s" % base_toe)
	m.set_leg_yaw(PI / 2.0)
	for _i in 40:
		await process_frame
	var toe := _flat(_bone_pos(m, "DEF-toeL") - _bone_pos(m, "DEF-footL"))
	var sh := _flat(_bone_pos(m, "DEF-shoulderR") - _bone_pos(m, "DEF-shoulderL"))
	_check(toe.dot(Vector2(1, 0)) > 0.7, "benen wijzen niet naar +X bij leg_yaw +90 graden: %s" % toe)
	_check(sh.dot(base_sh) > 0.97, "romp draait mee met de benen: %s" % sh)
	m.play("rollen", 0.0)
	_check(m.pose.leg_yaw == 0.0, "leg_yaw niet teruggezet buiten het lopen")
	m.play("stil", 0.0)
	m.set_leg_yaw(0.0)
	for _i in 40:
		await process_frame
	# treffer van voren (kogel vliegt naar -Z): romp en hoofd gaan naar achteren
	var base_lean := _bone_pos(m, "DEF-head").z - _bone_pos(m, "DEF-hips").z
	m.hit_reaction(Vector3(0, 0, -1), 1.0)
	var lowest := 99.0
	for _i in 12:
		await process_frame
		lowest = minf(lowest, _bone_pos(m, "DEF-head").z - _bone_pos(m, "DEF-hips").z)
	_check(m.pose.is_kicking(), "kick is niet actief na hit_reaction")
	_check(lowest < base_lean - 0.05, "hoofd gaat niet naar achteren bij een treffer van voren (%.3f t.o.v. %.3f)" % [lowest, base_lean])
	for _i in 120:
		await process_frame
	_check(not m.pose.is_kicking(), "kick dooft niet uit")
	await _check_holds()
	if failures.is_empty():
		print("SOLDAAT POSE TEST OK")
	else:
		print("SOLDAAT POSE TEST FAIL: ", failures.size())
	quit(1 if not failures.is_empty() else 0)


## Elk wapen wordt met twee handen vastgehouden: beide polsen bereiken hun greep, de loop wijst recht vooruit en zit voor de borst.
func _check_holds() -> void:
	for kind in ["m1911", "thompson", "garand", "trench", "mg42", "bazooka"]:
		var m := SoldierModel.new()
		root.add_child(m)
		m.setup(Color("4b5a2c"), kind, "speler:uniform")
		m.play("stil", 0.0)
		for _i in 20:
			await process_frame
		var gap: Dictionary = m.pose.reach_gap
		_check(gap.R < 0.02, "%s: rechterhand reikt %.3f m te kort" % [kind, gap.R])
		_check(gap.L < 0.06, "%s: linkerhand reikt %.3f m te kort" % [kind, gap.L])
		var muzzle := m.muzzle_position() - m.global_position
		_check(muzzle.z > 0.5 and absf(muzzle.x) < 0.3, "%s: loop wijst niet recht vooruit (monding %s)" % [kind, muzzle])
		_check(muzzle.y > 1.0 and muzzle.y < 1.9, "%s: monding niet op borst-/schouderhoogte (%.2f)" % [kind, muzzle.y])
		# tijdens het herladen speelt de animatie (geen IK) en tijdens het schieten blijft het wapen vast
		m.play("herladen", 0.0)
		_check(not m.pose.hold, "%s: wapen wordt tijdens herladen vastgehouden" % kind)
		m.play("schieten", 0.0)
		m.shoot_recoil(kind)
		for _i in 6:
			await process_frame
		_check(m.pose.hold and m.pose.reach_gap.R < 0.04, "%s: schieten verliest de greep (%.3f)" % [kind, m.pose.reach_gap.R])
		m.queue_free()
