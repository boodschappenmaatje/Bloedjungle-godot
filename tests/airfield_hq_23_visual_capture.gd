extends Node
## Renders production Airfield HQ 2.3 through the project main scene and build/shop UI.

const OUTPUT_DIR := "res://docs/airfield_hq_v23/screenshots"
const MAIN_SCENE := "res://scenes/main.tscn"

var _main: Node3D
var _capture_camera: Camera3D

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_main = (load(MAIN_SCENE) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child(_main)
	await get_tree().process_frame
	await _main.begin()
	var main_menu := get_tree().get_first_node_in_group("menus") as PauseMenu
	if main_menu != null:
		await main_menu._show("")
	await get_tree().process_frame
	Game.state = "prep"
	Game.points = 8000
	Game.build_credit = 0
	var build_ui: BuildMode
	var build_script := load("res://scripts/build_mode.gd") as Script
	for child in _main.get_node("Hud").get_children():
		if child.get_script() == build_script:
			build_ui = child as BuildMode
			break
	assert(build_ui != null, "The production HUD must contain the existing BuildMode node")
	build_ui._enter()
	await get_tree().process_frame
	var airfield_card: BuildMode.Card
	for item in build_ui._cards:
		var candidate_card := item as BuildMode.Card
		if candidate_card.kind == "airfield":
			airfield_card = candidate_card
			break
	assert(airfield_card != null, "The production build menu must contain the Airfield card")
	build_ui._down(0, airfield_card.get_global_rect().get_center())
	build_ui._up(0)
	await _settle_frames(3)
	# A swipe pans the actual construction map and never places the building.
	var map_center := get_viewport().get_visible_rect().size * 0.5
	var buildings_before_gesture := Game.buildings.size()
	var pan_before := Vector2(Game.bcam.x, Game.bcam.y)
	build_ui._down(10, map_center)
	build_ui._move(10, map_center + Vector2(28.0, 19.0))
	build_ui._up(10)
	assert(Game.buildings.size() == buildings_before_gesture, "A one-finger map drag must never place the airfield")
	assert(not Vector2(Game.bcam.x, Game.bcam.y).is_equal_approx(pan_before), "A one-finger drag must pan the airfield construction map")
	# Pinch on the map zooms in; the same input is scoped to this build view.
	var zoom_before := Game.bcam.z
	build_ui._down(11, map_center - Vector2(34.0, 0.0))
	build_ui._down(12, map_center + Vector2(34.0, 0.0))
	build_ui._move(12, map_center + Vector2(52.0, 0.0))
	build_ui._up(12)
	build_ui._up(11)
	assert(Game.bcam.z < zoom_before, "Spreading two map fingers must zoom in")
	var zoomed_pan_before := Vector2(Game.bcam.x, Game.bcam.y)
	build_ui._down(14, map_center)
	build_ui._move(14, map_center + Vector2(-21.0, 17.0))
	build_ui._up(14)
	assert(Game.buildings.size() == buildings_before_gesture, "A zoomed one-finger drag must never place the airfield")
	assert(not Vector2(Game.bcam.x, Game.bcam.y).is_equal_approx(zoomed_pan_before), "One-finger panning must still work while zoomed")
	var build_site: Vector3 = AirfieldHQ23.SUGGESTED_CENTER
	var placement: Dictionary = Game.builds.placement_status("airfield", build_site, 0.0)
	assert(placement.valid, "The designated default site directly south of the base must be placeable in the production world: %s" % placement.reason)
	assert(int(placement.vegetation_count) > 0, "The default south site must exercise the green vegetation-clearance preview")
	build_ui._airfield_yaw = 0.0
	build_ui._airfield_candidate = build_site
	Game.bcam = Vector3(build_site.x, build_site.z, 1.0)
	# Keep the real build HUD, but frame the complete footprint in the production
	# camera before taking the green/red placement preview.
	build_ui._show_airfield_preview()
	_hide_canvas_items_except(build_ui)
	await _settle_frames(24)
	await _save_view("08_build_menu_preview.png")
	await _save_view("14_airfield_south_site_green_vegetation_preview.png")
	# One short map tap confirms the current location. A successful UI placement
	# must use the same validation and economy path as a direct build action.
	var center_ground: Variant = build_ui._ground(map_center)
	assert(center_ground != null, "The center of the airfield build camera must project to playable terrain")
	build_ui._down(13, map_center)
	build_ui._up(13)
	var building: Variant = null
	for registered in Game.buildings:
		if registered.kind == "airfield":
			building = registered
			break
	assert(building != null, "A short map tap at the valid default preview must place the airfield")
	assert(Game.points == 5200, "The UI placement must charge the build price exactly once")
	assert(Game.airfield_build_view, "After placement the wide build camera must remain active so the player can find and select the airport")
	build_ui._sel = null
	build_ui._fill_panel()
	build_ui._down(15, map_center)
	build_ui._up(15)
	assert(build_ui._sel == building and build_ui._panel.visible, "A short tap on the placed airfield must select it and show its existing building panel")
	build_ui._airfield_armed = false
	build_ui._ghost.visible = false
	Game.build_mode = false
	Game.airfield_build_view = false
	Game.changed.emit()
	_capture_camera = Camera3D.new()
	_capture_camera.name = "HQ23 review capture camera"
	_capture_camera.fov = 43.0
	_capture_camera.far = 900.0
	_main.add_child(_capture_camera)
	var airport_basis := Basis(Vector3.UP, building.yaw)
	var tower_target: Vector3 = building.at + airport_basis * Vector3(AirfieldHQ23.TOWER_CENTER.x, 8.0, AirfieldHQ23.TOWER_CENTER.y)
	_capture_camera.global_position = building.at + airport_basis * Vector3(52.0, 132.0, 72.0)
	_capture_camera.look_at(building.at + airport_basis * Vector3(0.0, 2.0, -10.0), Vector3.UP)
	_capture_camera.make_current()
	build_ui._ui.visible = false
	_hide_canvas_items_except(null)
	await _settle_frames(8)
	await _save_view("09_full_airfield_game_world.png")
	# Show the relationship between the unchanged player compound and the new
	# airfield site south of its gate in one production-world capture.
	_capture_camera.fov = 38.0
	_capture_camera.global_position = Vector3(40.0, 330.0, 65.0)
	_capture_camera.look_at(Vector3(40.0, 0.0, 65.0), Vector3.FORWARD)
	_capture_camera.make_current()
	await _settle_frames(8)
	await _save_view("15_airfield_south_of_player_base.png")
	_capture_camera.fov = 43.0
	_capture_camera.global_position = tower_target + airport_basis * Vector3(23.0, 12.0, 25.0)
	_capture_camera.look_at(tower_target + Vector3(0.0, 1.0, 0.0), Vector3.UP)
	_capture_camera.make_current()
	await _settle_frames(8)
	await _save_view("10_control_tower_game_closeup.png")
	_capture_camera.global_position = building.at + airport_basis * Vector3(47.875, 15.25, -20.3)
	_capture_camera.look_at(building.at + airport_basis * Vector3(46.25, 15.0, -17.2), Vector3.UP)
	_capture_camera.make_current()
	await _settle_frames(8)
	await _save_view("10b_control_tower_observation_room_godot.png")
	var old_showcase := (load(AirfieldHQ23.COMPLEX_SCENE) as PackedScene).instantiate() as Node3D
	old_showcase.position = building.at + airport_basis * (AirfieldHQ23.COMPLEX_CENTER_OFFSET + Vector3(-25.0, 0.0, 0.0))
	old_showcase.rotation.y = building.yaw
	_main.add_child(old_showcase)
	for mesh in old_showcase.find_children("*", "MeshInstance3D", true, false):
		mesh.visible = mesh.name.begins_with("Control Tower 22")
	var comparison_target := tower_target + airport_basis * Vector3(-12.5, 0.0, 0.0)
	_capture_camera.fov = 55.0
	_capture_camera.global_position = comparison_target + airport_basis * Vector3(13.0, 17.0, 39.0)
	_capture_camera.look_at(comparison_target + Vector3.UP * 1.5, Vector3.UP)
	_capture_camera.make_current()
	await _settle_frames(8)
	await _save_view("13_2_2_control_tower_same_camera.png")
	old_showcase.queue_free()
	await get_tree().process_frame
	var runway_target: Vector3 = building.at + airport_basis * Vector3(-19.0, 0.0, AirfieldHQ23.RUNWAY_CENTER_Z)
	_capture_camera.fov = 55.0
	_capture_camera.global_position = runway_target + Vector3.UP * 82.0 + airport_basis * Vector3(0.0, 0.0, 4.0)
	_capture_camera.look_at(runway_target, Vector3.UP)
	_capture_camera.make_current()
	await _settle_frames(8)
	await _save_view("11_runway_75x18_game.png")
	Game.build_mode = true
	Game.airfield_build_view = true
	Game.bcam = Vector3(build_site.x, build_site.z, 1.0)
	build_ui._ui.visible = true
	build_ui._sel = building
	build_ui._fill_panel()
	_hide_canvas_items_except(build_ui)
	await _settle_frames(12)
	await _save_view("12_airfield_aircraft_shop_disabled.png")
	print("AIRFIELD HQ 2.3 VISUAL CAPTURE PASS site=", build_site, " screenshots=docs/airfield_hq_v23/screenshots")
	get_tree().quit(0)

func _settle_frames(count: int) -> void:
	for _frame in count:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

func _save_view(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUTPUT_DIR.path_join(filename))
	var error := image.save_png(path)
	assert(error == OK, "Failed to save visual capture %s: %s" % [filename, error])

func _hide_canvas_items_except(keep: Node) -> void:
	var hud := _main.get_node("Hud") as CanvasLayer
	if hud != null:
		hud.process_mode = Node.PROCESS_MODE_DISABLED
		for child in hud.get_children():
			if keep != null and (child == keep or keep.is_ancestor_of(child)):
				child.process_mode = Node.PROCESS_MODE_ALWAYS
				continue
			child.process_mode = Node.PROCESS_MODE_DISABLED
			if child is CanvasItem:
				(child as CanvasItem).visible = false
	for layer in _main.find_children("*", "CanvasLayer", true, false):
		if layer == hud:
			continue
		layer.process_mode = Node.PROCESS_MODE_DISABLED
		layer.visible = false
	for item in _main.find_children("*", "CanvasItem", true, false):
		if keep != null and (item == keep or keep.is_ancestor_of(item)):
			continue
		(item as CanvasItem).visible = false
