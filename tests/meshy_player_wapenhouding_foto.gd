extends Node
## Opnames van de Meshy-speler met een gekozen wapen, lopend en stil, vanuit de spelcamera.
## Gebruik: godot --rendering-driver opengl3 res://tests/meshy_player_wapenhouding_foto.tscn -- --wapen=m1911

const OUT_DIR := "user://meshy_wapen/"


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var wapen := "m1911"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--wapen="):
			wapen = a.substr(8)
	GameSettings.get_value("soldaat")
	GameSettings.values["soldaat"] = "meshy"
	var game: Node = get_tree().root.get_node("Game")
	game.set("state", "menu")
	game.set("cur", wapen)
	game.set("owned", game.call("_fresh_owned"))
	var owned: Dictionary = game.get("owned")
	owned[wapen] = {"up": {"dmg": 0, "rate": 0, "mag": 0, "rel": 0}, "ammo": 5}
	game.set("owned", owned)
	var world := Node3D.new()
	get_tree().root.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	world.add_child(sun)
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
	for clip in ["stil", "lopen"]:
		for yaw in [0, 90, 180, 270]:
			model.play(clip, 0.0, 1.0)
			model.anim.seek(model.anim.get_animation(clip).length * 0.3, true)
			model.anim.pause()
			player.rotation.y = deg_to_rad(yaw)
			var ang := deg_to_rad(58.0)
			cam.global_position = player.global_position + Vector3(0, sin(ang) * 4.5, cos(ang) * 4.5)
			cam.look_at(player.global_position + Vector3(0, 0.6, 0))
			for _i in 4:
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT_DIR) + "%s_%s_%d.png" % [wapen, clip, yaw])
	get_tree().quit(0)
