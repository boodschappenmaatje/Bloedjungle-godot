extends Node
## Matched before/after review captures of the placed HQ2.3 airfield in the production world
## (main.tscn, Atmosphere light/tonemap, game camera rig). Output dir: env AIRFIELD_CAPTURE_DIR
## (default docs/airfield_hq_v23/exposure_fix/after). Prints the clipped-pixel share per view.

const MAIN_SCENE := "res://scenes/main.tscn"

var _main: Node3D
var _out := ""

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_out = OS.get_environment("AIRFIELD_CAPTURE_DIR")
	if _out.is_empty():
		_out = "res://docs/airfield_hq_v23/exposure_fix/after"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_main = (load(MAIN_SCENE) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child(_main)
	await get_tree().process_frame
	await _main.begin()
	var menu := get_tree().get_first_node_in_group("menus")
	if menu != null:
		await menu._show("")
	Game.state = "prep"
	Game.points = 8000
	Game.build_credit = 0
	var building: Variant = Game.builds.place("airfield", AirfieldHQ23.SUGGESTED_CENTER, 0.0)
	assert(building != null, "airfield must be placeable at the suggested site")
	_hide_ui()
	if OS.get_environment("AIRFIELD_CAPTURE_EXPERIMENT") == "noshadow":
		for l in _main.find_children("*", "DirectionalLight3D", true, false):
			(l as DirectionalLight3D).shadow_enabled = false
	var basis := Basis(Vector3.UP, building.yaw)
	var at: Vector3 = building.at
	var tower := at + basis * Vector3(AirfieldHQ23.TOWER_CENTER.x, 8.0, AirfieldHQ23.TOWER_CENTER.y)
	var hangar := at + basis * Vector3(AirfieldHQ23.HANGAR_CENTER.x, 3.0, AirfieldHQ23.HANGAR_CENTER.y)
	var runway := at + basis * Vector3(-19.0, 0.0, AirfieldHQ23.RUNWAY_CENTER_Z)
	# 1) real gameplay camera: player standing on the apron, rig follows as in play
	var p = Game.player
	p.global_position = at + basis * Vector3(AirfieldHQ23.APRON_CENTER.x - 6.0, 0.3, AirfieldHQ23.APRON_CENTER.y - 4.0)
	p.velocity = Vector3.ZERO
	await _settle(90)
	await _save("01_gamecamera_speler_platform.png")
	var rig := get_viewport().get_camera_3d()
	var cam := Camera3D.new()
	cam.fov = 43.0
	cam.far = 900.0
	if rig != null:
		cam.attributes = rig.attributes
	_main.add_child(cam)
	cam.make_current()
	# 2) outside overview (same framing as the earlier 09 capture)
	await _shot(cam, at + basis * Vector3(52.0, 132.0, 72.0), at + basis * Vector3(0.0, 2.0, -10.0), 43.0, "02_buiten_overzicht.png")
	# 3) tower close-up (same framing as 10)
	await _shot(cam, tower + basis * Vector3(23.0, 12.0, 25.0), tower + Vector3.UP, 43.0, "03_toren.png")
	# 4) hangar roof + doors at game distance (moire check)
	await _shot(cam, hangar + basis * Vector3(26.0, 34.0, 30.0), hangar, 45.0, "04_hangar.png")
	# 5) runway top-down (same framing as 11)
	await _shot(cam, runway + Vector3.UP * 82.0 + basis * Vector3(0.0, 0.0, 4.0), runway, 55.0, "05_baan.png")
	print("AIRFIELD GAME CAMERA CAPTURE DONE ", _out)
	get_tree().quit(0)

func _shot(cam: Camera3D, from: Vector3, target: Vector3, fov: float, file: String) -> void:
	cam.fov = fov
	cam.global_position = from
	cam.look_at(target, Vector3.UP)
	await _settle(10)
	await _save(file)

func _settle(n: int) -> void:
	for _i in n:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

func _save(file: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(_out.path_join(file)))
	var clipped := 0
	var total := 0
	for y in range(0, img.get_height(), 4):
		for x in range(0, img.get_width(), 4):
			var c := img.get_pixel(x, y)
			total += 1
			if c.r > 0.96 and c.g > 0.96 and c.b > 0.96:
				clipped += 1
	print("CAPTURE ", file, " clipped_white=%.2f%%" % (100.0 * clipped / maxf(1.0, total)))

func _hide_ui() -> void:
	for layer in _main.find_children("*", "CanvasLayer", true, false):
		var cl := layer as CanvasLayer
		if cl.layer >= 0:
			cl.visible = false
