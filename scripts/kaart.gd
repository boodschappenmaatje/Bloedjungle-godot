class_name Kaart
extends Control
## Grote kaart: tik op de radar. Je ziet de stad met de bezette gebieden (naam, aantal vijanden of vrij), je basis, de rivier
## en je soldaten. Tik op een gebied en kies AANVALLEN of VERDEDIGEN: al je soldaten lopen erheen en blijven daar
## (Game.set_order). Het spel staat stil zolang de kaart open is.

const WORLD := Rect2(-92.0, -160.0, 184.0, 198.0)   # x, z, breedte, diepte van het getoonde stuk wereld (m)
const PANEL_W := 214.0
const BG := Color(0.03, 0.05, 0.035, 0.97)
const GROUND := Color(0.13, 0.17, 0.09)
const ROAD := Color(0.36, 0.37, 0.34)
const BUILDING := Color(0.52, 0.45, 0.33)
const RIVER := Color(0.14, 0.38, 0.5)
const ENEMY := Color(1.0, 0.28, 0.16)
const FREE := Color(0.5, 0.9, 0.35)

var selected := ""
var _map := Rect2()
var _scale := 1.0
var _title: Label
var _info: Label
var _attack: Button
var _defend: Button
var _recall: Button
var _close: Button
var _paused_by_me := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title = UI.label("KAART", UI.display(1), 22, UI.BRASS)
	add_child(_title)
	_info = UI.label("", UI.body(600, 0), 15, UI.INK)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_info)
	_attack = _button("AANVALLEN", "primary", func(): _order("aanval"))
	_defend = _button("VERDEDIGEN", "buy", func(): _order("verdedig"))
	_recall = _button("SOLDATEN TERUG", "gold", func():
		Game.recall()
		_refresh())
	_close = _button("SLUIT", "gold", close)
	resized.connect(_layout)
	_layout()


func _button(text_: String, kind: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text_
	UI.style_button(b, kind)
	b.pressed.connect(cb)
	add_child(b)
	return b


func open() -> void:
	if visible:
		return
	selected = Game.order.zone
	visible = true
	if not get_tree().paused:
		get_tree().paused = true
		_paused_by_me = true
	_layout()
	_refresh()


func close() -> void:
	visible = false
	if _paused_by_me:
		get_tree().paused = false
		_paused_by_me = false


func _layout() -> void:
	var safe := UI.safe_margins(size)
	var avail := Rect2(Vector2(safe.x, safe.y), size - Vector2(safe.x + safe.z, safe.y + safe.w))
	var landscape := size.x >= size.y
	var panel: Rect2
	var area: Rect2
	if landscape:
		panel = Rect2(avail.end.x - PANEL_W, avail.position.y, PANEL_W, avail.size.y)
		area = Rect2(avail.position, Vector2(avail.size.x - PANEL_W - 10.0, avail.size.y))
	else:
		var ph := minf(260.0, avail.size.y * 0.4)
		panel = Rect2(avail.position.x, avail.end.y - ph, avail.size.x, ph)
		area = Rect2(avail.position, Vector2(avail.size.x, avail.size.y - ph - 8.0))
	_scale = minf(area.size.x / WORLD.size.x, area.size.y / WORLD.size.y)
	var msize := WORLD.size * _scale
	_map = Rect2(area.position + (area.size - msize) * 0.5, msize)
	_title.position = panel.position
	_title.size = Vector2(panel.size.x, 28.0)
	_info.position = panel.position + Vector2(0, 30.0)
	_info.size = Vector2(panel.size.x, 118.0 if landscape else 60.0)
	var by := panel.position.y + (150.0 if landscape else 92.0)
	var bh := 40.0
	var bw := panel.size.x
	if landscape:
		for b in [_attack, _defend, _recall, _close]:
			b.position = Vector2(panel.position.x, by)
			b.size = Vector2(bw, bh)
			by += bh + 6.0
	else:
		var half := (bw - 6.0) * 0.5
		_attack.position = Vector2(panel.position.x, by)
		_attack.size = Vector2(half, bh)
		_defend.position = Vector2(panel.position.x + half + 6.0, by)
		_defend.size = Vector2(half, bh)
		_recall.position = Vector2(panel.position.x, by + bh + 6.0)
		_recall.size = Vector2(half, bh)
		_close.position = Vector2(panel.position.x + half + 6.0, by + bh + 6.0)
		_close.size = Vector2(half, bh)
	queue_redraw()


func _to_screen(x: float, z: float) -> Vector2:
	return _map.position + Vector2((x - WORLD.position.x) * _scale, (z - WORLD.position.y) * _scale)


func _to_world(p: Vector2) -> Vector2:
	return Vector2((p.x - _map.position.x) / _scale + WORLD.position.x, (p.y - _map.position.y) / _scale + WORLD.position.y)


func _rect_screen(r: Rect2) -> Rect2:
	return Rect2(_to_screen(r.position.x, r.position.y), r.size * _scale)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if not _map.has_point(event.position):
			return
		var w := _to_world(event.position)
		var best := ""
		var bd := 14.0
		for id in Gebieden.ZONES:
			var r: Rect2 = Gebieden.ZONES[id].rect
			var d := 0.0 if r.has_point(w) else Gebieden.dist_to(id, Vector3(w.x, 0, w.y))
			if d < bd or (d == 0.0 and bd > 0.0):
				bd = d
				best = id
		selected = best
		_refresh()


func _order(mode: String) -> void:
	if selected == "":
		return
	Game.set_order(selected, mode)
	Game.banner.emit("SOLDATEN NAAR " + String(Gebieden.ZONES[selected].naam), "AANVALLEN" if mode == "aanval" else "VERDEDIGEN", 1.8)
	close()


func _soldiers() -> int:
	var n := 0
	for a in Game.allies:
		if is_instance_valid(a):
			n += 1
	return n


func _refresh() -> void:
	var n := _soldiers()
	var cleared: bool = selected != "" and Game.gebieden.is_cleared(selected)
	if selected == "":
		_info.text = "Tik op een gebied op de kaart om je soldaten erheen te sturen.\nSoldaten: %d" % n
	else:
		var z: Dictionary = Gebieden.ZONES[selected]
		var status := "VRIJ, het is van jou" if cleared else "BEZET door %d vijanden" % Game.gebieden.count_of(selected)
		_info.text = "%s\n%s\nSoldaten: %d" % [z.naam, status, n]
	if Game.order.zone != "":
		_info.text += "\nBevel: %s %s" % ["aanval op" if Game.order.mode == "aanval" else "verdediging van", Gebieden.ZONES[Game.order.zone].naam]
	_attack.disabled = selected == "" or cleared or n == 0
	_defend.disabled = selected == "" or n == 0
	_recall.disabled = Game.order.zone == "" 
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG, true)
	draw_rect(_map, GROUND, true)
	# rivier
	var line := PackedVector2Array()
	for i in 41:
		var x := lerpf(WORLD.position.x, WORLD.end.x, float(i) / 40.0)
		line.append(_to_screen(x, Data.river_z(x)))
	draw_polyline(line, RIVER, maxf(3.0, Data.RIVER_HALF * 2.0 * _scale), true)
	# stad: wegen en gebouwen
	for row in StadData.ITEMS:
		var k: Dictionary = Stad.KINDS.get(row[0], {})
		if k.is_empty():
			continue
		var h := Vector2(k.hx, k.hz)
		if int(row[3]) % 2 == 1:
			h = Vector2(h.y, h.x)
		var r := _rect_screen(Rect2(Vector2(row[1], row[2]) - h, h * 2.0))
		match String(k.cat):
			"weg":
				draw_rect(r, ROAD, true)
			"gebouw":
				draw_rect(r, BUILDING, true)
	# brug
	draw_rect(_rect_screen(Rect2(-2.0, Data.river_z(0.0) - 4.0, 4.0, 8.0)), Color(0.42, 0.3, 0.17), true)
	# basis
	var c := Data.COMPOUND
	draw_rect(_rect_screen(Rect2(-c, -c, c * 2.0, c * 2.0)), Color(0.56, 0.64, 0.42, 0.9), false, 2.0)
	var bb := _to_screen(0.0, 0.0)
	draw_rect(Rect2(bb - Vector2(5, 5), Vector2(10, 10)), Color(1.0, 0.74, 0.28), true)
	var f := UI.body(700, 0)
	draw_string(f, bb + Vector2(-16, 22), "BASIS", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.86, 0.6))
	# gebieden
	if Game.gebieden != null:
		for id in Gebieden.ZONES:
			_draw_zone(id, f)
	# soldaten en speler
	for a in Game.allies:
		if is_instance_valid(a):
			draw_circle(_to_screen(a.global_position.x, a.global_position.z), 3.2, FREE)
	if Game.player:
		var p := _to_screen(Game.player.global_position.x, Game.player.global_position.z)
		draw_circle(p, 4.5, Color(1.0, 0.84, 0.3))
		draw_arc(p, 6.5, 0.0, TAU, 20, Color(0, 0, 0, 0.7), 1.5)
	draw_rect(_map, UI.PANEL_LINE, false, 1.5)
	draw_string(f, _map.position + Vector2(_map.size.x - 14.0, 15.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.INK)


func _draw_zone(id: String, f: Font) -> void:
	var z: Dictionary = Gebieden.ZONES[id]
	var cleared: bool = Game.gebieden.is_cleared(id)
	var col := FREE if cleared else ENEMY
	var r := _rect_screen(z.rect)
	var sel := id == selected
	draw_rect(r, Color(col, 0.26 if sel else 0.15), true)
	draw_rect(r, UI.BRASS if sel else Color(col, 0.85), false, 3.0 if sel else 1.6)
	var mid := r.get_center()
	var name_: String = z.naam
	var nw := f.get_string_size(name_, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string_outline(f, mid + Vector2(-nw * 0.5, -2.0), name_, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0, 0, 0, 0.85))
	draw_string(f, mid + Vector2(-nw * 0.5, -2.0), name_, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.95))
	var st := "VRIJ" if cleared else str(Game.gebieden.count_of(id))
	var sw := f.get_string_size(st, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	draw_string_outline(f, mid + Vector2(-sw * 0.5, 14.0), st, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color(0, 0, 0, 0.85))
	draw_string(f, mid + Vector2(-sw * 0.5, 14.0), st, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col.lightened(0.25))
	if Game.order.zone == id:
		# vlag: hier gaan je soldaten naartoe
		var top := Vector2(r.position.x + 8.0, r.position.y + 4.0)
		draw_line(top, top + Vector2(0, 16), UI.BRASS, 2.0)
		draw_colored_polygon(PackedVector2Array([top, top + Vector2(12, 4), top + Vector2(0, 8)]), UI.BRASS)
		draw_string(f, top + Vector2(14, 14), "A" if Game.order.mode == "aanval" else "V", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.BRASS)
