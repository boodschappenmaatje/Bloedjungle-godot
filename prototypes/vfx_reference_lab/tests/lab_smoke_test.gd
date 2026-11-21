extends Node
## Run the paired .tscn with: godot --headless --path . --scene res://prototypes/vfx_reference_lab/tests/lab_smoke_test.tscn

func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	GameSettings.get_value("quality")
	var before_settings: Dictionary = GameSettings.values.duplicate(true)
	var game: Node = get_node("/root/Game")
	var before_game := {"state": game.get("state"), "wave": game.get("wave"), "points": game.get("points"), "player": game.get("player")}
	var scene := load("res://prototypes/vfx_reference_lab/scenes/lab.tscn") as PackedScene
	assert(scene != null, "Reference lab scene failed to load")
	var lab := scene.instantiate() as Node3D
	get_tree().root.add_child(lab)
	await get_tree().process_frame
	lab.set("auto_fire", false)
	lab.call("_set_preset", "MOBILE")
	assert(GameSettings.get_value("quality") == "low", "Mobile preset must use the lab's low quality tier")
	lab.call("_set_preset", "HIGH")
	assert(GameSettings.get_value("quality") == "high", "High preset must use the lab's high quality tier")
	assert(lab.get_viewport().get_camera_3d() != null, "Bloedjungle reference camera missing")
	assert(lab.get_child_count() > 12, "Visual stage has not been assembled")
	lab.call("_select_view", 1)
	assert((lab.get("comparison_mode") as String) == "CLASSIC", "A/B view selector did not switch to classic only")
	lab.call("_select_view", 0)
	assert((lab.get("comparison_mode") as String) == "BOTH", "A/B view selector did not restore both lanes")
	for material_index in 3:
		lab.set("selected_material", material_index)
		lab.set("shot_cooldown", 0.0)
		lab.call("_fire")
		var tracer_pool: Array = lab.get("tracers")
		assert(tracer_pool.size() == 2, "Tracer pool must stay bounded at two lanes")
		for lane in 2:
			var trail := tracer_pool[lane] as MeshInstance3D
			assert(trail.mesh != null and trail.visible, "Both A/B tracer previews must animate")
			var origin: Vector3 = (lab.get("muzzle_points") as Array)[lane]
			var board: Node3D = (lab.get("targets") as Array)[lane][material_index]
			var target := board.global_position + Vector3(0.0, 0.0, 0.19)
			assert(trail.global_basis.z.dot((target - origin).normalized()) > 0.99, "Tracer should face the target along local +Z")
		await get_tree().create_timer(0.18).timeout
	# Stress existing impact/flash pools and the lab's fixed tracer pair.
	for shot in 72:
		lab.set("selected_material", shot % 3)
		lab.set("shot_cooldown", 0.0)
		lab.call("_fire")
	assert((lab.get("tracers") as Array).size() == 2, "Tracer pool must stay bounded at two lanes")
	var fx_counts := Fx.combat_counts()
	assert(fx_counts.burst_nodes <= Fx.MAX_BURST_NODES, "Shared Fx burst pool exceeded its bound")
	assert(fx_counts.burst_live <= Fx.MAX_ACTIVE_BURSTS, "Shared Fx burst live cap exceeded")
	assert(fx_counts.muzzle_flashes <= Fx.MAX_MUZZLE_FLASHES, "Shared muzzle flash pool exceeded its bound")
	assert(Fx._decals.size() <= Fx.MAX_DECALS, "Shared impact decal cap exceeded")
	for key in WapenFx.counts():
		var pool_key := String(key).get_slice(":", 0)
		var max_count := int(WapenFx.CAP.get(pool_key, 8))
		assert(int(WapenFx.counts()[key]) <= max_count, "Shared WapenFx pool exceeded its bound: %s" % key)
	var game_after := {"state": game.get("state"), "wave": game.get("wave"), "points": game.get("points"), "player": game.get("player")}
	assert(game_after == before_game, "Preview modified gameplay state")
	lab.queue_free()
	await get_tree().process_frame
	assert(GameSettings.values == before_settings, "Preview did not restore in-memory settings")
	print("BLOEDJUNGLE VFX REFERENCE LAB SMOKE: PASS (scene, camera, 3 materials, A/B, bounded pools, gameplay/settings isolation)")
	get_tree().quit(0)
