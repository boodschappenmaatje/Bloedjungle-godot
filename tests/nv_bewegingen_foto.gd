extends SceneTree
## Voor/na-opnames van de NVIDIA-bewegingen (bron/soldaat_vq2/nvidia): boven = oud (benen verdraaien / direct stil),
## onder = nieuw. Zelfde camera en belichting voor beide. Drie scènes: opzij lopen, draaien op de plek, afremmen.
## xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --path . -s tests/nv_bewegingen_foto.gd --fixed-fps 30
## Uitvoer: OUT/nv_<scene>_<nr>.png (OUT = omgevingsvariabele NV_OUT, standaard /tmp/nvfoto)

var frames := 0
var out := "/tmp/nvfoto"
var cam: Camera3D
var oud: SoldierModel
var nieuw: SoldierModel
var scene_i := 0
var t0 := 0
const SCENES := ["opzij", "draaien", "stoppen"]
const LEN := 64


func _initialize() -> void:
	if OS.get_environment("NV_OUT") != "":
		out = OS.get_environment("NV_OUT")
	DirAccess.make_dir_recursive_absolute(out)
	GameSettings.values["soldaat"] = "vq2"
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	root.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.45, 0.52, 0.38)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.72, 0.7)
	root.add_child(env)
	var gm := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 40)
	gm.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.36, 0.42, 0.27)
	gm.material_override = mat
	root.add_child(gm)
	cam = Camera3D.new()
	cam.position = Vector3(0, 4.6, 6.2)
	cam.rotation_degrees = Vector3(-33, 0, 0)
	cam.fov = 38
	root.add_child(cam)


func _maak(nv: bool, z: float) -> SoldierModel:
	GameSettings.values["soldaat"] = "vq2"
	GameSettings.values["nv_anim"] = "on" if nv else "off"
	var m := SoldierModel.new()
	root.add_child(m)
	m.setup(Color("4b5a2c"), "garand", "speler:uniform")
	m.scale = Vector3.ONE * Data.SOLDIER_SCALE
	m.position = Vector3(0, 0, z)
	return m


func _start(naam: String) -> void:
	if oud != null:
		oud.queue_free()
		nieuw.queue_free()
	oud = _maak(false, -1.1)
	nieuw = _maak(true, 1.1)
	GameSettings.values["nv_anim"] = "on"
	for m in [oud, nieuw]:
		m.play("stil", 0.0)
		if naam == "opzij":
			m.position.x = -2.6
		if naam == "stoppen":
			m.position.x = -2.6
			m.rotation.y = PI / 2.0   # kijkt naar +X en loopt naar +X


func _stap(naam: String, k: int, dt: float) -> void:
	var s := Data.SOLDIER_SCALE
	for m in [oud, nieuw]:
		if naam == "opzij":
			# gezicht naar de camera (+Z), lopen naar links van het mannetje (+X), 2,85 m/s
			var spd := 2.85
			m.position.x += spd * s * dt
			if not m.play_nv_move(PI / 2.0, spd):
				m.play("lopen", 0.2, spd / 2.4)
				m.set_leg_yaw(PI / 2.0)
		elif naam == "draaien":
			# stilstaan en snel een halve slag linksom draaien (zoals richten met de rechterstick)
			if k > 8 and k < 30:
				m.rotation.y += PI / 22.0
			m.play("stil")
		elif naam == "stoppen":
			if k < 22:
				m.position.x += 4.0 * s * dt
				m.play("lopen", 0.2, 4.0 / 2.4)
			else:
				m.play("stil")


func _process(d: float) -> bool:
	frames += 1
	if frames == 2:
		_start(SCENES[0])
		t0 = frames
	if frames > 2:
		var k := frames - t0
		var naam: String = SCENES[scene_i]
		_stap(naam, k, 1.0 / 30.0)
		if k >= 4 and k % 2 == 0:
			root.get_viewport().get_texture().get_image().save_png("%s/nv_%s_%02d.png" % [out, naam, (k - 4) / 2])
		if k >= LEN:
			scene_i += 1
			if scene_i >= SCENES.size():
				print("NV FOTO KLAAR")
				quit(0)
				return false
			_start(SCENES[scene_i])
			t0 = frames
	return false
