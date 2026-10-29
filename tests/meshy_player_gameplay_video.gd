extends Node
## Captures a short Meshy/Garand proof using scenes/main.tscn and its real CameraRig.

const CAMERA_SCRIPT := preload("res://scripts/camera_rig.gd")
var _output_dir := ""
var _frame_index := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_output_dir = OS.get_environment("MESHY_PREVIEW_DIR")
	if _output_dir.is_empty():
		_output_dir = ProjectSettings.globalize_path("res://artifacts/meshy_player/previews/gameplay_camera")
	DirAccess.make_dir_recursive_absolute(_output_dir)
	get_tree().root.size = Vector2i(1600, 900)
	GameSettings.get_value("soldaat") # load persisted defaults before applying the test-only override
	GameSettings.values["soldaat"] = "meshy"
	GameSettings.values["quality"] = "high"
	var world := Node3D.new()
	world.name = "MeshyGameplayCameraPreview"
	get_tree().root.add_child(world)
	_add_preview_environment(world)
	Game.state = "play"
	Game.build_mode = false
	Game.owned = Game.call("_fresh_owned")
	Game.owned["garand"] = {"up": {"dmg": 0, "rate": 0, "mag": 0, "rel": 0}, "ammo": 8}
	Game.cur = "garand"
	var player_scene := load("res://scenes/player.tscn") as PackedScene
	var player_instance := player_scene.instantiate()
	world.add_child(player_instance)
	await get_tree().process_frame
	await get_tree().physics_frame
	var player: Variant = Game.player
	var model: Variant = player.get_node("Model")
	print("MESHY_VIDEO_SETUP setting=", GameSettings.get_value("soldaat"), " model_meshy=", model.meshy_player, " setting_values=", GameSettings.values)
	if not model.meshy_player or model._mesh_skeleton == null:
		push_error("The camera preview did not select the Meshy player.")
		get_tree().quit(2)
		return
	var camera := Camera3D.new()
	camera.name = "Camera"
	camera.set_script(CAMERA_SCRIPT)
	world.add_child(camera)
	camera.combat_view = true
	camera.zoom_step = -3
	camera.attributes.dof_blur_far_enabled = false
	player.weapon = "garand"
	player.model.set_gun("garand")
	player.ammo = 8
	player.fire_t = 0.0
	player.reload_t = 0.0
	player.sprint_on = false
	player.face = 0.0
	player.rotation.y = 0.0
	player.set_physics_process(false)
	Game.state = "menu" # hold position; play the real imported clips for a clear IK inspection
	Game.move = Vector2.ZERO
	Game.aim = NAN
	model.current = ""
	model.play("stil")
	await _capture_segment(24)
	model.play("lopen")
	await _capture_segment(24)
	model.play("rennen")
	await _capture_segment(24)
	model.play("sprinten")
	await _capture_segment(24)
	model.play("stil")
	player.fire_t = 0.0
	player._shoot(Game.call("wstat", "garand"))
	await _capture_segment(18)

	player.ammo = 1
	player.reload_t = 0.0
	player.idle_t = 0.0
	player._reload(Game.call("wstat", "garand"))
	model.play("herladen")
	await _capture_segment(30)

	print("MESHY_GAMEPLAY_VIDEO frames=", _frame_index, " output=", _output_dir, " camera_script=", camera.get_script().resource_path, " player_rig_bones=", model._mesh_skeleton.get_bone_count(), " garand=", model._mesh_weapon_adapter.weapon.name)
	get_tree().quit(0)


func _add_preview_environment(world: Node3D) -> void:
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("263c2f")
	sky_material.sky_horizon_color = Color("b5a574")
	sky_material.ground_bottom_color = Color("171b12")
	sky_material.ground_horizon_color = Color("8c8356")
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b9c09d")
	environment.ambient_light_energy = 0.7
	env.environment = environment
	world.add_child(env)
	var floor := StaticBody3D.new()
	floor.name = "PreviewFloor"
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80.0, 0.1, 80.0)
	floor_shape.shape = box
	floor_shape.position.y = -0.05
	floor.add_child(floor_shape)
	world.add_child(floor)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80.0, 80.0)
	ground.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("46452d")
	material.roughness = 0.95
	ground.material_override = material
	ground.position.y = -0.055
	world.add_child(ground)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_color = Color("fff0ce")
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	world.add_child(sun)


func _capture_segment(frame_count: int) -> void:
	for _i in frame_count:
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var path := _output_dir.path_join("frame_%04d.png" % _frame_index)
		var error := image.save_png(path)
		if error != OK:
			push_error("Could not save gameplay preview frame: " + path + " error=" + str(error))
		_frame_index += 1
