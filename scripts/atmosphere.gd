class_name Atmosphere
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
	"day": {"rot": Vector3(-33, -38, 0), "col": "ffe2b0", "e": 1.55, "amb": 0.32, "top": "56707a", "hor": "a3b09a", "gnd": "8e9c80", "fog": "7f9078", "exp": 0.9},
	"dusk": {"rot": Vector3(-9, -38, 0), "col": "ff8f50", "e": 1.6, "amb": 0.3, "top": "3a3f5c", "hor": "d98a55", "gnd": "8a6a50", "fog": "a87a5c", "exp": 1.0},
	"night": {"rot": Vector3(-52, -38, 0), "col": "8fa8ff", "e": 0.9, "amb": 0.34, "top": "10182e", "hor": "2c3b5a", "gnd": "141c2a", "fog": "27324a", "exp": 0.95},
}

# Graphics 2.0, dag = gouden ochtend (keuze 1A, 10 nov 2026): lage goudgele zon schuin van voren (tegenlicht, de schaduwen
# vallen naar de camera toe), veel warm omgevingslicht zodat het beeld licht blijft, warme mist en nevel.
# ambc = kleur van het omgevingslicht, mist/ms = kleur en dichtheid van de nevel, beam/bs = kleur en sterkte van de lichtbundels.
const TIMES_G2 := {
	"day": {"rot": Vector3(-23, -142, 0), "col": "ffcf8a", "e": 2.05, "amb": 0.6, "ambc": "a9b596", "top": "5f7f96", "hor": "ecd9ac", "gnd": "a59a70", "fog": "c9c19a", "exp": 1.0, "mist": "f1e2b8", "ms": 0.09, "beam": "ffd591", "bs": 0.12},
	"dusk": {"rot": Vector3(-9, -38, 0), "col": "ff8644", "e": 1.9, "amb": 0.32, "ambc": "7d7fb0", "top": "3a3f5c", "hor": "e0915a", "gnd": "8a6a50", "fog": "b0805e", "exp": 1.0, "mist": "e0a57c", "ms": 0.13, "beam": "ff9a55", "bs": 0.16},
	"night": {"rot": Vector3(-48, -38, 0), "col": "9db4ff", "e": 1.0, "amb": 0.34, "ambc": "3d5a96", "top": "10182e", "hor": "2c3b5a", "gnd": "141c2a", "fog": "27324a", "exp": 0.95, "mist": "5a6c8e", "ms": 0.16},
}

var _world: Graphics2Wereld
var _fill: DirectionalLight3D   # zacht invullicht vanaf de camerakant, zodat soldaten in het tegenlicht niet zwart worden
var _luts := {}


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
	env.ambient_light_energy = 0.58
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.tonemap_white = 8.0
	env.fog_enabled = true
	env.fog_light_color = Color("7f9078")
	env.fog_density = 0.0075
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
	sun.shadow_blur = 1.8  # zachtere randen
	sun.shadow_opacity = 0.72  # schaduw wordt niet meer pikzwart
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 80.0
	sun.shadow_normal_bias = 1.2
	add_child(sun)
	_sky_mat = sky_mat
	_env = env
	_sun = sun
	_world = Graphics2Wereld.new()
	add_child(_world)
	_fill = DirectionalLight3D.new()
	_fill.rotation_degrees = Vector3(-42.0, 30.0, 0.0)
	_fill.light_color = Color("d6dde6")
	_fill.light_energy = 0.55
	_fill.light_specular = 0.0
	_fill.shadow_enabled = false
	_fill.visible = false
	add_child(_fill)
	apply_settings()
	apply_settings.call_deferred()  # nog eens als de camera en de jungle er staan

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
	var weather := GameSettings.get_value("weather")
	var quality := Upscaling.effective_quality()
	var g2_light := Graphics2.light() and quality != "low"
	var t: Dictionary = (TIMES_G2 if g2_light else TIMES)[GameSettings.get_value("time")]
	var dim := 1.0 if weather == "clear" else (0.6 if weather == "rain" else 0.75)
	_sun.rotation_degrees = t["rot"]
	_sun.light_color = Color(t["col"])
	_sun.light_energy = t["e"] * dim
	_env.ambient_light_energy = t["amb"] * (1.0 if weather == "clear" else 0.9)
	_sky_mat.sky_top_color = Color(t["top"])
	_sky_mat.sky_horizon_color = Color(t["hor"])
	_sky_mat.ground_horizon_color = Color(t["gnd"])
	_env.fog_light_color = Color(t["fog"]).lerp(Color("9aa59a"), 0.0 if weather == "clear" else 0.35)
	_env.fog_density = {"clear": 0.0075, "rain": 0.014, "mist": 0.018}[weather]
	_env.tonemap_exposure = t["exp"]
	_env.adjustment_saturation = 1.1 if weather == "clear" else 0.85
	_apply_quality(quality)
	_apply_g2(quality, t, weather)
	_apply_trees()
	Woonhuis.apply_shadow_setting()
	_set_rain(weather == "rain")
	Sfx.rain(weather == "rain")
	_apply_diagnose()
	_apply_tier()
	for field in get_tree().get_nodes_in_group("grass_fields"):
		field.apply_quality(quality, quality == "ultra" and tier == 0)


## Automatische kwaliteitstrap (PerfGovernor): haalt het spel het doel niet, ook niet op de laagste resolutie, dan gaan de
## duurste onderdelen stap voor stap uit tot het wel lukt. 0 = zoals de gekozen grafiek, 4 = zon-schaduw ook uit.
## Wordt teruggezet als je de grafiekstand verandert.
static var tier := 0
const TIER_MAX := 4


func _apply_tier() -> void:
	if tier >= 1:
		_fill.visible = false
		if _world != null:
			_world.apply(false, _world.shadow_on, _world.dust_on)   # Graphics 2.0: de nevel en de lichtbundels gaan als eerste uit
			_world.apply_beams(false)
		_env.fog_height_density = 0.0
		_env.glow_enabled = false
		_env.ssao_enabled = false
		_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		RenderingServer.directional_shadow_atlas_set_size(1024, true)
		var cam := get_viewport().get_camera_3d()
		if cam and cam.attributes is CameraAttributesPractical:
			(cam.attributes as CameraAttributesPractical).dof_blur_far_enabled = false
	if tier >= 2:
		Fx.g2_budget = 0.5   # Graphics 2.0: minder rook en licht per explosie
		_sun.directional_shadow_max_distance = minf(_sun.directional_shadow_max_distance, 28.0)
		for kind in ["bush", "fern", "palm", "rock"]:
			for n: MultiMeshInstance3D in get_tree().get_nodes_in_group("foliage_" + kind):
				n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if tier >= 3:
		for kind in ["grass", "fern"]:
			for n: MultiMeshInstance3D in get_tree().get_nodes_in_group("foliage_" + kind):
				n.multimesh.visible_instance_count = roundi(n.multimesh.visible_instance_count * 0.5)
	if tier >= 4:
		_sun.shadow_enabled = false


## Eén stap lager; false als er niets meer te winnen valt.
func step_down() -> bool:
	if tier >= TIER_MAX:
		return false
	tier += 1
	PerfMonitor.note("kwaliteit lager (trap %d)" % tier)
	apply_settings()
	return true


## Test-schakelaars (Instellingen): zet onderdelen even uit om te zien welke de fps drukken. Standaard alles aan.
func _apply_diagnose() -> void:
	if GameSettings.get_value("t_sun") == "off":
		_sun.shadow_enabled = false
	var jungle: bool = GameSettings.get_value("t_jungle") == "on"
	for g in ["foliage_palm", "foliage_bush", "foliage_fern", "foliage_grass", "foliage_rock", "treeshadow"]:
		for n: Node3D in get_tree().get_nodes_in_group(g):
			n.visible = jungle and (g != "treeshadow" or n.visible)
	if Stad.current != null and is_instance_valid(Stad.current):
		Stad.current.visible = GameSettings.get_value("t_stad") == "on"
	if GameSettings.get_value("t_post") == "off":
		if _world != null:
			_world.apply(false, _world.shadow_on, _world.dust_on)
			_world.apply_beams(false)
		_env.fog_enabled = false
		_env.glow_enabled = false
		_env.ssao_enabled = false
		var cam := get_viewport().get_camera_3d()
		if cam and cam.attributes is CameraAttributesPractical:
			(cam.attributes as CameraAttributesPractical).dof_blur_far_enabled = false
	else:
		_env.fog_enabled = true


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


# Grafiekniveaus. Hoog is gemaakt om op 60 beeld per seconde te blijven: lichtere schaduwen, geen gloed en
# geen onscherpe verte, minder gras en iets minder pixels. Ultra is het volledige beeld.
const QUALITY := {
	"low": {"shadow": false, "dist": 40.0, "atlas": 1024, "glow": false, "dof": false, "scale": 0.6, "grass": 0.2, "fern": 0.5, "bush_shadow": false, "ssao": false},
	"high": {"shadow": true, "dist": 40.0, "atlas": 1024, "glow": false, "dof": false, "scale": 0.8, "grass": 0.45, "fern": 0.7, "bush_shadow": false, "ssao": false},
	"ultra": {"shadow": true, "dist": 55.0, "atlas": 4096, "glow": true, "dof": true, "scale": 1.0, "grass": 1.0, "fern": 1.0, "bush_shadow": true, "ssao": true},
}


func _apply_quality(q: String) -> void:
	var c: Dictionary = QUALITY[q]
	_sun.shadow_enabled = c.shadow
	_sun.directional_shadow_max_distance = c.dist
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if q == "ultra" else DirectionalLight3D.SHADOW_ORTHOGONAL
	RenderingServer.directional_shadow_atlas_set_size(c.atlas, true)
	_env.glow_enabled = c.glow
	_env.ssao_enabled = c.ssao
	var vp := get_viewport()
	# FXAA alone misses thin Meshy edges at the reduced mobile render resolution.
	# MSAA covers geometry samples; the terrain shader separately filters texture detail.
	vp.msaa_3d = Viewport.MSAA_DISABLED if q == "low" else Viewport.MSAA_4X
	Upscaling.apply_mode(vp)  # MetalFX Spatial op iPhone; FSR en MetalFX Temporal kunnen alleen in Forward+
	vp.scaling_3d_scale = Upscaling.band().start if Upscaling.active() else c.scale
	# SMAA is scherper dan FXAA en past bij MetalFX (keuze 5B); met upscaling uit blijft het beeld precies zoals het was
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_SMAA if Upscaling.active() else Viewport.SCREEN_SPACE_AA_FXAA
	var cam := vp.get_camera_3d()
	if cam and cam.attributes is CameraAttributesPractical:
		(cam.attributes as CameraAttributesPractical).dof_blur_far_enabled = c.dof
	for kind in ["grass", "fern"]:
		for n: MultiMeshInstance3D in get_tree().get_nodes_in_group("foliage_" + kind):
			if not n.has_meta("full"):
				n.set_meta("full", n.multimesh.instance_count)
			n.multimesh.visible_instance_count = roundi(n.get_meta("full") * c[kind])
	for kind in ["bush", "fern"]:
		for n: MultiMeshInstance3D in get_tree().get_nodes_in_group("foliage_" + kind):
			n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if c.bush_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Graphics 2.0 bovenop de gekozen grafiekstand (niet bij Laag). Belichting: schaduw in twee delen tot 64 m (genoeg voor de
## camera op 40 graden), gloed, koel omgevingslicht en een kleurtabel. Diepte: hoogtemist, zongloed in de mist en nevel.
## Met de schakelaar op Klassiek zet dit alles terug naar de waarden van vóór v205.
func _apply_g2(q: String, t: Dictionary, weather: String) -> void:
	var light := Graphics2.light() and q != "low"
	var depth := Graphics2.depth() and q != "low"
	Fx.g2_budget = 1.0
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR if light else Environment.AMBIENT_SOURCE_SKY
	_env.glow_intensity = 0.62 if light else 0.4
	_env.glow_bloom = 0.06 if light else 0.02
	_env.glow_hdr_threshold = 1.0 if light else 1.2
	_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN if light else Environment.GLOW_BLEND_MODE_SOFTLIGHT
	_env.adjustment_contrast = 1.18 if light else 1.2
	_env.adjustment_color_correction = _lut(GameSettings.get_value("time")) if light else null
	_sun.shadow_opacity = 0.78 if light else 0.72
	_fill.visible = light and GameSettings.get_value("time") == "day"
	_sun.shadow_blur = 1.3 if light else 1.8
	if light:
		_env.ambient_light_color = Color(t["ambc"])
		_env.adjustment_saturation = 1.22 if weather == "clear" else 0.9
		_env.glow_enabled = true
		_sun.shadow_enabled = true
		# Eén schaduwkaart in plaats van twee: op de iPhone kostte de tweede kaart (alle palmen nog een keer tekenen)
		# te veel (v205: 89 fps bij 50% resolutie). Ultra houdt twee kaarten.
		var two: bool = q == "ultra"
		_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if two else DirectionalLight3D.SHADOW_ORTHOGONAL
		_sun.directional_shadow_split_1 = 0.28
		_sun.directional_shadow_blend_splits = false
		_sun.directional_shadow_max_distance = 64.0 if two else 46.0
		RenderingServer.directional_shadow_atlas_set_size(4096 if two else 2048, true)
	_env.fog_height = 2.4 if depth else 0.0
	_env.fog_height_density = (0.035 if weather == "clear" else 0.07) if depth else 0.0
	_env.fog_sun_scatter = 0.3 if depth else 0.0
	_env.fog_aerial_perspective = 0.18 if depth else 0.1
	if depth:
		_env.fog_density *= 0.5   # de hoogtemist neemt een deel van de dichtheid over
	for g in get_tree().get_nodes_in_group("ground"):
		var mat: ShaderMaterial = g.get_meta("mat") if g.has_meta("mat") else null
		if mat != null:
			mat.set_shader_parameter("g2_wet", 1.0 if depth else 0.0)
			mat.set_shader_parameter("g2_gold", 1.0 if light and GameSettings.get_value("time") == "day" else 0.0)
			mat.set_shader_parameter("g2_sky", Color(t["hor"]))
	var mist_col := Color(t.get("mist", "c9d3bd"))
	var strength: float = float(t.get("ms", 0.26)) * (1.0 if weather == "clear" else 1.5)
	_world.apply(depth, light, Graphics2.fx(), mist_col, strength)
	# lichtbundels: alleen bij helder weer en als er een zon is die laag genoeg staat (dag en avond)
	var beams: bool = light and depth and weather == "clear" and t.has("beam")
	_world.apply_beams(beams, -_sun.global_transform.basis.z, Color(t.get("beam", "ffd591")), float(t.get("bs", 0.2)))
	_world.apply_plants(depth)


## Kleurtabel per tijdstip: donkere tinten zakken iets weg naar koel groenblauw, lichte tinten worden warm. Eén kleine textuur.
func _lut(time: String) -> GradientTexture1D:
	if not _luts.has(time):
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.25, 0.6, 1.0])
		match time:
			"dusk":
				g.colors = PackedColorArray([Color(0.012, 0.01, 0.03), Color(0.23, 0.22, 0.26), Color(0.62, 0.59, 0.57), Color(1.0, 0.95, 0.86)])
			"night":
				g.colors = PackedColorArray([Color(0.0, 0.008, 0.03), Color(0.21, 0.24, 0.29), Color(0.57, 0.6, 0.65), Color(0.94, 0.97, 1.0)])
			_:
				g.colors = PackedColorArray([Color(0.002, 0.004, 0.002), Color(0.225, 0.235, 0.215), Color(0.615, 0.612, 0.565), Color(1.0, 0.975, 0.89)])
		var tex := GradientTexture1D.new()
		tex.gradient = g
		tex.width = 256
		_luts[time] = tex
	return _luts[time]


## Bomen: wind aan/uit en schaduw (Vast = nepschaduw onder elke boom, Echt = schaduwkaart, Uit).
func _apply_trees() -> void:
	Foliage.set_wind(GameSettings.get_value("wind") == "on")
	var fwd := -_sun.global_transform.basis.z
	Foliage.set_sun(Vector2(fwd.x, fwd.z), -_sun.rotation_degrees.x)
	var mode := GameSettings.get_value("treeshadow")
	var c: Dictionary = QUALITY[GameSettings.get_value("quality")]
	if Graphics2.light() and c.shadow and mode != "off":
		mode = "real"   # Graphics 2.0: palmen en rotsen werpen echte schaduw, de vaste vlek vervalt
	for n in get_tree().get_nodes_in_group("treeshadow"):
		n.visible = mode == "fake" and c.shadow
	for kind in ["palm", "bush", "fern", "rock"]:
		var on: bool = mode == "real" and c.shadow and (kind == "palm" or kind == "rock" or c.bush_shadow)
		for n: MultiMeshInstance3D in get_tree().get_nodes_in_group("foliage_" + kind):
			n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
