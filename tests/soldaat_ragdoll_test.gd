extends SceneTree
## Controleert de ragdoll (SoldierRagdoll) op het VQ2-mannetje: hij valt, blijft boven de grond, raakt niet in de war
## (geen explosie van het lichaam) en het aantal gelijktijdige ragdolls is begrensd.
## Draaien: godot --headless --path . -s tests/soldaat_ragdoll_test.gd --fixed-fps 60

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("SOLDAAT RAGDOLL TEST: " + message)


func _bone(m: SoldierModel, name: String) -> Vector3:
	# positie van het fysieke lichaamsdeel (midden van de capsule); get_bone_global_pose geeft de gesimuleerde pose niet terug
	var skel: Skeleton3D = m.find_children("*", "Skeleton3D", true, false)[0]
	return (skel.get_node("Ragdoll/" + name.trim_prefix("DEF-")) as PhysicalBone3D).global_position


func _run() -> void:
	GameSettings.values["soldaat"] = "vq2"
	var ground := StaticBody3D.new()
	ground.collision_layer = 1
	var cs := CollisionShape3D.new()
	cs.shape = WorldBoundaryShape3D.new()
	ground.add_child(cs)
	root.add_child(ground)
	var models: Array[SoldierModel] = []
	for i in SoldierRagdoll.MAX_ACTIVE + 2:
		var m := SoldierModel.new()
		root.add_child(m)
		m.setup(Color("8c7b52"), "garand", "vijand:rifle")
		m.scale = Vector3.ONE * Data.SOLDIER_SCALE
		m.position = Vector3(i * 2.0, 0.0, 0.0)
		m.play("lopen", 0.0)
		models.append(m)
	for _i in 10:
		await process_frame
	var started := 0
	for m in models:
		if SoldierRagdoll.start(m, Vector3(0, 0, -2.0), Vector3(0, 1.0, -4.0)):
			started += 1
	_check(started == SoldierRagdoll.MAX_ACTIVE, "aantal ragdolls %d, verwacht %d" % [started, SoldierRagdoll.MAX_ACTIVE])
	for _i in 180:
		await process_frame
	for i in SoldierRagdoll.MAX_ACTIVE:
		var m := models[i]
		var hips := _bone(m, "DEF-hips")
		var head := _bone(m, "DEF-head")
		_check(is_finite(hips.x) and is_finite(hips.y) and is_finite(hips.z), "ragdoll %d: oneindig" % i)
		_check(hips.y > 0.02 and hips.y < 0.6, "ragdoll %d: heup op hoogte %.2f (grond 0)" % [i, hips.y])
		_check(head.y > 0.02 and head.y < 0.7, "ragdoll %d: hoofd op hoogte %.2f, ligt niet op de grond" % [i, head.y])
		_check(hips.distance_to(head) < 1.6, "ragdoll %d: hoofd %.2f van de heup" % [i, hips.distance_to(head)])
		_check(Vector2(hips.x - m.position.x, hips.z).length() < 6.0, "ragdoll %d: te ver weggevlogen" % i)
	_check(not SoldierRagdoll.can_start(), "limiet niet bereikt")
	models[0].queue_free()
	await process_frame
	await process_frame
	_check(SoldierRagdoll.can_start(), "plek komt niet vrij na verwijderen")
	if failures.is_empty():
		print("SOLDAAT RAGDOLL TEST OK")
	else:
		print("SOLDAAT RAGDOLL TEST FAIL: ", failures.size())
	quit(1 if not failures.is_empty() else 0)
