extends SceneTree
## Schietbeeld in spelcamera (58 graden, 28 m): per wapen een reeks beelden na een schot (flits, spoor, terugslag).
## xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --path . -s tests/schiet_foto.gd --fixed-fps 60
## Uitvoer: OUT/schiet_<wapen>_<n>.png (OUT = SCHIET_OUT, standaard /tmp/schietfoto); SCHIET_WEAPON kiest het wapen.
const SHOTS := [1, 3, 5, 8, 12, 18]
var out := "/tmp/schietfoto"
var weapon := "m1911"
var frames := 0
var m: SoldierModel
var cam: Camera3D
var n := 0


func _initialize() -> void:
	if OS.get_environment("SCHIET_OUT") != "":
		out = OS.get_environment("SCHIET_OUT")
	if OS.get_environment("SCHIET_WEAPON") != "":
		weapon = OS.get_environment("SCHIET_WEAPON")
	DirAccess.make_dir_recursive_absolute(out)
	GameSettings.values["soldaat"] = "vq2"
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
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
	cam.fov = 40.0
	cam.current = true
	cam.position = Vector3(0, 9.0, 5.5)
	cam.rotation_degrees = Vector3(-58, 0, 0)
	m = SoldierModel.new()
	root.add_child(m)
	m.setup(Color("4b5a2c"), weapon, "speler:uniform")
	m.scale = Vector3.ONE * Data.SOLDIER_SCALE
	m.set_shoot_pose(true, weapon, 0.2)
	m.play("schieten", 0.0)


func _process(_d: float) -> bool:
	frames += 1
	if frames == 30:
		m.shoot_recoil(weapon)
		var p := m.muzzle_position()
		var bullet_script: GDScript = load("res://scripts/bullet.gd")
		var fx_script: GDScript = load("res://scripts/fx.gd")
		bullet_script.fire(root, p, 0.0, 60.0, 1.0, 1.0, true, false, 0, 0.0, 0.0, 0.0, weapon)
		fx_script.muzzle(root, p, weapon, 0.0)
	var k := frames - 30
	if k >= 0 and SHOTS.has(k):
		root.get_viewport().get_texture().get_image().save_png("%s/schiet_%s_%02d.png" % [out, weapon, k])
		n += 1
	return frames > 30 + SHOTS[-1] + 2
