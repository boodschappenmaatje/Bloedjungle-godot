extends Node
## Offscreen Godot capture of the actual Assault scene instance, including the detached Meshy rifle.

const OUTPUT_DEFAULT := "res://source_assets/enemy_assault/rig_test"

func _ready() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
	get_tree().root.add_child(main)
	await get_tree().process_frame
	Game.state = "menu"
	var enemy := (load("res://scenes/enemy.tscn") as PackedScene).instantiate() as Node3D
	enemy.call("setup", "assault", 1)
	enemy.position = Vector3.ZERO
	get_tree().root.add_child(enemy)
	await get_tree().process_frame
	await get_tree().process_frame
	enemy.set_physics_process(false)
	var camera := Camera3D.new()
	camera.name = "AssaultWeaponCaptureCamera"
	camera.fov = 32.0
	camera.far = 60.0
	get_tree().root.add_child(camera)
	camera.global_position = Vector3(2.7, 1.8, 4.2)
	camera.look_at(Vector3(0.0, 0.94, 0.0), Vector3.UP)
	camera.make_current()
	for layer in main.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	var output_dir := OS.get_environment("ASSAULT_CAPTURE_DIR")
	if output_dir.is_empty():
		output_dir = OUTPUT_DEFAULT
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	if not _save(output_dir.path_join("capture_meshy_weapon_godot_idle.png")):
		get_tree().quit(2)
		return
	print("ASSAULT_GODOT_CAPTURES=", output_dir)
	get_tree().quit(0)


func _save(path: String) -> bool:
	RenderingServer.force_draw()
	var viewport_texture := get_viewport().get_texture()
	if viewport_texture == null:
		push_error("Godot viewport texture is unavailable for Assault capture")
		return false
	var image := viewport_texture.get_image()
	if image == null:
		push_error("Godot's active renderer does not support viewport readback; run this capture scene with a rendering driver")
		return false
	var err := image.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		push_error("Could not write capture at %s (error %d)" % [path, err])
		return false
	print("ASSAULT_CAPTURE path=", path, " size=", image.get_width(), "x", image.get_height(), " bytes=", FileAccess.get_file_as_bytes(ProjectSettings.globalize_path(path)).size())
	return true
