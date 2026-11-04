extends Node
## Headless integration test for Settings > Vijandmodellen > Alleen Meshy.
## Run as a scene, not -s: the Godot autoloads must already be initialized.

var failures := 0

func _ready() -> void:
	call_deferred("_run")

func _check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error("ENEMY MESHY MODE TEST: " + description)

func _run() -> void:
	var old_mode := GameSettings.get_value("enemy_models")
	var main: Node3D = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(main)
	await get_tree().process_frame
	_check(GameSettings.DEFAULTS["enemy_models"] == "all", "existing installs must retain normal enemy mix by default")

	# The mode is visible in the native settings screen and persists on device.
	var ui_mode_found := false
	for row in PauseMenu.ROWS:
		if row[0] != "enemy_models":
			continue
		var options := {}
		for o in row[2]:
			options[o[0]] = true
		ui_mode_found = options.has("all") and options.has("meshy")
	_check(ui_mode_found, "all/meshy options missing from Settings")
	GameSettings.set_value("enemy_models", "all")
	_check(Data.build_group(1).size() == 6, "default first assault group size changed")
	main.call("_spawn", {"kind": "knife", "n": 1, "routes": ["brug"]})
	await get_tree().process_frame
	var old_enemy: Node = Game.enemies.back() if not Game.enemies.is_empty() else null
	_check(old_enemy != null and str(old_enemy.get("type")) == "knife", "normal mode should keep old enemy types")

	GameSettings.set_value("enemy_models", "meshy")
	var cf := ConfigFile.new()
	_check(cf.load(GameSettings.PATH) == OK and str(cf.get_value("instellingen", "enemy_models", "")) == "meshy",
		"Meshy-only selection was not persisted")
	for n in [1, 2, 5, 10]:
		var group := Data.build_group(n)
		_check(group.size() == 4 + int(n * 2.4) and group.all(func(k): return k == "assault"),
			"group %d still spawns legacy enemies or loses its original size" % n)
	main.queue.append({"kind": "rocket", "n": 2, "routes": ["brug"]})
	main.call("apply_enemy_model_filter")
	_check(not Game.enemies.has(old_enemy), "old active knife remains a live invisible attacker")
	_check(main.queue[0]["kind"] == "assault", "already queued old types not converted")
	await get_tree().process_frame
	_check(not is_instance_valid(old_enemy), "old enemy was not actually freed")

	# Force a queued old type through the actual spawn entrypoint.
	# It must instantiate the imported 28-bone Assault Meshy rig, not VQ2.
	main.call("_spawn", {"kind": "knife", "n": 1, "routes": ["brug"]})
	await get_tree().process_frame
	var enemy: Node = Game.enemies.back() if not Game.enemies.is_empty() else null
	_check(enemy != null and str(enemy.get("type")) == "assault", "old enemy type escaped spawn-time filter")
	if enemy != null:
		var model := enemy.get_node_or_null("Model") as SoldierModel
		_check(model != null and model.assault_rig_test and model.meshy_player,
			"Assault uses fallback model instead of the Meshy GLB")
		_check(model != null and model._mesh_skeleton != null and model._mesh_skeleton.get_bone_count() == 28,
			"runtime Assault 28-bone skeleton missing")
	_check(SoldierModel.enemy_status == "Meshy-Assault geladen", "enemy load diagnosis is not truthful")

	# Switch back; legacy kinds are allowed again for new spawns.
	GameSettings.set_value("enemy_models", "all")
	main.call("_spawn", {"kind": "knife", "n": 1, "routes": ["brug"]})
	await get_tree().process_frame
	var restored: Node = Game.enemies.back() if not Game.enemies.is_empty() else null
	_check(restored != null and str(restored.get("type")) == "knife", "switching back does not restore normal mode")

	GameSettings.set_value("enemy_models", old_mode)
	main.queue_free()
	await get_tree().process_frame
	if failures == 0:
		print("ENEMY MESHY MODE TEST PASS")
	else:
		print("ENEMY MESHY MODE TEST FAIL: ", failures)
	get_tree().quit(0 if failures == 0 else 1)
