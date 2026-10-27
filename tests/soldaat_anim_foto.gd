extends SceneTree
## Demo van de code-gestuurde mannetjesanimaties (SoldierPose): lopen in 8 richtingen met het gezicht naar het richtpunt,
## trefferreacties vanuit vier richtingen en de ragdoll. Eén contactblad per onderdeel.
## xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --path . -s tests/soldaat_anim_foto.gd --fixed-fps 60
## Uitvoer: OUT/soldaat_anim_*.png (OUT = omgevingsvariabele SOLDAAT_OUT, standaard /tmp/soldaatfoto)

var frames := 0
var out := "/tmp/soldaatfoto"
var cam: Camera3D
var models: Array[SoldierModel] = []
var ground: StaticBody3D


func _initialize() -> void:
	if OS.get_environment("SOLDAAT_OUT") != "":
		out = OS.get_environment("SOLDAAT_OUT")
	DirAccess.make_dir_recursive_absolute(out)
	GameSettings.values["soldaat"] = "vq2"
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 1.1
	root.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.45, 0.52, 0.38)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.72, 0.7)
	root.add_child(env)
	ground = StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = WorldBoundaryShape3D.new()
	ground.add_child(cs)
	root.add_child(ground)
	var gm := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 40)
	gm.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.36, 0.42, 0.27)
	gm.material_override = mat
	root.add_child(gm)
	cam = Camera3D.new()
	root.add_child(cam)


func _row(z: float, look: String, gun: String) -> Array[SoldierModel]:
	var row: Array[SoldierModel] = []
	for i in 8:
		var m := SoldierModel.new()
		root.add_child(m)
		m.setup(Color("4b5a2c"), gun, look)
		m.scale = Vector3.ONE * Data.SOLDIER_SCALE
		m.position = Vector3((i - 3.5) * 1.8, 0.0, z)
		row.append(m)
	return row


func _shot(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("%s/soldaat_anim_%s.png" % [out, name])
	print("foto ", name)


func _walk(m: SoldierModel, rel: float) -> void:
	# zelfde keuze als Player._animate: achterstevoren lopen bij meer dan ~105 graden, anders vooruit; de benen draaien naar de looprichting
	var back := absf(rel) > 1.83
	m.play("lopen", 0.0, -1.0 if back else 1.0)   # achteruit = de loopcyclus achterstevoren (zoals Player._animate bij VQ2)
	m.set_leg_yaw(rel - signf(rel) * PI if back else rel)


func _clear() -> void:
	for m in models:
		m.queue_free()
	models.clear()


func _process(_d: float) -> bool:
	frames += 1
	# 1. lopen in 8 richtingen, gezicht steeds naar -Z (het richtpunt); van links naar rechts: 0, 45, 90, ... graden
	if frames == 2:
		cam.position = Vector3(0, 21, 12)
		cam.rotation_degrees = Vector3(-58, 0, 0)
		cam.fov = 30
		models = _row(0.0, "speler:uniform", "garand")
		for i in 8:
			models[i].rotation.y = PI
			_walk(models[i], _rel(i))
	if frames == 50:
		_shot("lopen8_spelcamera")
		cam.position = Vector3(0, 6, 9)
		cam.rotation_degrees = Vector3(-30, 0, 0)
		cam.fov = 40
	if frames == 52:
		_shot("lopen8_dichtbij")
		_clear()
	# 2. treffers vanuit vier richtingen (voor, rechts, achter, links van het mannetje); romp en hoofd duwen mee
	if frames == 56:
		cam.position = Vector3(0, 5, 8)
		cam.rotation_degrees = Vector3(-24, 0, 0)
		for i in 8:
			var m := SoldierModel.new()
			root.add_child(m)
			m.setup(Color("8c7b52"), "rifle", "vijand:rifle")
			m.scale = Vector3.ONE * Data.SOLDIER_SCALE
			m.position = Vector3((i - 3.5) * 1.8, 0.0, 0.0)
			m.rotation.y = PI
			m.play("stil", 0.0)
			models.append(m)
	if frames == 80:
		# kogelrichting in de wereld: het mannetje kijkt naar -Z, dus een schot van voren vliegt naar +Z
		var dirs := [Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, 0, -1), Vector3(1, 0, 0)]
		for i in 8:
			models[i].hit_reaction(dirs[i % 4], 1.4 if i < 4 else 0.7)
	if frames == 88:
		_shot("treffers")
		_clear()
	# 3. ragdoll: dezelfde rij lopende vijanden, daarna om en om geraakt; vier momenten
	if frames == 92:
		cam.position = Vector3(0, 3.2, 9)
		cam.rotation_degrees = Vector3(-14, 0, 0)
		cam.fov = 35
		for i in 6:
			var m := SoldierModel.new()
			root.add_child(m)
			m.setup(Color("8c7b52"), "rifle", "vijand:rifle")
			m.scale = Vector3.ONE * Data.SOLDIER_SCALE
			m.position = Vector3((i - 2.5) * 2.2, 0.0, 0.0)
			m.rotation.y = PI
			m.play("lopen", 0.0)
			models.append(m)
	if frames == 120:
		for i in models.size():
			SoldierRagdoll.start(models[i], Vector3(0, 0, -1.0 - 0.4 * i), Vector3(0, 0.5, -3.0))
	for f in [124, 134, 150, 190]:
		if frames == f:
			_shot("ragdoll_%d" % f)
	if frames == 191:
		quit(0)
	return false


func _rel(i: int) -> float:
	# looprichting t.o.v. het gezicht: vooruit, schuin rechts, rechts, schuin rechts achter, achteruit, schuin links achter, links, schuin links
	return deg_to_rad([0.0, 45.0, 90.0, 135.0, 180.0, -135.0, -90.0, -45.0][i])
