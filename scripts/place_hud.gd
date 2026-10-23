class_name PlaceHud
extends Control
## Keuzebalk voor verdediging: een vakje per ding in je tas (plaatje + aantal), het gekozen vakje is goud,
## en een ronde knop ernaast om het neer te zetten. Alleen zichtbaar als je iets in je tas hebt.

const TILE := 62.0
const GAP := 8.0
const BIG := 74.0
const EQUIPMENT := ["grenade", "mine", "c4"]

var _tiles := {}
var _place: Button
var _more: Button
var _open := false
var _equipment_panel: Panel
var _equipment_prev: Button
var _equipment_next: Button
var _equipment_slots: Array[EquipmentSlot] = []


class EquipmentArrow:
	extends Button
	var direction := 1.0
	func _draw() -> void:
		var c := size * 0.5
		var w := 5.0
		var h := 8.0
		draw_colored_polygon(PackedVector2Array([c + Vector2(direction * w, 0), c + Vector2(-direction * w, -h), c + Vector2(-direction * w, h)]), UI.BRASS)


class EquipmentSlot:
	extends Button
	var item := ""
	var stock := 0
	var selected := false
	func _draw() -> void:
		var c := Vector2(size.x * 0.5, 16.0)
		var col := UI.BRASS if selected else UI.INK_DIM
		match item:
			"grenade":
				draw_circle(c + Vector2(0, 2), 8, col)
				draw_rect(Rect2(c + Vector2(-2, -9), Vector2(4, 4)), col)
				draw_line(c + Vector2(2, -8), c + Vector2(8, -11), col, 1.8)
			"mine":
				draw_circle(c + Vector2(0, 2), 9, col)
				draw_arc(c + Vector2(0, 2), 9, 0, TAU, 20, Color(0.04, 0.05, 0.035), 1.8)
				draw_circle(c + Vector2(0, 2), 3, Color(0.04, 0.05, 0.035))
			"c4":
				draw_rect(Rect2(c + Vector2(-8, -6), Vector2(16, 16)), col, false, 1.8)
				draw_line(c + Vector2(-5, -9), c + Vector2(5, -9), col, 1.8)
				draw_line(c + Vector2(-4, -9), c + Vector2(-4, -6), col, 1.5)
				draw_line(c + Vector2(4, -9), c + Vector2(4, -6), col, 1.5)
		var f: Font = UI.body(700, 0)
		var label: String = {"grenade": "GRANAAT", "mine": "MIJN", "c4": "C4"}.get(item, item.to_upper())
		draw_string(f, Vector2(0, size.y - 4), label, HORIZONTAL_ALIGNMENT_CENTER, size.x, 8, UI.INK if selected else UI.INK_DIM)
		var badge := "×%d" % stock
		var bw := f.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 5
		var r := Rect2(size.x - bw, 1, bw, 12)
		draw_rect(r, Color(0, 0, 0, 0.78))
		draw_string(f, r.position + Vector2(2, 9), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UI.BRASS if selected else UI.INK_DIM)


class Tile:
	extends Button
	var kind := ""
	var count := 0
	var picked := false
	var armed := false

	func _draw() -> void:
		var c := Vector2(size.x / 2.0, size.y / 2.0 - 5.0)
		match kind:
			"bags":
				for i in 3:
					var p := c + Vector2((i - 1) * 11.0 + (4.0 if i == 1 else 0.0), 7.0 - (8.0 if i == 1 else 0.0))
					draw_circle(p, 8.0, Color("b59a62"))
					draw_arc(p, 8.0, 0, TAU, 12, Color("6b5a35"), 1.5)
			"trench":
				draw_rect(Rect2(c - Vector2(21, 10), Vector2(42, 20)), Color("5b4630"))
				draw_rect(Rect2(c - Vector2(17, 6), Vector2(34, 12)), Color("160f08"))
				for i in 4:
					draw_line(c + Vector2(-12 + i * 8, -6), c + Vector2(-12 + i * 8, 6), Color("6a5233"), 2.0)
			"mine":
				draw_circle(c + Vector2(0, 2), 13.0, Color("3f4524"))
				draw_arc(c + Vector2(0, 2), 13.0, 0, TAU, 16, Color("7a8040"), 1.5)
				draw_circle(c + Vector2(0, 2), 4.0, Color("9a9a96"))
			"wire":
				for i in 3:
					var y := -8.0 + i * 8.0
					var pts := PackedVector2Array()
					for j in 7:
						pts.append(c + Vector2(-20 + j * 6.7, y + (3.0 if j % 2 else -3.0)))
					draw_polyline(pts, Color("b0aa9a"), 1.6)
				draw_line(c + Vector2(-20, -14), c + Vector2(-20, 14), Color("7a5a33"), 3.0)
				draw_line(c + Vector2(20, -14), c + Vector2(20, 14), Color("7a5a33"), 3.0)
			"sentry":
				draw_line(c + Vector2(-9, 14), c + Vector2(0, 0), Color("55554f"), 3.0)
				draw_line(c + Vector2(9, 14), c + Vector2(0, 0), Color("55554f"), 3.0)
				draw_rect(Rect2(c + Vector2(-8, -9), Vector2(16, 9)), Color("3a3a36"))
				draw_rect(Rect2(c + Vector2(6, -7), Vector2(16, 3.5)), Color("22221f"))
		var f: Font = UI.body(700, 0)
		var name: String = Defenses.NAMES[kind].to_upper()
		draw_string(f, Vector2(0, size.y - 6.0), name, HORIZONTAL_ALIGNMENT_CENTER, size.x, 9, UI.BRASS if picked and armed else UI.INK_DIM)
		var tag := "×%d" % count
		var w := f.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 10.0
		var r := Rect2(size.x - w - 3.0, 3.0, w, 17.0)
		draw_rect(r, UI.BRASS if picked and armed else Color(0, 0, 0, 0.65))
		draw_string(f, r.position + Vector2(5, 13), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("1a1405") if picked and armed else UI.INK)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_equipment_selector()
	for k in Defenses.KINDS:
		var t := Tile.new()
		t.kind = k
		t.add_to_group("hud_button")
		t.focus_mode = Control.FOCUS_NONE
		t.size = Vector2(TILE, TILE)
		t.button_down.connect(func(): _tap(k))
		add_child(t)
		_tiles[k] = t
	_more = Button.new()
	_more.name = "ExpandEquipment"
	_more.add_to_group("hud_button")
	_more.text = "▲"
	UI.style_button(_more, "pause")
	_more.add_theme_font_override("font", UI.display(0))
	_more.pressed.connect(func():
		_open = not _open
		_sync())
	add_child(_more)
	_place = Button.new()
	_place.add_to_group("hud_button")
	_place.text = "ZET\nNEER"
	UI.style_button(_place, "gold")
	var sb := UI.bevel(UI.box(Color(0.42, 0.3, 0.07, 0.95), UI.BRASS, 2, 37, 6), 4)
	var sp := UI.bevel(UI.box(Color(0.6, 0.43, 0.1, 1.0), UI.BRASS, 2, 37, 6), 4, true)
	_place.add_theme_stylebox_override("normal", sb)
	_place.add_theme_stylebox_override("hover", sb)
	_place.add_theme_stylebox_override("pressed", sp)
	_place.add_theme_font_override("font", UI.display(1))
	_place.add_theme_font_size_override("font_size", 17)
	_place.add_theme_color_override("font_color", UI.INK)
	_place.add_theme_constant_override("line_spacing", -2)
	_place.custom_minimum_size = Vector2(BIG, BIG)
	_place.pressed.connect(func(): Game.defs.place())
	add_child(_place)
	resized.connect(_layout)
	Game.changed.connect(_sync)
	_sync()


func _build_equipment_selector() -> void:
	_equipment_panel = Panel.new()
	_equipment_panel.name = "EquipmentSelector"
	_equipment_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_equipment_panel.add_theme_stylebox_override("panel", UI.box(Color(0.015, 0.025, 0.02, 0.9), Color(UI.BRASS, 0.44), 1, 6, 3))
	add_child(_equipment_panel)
	_equipment_prev = EquipmentArrow.new()
	_equipment_prev.name = "EquipmentPrevious"
	_equipment_prev.direction = -1.0
	_equipment_prev.add_to_group("hud_button")
	_equipment_prev.tooltip_text = "Vorige uitrusting"
	_equipment_prev.focus_mode = Control.FOCUS_NONE
	_equipment_prev.button_down.connect(func(): _cycle_equipment(-1))
	_equipment_panel.add_child(_equipment_prev)
	_equipment_next = EquipmentArrow.new()
	_equipment_next.name = "EquipmentNext"
	_equipment_next.add_to_group("hud_button")
	_equipment_next.tooltip_text = "Volgende uitrusting"
	_equipment_next.focus_mode = Control.FOCUS_NONE
	_equipment_next.button_down.connect(func(): _cycle_equipment(1))
	_equipment_panel.add_child(_equipment_next)
	for item in EQUIPMENT:
		var slot := EquipmentSlot.new()
		slot.item = item
		slot.name = "Equipment_" + item
		slot.add_to_group("hud_button")
		slot.focus_mode = Control.FOCUS_NONE
		slot.tooltip_text = {"grenade": "Handgranaat gebruiken", "mine": "Landmijn plaatsen", "c4": "C4 bestaat nog niet in de game"}[item]
		slot.button_down.connect(_select_equipment.bind(item))
		_equipment_panel.add_child(slot)
		_equipment_slots.append(slot)
	_layout_equipment()


func _layout_equipment() -> void:
	if _equipment_panel == null:
		return
	var radar := get_parent().find_child("TacticalRadar", true, false) as Control
	var safe := UI.safe_margins(size)
	var top := safe.y + 8.0 + 144.0
	if radar != null:
		top = radar.position.y + radar.size.y
	_equipment_panel.size = Vector2(194, 38)
	_equipment_panel.position = Vector2(size.x - safe.z - _equipment_panel.size.x, top + 6.0)
	_equipment_prev.position = Vector2(2, 4)
	_equipment_prev.size = Vector2(20, 30)
	_equipment_next.position = Vector2(172, 4)
	_equipment_next.size = Vector2(20, 30)
	for i in _equipment_slots.size():
		_equipment_slots[i].position = Vector2(25 + i * 48, 2)
		_equipment_slots[i].size = Vector2(46, 34)


func _unhandled_key_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and Game.defs:
		if e.keycode == KEY_F:
			if Game.place_armed:
				Game.defs.place()
			else:
				_tap(Game.place_sel)
		elif e.keycode == KEY_V:
			Game.defs.cycle()


## Tik op het gekozen vakje zet neerzetten aan of uit; een ander vakje kiest dat ding en zet het aan.
func _tap(k: String) -> void:
	Sfx.play("click")
	if k == Game.place_sel:
		Game.place_armed = not Game.place_armed
	else:
		Game.place_sel = k
		Game.place_armed = true
	_open = false
	Game.changed.emit()


func _select_equipment(item: String) -> void:
	Game.equipment_sel = item
	Game.changed.emit()


func _cycle_equipment(direction: int) -> void:
	var index := EQUIPMENT.find(Game.equipment_sel)
	Game.equipment_sel = EQUIPMENT[posmod(index + direction, EQUIPMENT.size())]
	Game.changed.emit()


func _equipment_stock(item: String) -> int:
	match item:
		"grenade":
			return Game.grenades
		"mine":
			return int(Game.inv.get("mine", 0))
		_:
			return 0


func _sync() -> void:
	var total := 0
	for k in Game.inv:
		total += Game.inv[k]
	if total <= 0:
		Game.place_armed = false
		_open = false
	elif Game.inv[Game.place_sel] <= 0 and Game.defs != null:
		Game.defs.cycle()
	var show := total > 0 and not Game.build_mode and (Game.state == "play" or Game.state == "prep")
	var active := not Game.build_mode and (Game.state == "play" or Game.state == "prep")
	_equipment_panel.visible = active and not Game.editing
	for slot in _equipment_slots:
		slot.stock = _equipment_stock(slot.item)
		slot.selected = slot.item == Game.equipment_sel
		var picked: bool = slot.selected
		var fill := Color(0.22, 0.16, 0.055, 0.96) if picked else Color(0.03, 0.045, 0.035, 0.9)
		var edge := UI.BRASS if picked else Color(UI.PANEL_LINE, 0.82)
		var sb := UI.box(fill, edge, 1 if not picked else 2, 4, 0)
		slot.add_theme_stylebox_override("normal", sb)
		slot.add_theme_stylebox_override("hover", sb)
		slot.add_theme_stylebox_override("pressed", UI.box(fill.lightened(0.08), edge, 2, 4, 0))
		slot.add_theme_stylebox_override("disabled", UI.box(Color(fill, 0.52), Color(edge, 0.42), 1, 4, 0))
		slot.disabled = slot.item == "c4"
		slot.queue_redraw()
	for arrow in [_equipment_prev, _equipment_next]:
		arrow.add_theme_stylebox_override("normal", UI.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 2, 0))
		arrow.add_theme_stylebox_override("hover", UI.box(Color(1, 1, 1, 0.06), Color(0, 0, 0, 0), 0, 2, 0))
		arrow.add_theme_stylebox_override("pressed", UI.box(Color(UI.BRASS, 0.2), Color(0, 0, 0, 0), 0, 2, 0))
		arrow.queue_redraw()
	var others := 0
	for k in _tiles:
		if k != Game.place_sel and Game.inv[k] > 0:
			others += 1
	_place.visible = show and Game.place_armed
	_more.visible = show and others > 0
	_more.text = "▼" if _open else "▲"
	for k in _tiles:
		var t: Tile = _tiles[k]
		t.count = Game.inv[k]
		t.picked = k == Game.place_sel
		t.armed = Game.place_armed
		t.visible = show and t.count > 0 and (t.picked or _open)
		var on := t.picked and Game.place_armed
		var edge := UI.BRASS if on else UI.PANEL_LINE
		var fill := Color(0.28, 0.21, 0.07, 0.92) if on else Color(0.07, 0.09, 0.04, 0.82)
		var sb := UI.bevel(UI.box(fill, edge, 2 if on else 1, 8, 4), 3)
		t.add_theme_stylebox_override("normal", sb)
		t.add_theme_stylebox_override("hover", sb)
		t.add_theme_stylebox_override("pressed", UI.bevel(UI.box(fill, edge, 2, 8, 4), 3, true))
		t.modulate.a = 1.0 if (on or not t.picked) else 0.8
		t.queue_redraw()
	if show:
		_layout()


func _layout() -> void:
	var safe := UI.safe_margins(size)
	_layout_equipment()
	var landscape := size.x >= size.y
	var safe_bottom := maxf(0.0, safe.w - 12.0)
	var bottom := size.y - 8.0 - safe_bottom
	var row_y := size.y - 416.0 - safe_bottom
	if not landscape:
		row_y = size.y - 492.0 - safe_bottom
		bottom = row_y + TILE
	var radar_bottom := 0.0
	if landscape:
		var radar_h := 120.0 if size.y < 420.0 else 144.0
		radar_bottom = safe.y + 8.0 + radar_h
		row_y = maxf(size.y - 208.0 - safe_bottom, radar_bottom + 8.0)
		bottom = row_y + TILE
	var x := size.x - safe.z - (172.0 if landscape else 0.0)  # liggend: vrij van de richtstick en actieknoppen
	if _place.visible:
		_place.size = Vector2(BIG, BIG)
		var place_y := bottom - BIG
		if landscape:
			place_y = row_y + 2.0
		else:
			place_y = row_y - BIG - 2.0
		_place.position = Vector2(x - BIG, place_y)
		if landscape or not _open:
			x -= BIG + 12.0
	var base := Vector2(x - TILE, bottom - TILE)
	var sel: Tile = _tiles[Game.place_sel]
	sel.size = Vector2(TILE, TILE)
	if _open:
		base.y = row_y
	sel.position = base
	_more.size = Vector2(34, TILE)
	_more.position = Vector2(base.x - 6.0 - 34.0, base.y)
	if _open:
		var available: Array[String] = []
		for k in Defenses.KINDS:
			if k != Game.place_sel and Game.inv[k] > 0:
				available.append(k)
		var start_x := base.x - available.size() * (TILE + GAP)
		for i in available.size():
			var t: Tile = _tiles[available[i]]
			t.size = Vector2(TILE, TILE)
			t.position = Vector2(start_x + i * (TILE + GAP), base.y)
		_more.position = Vector2(start_x - 6.0 - 34.0, base.y)
	var y := base.y
	for k in Defenses.KINDS:
		if k == Game.place_sel:
			continue
		var t: Tile = _tiles[k]
		if not t.visible:
			continue
		if _open:
			continue
		y -= TILE + GAP
		t.size = Vector2(TILE, TILE)
		t.position = Vector2(base.x, y)
