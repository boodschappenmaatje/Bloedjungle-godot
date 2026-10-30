extends Node
## Opnames van de Meshy-speler tijdens de gekoppelde API-acties (echte player.tscn, spelcamera-hoek 58°).
## Gebruik: godot --rendering-driver opengl3 res://tests/meshy_player_actions_foto.tscn  (schrijft naar OUT_DIR)

const OUT_DIR := "user://meshy_acties/"
const ACTIES := [["stil", 0.5], ["achteruit", 0.5], ["geraakt", 0.5], ["dood1", 1.2], ["dood2", 1.2], ["explosie_dood", 1.0], ["rollen", 0.6],
	["klimmen", 0.8], ["zitten", 0.5], ["steken", 0.5], ["brand_rennen", 0.6], ["brand_val", 1.2]]


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	GameSettings.values["soldaat"] = "meshy"
	var game: Node = get_tree().root.get_node("Game")
	game.set("state", "menu")
	var world := Node3D.new()
	get_tree().root.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.shadow_enabled = true
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
	player.set_physics_process(false)
	player.set_process(false)
	var model: Variant = player.get_node("Model")
	var lijst := FileAccess.open(OUT_DIR + "lijst.txt", FileAccess.WRITE)
	for a in ACTIES:
		for moment in [0.15, 0.45, 0.9]:
			model.play("stil", 0.0, 1.0)
			await get_tree().process_frame
			model.play(a[0], 0.0, 1.0)
			model.anim.seek(model.anim.get_animation(a[0]).length * moment, true)
			model.anim.pause()
			var ang := deg_to_rad(40.0)
			cam.global_position = player.global_position + Vector3(0, sin(ang) * 7.0 + 0.6, cos(ang) * 7.0)
			cam.look_at(player.global_position + Vector3(0, 0.5, 0))
			for _i in 4:
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT_DIR) + "%s_%d.png" % [a[0], int(moment * 100)])
		lijst.store_line(a[0])
	lijst.close()
	get_tree().quit(0)
