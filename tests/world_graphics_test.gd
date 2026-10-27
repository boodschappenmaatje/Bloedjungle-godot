extends SceneTree
## Actual material/import/quality contracts; no saved preferences are changed.

var failures: Array[String] = []
var main: Node3D


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error("WORLD GRAPHICS FAIL: " + message)


func _run() -> void:
	GameSettings._load()
	GameSettings.values = GameSettings.DEFAULTS.duplicate()
	GameSettings.values["weather"] = "rain"
	GameSettings.values["quality"] = "low"
	load("res://scripts/perf_governor.gd").set("paused", true)
	var atm_script: GDScript = load("res://scripts/atmosphere.gd")
	atm_script.set("tier", 0)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await main.begin()
	main.set_process(false)
	await physics_frame
	var ground: StaticBody3D = get_first_node_in_group("ground")
	check(ground != null, "existing ground missing")
	var mat: ShaderMaterial = ground.get_meta("mat")
	check(mat.shader.resource_path == "res://shaders/ground.gdshader", "parallel terrain system introduced")
	check(is_equal_approx(mat.get_shader_parameter("wetness"), 0.75), "weather selected before world load not applied")
	check(is_equal_approx(mat.get_shader_parameter("normal_strength"), 0.48), "startup low-quality normal strength")
	for layer in ["earth", "gravel", "mud", "grass", "litter"]:
		var color: Texture2D = mat.get_shader_parameter(layer + "_tex")
		var surface: Texture2D = mat.get_shader_parameter(layer + "_surface")
		check(color != null and surface != null, layer + " PBR maps missing")
		check(color.get_width() == 1024 and surface.get_width() == 1024, layer + " stored resolution")
		check(surface.resource_path.ends_with(layer + "_normal_roughness.png"), layer + " wrong layer binding")
		var image := surface.get_image()
		if image.is_compressed():
			check(image.decompress() == OK, layer + " compressed map cannot decode")
		var alpha_min := 1.0
		var alpha_max := 0.0
		for y in range(0, image.get_height(), 32):
			for x in range(0, image.get_width(), 32):
				var value := image.get_pixel(x, y).a
				alpha_min = minf(alpha_min, value)
				alpha_max = maxf(alpha_max, value)
		check(alpha_min < 0.98 and alpha_max - alpha_min > 0.025, layer + " packed roughness alpha was lost on import")
	var collision: CollisionShape3D = ground.get_child(0)
	check(collision.shape is BoxShape3D and collision.shape.size == Vector3(440, 1, 440), "ground collision changed")
	check(collision.position.y == -0.5, "walkable ground height changed")
	check(ground.collision_layer == 1, "ground physics layer changed")
	check(ground.get_child(1).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "flat ground casts self-shadow")
	var query := PhysicsRayQueryParameters3D.create(Vector3(5, 3, 6), Vector3(5, -3, 6), 1)
	var hit := main.get_world_3d().direct_space_state.intersect_ray(query)
	check(not hit.is_empty() and absf(hit.position.y) < 0.001, "real ray hit no longer at original ground height")
	var atm: Node = get_first_node_in_group("atmosphere")
	for quality in ["low", "high", "ultra"]:
		GameSettings.values["quality"] = quality
		for weather in ["clear", "rain", "mist"]:
			GameSettings.values["weather"] = weather
			for time in ["day", "dusk", "night"]:
				GameSettings.values["time"] = time
				atm.apply_settings()
				check(is_equal_approx(mat.get_shader_parameter("wetness"), {"clear": 0.0, "rain": 0.75, "mist": 0.25}[weather]), "runtime weather parameter")
				check(atm._sun.light_energy > 0 and atm._env.ambient_light_energy > 0, "unlit time/weather")
		check(atm._sun.shadow_enabled == (quality != "low"), "quality shadow switch")
	GameSettings.values["quality"] = "high"
	GameSettings.values["time"] = "day"
	GameSettings.values["weather"] = "clear"
	atm.apply_settings()
	check(atm._sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, "high shadow cascades missing")
	check(not atm._env.ssao_enabled and not atm._env.glow_enabled, "mobile high enables expensive post effects")
	check(is_equal_approx(mat.get_shader_parameter("normal_strength"), 0.72), "high material strength")
	for _tier in 4:
		check(atm.step_down(), "adaptive governor tier missing")
	check(not atm._sun.shadow_enabled, "lowest tier still draws sun shadows")
	# Existing building/defense writers keep ownership of these same uniform slots.
	mat.set_shader_parameter("pits", PackedVector4Array([Vector4(4, 6, 1, 0)]))
	mat.set_shader_parameter("pit_n", 1)
	mat.set_shader_parameter("pad", Vector4(-5, 7, 1, 0))
	mat.set_shader_parameter("pad_half", 4.5)
	atm.apply_settings()
	check(mat.get_shader_parameter("pit_n") == 1 and mat.get_shader_parameter("pad_half") == 4.5, "weather reset trench/helipad cut-outs")
	var code := mat.shader.code
	check(not code.contains("dirt_height") and not code.contains("specular_disabled"), "fake height or disabled PBR remains")
	check(code.contains("if (river_off < 2.6)") and code.contains("abs(lx) < 2.36") and code.contains("abs(qx) < pad_half"), "existing terrain opening contract changed")
	print("WORLD GRAPHICS ", "PASS" if failures.is_empty() else "FAIL", ": real imports, roughness alpha, ground physics, 27 weather/time/quality cases, adaptive tiers, cut-outs")
	quit(0 if failures.is_empty() else 1)
