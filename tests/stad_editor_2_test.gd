extends SceneTree
## Integratiecontroles voor Stadseditor 2.0; gebruikt echte wereld, UI en inputevents.
## godot --headless --path . -s tests/stad_editor_2_test.gd --fixed-fps 60

var failures: Array[String] = []
var checks := 0
var main
var ed
var city
var game


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)
		push_error("EDITOR 2: " + description)


func _frames(n := 4) -> void:
	for _i in n:
		await process_frame


func _screen(d: Dictionary) -> Vector2:
	return root.get_camera_3d().unproject_position(Vector3(d.x, 0, d.z))


func _free(kind: String, except := Vector2.INF) -> Dictionary:
	for z in range(-144, -89, 6):
		for x in range(-48, 55, 6):
			var d := {"k": kind, "x": float(x), "z": float(z), "r": 0, "m": 0}
			var p := _screen(d)
			if Rect2(Vector2(10, 10), Vector2(root.size) - Vector2(20, 20)).has_point(p) and not ed._over_ui(p) and Vector2(x, z).distance_to(except) > 8 and city.problem(d, ed._stad.items) == "":
				return d
	_check(false, "vrije zichtbare testplek voor " + kind)
	return {"k": kind, "x": 48.0, "z": -144.0, "r": 0, "m": 0}


func _mouse(p: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = p
	event.global_position = p
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _click(p: Vector2) -> void:
	_motion(p)
	if DisplayServer.get_name() == "headless":
		# De dummy Window-server verstuurt geen muis-enter. Simuleer alleen die OS-melding;
		# hit testing en de druk/loslaat-events lopen nog steeds door de echte GUI.
		var hovered := root.gui_get_hovered_control()
		if hovered:
			hovered.notification(Control.NOTIFICATION_MOUSE_ENTER)
	_mouse(p, true)
	_mouse(p, false)


func _motion(p: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = p
	event.global_position = p
	event.relative = Vector2.ONE
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _touch(id: int, p: Vector2, down: bool, canceled := false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = id
	event.position = p
	event.pressed = down
	event.canceled = canceled
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _drag(id: int, p: Vector2, relative := Vector2.ZERO) -> void:
	var event := InputEventScreenDrag.new()
	event.index = id
	event.position = p
	event.relative = relative
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _undo_all() -> void:
	while not ed._undo.is_empty():
		ed._do_undo()


func _same_layout(a: Array, b: Array) -> bool:
	# Een wegenlijn vervangt bestaande delen; undo kan hun volgorde wijzigen.
	var left := a.map(func(row): return JSON.stringify(row))
	var right := b.map(func(row): return JSON.stringify(row))
	left.sort()
	right.sort()
	return left == right


func _panels() -> Array:
	return [ed._top, ed._side, ed._palette, ed._palette_handle, ed._zoom_box, ed._actions]


func _layout_checks(label: String) -> void:
	var safe: Rect2 = ed._safe_rect()
	var panels := _panels()
	for i in panels.size():
		var a: Control = panels[i]
		if not a.is_visible_in_tree():
			continue
		_check(safe.encloses(a.get_global_rect()), label + ": binnen safe area " + a.name)
		for j in range(i + 1, panels.size()):
			var b: Control = panels[j]
			if b.is_visible_in_tree():
				_check(not a.get_global_rect().intersects(b.get_global_rect()), label + ": overlap " + a.name + "/" + b.name)
	for b in [ed._title_btn, ed._undo_btn, ed._done_btn, ed._palette_handle] + ed._tab_btns.values() + ed._action_grid.get_children() + ed._zoom_box.get_children():
		_check(b.size.x >= 43.9 and b.size.y >= 43.9, label + ": aanraakvlak " + b.name)
	var top_row = ed._top.get_child(0)
	for child in top_row.get_children():
		_check(ed._top.get_global_rect().encloses(child.get_global_rect()), label + ": bovenbalk inhoud " + child.name)
	_check(ed._palette.size.y < root.size.y * 0.45, label + ": bibliotheek laat kaart vrij")


func _run() -> void:
	city = load("res://scripts/stad.gd")
	city.save_path = "user://stad_editor_2_test.json"
	city.clear_saved()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	root.size = Vector2i(1280, 720)
	root.content_scale_factor = 1.0
	main.get_node("Hud/Sticks").set_process(false)
	await main.begin()
	for menu in get_nodes_in_group("menus"):
		menu._show("")
	await _frames(8)
	game = root.get_node("Game")
	ed = get_first_node_in_group("stad_editor")
	var original: Array = city.to_lines(city.current.items)
	_check(original == city.to_lines(city.from_lines(load("res://scripts/stad_data.gd").ITEMS)), "ongewijzigde standaardstad inclusief magazijn")
	ed.enter()
	await _frames(45)
	_check(game.editing and game.build_mode and ed._ui.visible, "editor openen")
	_check(ed._library_state == 1, "compact is standaard")
	_check(ed._tab_btns.size() == 4, "vier categorieën")
	_check(ed._undo_btn.disabled, "undo aanvankelijk uit")
	for cat in ["weg", "straat", "gebouw"]:
		ed._pick_tab(cat)
		for kind in city.ORDER[cat]:
			_check(ed._cards.has(kind), "actuele bibliotheek: " + kind)
			var card: Button = ed._cards[kind]
			_check(card.get_node("Inhoud/Preview").texture != null, "gecachet icoon: " + kind)
	var cached = ed._cards.magazijn
	ed._pick_tab("straat")
	ed._pick_tab("gebouw")
	_check(is_same(cached, ed._cards.magazijn), "kaarten hergebruikt bij categorie wisselen")
	ed._pick_tab("gum")
	_check(ed._tool == "gum" and not ed._palette.visible, "gumcategorie")
	ed._pick_tab("gebouw")
	ed._pick_kind("magazijn")
	var free := _free("magazijn")
	ed._aim(Vector3(free.x, 0, free.z))
	_check(ed._ghost.visible and ed._ghost.kind == "magazijn", "echte magazijnpreview")
	_check(ed._ghost.model.find_children("*", "MeshInstance3D", true, false).size() > 10, "GLB geometrie in preview")
	_check(ed._ghost.find_children("*", "CollisionObject3D", true, false).is_empty(), "preview heeft geen botsingen")
	_check(ed._ghost.material.albedo_color.g > ed._ghost.material.albedo_color.r, "geldige preview groen")
	_check(ed._grid.visible and ed._borders.size() == 4, "raster en vier footprintcontouren")
	_check(ed._mirror_btn.disabled, "bestaande gebouw spiegelbeperking zichtbaar")
	ed._rotate()
	_check(ed._rot == 1 and is_equal_approx(ed._ghost.rotation.y, city.yaw_of(ed._cand)), "preview draait 90 graden")
	var invalid := {"k": "magazijn", "x": 0.0, "z": -102.0, "r": 0, "m": 0}
	ed._cand = invalid
	ed._show_cand()
	_check(ed._ghost.material.albedo_color.r > ed._ghost.material.albedo_color.g, "ongeldige preview rood")
	_check(not ed._place_cand(), "preview omzeilt validatie niet")
	ed._msg.text = ""
	await _frames()
	# Echte muisklik, selectie en contextacties; één undo per verandering.
	ed._pick_tab("weg")
	ed._pick_kind("weg_recht")
	var road := _free("weg_recht")
	var before: int = city.current.items.size()
	_click(_screen(road))
	_check(city.current.items.size() == before + 1, "muisklik plaatst precies één weg")
	_click(_screen(road))
	_check(city.current.items.size() == before + 1, "dubbele plaatsing geweigerd")
	ed._pick_kind("weg_recht")
	_click(_screen(road))
	_check(ed._sel.get("k") == "weg_recht", "selecteren met muis")
	var moved := _free("weg_recht", Vector2(road.x, road.z))
	_mouse(_screen(road), true)
	_motion(_screen(moved))
	_mouse(_screen(moved), false)
	_check(ed._sel.get("x") == moved.x and ed._sel.get("z") == moved.z, "selectie verslepen met snap en validatie")
	ed._do_undo()
	_click(_screen(road))
	ed._rotate()
	_check(ed._sel.get("r") == 1, "context draait selectie direct 90 graden")
	ed._mirror()
	_check(ed._sel.get("m") == 1, "weg spiegelen")
	ed._copy()
	_check(city.current.items.size() == before + 2, "kopiëren")
	ed._delete_sel()
	_check(city.current.items.size() == before + 1, "wissen")
	_undo_all()
	_check(city.to_lines(city.current.items) == original, "undo herstelt alle contextacties")
	_check(ed._undo_btn.disabled, "undo knop bijgewerkt")
	# Eén vinger plaatst pas bij loslaten; slepen en twee vingers plaatsen niets.
	ed._pick_kind("bankje")
	ed._brush = false
	ed._refresh()
	var bench := _free("bankje")
	var p := _screen(bench)
	_touch(0, p, true)
	_check(city.current.items.size() == before, "touch down plaatst nog niets")
	_touch(0, p, false)
	_check(city.current.items.size() == before + 1, "touch up plaatst eenmaal")
	_undo_all()
	_touch(0, p, true)
	_touch(0, p, false, true)
	_check(city.current.items.size() == before and ed._ptrs.is_empty(), "door OS geannuleerde touch plaatst niets")
	_touch(0, p, true)
	_touch(0, p + Vector2(20, 0), false)
	_check(city.current.items.size() == before, "samengevoegde laatste touchbeweging plaatst niets")
	_touch(0, p, true)
	_drag(0, p + Vector2(20, 0))
	_touch(0, p + Vector2(20, 0), false)
	_check(city.current.items.size() == before, "kaart slepen met bouwobject plaatst niets")
	await _frames(8)
	p = _screen(bench)
	var p2 := p + Vector2(30, 12)
	_touch(0, p, true)
	_touch(1, p2, true)
	_drag(1, p2 + Vector2(30, 0))
	_touch(0, p, false)
	_touch(1, p2 + Vector2(30, 0), false)
	_check(city.current.items.size() == before and ed._ptrs.is_empty(), "pinch plaatst niets en laat geen pointers achter")
	_check(game.ecam.z >= 0.35 and game.ecam.z <= 1.9, "pinch behoudt zoomlimieten")
	game.ecam = Vector3(6, -108, 1)
	await _frames(30)
	# Kwast mag plaatsen; tweede vinger draait een begonnen kwaststreek terug.
	ed._brush = true
	ed._refresh()
	bench = _free("bankje")
	var next := _free("bankje", Vector2(bench.x, bench.z))
	p = _screen(bench)
	p2 = _screen(next)
	_touch(0, p, true)
	_drag(0, p2)
	_check(city.current.items.size() > before, "kwast veeg plaatst straatmeubilair")
	_touch(1, p, true)
	_check(city.current.items.size() == before, "tweede vinger herstelt begonnen kwaststreek")
	_touch(0, p2, false)
	_touch(1, p, false)
	_touch(0, p, true)
	_touch(0, p, false)
	_check(city.current.items.size() == before + 1, "kwast tik plaatst straatobject")
	ed._pick_tab("gum")
	_touch(0, p, true)
	_touch(0, p, false)
	_check(city.current.items.size() == before, "gum tik verwijdert straatobject")
	_undo_all()
	# UI en popup mogen de kaart niet veranderen of erdoorheen zoomen.
	var weight: float = city.weight_of(city.current.items)
	_check(is_equal_approx(ed._load_bar.value, minf(100, weight)), "werkelijke stadsbelasting")
	_check(ed._sloop_label.text == "SLOOPBAAR %d" % city.sloop_count(city.current.items), "werkelijke sloopindicator")
	var zoom: float = game.ecam.z
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = ed._side.get_global_rect().get_center()
	Input.parse_input_event(wheel)
	Input.flush_buffered_events()
	var wheel_up := wheel.duplicate()
	wheel_up.pressed = false
	Input.parse_input_event(wheel_up)
	Input.flush_buffered_events()
	_check(is_equal_approx(game.ecam.z, zoom), "wiel boven UI zoomt kaart niet")
	ed._show_text()
	_check(ed._popup.visible and ed._modal_scrim.visible and ed._over_ui(Vector2(500, 200)), "exportpopup blokkeert kaart")
	_check(ed._text.text.contains("const ITEMS"), "export blijft beschikbaar via titel")
	ed._close_popup()
	# Bestaande lijnen: automatisch bocht, T-stuk en kruising; undo als groep.
	ed._pick_kind("lijn")
	for cells in [[Vector2i(9, -20), Vector2i(10, -20), Vector2i(10, -21)], [Vector2i(1, -16), Vector2i(1, -17)]]:
		ed._line_cells = cells
		ed._line_update()
		_check(ed._line_plan.ok, "weg tekenen geldige lijn")
		ed._line_apply()
	_check(city.current.items.any(func(d): return d.k == "weg_bocht" and d.x == 60 and d.z == -120), "automatische bocht")
	_check(ed.piece_for(7, false)[0] == "weg_t", "automatisch T-stuk")
	_check(ed.piece_for(15, false)[0] == "weg_kruis", "automatische kruising")
	_undo_all()
	_check(_same_layout(city.to_lines(city.current.items), original), "wegen undo behoudt bestaande stad")
	# Opslagformaat blijft identiek: oude indeling laden en eigen indeling herladen.
	city.current.save_user()
	_check(_same_layout(city.to_lines(city.load_saved()), original), "bestaande save terugladen")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(city.save_path))
	_check(saved.has("basis") and city.to_lines(city.from_lines(saved.items)) == city.to_lines(city.current.items), "bestaand opslagformaat")
	# Bedien de greep ook via de echte GUI, niet alleen met de layoutfuncties.
	ed._set_library_state(1)
	await _frames()
	for expected in [2, 0, 1]:
		_click(ed._palette_handle.get_global_rect().get_center())
		await _frames()
		_check(ed._library_state == expected, "greep via muis: verwacht %d, werkelijk %d, hover %s" % [expected, ed._library_state, root.gui_get_hovered_control()])
	# Horizontaal scrollen met de vinger mag geen kaart kiezen of object plaatsen.
	root.size = Vector2i(934, 430)
	ed._pick_tab("gebouw")
	ed._pick_kind("magazijn")
	await _frames()
	var library: Rect2 = ed._palette.get_global_rect()
	var swipe := Vector2(library.end.x - 70, library.get_center().y)
	var selected_tool: String = ed._tool
	_touch(4, swipe, true)
	await _frames(2)
	_drag(4, swipe - Vector2(25, 0), Vector2(-25, 0))
	_drag(4, swipe - Vector2(180, 0), Vector2(-155, 0))
	_touch(4, swipe - Vector2(180, 0), false)
	await _frames(2)
	_check(ed._library_scroll.scroll_horizontal > 0, "bibliotheek horizontaal scrollen met touch")
	_check(ed._tool == selected_tool and city.current.items.size() == before, "bibliotheekveeg selecteert en plaatst niets")
	ed._library_scroll.scroll_horizontal = 0
	# De editor negeert de korte uitloop van een veeg; een volgende echte tik blijft werken.
	while Time.get_ticks_msec() - ed._library_drag_end <= 160:
		await process_frame
	await _frames()
	_click(ed._cards.woonhuis.get_global_rect().get_center())
	_check(ed._tool == "woonhuis", "gebouwkaart kiezen via echte GUI")
	# Alle paneelstanden en randen op gangbare liggende viewports plus notch/home-indicator.
	ed._pick_kind("magazijn")
	ed._msg.text = ""
	for view in [Vector2i(934, 430), Vector2i(844, 390), Vector2i(736, 414), Vector2i(1280, 720)]:
		root.size = view
		await _frames()
		for state in [1, 2, 0]:
			ed._set_library_state(state)
			await _frames()
			_check(ed._palette.visible == (state != 0), "paneelstand %d" % state)
			_layout_checks("%s stand %d" % [view, state])
			for world in [Vector3(-45, 0, -135), Vector3(45, 0, -135), Vector3(-45, 0, -90), Vector3(45, 0, -90)]:
				ed._aim(world)
				await _frames(2)
				_layout_checks("%s objectrand" % view)
		root.size = view
		ed._safe_area_override = Rect2(44, 0, view.x - 88, view.y - 21)
		ed._layout()
		await _frames()
		_layout_checks("%s safe area" % view)
		ed._safe_area_override = Rect2()
	_check(not ed.debug_enabled, "normale editor zonder debug")
	for n in main.get_node("Hud").find_children("*", "Control", true, false):
		if n.get_script() and String(n.get_script().resource_path).ends_with("hud_extra.gd"):
			_check(not n._fps.visible and not n._bars.visible and not n._top_right.visible, "game HUD en diagnostiek verborgen in editor")
	ed.exit()
	await _frames()
	_check(not game.editing and not game.build_mode and not ed._ui.visible, "klaar sluit editor")
	_check(not ed._ghost.visible and not ed._grid.visible, "preview verdwijnt na sluiten")
	_check(main.get_node("Hud/HudExtra")._bars.visible and main.get_node("Hud/HudExtra")._top_right.visible, "game HUD hersteld na editor")
	game.state = "play"
	ed.enter()
	_check(not game.editing, "bestaande spelregel: editor uitsluitend tussen golven")
	city.clear_saved()
	main.queue_free()
	await _frames()
	print("STADSEDITOR 2.0: %d controles, %d fouten" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
