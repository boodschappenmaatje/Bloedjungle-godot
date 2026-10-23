extends SceneTree
## Nieuwe kijkhoeken, grondprojectie en herkenbaarheid van kleine objecten.
## godot --headless --path . -s tests/stad_editor_view_test.gd --fixed-fps 60

var checks := 0
var failures: Array[String] = []
var game
var ed
var city
var camera: Camera3D


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures.append(text)
		push_error("EDITOR VIEW: " + text)


func _settle(n := 90) -> void:
	for _i in n:
		camera._process(1.0 / 60.0)
		await process_frame


func _touch(id: int, pos: Vector2, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = id
	event.position = pos
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _run() -> void:
	city = load("res://scripts/stad.gd")
	city.save_path = "user://stad_editor_view_%s_test.json" % DisplayServer.get_name()
	city.clear_saved()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for _i in 3:
		await process_frame
	root.size = Vector2i(934, 430)
	root.content_scale_factor = 1
	main.get_node("Hud/Sticks").set_process(false)
	await main.begin()
	for menu in get_nodes_in_group("menus"):
		menu._show("")
	game = root.get_node("Game")
	ed = get_first_node_in_group("stad_editor")
	camera = root.get_camera_3d()
	var strategic_view = camera.combat_view
	var strategic_zoom = camera.zoom_step
	var world_before: Array = city.to_lines(city.current.items)
	ed.enter()
	await _settle()
	_check(camera.editor_oblique and ed._view_btn.text == "SCHUIN", "schuin is standaard")
	var selected_center: Vector3 = game.ecam
	ed._pick_kind("magazijn")
	var preview: Dictionary = ed._cand.duplicate()
	for mode in [false, true]:
		ed._view_btn.pressed.emit()
		_check(camera.editor_oblique == mode, "kijkhoek via aangesloten knop")
		for _i in 45:
			await process_frame
			var distance: float = camera.global_position.distance_to(camera._blook)
			_check(absf(distance - 62.0 * game.ecam.z) < 0.01, "geen zoompuls tijdens kantelen")
		_check(game.ecam == selected_center and ed._cand == preview, "kaartpunt, zoom en preview behouden bij wisselen")
		_check(ed._view_btn.text == ("SCHUIN" if mode else "BOVEN"), "zichtbare actuele stand")
	var height_pixels := {}
	for mode in [false, true]:
		camera.editor_oblique = mode
		ed._sync_camera_button()
		game.ecam = Vector3(6, -108, 1)
		await _settle()
		var angle := rad_to_deg(asin(camera.global_basis.z.y))
		_check(absf(angle - (60.0 if mode else 90.0)) < 0.1, "kijkhoek 60/90 graden")
		var center: Vector3 = ed._ground(Vector2(root.size) * 0.5)
		_check(center.distance_to(Vector3(6, 0, -108)) < 0.01, "zelfde grondpunt midden in beeld")
		var pole_base := Vector3(6, 0, -108)
		height_pixels[mode] = camera.unproject_position(pole_base).distance_to(camera.unproject_position(pole_base + Vector3.UP * 4.2))
		for zoom in [0.35, 1.0, 1.9]:
			ed._set_zoom(zoom)
			await _settle(3)
			_check(is_equal_approx(game.ecam.z, zoom), "bestaande editorzoom behouden")
			_check(absf(camera.global_position.distance_to(camera._blook) - 62 * zoom) < 0.01, "gelijke cameraafstand in beide standen")
			for world in [Vector3(6, 0, -108), Vector3(12, 0, -102), Vector3(-12, 0, -120)]:
				var screen := camera.unproject_position(world)
				var back: Vector3 = ed._ground(screen)
				_check(back.distance_to(world) < 0.002, "wereld/scherm/grond rondgang")
		ed._set_zoom(1)
		await _settle()
		var start := Vector2(460, 165)
		var end := start + Vector2(21, 13)
		var a: Vector3 = ed._ground(start)
		var b: Vector3 = ed._ground(end)
		var before: Vector3 = game.ecam
		ed._pan_screen(start, end)
		_check(Vector2(game.ecam.x - before.x, game.ecam.y - before.y).distance_to(Vector2(a.x - b.x, a.z - b.z)) < 0.001, "slepen volgt echte grondprojectie")
		game.ecam = before
		await _settle()
	_check(height_pixels[true] > 12 and height_pixels[false] < 0.1, "lantaarnhoogte wordt zichtbaar in schuine stand")
	# Raak de paal zelf op hoogte; alleen een grond-footprint zou deze aanraking missen.
	camera.editor_oblique = true
	ed._tool = ""
	ed._cand = {}
	ed._refresh()
	await _settle()
	await physics_frame
	var pole: Dictionary = city.current.items.filter(func(d): return d.k == "lantaarn" and d.z == -99)[0]
	var pole_pixel := camera.unproject_position(Vector3(pole.x, 2.2, pole.z))
	var pole_ground: Vector3 = ed._ground(pole_pixel)
	_check(is_same(ed._pick(pole_ground), pole), "lantaarn op zichtbare hoogte selecteerbaar")
	# Een tweede vinger op UI mag een begonnen plaatsing op de kaart niet bevestigen.
	ed._pick_kind("bankje")
	var point := Vector2(500, 145)
	var found := false
	for z in range(-132, -93, 4):
		for x in range(-40, 49, 4):
			var candidate := {"k": "bankje", "x": float(x), "z": float(z), "r": 0, "m": 0}
			var screen := camera.unproject_position(Vector3(x, 0, z))
			if Rect2(100, 80, 650, 200).has_point(screen) and not ed._over_ui(screen) and city.problem(candidate, city.current.items) == "":
				point = screen
				found = true
				break
		if found:
			break
	_check(found, "testaanraking ligt op een geldig vrij kaartvlak")
	var count: int = city.current.items.size()
	_touch(0, point, true)
	_touch(1, ed._side.get_global_rect().get_center(), true)
	_touch(0, point, false)
	_touch(1, ed._side.get_global_rect().get_center(), false)
	_check(city.current.items.size() == count and ed._ptrs.is_empty(), "tweede vinger op UI annuleert kaartplaatsing")
	var helper = load("res://scripts/stad_editor_ui.gd")
	_check(ed._count.get_theme_font("font") == helper.font(), "rustig editorlettertype")
	_check(helper.font().resource_path.ends_with("Barlow-SemiBold.ttf"), "lokale sans-serif zonder externe afhankelijkheid")
	ed._pick_tab("gebouw")
	_check(ed._cards.magazijn.custom_minimum_size.x == 140, "grotere objectkaarten")
	_check(ed._cards.magazijn.get_node("Inhoud/Preview").texture.get_size() == Vector2(256, 256), "gecachete scherpe previews")
	_check(ed._over_ui(ed._view_btn.get_global_rect().get_center()), "kijkhoekknop blokkeert kaartinput")
	# Ook de hoge stadsbelasting uit de gebruikersreferentie moet op een smalle iPhone passen.
	for view in [Vector2i(934, 430), Vector2i(844, 390), Vector2i(736, 414)]:
		root.size = view
		ed._safe_area_override = Rect2(44, 0, view.x - 88, view.y - 21)
		ed._count.text = "195 / 100 · TE ZWAAR"
		ed._sloop_label.text = "SLOOPBAAR 18"
		ed._layout()
		for _i in 5:
			await process_frame
		for control in ed._top.get_child(0).get_children():
			_check(ed._top.get_global_rect().encloses(control.get_global_rect()), "bovenbalk 195/100 binnen safe area: %s %s" % [view, control.name])
		_check(ed._safe_rect().encloses(ed._top.get_global_rect()), "belastingsbalk past met notch")
	ed._safe_area_override = Rect2()
	root.size = Vector2i(934, 430)
	ed._stats(false)
	ed._layout()
	ed.exit()
	await _settle(120)
	_check(camera.combat_view == strategic_view and camera.zoom_step == strategic_zoom, "speelcamera blijft ingesteld zoals voor de editor")
	_check(not game.editing and not ed._ui.visible, "editor sluit correct")
	_check(city.to_lines(city.current.items) == world_before, "wereld en opgeslagen indeling ongewijzigd")
	city.clear_saved()
	main.queue_free()
	await process_frame
	print("EDITOR VIEW RESULT: %d controles, %d fouten" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
