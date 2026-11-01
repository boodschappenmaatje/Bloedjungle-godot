extends Node
## Vergelijkingsopnames van het verkleinde vliegveld (Generals-verhoudingen) in het echte spel (main.tscn, spelcamera-instellingen):
## vliegveld naast kazerne, garage, tank, jeep en het toestel. Uitvoer: env AIRFIELD_CAPTURE_DIR.

var _main: Node3D
var _out := ""

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_out = OS.get_environment("AIRFIELD_CAPTURE_DIR")
	if _out.is_empty():
		_out = "res://docs/airfield_generals_scale/captures"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
	get_tree().root.add_child(_main)
	await get_tree().process_frame
	await _main.begin()
	var menu := get_tree().get_first_node_in_group("menus")
	if menu != null:
		await menu._show("")
	Game.state = "prep"
	Game.points = 20000
	Game.build_credit = 0
	var at := AirfieldHQ23.SUGGESTED_CENTER
	var b: Variant = Game.builds.place("airfield", at, 0.0)
	assert(b != null, "vliegveld moet plaatsbaar zijn")
	# kazerne en garage mogen alleen in de basis staan: voor de schaalvergelijking zetten we alleen de modellen naast het vliegveld
	for entry in [["kazerne", Vector3(-44.0, 0.0, 4.0)], ["garage", Vector3(-44.0, 0.0, 14.0)]]:
		var node: Node3D = Game.builds.make_node(entry[0])
		if node != null:
			Game.builds.add_child(node)
			node.global_position = at + entry[1]
			node.rotation.y = PI * 0.5
			print("model naast vliegveld: ", entry[0])
	var tank := (load("res://scenes/tank.tscn") as PackedScene).instantiate() as Node3D
	_main.add_child(tank)
	tank.global_position = at + Vector3(-36.0, 0.0, 6.0)
	var jeep := (load("res://scenes/jeep.tscn") as PackedScene).instantiate() as Node3D
	_main.add_child(jeep)
	jeep.global_position = at + Vector3(-36.0, 0.0, 12.0)
	_hide_ui()
	await _settle(200)  # het toestel wordt na ~1 s klaargezet
	var p = Game.player
	p.global_position = at + Vector3(-10.0, 0.3, 19.0)
	var cam := Camera3D.new()
	cam.far = 900.0
	var rig := get_viewport().get_camera_3d()
	if rig != null:
		cam.attributes = rig.attributes
	_main.add_child(cam)
	cam.make_current()
	var mid := at + Vector3(-1.0, 0.0, 2.0)
	var wide := at + Vector3(-20.0, 0.0, 6.0)
	await _shot(cam, wide + Vector3(0.0, 95.0, 0.1), wide, 43.0, "00_vergelijk_bovenaanzicht.png")
	await _shot(cam, wide + Vector3(20.0, 38.0, 46.0), wide + Vector3(-4.0, 0.0, 4.0), 45.0, "00b_vergelijk_schuin.png")
	await _shot(cam, mid + Vector3(0.0, 70.0, 0.1), mid, 43.0, "01_bovenaanzicht.png")
	await _shot(cam, mid + Vector3(26.0, 22.0, 30.0), mid, 45.0, "02_schuin_zuidoost.png")
	await _shot(cam, mid + Vector3(-30.0, 20.0, 30.0), mid + Vector3(-8.0, 0.0, 6.0), 45.0, "03_schuin_zuidwest_gebouwen.png")
	await _shot(cam, at + Vector3(0.0, 9.0, 20.0), at + Vector3(0.0, 1.0, 2.0), 50.0, "04_hangardeur.png")
	# speler in de hangar: deuren open en dak weg, zodat het toestel binnen te zien is
	p.global_position = at + Vector3(2.5, 0.3, 2.0)
	await _settle(120)
	await _shot(cam, at + Vector3(0.0, 11.0, 14.0), at + Vector3(0.0, 1.0, 1.5), 50.0, "05_toestel_in_hangar.png")
	print("AIRFIELD SCALE CAPTURE DONE ", _out)
	get_tree().quit(0)

func _shot(cam: Camera3D, from: Vector3, target: Vector3, fov: float, file: String) -> void:
	cam.fov = fov
	cam.global_position = from
	cam.look_at(target, Vector3.UP)
	await _settle(30)
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(_out.path_join(file)))
	print("CAPTURE ", file)

func _settle(n: int) -> void:
	for _i in n:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

func _hide_ui() -> void:
	for layer in _main.find_children("*", "CanvasLayer", true, false):
		var cl := layer as CanvasLayer
		if cl.layer >= 0:
			cl.visible = false
