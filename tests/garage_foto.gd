extends SceneTree
## Voor/na-opnames van de garage in Godot met de lichtinstellingen van het spel (zoals tests/hq_licht_foto.gd): oude garage
## (assets/vq2_baseline/garage_v1.glb) links, de Meshy-motorpool (assets/garage.glb) rechts, identieke camera en belichting.
## Compatibiliteitsrenderer zonder de hele wereld: geen meting van iPhone-snelheid.
## xvfb-run -a -s "-screen 0 1400x800x24" godot --rendering-driver opengl3 --path . -s tests/garage_foto.gd --fixed-fps 60

var out := OS.get_environment("GARAGE_FOTO_DIR").path_join("garage_%s.png") if OS.get_environment("GARAGE_FOTO_DIR") != "" else "/tmp/garage_%s.png"
var tag := ""
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
	var oud: Node3D = (load("res://assets/vq2_baseline/garage_v1.glb") as PackedScene).instantiate()
	oud.position = Vector3(-9.0, 0, 0)
	root.add_child(oud)
	var nieuw: Node3D = (load("res://assets/garage.glb") as PackedScene).instantiate()
	nieuw.position = Vector3(6.0, 0, 0)
	root.add_child(nieuw)
	for n in ["Romp_LOD1"]:
		nieuw.find_child(n, true, false).visible = false
	for n in ["DeurLampL", "DeurLampM", "DeurLampR", "BinnenLamp"]:
		nieuw.find_child(n, true, false).visible = false
	for n in ["DeurLampL", "DeurLampR", "BinnenLamp", "ZwaaiLicht"]:
		var l := oud.find_child(n, true, false)
		if l:
			l.visible = false
	await _frames(8)
	# spelcamera: 58 graden schuin van voren-boven, 28 m afstand, zoals de viewer (tools/blender-vq2-viewer)
	var mid := Vector3(-1.5, 0, 0)
	_look(mid + Vector3(0, 28.0 * sin(deg_to_rad(58)), 28.0 * cos(deg_to_rad(58))), mid, 45.0)
	await _frames(6)
	_shot("spelcamera_oud_links_nieuw_rechts")
	_look(Vector3(-9.0 - 7.0, 6.5, 12.0), Vector3(-9.0, 1.6, 0), 45.0)
	await _frames(4)
	_shot("oud_schuin")
	_look(Vector3(6.0 - 10.0, 9.0, 17.0), Vector3(6.0, 2.0, 0), 45.0)
	await _frames(4)
	_shot("nieuw_schuin_dicht")
	var ap: AnimationPlayer = nieuw.find_child("AnimationPlayer", true, false)
	ap.play("Open")
	ap.seek(2.0, true)
	await _frames(4)
	_shot("nieuw_schuin_open")
	_look(Vector3(6.0, 22.0, 13.0), Vector3(6.0, 0, 1.5), 45.0)
	await _frames(4)
	_shot("nieuw_spelcamera_open")
	quit(0)
