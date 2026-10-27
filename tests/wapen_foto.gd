extends SceneTree
## Wapenhouding per wapen: elk wapen vastgehouden (stil), schietend en lopend, van opzij en met de spelcamera van boven.
## xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --path . -s tests/wapen_foto.gd --fixed-fps 60
## Uitvoer: OUT/wapen_*.png (OUT = omgevingsvariabele WAPEN_OUT, standaard /tmp/wapenfoto)

const WEAPONS := ["m1911", "thompson", "garand", "trench", "mg42", "bazooka", "rifle", "heavy", "rocket"]
var frames := 0
var out := "/tmp/wapenfoto"
var cam: Camera3D
var models: Array[SoldierModel] = []


func _initialize() -> void:
	if OS.get_environment("WAPEN_OUT") != "":
		out = OS.get_environment("WAPEN_OUT")
	DirAccess.make_dir_recursive_absolute(out)
	GameSettings.values["soldaat"] = "vq2"
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.1
	root.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.45, 0.52, 0.38)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.72, 0.7)
	root.add_child(env)
	cam = Camera3D.new()
	root.add_child(cam)
	for i in WEAPONS.size():
		var m := SoldierModel.new()
		root.add_child(m)
		var kind: String = WEAPONS[i]
		m.setup(Color("4b5a2c"), kind, "speler:uniform")
		m.scale = Vector3.ONE * Data.SOLDIER_SCALE
		m.position = Vector3(0, 0, (i - (WEAPONS.size() - 1) / 2.0) * 1.9)
		m.rotation.y = PI   # kijkt naar -Z, dus naar links in een zijaanzicht vanaf +X? (camera hieronder)
		models.append(m)


func _gaps() -> void:
	for i in models.size():
		var g: Dictionary = (models[i].get("pose") as SoldierPose).reach_gap
		print("bereik %s: rechts %+.3f links %+.3f (meter buiten bereik)" % [WEAPONS[i], g.R, g.L])


func _shot(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("%s/wapen_%s.png" % [out, name])
	print("foto ", name)


func _pose(mode: String) -> void:
	for i in models.size():
		var kind: String = WEAPONS[i]
		var wk := {"rifle": "garand", "heavy": "mg42", "rocket": "bazooka"}.get(kind, kind) as String
		match mode:
			"stil":
				models[i].set_shoot_pose(false, wk, 0.2)
				models[i].play("stil", 0.0)
			"schieten":
				models[i].set_shoot_pose(true, wk, 0.2)
				models[i].play("schieten", 0.0)
			"lopen":
				models[i].set_shoot_pose(false, wk, 0.2)
				models[i].play("lopen", 0.0)


func _side(first: int, from_right: bool) -> void:
	# zijaanzicht van drie wapens tegelijk; het mannetje kijkt naar -Z: camera op +X ziet zijn rechterkant (de schietende hand), op -X de linkerkant
	var center := models[first + 1].position.z
	var sx := 10.5 if from_right else -10.5
	cam.position = Vector3(sx, 1.5, center)
	cam.look_at(Vector3(0, 1.3, center), Vector3.UP)
	cam.fov = 22


func _closeup() -> bool:
	# WAPEN_ONE=<wapen>: één wapen van vier kanten dichtbij (rechts, links, boven, schuin voor), apart in WAPEN_OUT
	var one := OS.get_environment("WAPEN_ONE")
	if one == "":
		return false
	var idx := WEAPONS.find(one)
	for i in models.size():
		models[i].visible = i == idx
	var m := models[idx]
	var c := m.global_position + Vector3(0, 1.45, 0)
	var views := [["rechts", Vector3(3.2, 0.1, 0)], ["links", Vector3(-3.2, 0.1, 0)], ["boven", Vector3(0.0, 3.2, 0.6)], ["voor", Vector3(1.6, 0.3, -2.8)]]
	var k := frames - 8
	if k >= 0 and k < views.size() * 3:
		if k % 3 == 0:
			cam.position = c + (views[k / 3][1] as Vector3)
			cam.look_at(c + Vector3(0, 0, -0.35), Vector3.UP)
			cam.fov = 38
		if k % 3 == 2:
			_shot("een_%s_%s" % [one, views[k / 3][0]])
	if k >= views.size() * 3:
		quit(0)
	return true


func _process(_d: float) -> bool:
	frames += 1
	if frames == 3:
		_pose(OS.get_environment("WAPEN_POSE") if OS.get_environment("WAPEN_POSE") != "" else "schieten")
	if _closeup():
		return false
	# 9 wapens: groepen van 3 vanaf rechts (r) en links (l)
	var k := frames - 10
	if k >= 0 and k < 12 and k % 2 == 0:
		_side((k / 2) % 3 * 3, k < 6)
	if k >= 0 and k < 12 and k % 2 == 1:
		_shot("%s_%d" % ["r" if k < 6 else "l", ((k - 1) / 2) % 3])
	if frames == 28:
		_gaps()
	if frames == 30:
		for i in models.size():
			models[i].position = Vector3((i - (models.size() - 1) / 2.0) * 1.9, 0, 0)
		cam.position = Vector3(0, 21, 12)
		cam.rotation_degrees = Vector3(-58, 0, 0)
		cam.fov = 30
	if frames == 36:
		_shot("spelcamera")
		quit(0)
	return false
