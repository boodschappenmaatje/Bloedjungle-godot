extends SceneTree
## Headless contract test for the Asset Test Zone 2.0 controls and telemetry math.

const METRICS := preload("res://scripts/bunker_asset_metrics.gd")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error("BUNKER ASSET TEST ZONE V2: " + message)


func _run() -> void:
	var packed := load("res://scenes/bunker_asset_test.tscn") as PackedScene
	_check(packed != null, "test-zone scene failed to load")
	if packed == null:
		quit(1)
		return
	var zone := packed.instantiate()
	root.add_child(zone)
	await process_frame
	_check(zone.bunker_instances.size() == 1, "baseline should contain one bunker")
	_check(zone.bunker != null and zone._audit_model(zone.bunker).triangles == 37928, "baseline bunker/PBR GLB did not import")
	_check(zone.scenario_option.item_count == 4, "expected four reproducible scenarios")
	_check(zone.camera_option.item_count == 4, "expected four camera profiles")
	_check(zone.lighting_option.item_count == 2, "expected standard and enhanced lighting")
	_check(not zone.expanded_panel.visible and zone.collapsed_bar.visible, "HUD should start compact")

	zone._set_camera_profile(0)
	_check(is_equal_approx(rad_to_deg(zone.pitch), 58.0) and is_equal_approx(zone.camera_distance, 28.0), "normal gameplay camera must match 58 degrees / 28 metres")
	_check(is_equal_approx(zone.camera.fov, 45.0), "normal gameplay FOV must match 45 degrees")
	zone._set_camera_profile(1)
	_check(is_equal_approx(rad_to_deg(zone.pitch), 48.0) and is_equal_approx(zone.camera_distance, 16.0), "combat camera must match 48 degrees / 16 metres")
	_check(is_equal_approx(zone.camera.fov, 45.0), "combat camera should retain the game camera FOV")
	zone._set_camera_profile(2)
	_check(is_equal_approx(rad_to_deg(zone.pitch), 32.0) and is_equal_approx(zone.camera_distance, 18.0), "oblique inspection preset is incorrect")
	zone._set_camera_profile(3)
	_check(is_equal_approx(rad_to_deg(zone.pitch), 12.0), "front inspection preset is incorrect")

	zone._set_scenario(1)
	_check(zone.bunker_instances.size() == 1 and zone.environment_root.get_child_count() >= 5, "visual environment scenario is missing existing game assets")
	zone._set_scenario(2)
	_check(zone.bunker_instances.size() == 3 and zone.environment_root.get_child_count() == 0, "three-bunker comparison must contain exactly three bunker instances without extra scene props")
	zone._set_scenario(3)
	_check(zone.bunker_instances.size() == 3 and zone.environment_root.get_child_count() >= 10, "heavy stress scenario did not instantiate its existing buildings and environment assets")

	var samples: Array[float] = [8.0, 8.0, 50.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0]
	var summary := METRICS.summarize(samples)
	_check(summary.frames == 10, "metrics helper returned wrong frame count")
	_check(is_equal_approx(summary.one_percent_low_fps, 20.0), "1%-low must average the slowest ceil(1% of frames)")
	_check(is_equal_approx(summary.p99_frame_time_ms, 50.0), "p99 must use nearest rank over frame times")
	_check(is_equal_approx(summary.minimum_fps, 20.0) and is_equal_approx(summary.maximum_fps, 125.0), "min/max FPS must be derived from frame time")
	_check(METRICS.summarize([]).frames == 0, "empty runs should not invent performance values")

	zone.queue_free()
	await process_frame
	if failures.is_empty():
		print("BUNKER ASSET TEST ZONE V2 PASS: four scenarios, HUD controls, camera profiles and frame-time statistics")
		quit(0)
	else:
		quit(1)
