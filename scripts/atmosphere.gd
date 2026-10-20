extends Node3D
## Lucht, zon, mist en kleur van het beeld: warme middagzon laag boven de jungle, heiige verte,
## filmische kleuren en een zachte gloed. Alles in code, zodat je het hier makkelijk kunt bijstellen.
# Test synchronisatie iPhone

var _sky_mat: ProceduralSkyMaterial
var _env: Environment
var _sun: DirectionalLight3D
var _rain: GPUParticles3D

# per tijdstip: zonrichting, zonkleur, zonkracht, omgevingslicht, hemel (boven/horizon/grond), mist, belichting
const TIMES := {
	"day": {"rot": Vector3(-33, -38, 0), "col": "ffe2b0", "e": 2.2, "amb": 0.38, "top": "56707a", "hor": "a3b09a", "gnd": "8e9c80", "fog": "7f9078", "exp": 1.0},
	"dusk": {"rot": Vector3(-9, -38, 0), "col": "ff8f50", "e": 1.6, "amb": 0.3, "top": "3a3f5c", "hor": "d98a55", "gnd": "8a6a50", "fog": "a87a5c", "exp": 1.0},
	"night": {"rot": Vector3(-52, -38, 0), "col": "8fa8ff", "e": 0.9, "amb": 0.34, "top": "10182e", "hor": "2c3b5a", "gnd": "141c2a", "fog": "27324a", "exp": 0.95},
}


func _ready() -> void:
	add_to_group("atmosphere")
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("56707a")
	sky_mat.sky_horizon_color = Color("a3b09a")
	sky_mat.ground_horizon_color = Color("8e9c80")
	sky_mat.ground_bottom_color = Color("2a3820")
	sky_mat.sky_curve = 0.18
	sky_mat.sun_angle_max = 25.0
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.38
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.tonemap_white = 8.0
	env.fog_enabled = true
	env.fog_light_color = Color("7f9078")
	env.fog_density = 0.005
	env.fog_aerial_perspective = 0.1
	env.fog_sky_affect = 0.3
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.2
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.2
	env.adjustment_saturation = 1.1
	# alleen bij de zwaarste renderer (Forward+) actief; de mobiele renderer slaat dit over
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 2.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-33.0, -38.0, 0.0)
	sun.light_color = Color("ffe2b0")
	sun.light_energy = 2.2
	sun.shadow_enabled = true
	sun.shadow_blur = 0.8
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 80.0
	sun.shadow_normal_bias = 1.2
	add_child(sun)
	_sky_mat = sky_mat
	_env = env
	_sun = sun
	apply_settings()

	# donkere randen en een warme tint over alles, zoals een filmbeeld
	var layer := CanvasLayer.new()
	layer.layer = -1
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
void fragment() {
	vec2 d = UV - 0.5;
	float v = smoothstep(0.35, 0.95, length(d * vec2(1.0, 1.15)));
	COLOR = vec4(0.03, 0.05, 0.02, v * 0.55);
}"""
	var sm := ShaderMaterial.new()
	sm.shader = sh
	rect.material = sm
	layer.add_child(rect)
	add_child(layer)


## Past tijd, weer en grafiek uit GameSettings toe (ook midden in het spel, vanuit het menu).
func apply_settings() -> void:
	var t: Dictionary = TIMES[GameSettings.get_value("time")]
	var weather := GameSettings.get_value("weather")
	var quality := GameSettings.get_value("quality")
	var dim := 1.0 if weather == "clear" else (0.6 if weather == "rain" else 0.75)
	_sun.rotation_degrees = t["rot"]
	_sun.light_color = Color(t["col"])
	_sun.light_energy = t["e"] * dim
	_env.ambient_light_energy = t["amb"] * (1.0 if weather == "clear" else 0.9)
	_sky_mat.sky_top_color = Color(t["top"])
	_sky_mat.sky_horizon_color = Color(t["hor"])
	_sky_mat.ground_horizon_color = Color(t["gnd"])
	_env.fog_light_color = Color(t["fog"]).lerp(Color("9aa59a"), 0.0 if weather == "clear" else 0.35)
	_env.fog_density = {"clear": 0.005, "rain": 0.013, "mist": 0.017}[weather]
	_env.tonemap_exposure = t["exp"]
	_env.adjustment_saturation = 1.1 if weather == "clear" else 0.85
	_sun.shadow_enabled = quality != "low"
	_sun.directional_shadow_max_distance = 55.0 if quality == "high" else 80.0
	_env.glow_enabled = quality != "low"
	get_viewport().scaling_3d_scale = 0.75 if quality == "low" else 1.0
	_set_rain(weather == "rain")


func _set_rain(on: bool) -> void:
	if on and _rain == null:
		_rain = GPUParticles3D.new()
		_rain.top_level = true
		_rain.amount = 900
		_rain.lifetime = 0.7
		_rain.visibility_aabb = AABB(Vector3(-20, -20, -20), Vector3(40, 40, 40))
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(18, 0.1, 18)
		pm.direction = Vector3(0.12, -1, 0.05)
		pm.spread = 2.0
		pm.initial_velocity_min = 24.0
		pm.initial_velocity_max = 28.0
		pm.gravity = Vector3.ZERO
		_rain.process_material = pm
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.015, 0.55, 0.015)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.75, 0.82, 0.9, 0.28)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh.material = mat
		_rain.draw_pass_1 = mesh
		add_child(_rain)
	if _rain:
		_rain.emitting = on
		_rain.visible = on
		set_process(on)


func _process(_d: float) -> void:
	if _rain and Game.player:
		_rain.global_position = Game.player.global_position + Vector3(0, 15, 0)
