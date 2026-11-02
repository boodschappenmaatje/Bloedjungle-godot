extends SceneTree
## Schermafbeeldingen van het hoofdkwartier en het voorplein in Godot, met de lichtinstellingen van het spel (atmosphere.gd: zon,
## ACES, contrast 1,2, mist), maar zonder de hele wereld (snel, ook zonder GPU). Compatibiliteitsrenderer: geen meting van iPhone-snelheid
## en niet pixelgelijk aan de mobiele renderer van de app.
## xvfb-run -a -s "-screen 0 1400x800x24" godot --rendering-driver opengl3 --path . -s tests/hq_licht_foto.gd --fixed-fps 60

var out := "/tmp/claude-0/hql_%s.png"
var tag := OS.get_environment("HQ_FOTO_TAG")
var cam: Camera3D


func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	call_deferred("_run")


func _frames(n: int) -> void:
	for _i in n:
		await process_frame


func _shot(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(out % (tag + name))
	print("foto ", name)


func _look(from: Vector3, at: Vector3, fov := 45.0) -> void:
	cam.fov = fov
	cam.global_position = from
	cam.look_at(at, Vector3.UP)
	cam.make_current()


func _run() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("56707a")
	sky_mat.sky_horizon_color = Color("a3b09a")
	sky_mat.ground_horizon_color = Color("8e9c80")
	sky_mat.ground_bottom_color = Color("2a3820")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.32 * 1.8
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.9
	env.tonemap_white = 8.0
	env.fog_enabled = true
	env.fog_light_color = Color("7f9078")
	env.fog_density = 0.0075
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.2
	env.adjustment_saturation = 1.1
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-33.0, -38.0, 0.0)
	sun.light_color = Color("ffe2b0")
	sun.light_energy = 1.55
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	root.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(120, 120)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.30, 0.19, 0.11)
	gm.roughness = 1.0
	ground.material_override = gm
	root.add_child(ground)
	cam = Camera3D.new()
	root.add_child(cam)
	var game: Node = root.get_node("Game")
	game.hq_level = 1
	var hq := Node3D.new()
	hq.set_script(load("res://scripts/hoofdkwartier.gd"))
	root.add_child(hq)
	root.add_child(load("res://scripts/hq_omgeving.gd").new())
	await _frames(8)
	_look(Vector3(0, 17.0, 14.0), Vector3(0, 0.6, 0.8), 45.0)
	await _frames(4)
	_shot("1_tactisch")
	_look(Vector3(1.5, 8.5, 9.0), Vector3(0.3, 2.2, 0.0), 45.0)
	await _frames(4)
	_shot("2_voorkant")
	_look(Vector3(-8.5, 7.0, 6.0), Vector3(-1.0, 1.8, 0.5), 45.0)
	await _frames(4)
	_shot("3_links_net")
	_look(Vector3(0.0, 22.0, 6.0), Vector3(0, 0, 1.0), 50.0)
	await _frames(4)
	_shot("4_boven")
	game.hq_level = 3
	await _frames(6)
	_look(Vector3(0, 17.0, 14.0), Vector3(0, 0.6, 0.8), 45.0)
	await _frames(4)
	_shot("5_niveau3")
	# niveau 1 en 3 vanuit dezelfde hoek, zoals in de viewer (linksvoor, hoog): de zandzakken horen op elk niveau het lagere dak te sluiten
	for lvl in [1, 2, 3]:
		game.hq_level = lvl
		await _frames(6)
		_look(Vector3(-7.5, 8.5, 8.0), Vector3(-0.3, 2.6, 0.0), 45.0)
		await _frames(4)
		_shot("6_niveau%d_linksvoor" % lvl)
	print("klaar")
	quit(0)
