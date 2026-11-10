extends SceneTree
## Test: Graphics 2.0 (schakelaar Aan/Klassiek, testknoppen per onderdeel, bovengrenzen van de effecten, kwaliteitstrap).
## Draaien: godot --headless --path . -s tests/graphics2_test.gd --fixed-fps 60

var main: Node
var frames := 0
var fails := 0
var jeep: Node3D
var atm: Node
var world: Node
var fx: GDScript


func _initialize() -> void:
	for k in ["g2", "g2_fx", "g2_licht", "g2_diepte"]:
		GameSettings.set_value(k, "on")
	GameSettings.set_value("quality", "high")
	GameSettings.set_value("time", "day")
	GameSettings.set_value("weather", "clear")
	load("res://scripts/data.gd").set("mcv_autodeploy", true)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		push_error("GRAPHICS2 TEST: " + msg)


func _env() -> Environment:
	return atm.get("_env")


func _sun() -> DirectionalLight3D:
	return atm.get("_sun")


func _wet() -> float:
	var g := get_first_node_in_group("ground")
	return float((g.get_meta("mat") as ShaderMaterial).get_shader_parameter("g2_wet"))


func _process(_d: float) -> bool:
	frames += 1
	var game := root.get_node("Game")
	if frames == 3:
		main.begin()
		for m in get_nodes_in_group("menus"):
			m._show("")
	if frames == 5:
		jeep = load("res://scripts/vijand_jeep.gd").new()
		jeep.route = []
		jeep.position = Vector3(-9, 0, 12)
		main.add_child(jeep)
		jeep.set_physics_process(false)
	if frames == 8:
		atm = get_first_node_in_group("atmosphere")
		world = get_first_node_in_group("graphics2_wereld")
		fx = load("res://scripts/fx.gd")
		_check(world != null, "de wereldknoop van Graphics 2.0 bestaat")
		atm.apply_settings()
		# Aan (standaard): belichting
		_check(_env().glow_enabled, "aan: gloed aan in stand Hoog")
		_check(_env().ambient_light_source == Environment.AMBIENT_SOURCE_COLOR, "aan: koel omgevingslicht")
		_check(_env().adjustment_color_correction != null, "aan: kleurtabel")
		_check(_sun().shadow_enabled and _sun().directional_shadow_mode == DirectionalLight3D.SHADOW_ORTHOGONAL, "aan: in Hoog één schaduwkaart (snelheid)")
		_check(absf(_sun().directional_shadow_max_distance - 46.0) < 0.1, "aan: schaduw tot 46 m")
		_check(absf(_sun().rotation_degrees.x + 23.0) < 0.1, "aan: lage zon op 23 graden, kreeg %.1f" % _sun().rotation_degrees.x)
		_check((atm.get("_fill") as DirectionalLight3D).visible, "aan: invullicht overdag")
		# gouden stijl: lichtbundels, begroeiing langs het pad, plassen en helder gras
		_check(world.beams_on, "aan: lichtbundels overdag bij helder weer")
		_check(get_nodes_in_group("g2_begroeiing").size() == 4, "aan: bloemen, struiken, varens en keien langs het pad, kreeg %d groepen" % get_nodes_in_group("g2_begroeiing").size())
		for n in get_nodes_in_group("g2_begroeiing"):
			_check((n as Node3D).visible and (n as MultiMeshInstance3D).multimesh.instance_count > 3, "aan: begroeiing zichtbaar en gevuld")
		var gmat := get_first_node_in_group("ground").get_meta("mat") as ShaderMaterial
		_check(float(gmat.get_shader_parameter("g2_gold")) > 0.5, "aan: helder gras overdag")
		GameSettings.set_value("time", "night")
		atm.apply_settings()
		_check(not world.beams_on and not (atm.get("_fill") as DirectionalLight3D).visible and float(gmat.get_shader_parameter("g2_gold")) < 0.5, "nacht: geen lichtbundels, invullicht of gouden gras")
		GameSettings.set_value("time", "day")
		GameSettings.set_value("weather", "rain")
		atm.apply_settings()
		_check(not world.beams_on, "regen: geen lichtbundels")
		GameSettings.set_value("weather", "clear")
		GameSettings.set_value("quality", "ultra")
		atm.apply_settings()
		_check(_sun().directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, "Ultra: twee schaduwkaarten")
		GameSettings.set_value("quality", "high")
		atm.apply_settings()
		# Aan: diepte
		_check(_env().fog_height_density > 0.0, "aan: hoogtemist")
		_check(world.mist_on and world.shadow_on and world.dust_on, "aan: nevel, contactschaduw en voertuigstof")
		_check(_wet() > 0.5, "aan: natte glans op de grond")
		# echte boomschaduw, ook als de instelling op Vast staat
		GameSettings.set_value("treeshadow", "fake")
		atm.apply_settings()
		var palms := get_nodes_in_group("foliage_palm")
		_check(not palms.is_empty() and (palms[0] as GeometryInstance3D).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "aan: palmen werpen echte schaduw")
		for n in get_nodes_in_group("treeshadow"):
			_check(not n.visible, "aan: de vaste boomvlek is weg")
			break
		# de drie testknoppen
		GameSettings.set_value("g2_licht", "off")
		atm.apply_settings()
		_check(not _env().glow_enabled and _env().adjustment_color_correction == null, "belichting uit: gloed en kleurtabel weg")
		_check(absf(_sun().rotation_degrees.x + 33.0) < 0.1, "belichting uit: zon terug op 33 graden")
		_check(world.mist_on and not world.shadow_on and not world.beams_on, "belichting uit: nevel blijft, contactschaduw en lichtbundels weg")
		GameSettings.set_value("g2_licht", "on")
		GameSettings.set_value("g2_diepte", "off")
		atm.apply_settings()
		_check(_env().fog_height_density == 0.0 and not world.mist_on and _wet() < 0.5, "diepte uit: geen hoogtemist, nevel of glans")
		_check(_env().glow_enabled, "diepte uit: belichting blijft")
		GameSettings.set_value("g2_diepte", "on")
		# Laag: Graphics 2.0 doet niets
		GameSettings.set_value("quality", "low")
		atm.apply_settings()
		_check(not _sun().shadow_enabled and not _env().glow_enabled and not world.mist_on, "Laag: geen schaduw, gloed of nevel")
		GameSettings.set_value("quality", "high")
		# Klassiek: precies het oude beeld
		GameSettings.set_value("g2", "off")
		atm.apply_settings()
		_check(not _env().glow_enabled, "klassiek: gloed uit in Hoog")
		_check(_env().ambient_light_source == Environment.AMBIENT_SOURCE_SKY, "klassiek: omgevingslicht uit de lucht")
		_check(_env().adjustment_color_correction == null, "klassiek: geen kleurtabel")
		_check(_env().fog_height_density == 0.0 and absf(_env().fog_density - 0.0075) < 0.0001, "klassiek: mist zoals voorheen")
		_check(absf(_env().glow_hdr_threshold - 1.2) < 0.001 and absf(_env().adjustment_contrast - 1.2) < 0.001, "klassiek: gloed- en contrastwaarden terug")
		_check(_sun().directional_shadow_mode == DirectionalLight3D.SHADOW_ORTHOGONAL and absf(_sun().directional_shadow_max_distance - 40.0) < 0.1, "klassiek: schaduw van Hoog")
		_check(absf(_sun().shadow_opacity - 0.72) < 0.001, "klassiek: schaduwsterkte terug")
		_check(not world.mist_on and not world.shadow_on and not world.dust_on and not world.beams_on and not world.is_processing(), "klassiek: wereldknoop staat stil")
		for n in get_nodes_in_group("g2_begroeiing"):
			_check(not (n as Node3D).visible, "klassiek: geen extra begroeiing")
		_check(not (atm.get("_fill") as DirectionalLight3D).visible, "klassiek: geen invullicht")
		_check(_wet() < 0.5, "klassiek: geen glans")
		for n in get_nodes_in_group("treeshadow"):
			_check(n.visible, "klassiek: de vaste boomvlek is terug")
			break
		# klassiek: een explosie maakt geen nieuwe onderdelen
		fx.call("explosion", game.player.get_parent(), game.player.global_position + Vector3(4, 0, 4), 1.0)
		_check(not (fx.get("_spray_pools") as Dictionary).has("g2_rookzuil"), "klassiek: geen rookzuil")
		_check(int(fx.get("_g2_shocks")) == 0, "klassiek: geen schokgolf")
		GameSettings.set_value("g2", "on")
		atm.apply_settings()
	if frames == 12:
		# aan: tien explosies tegelijk blijven binnen de bovengrenzen
		for i in 10:
			fx.call("explosion", game.player.get_parent(), game.player.global_position + Vector3(4 + i, 0, 4), 1.0)
		_check(int(fx.get("_g2_shocks")) == int(fx.get("G2_MAX_SHOCKS")), "aan: hooguit %d schokgolven, kreeg %d" % [fx.get("G2_MAX_SHOCKS"), fx.get("_g2_shocks")])
		_check(int(fx.get("_g2_smoke")) == int(fx.get("G2_MAX_SMOKE")), "aan: hooguit %d rookzuilen, kreeg %d" % [fx.get("G2_MAX_SMOKE"), fx.get("_g2_smoke")])
		_check((fx.get("_spray_pools") as Dictionary).has("g2_stofring"), "aan: stofring")
	if frames > 20 and frames < 140 and is_instance_valid(jeep):
		jeep.global_position = Vector3(-9.0 + (frames - 20) * 0.14, 0.0, 12.0)
	if frames == 139:
		var dust := jeep.get_node_or_null("G2Stof") as CPUParticles3D
		_check(dust != null and dust.emitting, "rijdende jeep maakt stof")
		var mm: MultiMesh = (world.get("_shadows") as MultiMeshInstance3D).multimesh
		_check(mm.visible_instance_count >= 2, "contactschaduw onder speler en jeep, kreeg %d" % mm.visible_instance_count)
	if frames == 200:
		var dust := jeep.get_node_or_null("G2Stof") as CPUParticles3D
		_check(dust != null and not dust.emitting, "stilstaande jeep maakt geen stof")
		_check(int(fx.get("_g2_shocks")) == 0, "schokgolven zijn opgeruimd")
		# kwaliteitstrap: de nevel gaat als eerste uit, daarna minder rook
		atm.step_down()
		_check(not world.mist_on and not world.beams_on and _env().fog_height_density == 0.0, "trap 1: nevel, lichtbundels en hoogtemist uit")
		atm.step_down()
		_check(float(fx.get("g2_budget")) < 1.0, "trap 2: minder rook per explosie")
		load("res://scripts/atmosphere.gd").set("tier", 0)
		atm.apply_settings()
		_check(world.mist_on and float(fx.get("g2_budget")) == 1.0, "trap terug op 0: alles weer aan")
		print("KLAAR, fouten: ", fails)
		quit(1 if fails > 0 else 0)
	return false
