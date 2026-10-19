extends Node3D
## Lucht, zon, mist en kleur van het beeld: warme middagzon laag boven de jungle, heiige verte,
## filmische kleuren en een zachte gloed. Alles in code, zodat je het hier makkelijk kunt bijstellen.


func _ready() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("60727a")
	sky_mat.sky_horizon_color = Color("c8b996")
	sky_mat.ground_horizon_color = Color("8a876b")
	sky_mat.ground_bottom_color = Color("202a1b")
	sky_mat.sky_curve = 0.18
	sky_mat.sun_angle_max = 25.0
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.65
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.12
	env.tonemap_white = 8.0
	env.fog_enabled = true
	env.fog_light_color = Color("a8a58e")
	env.fog_density = 0.0022
	env.fog_aerial_perspective = 0.16
	env.fog_sky_affect = 0.38
	# Keep the mobile renderer route light and consistent with Xogot/Web compatibility.
	env.glow_enabled = false
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 0.98
	# SSAO is intentionally off: this scene targets Mobile and GL Compatibility as well.
	env.ssao_enabled = false
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -34.0, 0.0)
	sun.light_color = Color("fff0d6")
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.shadow_blur = 1.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 82.0
	sun.shadow_normal_bias = 0.7
	add_child(sun)
