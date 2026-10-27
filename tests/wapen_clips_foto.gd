extends SceneTree
## Bewegende wapendelen in beeld: per wapen rust en schotpiek van boven en van rechts (clips uit bron/wapens, zie wapen_clips_test).
## xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --path . -s tests/wapen_clips_foto.gd --fixed-fps 60
## Uitvoer: OUT/klip_<wapen>_<aanzicht>_<rust|piek>.png (OUT = KLIP_OUT, standaard /tmp/klipfoto)
const WEAPONS := {"m1911": 3, "thompson": 1, "garand": 4, "trench": 15, "mg42": 1, "m1911_leeg": 5}
const VIEWS := {"boven": Vector3(0.0, 0.95, 0.12), "rechts": Vector3(-0.85, 0.15, 0.1)}
var out := "/tmp/klipfoto"
var cam: Camera3D
var model: SoldierModel
var queue: Array = []
var step := 0
var frames_left := 0
var plan: Array = []   # [wapen, aanzicht, na hoeveel beelden na het schot, label]


func _initialize() -> void:
	if OS.get_environment("KLIP_OUT") != "":
		out = OS.get_environment("KLIP_OUT")
	DirAccess.make_dir_recursive_absolute(out)
	GameSettings.values["soldaat"] = "vq2"
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	root.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.45, 0.52, 0.38)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.72, 0.7)
	root.add_child(env)
	cam = Camera3D.new()
	cam.fov = 30.0
	root.add_child(cam)
	cam.current = true
	_next.call_deferred()


func _snap(weapon: String, view: String, label: String) -> void:
	var gun := model.get("_gun") as Node3D
	var c := gun.global_position + gun.global_transform.basis * Vector3(0, 0.1, -0.1)
	cam.global_position = c + (VIEWS[view] as Vector3) * (1.0 if weapon != "garand" else 1.3)
	cam.look_at(c, Vector3.UP if view == "rechts" else Vector3.FORWARD)
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/klip_%s_%s_%s.png" % [out, weapon, view, label])


func _next() -> void:
	for key in WEAPONS:
		var weapon: String = key.trim_suffix("_leeg")
		for view in VIEWS:
			if model != null:
				model.queue_free()
			model = SoldierModel.new()
			root.add_child(model)
			model.setup(Color("4b5a2c"), weapon, "speler:uniform")
			model.set_shoot_pose(true, weapon, 0.2)
			model.play("schieten", 0.0)
			for _i in 12:
				await process_frame
			await _snap(key, view, "rust")
			model.shoot_recoil(weapon, key.ends_with("_leeg"))
			for _i in int(WEAPONS[key]):
				await process_frame
			await _snap(key, view, "piek")
	print("klaar: ", out)
	quit()
