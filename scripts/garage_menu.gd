class_name GarageMenu
extends CanvasLayer
## Tijdens het spel op de garage tikken opent een bestelpaneel (jeep, tank en truck), zoals in het bouwscherm.
## Een tik is: vinger kort neer en weer op, zonder te schuiven. Tik ergens anders om het paneel te sluiten.

const TAP_MAX_MOVE := 22.0
const TAP_MAX_TIME := 0.4

var _panel: PanelContainer
var _box: VBoxContainer
var _sel: Variant = null
var _press := {}  # vinger -> {"pos": Vector2, "t": float, "moved": float}


func _ready() -> void:
	layer = 6
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UI.box(UI.PANEL, UI.PANEL_LINE, 1, 6, 10))
	_panel.custom_minimum_size.x = 250
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.offset_bottom = -110
	_panel.visible = false
	add_child(_panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 6)
	_panel.add_child(_box)
	Game.changed.connect(_refresh)


func _process(_d: float) -> void:
	if _sel != null and (Game.build_mode or not Game.buildings.has(_sel) or (Game.state != "play" and Game.state != "prep")):
		_close()


func _input(event: InputEvent) -> void:
	if Game.build_mode or (Game.state != "play" and Game.state != "prep"):
		return
	var id := -2
	var pos := Vector2.ZERO
	if event is InputEventScreenTouch:
		id = event.index
		pos = event.position
		if event.pressed:
			_press[id] = {"pos": pos, "t": Time.get_ticks_msec() / 1000.0, "moved": 0.0}
		elif _press.has(id):
			var p: Dictionary = _press[id]
			_press.erase(id)
			if p.moved < TAP_MAX_MOVE and Time.get_ticks_msec() / 1000.0 - p.t < TAP_MAX_TIME:
				_tap(pos)
	elif event is InputEventScreenDrag and _press.has(event.index):
		_press[event.index].moved = maxf(_press[event.index].moved, event.position.distance_to(_press[event.index].pos))
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press[-1] = {"pos": event.position, "t": Time.get_ticks_msec() / 1000.0, "moved": 0.0}
		elif _press.has(-1):
			var p: Dictionary = _press[-1]
			_press.erase(-1)
			if event.position.distance_to(p.pos) < TAP_MAX_MOVE and Time.get_ticks_msec() / 1000.0 - p.t < TAP_MAX_TIME:
				_tap(event.position)


func _tap(pos: Vector2) -> void:
	if _panel.visible and _panel.get_global_rect().has_point(pos):
		return
	for b: Control in get_tree().get_nodes_in_group("hud_button"):
		if b.is_visible_in_tree() and b.get_global_rect().has_point(pos):
			return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var hit = Plane(Vector3.UP, 1.2).intersects_ray(cam.project_ray_origin(pos), cam.project_ray_normal(pos))
	var found: Variant = null
	if hit != null:
		for b in Game.buildings:
			if b.kind != "garage" and b.kind != "helipad" and b.kind != "airfield":
				continue
			var sz: Vector3 = Buildings.DEFS[b.kind].size
			var rel: Vector3 = hit - b.at
			var u := rel.dot(Vector3(cos(b.yaw), 0, -sin(b.yaw)))
			var v := rel.dot(Vector3(sin(b.yaw), 0, cos(b.yaw)))
			if absf(u) < sz.x / 2.0 + 0.6 and absf(v) < sz.z / 2.0 + 0.6:
				found = b
	if found == null:
		_close()
		return
	_sel = found
	Sfx.play("click")
	_refresh()


func _close() -> void:
	_sel = null
	_panel.visible = false


func _refresh() -> void:
	if _sel == null or _panel == null:
		return
	if not Game.buildings.has(_sel):
		_close()
		return
	for ch in _box.get_children():
		ch.queue_free()
	_panel.visible = true
	var b: Dictionary = _sel
	var head := HBoxContainer.new()
	_box.add_child(head)
	var title := "GARAGE" if b.kind == "garage" else ("VLIEGVELD — VLIEGTUIGHANGAR" if b.kind == "airfield" else "HELIPLATFORM")
	head.add_child(UI.label(title, UI.display(1), 18, UI.INK))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	head.add_child(UI.label(UI.nl(Game.points) + " PT", UI.body(700, 0), 13, UI.BRASS))
	var x := Button.new()
	x.add_to_group("hud_button")
	x.text = "✕"
	UI.style_button(x, "pause")
	x.custom_minimum_size = Vector2(30, 30)
	x.pressed.connect(_close)
	head.add_child(x)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	_box.add_child(row)
	if b.kind == "airfield":
		var capacity: int = int(b.get("aircraft_capacity", AirfieldHQ23.AIRCRAFT_CAPACITY))
		var owned: Array = b.get("aircraft", [])
		var operational := not bool(b.get("down", false)) and float(b.get("hp", 0.0)) > 0.0
		var max_hp := maxf(1.0, float(b.get("max_hp", 1.0)))
		var damage_percent := roundi(100.0 * (1.0 - clampf(float(b.get("hp", 0.0)) / max_hp, 0.0, 1.0)))
		var building_status := Label.new()
		building_status.text = "Gebouw: %s · schade %d%%" % ["operationeel" if operational else "buiten gebruik", damage_percent]
		building_status.add_theme_font_override("font", UI.body(600, 0))
		building_status.add_theme_font_size_override("font_size", 12)
		building_status.add_theme_color_override("font_color", UI.INK_DIM)
		_box.add_child(building_status)
		var slots := Label.new()
		slots.text = "Vliegtuigplaatsen: %d / %d" % [owned.size(), capacity]
		slots.add_theme_font_override("font", UI.body(600, 0))
		slots.add_theme_font_size_override("font_size", 12)
		slots.add_theme_color_override("font_color", UI.INK_DIM)
		_box.add_child(slots)
		for k in AirfieldHQ23.AIRCRAFT:
			var def: Dictionary = AirfieldHQ23.AIRCRAFT[k]
			var purchased := false
			for aircraft in owned:
				if aircraft.get("kind", "") == k:
					purchased = true
					break
			var aircraft_btn := Button.new()
			aircraft_btn.add_to_group("hud_button")
			aircraft_btn.text = def.name + "\n" + ("gekocht" if purchased else "%d pt" % def.cost)
			UI.style_button(aircraft_btn, "buy")
			aircraft_btn.add_theme_font_size_override("font_size", 13)
			aircraft_btn.custom_minimum_size = Vector2(180, 48)
			aircraft_btn.disabled = purchased or not Game.builds.can_buy_aircraft(b, k)
			aircraft_btn.pressed.connect(func(): Game.builds.buy_aircraft(b, k))
			row.add_child(aircraft_btn)
		for aircraft in owned:
			var entry := Label.new()
			entry.text = "%s · %s" % [AirfieldHQ23.AIRCRAFT.get(aircraft.get("kind", ""), {}).get("name", "Onbekend vliegtuig"), str(aircraft.get("state", "onbekend"))]
			entry.add_theme_font_override("font", UI.body(600, 0))
			entry.add_theme_font_size_override("font_size", 12)
			entry.add_theme_color_override("font_color", UI.INK_DIM)
			_box.add_child(entry)
		var status := Label.new()
		status.text = AirfieldHQ23.shop_status("p47")
		status.add_theme_font_override("font", UI.body(600, 0))
		status.add_theme_font_size_override("font_size", 12)
		status.add_theme_color_override("font_color", UI.INK_DIM)
		status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_box.add_child(status)
	elif b.kind == "helipad":
		var apache := Button.new()
		apache.add_to_group("hud_button")
		apache.text = "Apache\n" + ("gekocht" if b.has_heli else "%d pt" % Buildings.HELI_COST)
		UI.style_button(apache, "buy")
		apache.add_theme_font_size_override("font_size", 13)
		apache.custom_minimum_size = Vector2(110, 44)
		apache.disabled = not Game.builds.can_buy_heli(b)
		apache.pressed.connect(func(): Game.builds.buy_heli(b))
		row.add_child(apache)
		if b.has_heli:
			var call := Button.new()
			call.add_to_group("hud_button")
			call.text = "Oproepen\n" + ("klaar" if b.hs == "open" else "omhoog")
			UI.style_button(call, "buy")
			call.add_theme_font_size_override("font_size", 13)
			call.custom_minimum_size = Vector2(110, 44)
			call.disabled = b.hs == "open" or b.hs == "opening" or (b.heli != null and b.heli.mode != Apache.Mode.LIFT)
			call.pressed.connect(func(): Game.builds.call_heli(b))
			row.add_child(call)
	else:
		for k in Buildings.VEHICLES:
			var v: Dictionary = Buildings.VEHICLES[k]
			var btn := Button.new()
			btn.add_to_group("hud_button")
			btn.text = v.name + "\n" + ("gekocht" if b.has[k] else "%d pt" % v.cost)
			UI.style_button(btn, "buy")
			btn.add_theme_font_size_override("font_size", 13)
			btn.custom_minimum_size = Vector2(110, 44)
			btn.disabled = not Game.builds.can_buy_vehicle(b, k)
			btn.pressed.connect(func(): Game.builds.buy_vehicle(b, k))
			row.add_child(btn)
	var tip := Label.new()
	if b.kind == "garage":
		tip.text = "De wagen rijdt meteen de garage uit."
	elif b.kind == "helipad":
		tip.text = "De lift tilt de Apache uit de grond. Loop erheen en tik IN."
	else:
		tip.text = "Een vliegtuig verschijnt pas wanneer het originele model beschikbaar is en er een vrije plaats is."
	tip.add_theme_font_override("font", UI.body(600, 0))
	tip.add_theme_font_size_override("font_size", 12)
	tip.add_theme_color_override("font_color", UI.INK_DIM)
	_box.add_child(tip)
