extends Node
## Matched before/after review captures of the placed HQ2.3 airfield in the production world
## (main.tscn, Atmosphere light/tonemap, game camera rig). Output dir: env AIRFIELD_CAPTURE_DIR
## (default docs/airfield_hq_v23/hangar_gameplay). Prints the clipped-pixel share per view.

const MAIN_SCENE := "res://scenes/main.tscn"

var _main: Node3D
var _out := ""

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_out = OS.get_environment("AIRFIELD_CAPTURE_DIR")
	if _out.is_empty():
		_out = "res://docs/airfield_hq_v23/hangar_gameplay"
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
	var p = Game.player
	var spots := [["01_buiten_deuren_dicht", Vector3(0.0, 0.3, 24.0)], ["02_voor_deur_open", Vector3(0.0, 0.3, 13.5)], ["03_binnen_dak_weg", Vector3(0.0, 0.3, 0.0)], ["04_weer_buiten_dak_terug", Vector3(0.0, 0.3, 27.0)]]
	var showcase := (building.node.get_meta("complex") as Node3D) as AirfieldHQ23CompactShowcase
	for spot in spots:
		p.global_position = showcase.to_global(spot[1])
		p.velocity = Vector3.ZERO
		await _settle(150)
		await _save(String(spot[0]) + ".png")
	print("HANGAR GAMEPLAY CAPTURE DONE ", _out)
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
