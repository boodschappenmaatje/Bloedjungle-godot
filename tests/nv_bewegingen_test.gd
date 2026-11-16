extends SceneTree
## NVIDIA MotionBricks-bewegingen (bron/soldaat_vq2/nvidia, assets/nv_bewegingen.glb) op het VQ2-mannetje:
## clips aanwezig en zichtbaar bewegend, opzij/achteruit kiezen de juiste clip, afremmen na lopen, stapjes bij snel draaien,
## en instelling nv_anim = off geeft de oude beweging.
## Draaien: godot --headless --path . -s tests/nv_bewegingen_test.gd --fixed-fps 60

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("NV TEST: " + message)


func _bone(m: SoldierModel, name: String) -> Vector3:
	var skel: Skeleton3D = m.find_children("*", "Skeleton3D", true, false)[0]
	return skel.global_transform * skel.get_bone_global_pose(skel.find_bone(name)).origin


func _maak(look: String) -> SoldierModel:
	var m := SoldierModel.new()
	root.add_child(m)
	m.setup(Color("4b5a2c"), "garand", look)
	return m


func _run() -> void:
	GameSettings.values["soldaat"] = "vq2"
	GameSettings.values["nv_anim"] = "on"
	for look in ["vijand:rifle", "speler:uniform"]:
		var m := _maak(look)
		_check(m.nv, "%s: NVIDIA-clips niet geladen" % look)
		for c in SoldierModel.NV_CLIPS:
			_check(m.anim.has_animation(c), "%s: clip %s ontbreekt" % [look, c])
		for c in ["zij_links", "zij_rechts", "terug"]:
			_check(m.anim.get_animation(c).loop_mode == Animation.LOOP_LINEAR, "%s loopt niet rond" % c)
		# zichtbare beweging: de linkervoet verplaatst zich tijdens zij_links
		m.play_nv_move(PI / 2.0, 2.85)
		_check(m.current == "zij_links", "rel +90 graden geeft %s i.p.v. zij_links" % m.current)
		await process_frame
		var a := _bone(m, "DEF-footL")
		var verst := 0.0
		for _i in 30:
			await process_frame
			verst = maxf(verst, a.distance_to(_bone(m, "DEF-footL")))
		_check(verst > 0.15, "%s: voet beweegt nauwelijks in zij_links (%.3f m)" % [look, verst])
		m.play_nv_move(-PI / 2.0, 2.85)
		_check(m.current == "zij_rechts", "rel -90 graden geeft %s" % m.current)
		m.play_nv_move(PI, 2.0)
		_check(m.current == "terug", "rel 180 graden geeft %s" % m.current)
		_check(not m.play_nv_move(0.2, 2.0), "vooruit hoort de gewone loopclip te houden")
		_check(m.pose.hold, "%s: wapen niet vast in NVIDIA-clip" % look)
		# afremmen
		m.play("lopen", 0.0)
		m.play("stil")
		_check(m.current == "stoppen", "na lopen geen stoppen maar %s" % m.current)
		m.play("stil")
		_check(m.current == "stoppen", "stoppen wordt afgebroken")
		for _i in 140:
			await process_frame
		m.play("stil")
		_check(m.current == "stil", "na stoppen niet terug naar stil: %s" % m.current)
		# snel draaien op de plek
		for _i in 6:
			m.rotation.y += 0.08
			await process_frame
		_check(m.current == "draai_links", "snel linksom draaien geeft %s" % m.current)
		m.queue_free()
	# oude beweging via de instelling
	GameSettings.values["nv_anim"] = "off"
	var o := _maak("vijand:rifle")
	_check(not o.nv, "nv_anim off laadt toch NVIDIA-clips")
	_check(not o.play_nv_move(PI / 2.0, 2.0), "nv_anim off speelt toch zij-clip")
	o.play("lopen", 0.0)
	o.play("stil")
	_check(o.current == "stil", "nv_anim off: na lopen hoort direct stil")
	GameSettings.values["nv_anim"] = "on"
	if failures.is_empty():
		print("NV BEWEGINGEN TEST OK")
	else:
		print("NV BEWEGINGEN TEST FAIL: ", failures.size())
	quit(1 if not failures.is_empty() else 0)
