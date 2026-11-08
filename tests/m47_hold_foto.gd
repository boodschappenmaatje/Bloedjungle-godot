extends Node
## Opnames van de echte Meshy-speler met het M-47 in de hand (spelcamera-hoek en 3 zijaanzichten).
## Gebruik: godot --rendering-driver vulkan res://tests/m47_hold_foto.tscn -- --out=/pad/

func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var out := "/tmp/m47hold/"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	GameSettings.get_value("soldaat")
	GameSettings.values["soldaat"] = "meshy"
	var game: Node = get_tree().root.get_node("Game")
	game.set("state", "menu")
	game.set("cur", "garand")
	game.set("owned", game.call("_fresh_owned"))
	var owned: Dictionary = game.get("owned")
	owned["garand"] = {"up": {"dmg": 0, "rate": 0, "mag": 0, "rel": 0}, "ammo": 5}
	game.set("owned", owned)
	var world := Node3D.new()
	get_tree().root.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	world.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.25, 0.3, 0.25)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	world.add_child(env)
	var floor_mesh := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	floor_mesh.mesh = pm
	world.add_child(floor_mesh)
	var cam := Camera3D.new()
	cam.fov = 45.0
	world.add_child(cam)
	cam.current = true
	var player: Variant = load("res://scenes/player.tscn").instantiate()
	world.add_child(player)
	await get_tree().process_frame
	await get_tree().physics_frame
	player.set_physics_process(false)
	player.set_process(false)
	var model: Variant = player.get_node("Model")
	model.set_gun("m47")
	for _i in 6:
		await get_tree().process_frame
	var ad: Variant = model.get("_mesh_weapon_adapter")
	print("ADAPTER ", ad, " meshy ", model.meshy_player, " kind ", model.get("_weapon_kind"), " skel ", model.get("_mesh_skeleton"), " status ", model.player_status)
	if ad != null:
		print("WEAPON ", ad.weapon, " pos ", ad.global_position, " vis ", ad.weapon.visible)
		for n in ad.weapon.find_children("*", "MeshInstance3D", true, false):
			print(" mesh ", n.name, " vis ", n.is_visible_in_tree(), " aabb ", n.get_aabb().size, " gpos ", n.global_position)
	model.play("stil", 0.0, 1.0)
	for _i in 10:
		await get_tree().process_frame
	var views := {"spel": [58.0, 0.0, 7.0], "zij": [8.0, 90.0, 4.5], "voor": [10.0, 30.0, 4.5], "achter": [10.0, 200.0, 4.5], "boven": [75.0, 0.0, 5.0], "zijnabij": [5.0, 90.0, 2.6], "schuin": [25.0, 50.0, 2.8]}
	for k in views:
		var v: Array = views[k]
		var el := deg_to_rad(float(v[0]))
		var az := deg_to_rad(float(v[1]))
		var d: float = v[2]
		var c: Vector3 = player.global_position + Vector3(0, 0.9, 0)
		cam.global_position = c + Vector3(sin(az) * cos(el), sin(el), cos(az) * cos(el)) * d
		cam.look_at(c)
		for _i in 4:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(out + k + ".png")
	get_tree().quit(0)
