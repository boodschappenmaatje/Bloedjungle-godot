class_name GroteKaart
extends Control
## De grote kaart: tik op de radar rechtsboven en de kaart vult het scherm (Dennis' keuzes 2A, 3A, 5A, 7A, 8A, 11 nov 2026).
## Terrein is de luchtfoto van jouw wereld (KaartFoto), met een raster A-D / 1-5, pictogrammen per partij en een legenda.
## Bevelen zoals in Command & Conquer: tik een soldaat of voertuig aan (dubbeltik = al je eenheden van die soort), sleep met één vinger een kader,
## knijp om in te zoomen en schuif met twee vingers. Met een keuze tik je op de grond (verplaatsen), op een vijand (aanvallen) of
## je kiest een ander bevel in de bevelbalk onderaan. Groepsvakjes 1-2-3: tik = kiezen, vasthouden = de keuze opslaan.
## Wacht het oude commandowiel op een doel (Aanvallen, Verplaatsen, Verdedigen voor je hele leger), dan is een tik op de kaart dat doel,
## zoals vroeger. Zonder keuze sluit een tik op lege grond de kaart.
## Het tekenwerk van het kaartbeeld zelf staat in HudExtra.draw_map_on (dezelfde routine als de radar).

const MARGIN := 10.0
const HEAD := 30.0
const TAP_SLACK := 14.0   # verder dan dit verschuift de vinger: dan is het geen tik meer maar een kader of schuiven
const PICK_PX := 16.0     # zo dicht moet je bij een pictogram tikken
const HOLD_SAVE := 0.5    # s een groepsvakje vasthouden = de keuze opslaan
const DOUBLE_TAP := 0.4   # s tussen twee tikken op een soldaat = al zijn soortgenoten
const MAX_ZOOM := 5.0
const SIDE_W := 168.0

var _hud: Node
var _target := false
var _panel := Rect2()
var _map := Rect2()       # het zichtbare kaartvlak op het scherm
var _vr := Rect2()        # waar de hele wereld nu ligt (groter dan _map als je inzoomt)
var _fit := Rect2()       # de wereld bij zoom 1 (past precies in _map)
var _close := Rect2()
var _legend_btn := Rect2()
var _btn_all := Rect2()
var _btn_none := Rect2()
var _btn_veh := Rect2()   # VOERTUIGEN: al je jeeps en tanks
var _groups: Array = [Rect2(), Rect2(), Rect2()]
var _bar: Array = []
var _legend := Rect2()
var _portrait := false
var _legend_open := false
var _view: Control        # tekent het kaartbeeld, knipt af op _map

var _touches := {}        # vinger-index (-1 = muis) -> plek
var _primary := -2
var _mode := ""           # "", tap, box, pan, pinch, klaar
var _start := Vector2.ZERO
var _press_t := 0.0
var _press_btn := ""      # knop onder de vinger bij het neerkomen ("g0".."g2", "bar3", "all", ...)
var _box_to := Vector2.ZERO
var _pinch_d0 := 1.0
var _pinch_vr0 := Rect2()
var _pinch_mid0 := Vector2.ZERO
var _last_tap_t := -10.0
var _last_tap_unit: Node3D


func _ready() -> void:
	name = "GroteKaart"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # de invoer loopt via _input, zodat het commandowiel en de sticks er niet doorheen grijpen
	z_index = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _hud == null:
		_hud = get_parent()
	_view = Control.new()
	_view.name = "KaartBeeld"
	_view.clip_contents = true
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.draw.connect(_draw_view)
	add_child(_view)
	resized.connect(_layout)


func is_open() -> bool:
	return visible


## `target`: het commandowiel wacht op een doel, een tik op de kaart is dat doel.
func open_map(target: bool) -> void:
	_target = target
	_touches.clear()
	_mode = ""
	_primary = -2
	visible = true
	add_to_group("kaart_open")   # TouchSticks laat sticks en schieten met rust zolang deze groep gevuld is
	_layout()
	queue_redraw()


func close_map() -> void:
	visible = false
	_touches.clear()
	_mode = ""
	_primary = -2
	if is_in_group("kaart_open"):
		remove_from_group("kaart_open")


func _sel() -> TroepSelectie:
	return TroepSelectie.inst(get_tree())


func _process(_delta: float) -> void:
	if not visible:
		return
	# pauze, menu, bouwen of game over: de kaart gaat dicht
	if Game.state not in ["prep", "play"] or Game.build_mode or Game.editing or get_tree().paused:
		close_map()
		return
	var tc := get_tree().get_first_node_in_group("team_commands")
	if _target and (tc == null or tc.controller.pending_order == ""):
		_target = false   # het bevel is al geannuleerd of uitgegeven: alleen nog een overzicht
	# groepsvakje vastgehouden: opslaan zodra de tijd om is (dan voel je dat het gelukt is)
	if _mode == "tap" and _press_btn.begins_with("g") and _now() - _press_t >= HOLD_SAVE:
		var ts := _sel()
		if ts != null:
			ts.save_group(int(_press_btn.substr(1)))
			Game.banner.emit("GROEP %d" % (int(_press_btn.substr(1)) + 1), "%s opgeslagen. Tik het vakje om ze weer te kiezen." % TroepSelectie.wie(ts.sel), 1.6)
		_mode = "klaar"
	queue_redraw()
	_view.queue_redraw()


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


## Indeling. Liggend: kaart links, een kolom met knoppen en legenda rechts, de bevelbalk onder de kaart.
## Staand: kaart boven, knoppen en bevelbalk eronder, de legenda achter een knop.
func _layout() -> void:
	var safe := UI.safe_margins(size)
	_panel = Rect2(Vector2(safe.x + MARGIN, safe.y + MARGIN), size - Vector2(safe.x + safe.z + 2.0 * MARGIN, safe.y + safe.w + 2.0 * MARGIN))
	_portrait = _panel.size.x < _panel.size.y * 1.1
	var c := _panel.grow(-8.0)
	var aspect := (2.0 * Data.WORLD_X) / (Data.WORLD_Z_N + Data.WORLD_Z_S)
	var area := Rect2()
	if not _portrait:
		# liggend: de kaart over de volle hoogte in het midden, links titel, keuzeknoppen en legenda, rechts SLUIT en de bevelbalk
		var h := c.size.y
		var w := h * aspect
		var side := (c.size.x - w - 24.0) * 0.5
		if side < 150.0:
			side = 150.0
			w = c.size.x - 2.0 * side - 24.0
			h = w / aspect
		area = Rect2(Vector2(c.position.x + side + 12.0, c.position.y + (c.size.y - h) * 0.5), Vector2(w, h))
		var lx := c.position.x
		var rx := area.end.x + 12.0
		var cw := side
		_close = Rect2(Vector2(rx, c.position.y), Vector2(cw, 34.0))
		_bar = BevelBalk.rects_v(Rect2(Vector2(rx, _close.end.y + 12.0), Vector2(cw, c.end.y - _close.end.y - 12.0)), 6.0, 44.0)
		var y := c.position.y + 74.0
		_btn_all = Rect2(Vector2(lx, y), Vector2(cw * 0.5 - 3.0, 32.0))
		_btn_none = Rect2(Vector2(lx + cw * 0.5 + 3.0, y), Vector2(cw * 0.5 - 3.0, 32.0))
		y += 36.0
		_btn_veh = Rect2(Vector2(lx, y), Vector2(cw, 30.0))
		y += 36.0
		var gw := (cw - 12.0) / 3.0
		for i in 3:
			_groups[i] = Rect2(Vector2(lx + float(i) * (gw + 6.0), y), Vector2(gw, 32.0))
		y += 40.0
		_legend = Rect2(Vector2(lx, y), Vector2(cw, c.end.y - y))
		_legend_btn = Rect2()
		_legend_open = true
	else:
		_close = Rect2(Vector2(c.end.x - 84.0, c.position.y), Vector2(84.0, 30.0))
		_legend_btn = Rect2(Vector2(_close.position.x - 96.0, c.position.y), Vector2(88.0, 30.0))
		var bar_h := 46.0
		var rows_h := 34.0
		var bottom := c.end.y
		_bar = BevelBalk.rects(Rect2(Vector2(c.position.x, bottom - bar_h), Vector2(c.size.x, bar_h)), 4.0)
		var ry := bottom - bar_h - 8.0 - rows_h
		var w6 := (c.size.x - 5.0 * 6.0) / 6.0
		_btn_all = Rect2(Vector2(c.position.x, ry), Vector2(w6, rows_h))
		_btn_none = Rect2(Vector2(c.position.x + w6 + 6.0, ry), Vector2(w6, rows_h))
		_btn_veh = Rect2(Vector2(c.position.x + 2.0 * (w6 + 6.0), ry), Vector2(w6, rows_h))
		for i in 3:
			_groups[i] = Rect2(Vector2(c.position.x + float(i + 3) * (w6 + 6.0), ry), Vector2(w6, rows_h))
		var top := c.position.y + HEAD + 18.0
		var room := Rect2(Vector2(c.position.x, top), Vector2(c.size.x, ry - 8.0 - top))
		var w2 := room.size.x
		var h2 := w2 / aspect
		if h2 > room.size.y:
			h2 = room.size.y
			w2 = h2 * aspect
		area = Rect2(room.position + (room.size - Vector2(w2, h2)) * 0.5, Vector2(w2, h2))
		_legend = Rect2(area.position + Vector2(6.0, 6.0), Vector2(minf(176.0, area.size.x - 12.0), 196.0))
	_map = area
	_fit = area
	_vr = _fit
	_view.position = _map.position
	_view.size = _map.size


## Waar de hele wereld nu op het scherm ligt (bij zoom 1 past hij precies in het kaartvlak).
func map_rect() -> Rect2:
	return _vr


func zoom() -> float:
	return _vr.size.x / maxf(_fit.size.x, 1.0)


## Zoomt met factor `z` (tov de gepaste kaart) zo dat het schermpunt `anchor` op dezelfde plek in de wereld blijft.
func _zoom_to(z: float, anchor: Vector2, from: Rect2) -> void:
	z = clampf(z, 1.0, MAX_ZOOM)
	var frac := (anchor - from.position) / from.size
	var sz := _fit.size * z
	_vr = Rect2(anchor - frac * sz, sz)
	_clamp_view()


## Houdt de wereld in beeld: ingezoomd geen lege rand naast de kaart, uitgezoomd in het midden.
func _clamp_view() -> void:
	for ax in 2:
		if _vr.size[ax] <= _map.size[ax] + 0.5:
			_vr.position[ax] = _map.position[ax] + (_map.size[ax] - _vr.size[ax]) * 0.5
		else:
			_vr.position[ax] = clampf(_vr.position[ax], _map.end[ax] - _vr.size[ax], _map.position[ax])


## Schermpunt op de kaart naar een punt in de wereld (y = 0).
func to_world(screen: Vector2) -> Vector3:
	var fx := clampf((screen.x - _vr.position.x) / _vr.size.x, 0.0, 1.0)
	var fz := clampf((screen.y - _vr.position.y) / _vr.size.y, 0.0, 1.0)
	return Vector3(lerpf(-Data.WORLD_X, Data.WORLD_X, fx), 0.0, lerpf(-Data.WORLD_Z_N, Data.WORLD_Z_S, fz))


func to_screen(world: Vector3) -> Vector2:
	return _hud._radar_point(world, _vr)


func _px_per_m() -> float:
	return _vr.size.x / (2.0 * Data.WORLD_X)


func _hint() -> String:
	if _target:
		var tc := get_tree().get_first_node_in_group("team_commands")
		match tc.controller.pending_order if tc != null else "":
			"attack":
				return "Tik op het rode vlak om de vijandbasis aan te vallen"
			"move":
				return "Tik waar je soldaten heen moeten"
			"defend":
				return "Tik op de plek die ze moeten verdedigen"
		return "Tik op de kaart"
	var ts := _sel()
	if ts == null or ts.sel.is_empty():
		return "Tik een soldaat of voertuig aan, sleep een kader of tik ALLES"
	var wie := TroepSelectie.wie(ts.sel)
	match ts.armed:
		"attack":
			return wie + " · tik een vijand of plek om aan te vallen"
		"defend":
			return wie + " · tik de plek die ze verdedigen"
		"bewaak":
			return wie + " · tik wat ze moeten bewaken"
	return wie + " · tik waar ze heen moeten"


func _draw() -> void:
	if not visible or _hud == null:
		return
	var font := UI.body(700, 0)
	var ts := _sel()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.6))
	draw_style_box(UI.box(Color(0.02, 0.033, 0.024, 0.97), Color(HudExtra.C_RAND, 0.55), 2, 8, 0), _panel)
	var c := _panel.grow(-8.0)
	draw_string(UI.body(700, 2), c.position + Vector2(2.0, 20.0), "KAART", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, UI.BRASS)
	var hint_col := Color(1.0, 0.86, 0.55) if _target or (ts != null and not ts.sel.is_empty()) else UI.INK_DIM
	if _portrait:
		draw_string(font, c.position + Vector2(2.0, HEAD + 12.0), _hint(), HORIZONTAL_ALIGNMENT_LEFT, c.size.x, 12, hint_col)
	else:
		draw_multiline_string(font, c.position + Vector2(2.0, 40.0), _hint(), HORIZONTAL_ALIGNMENT_LEFT, _btn_all.size.x * 2.0 + 6.0, 12, 2, hint_col)
	_button(_close, "SLUIT", true, UI.BRASS)
	if _portrait:
		_button(_legend_btn, "LEGENDA", _legend_open, UI.INK_DIM)
	_button(_btn_all, "ALLES", false, UI.BRASS)
	_button(_btn_none, "GEEN", false, UI.INK_DIM)
	_button(_btn_veh, "VOERTUIGEN", false, UI.BRASS)
	for i in 3:
		var n: int = ts.group_count(i) if ts != null else 0
		var on: bool = n > 0
		var held: bool = _mode == "tap" and _press_btn == "g%d" % i
		var r: Rect2 = _groups[i]
		draw_style_box(UI.box(Color(0.1, 0.2, 0.07, 0.95) if held else Color(0.03, 0.045, 0.03, 0.92), Color(HudExtra.C_EIGEN if on else UI.PANEL_LINE, 0.9), 1, 5, 0), r)
		if held:
			var f := clampf((_now() - _press_t) / HOLD_SAVE, 0.0, 1.0)
			draw_rect(Rect2(r.position + Vector2(2.0, r.size.y - 4.0), Vector2((r.size.x - 4.0) * f, 2.0)), HudExtra.C_EIGEN_HI)
		var t := "%d · %d" % [i + 1, n] if on else str(i + 1)
		draw_string(font, Vector2(r.position.x, r.position.y + r.size.y * 0.5 + 5.0), t, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 13, HudExtra.C_EIGEN_HI if on else UI.INK_DIM)
	BevelBalk.draw(self, _bar, ts.armed if ts != null else "move", ts != null and not ts.sel.is_empty() and not _target)
	if _legend_open:
		_draw_legend(font)


func _button(r: Rect2, text: String, strong: bool, col: Color) -> void:
	draw_style_box(UI.box(Color(0.08, 0.1, 0.06, 0.95) if strong else Color(0.03, 0.045, 0.03, 0.92), Color(col, 0.85 if strong else 0.5), 1, 5, 0), r)
	var font := UI.body(700, 1)
	var fs := 12
	while fs > 8 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > r.size.x - 6.0:
		fs -= 1   # een lange tekst (VOERTUIGEN) krimpt tot hij in de knop past
	draw_string(font, Vector2(r.position.x, r.position.y + r.size.y * 0.5 + fs * 0.4), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, UI.INK if strong else col)


## Het kaartbeeld (in het knipvlak _view, dus in zijn eigen coördinaten).
func _draw_view() -> void:
	if not visible or _hud == null:
		return
	var off := _map.position
	var vr := Rect2(_vr.position - off, _vr.size)
	_view.draw_rect(Rect2(Vector2.ZERO, _map.size), Color(0.035, 0.05, 0.03), true)
	var k := clampf(_fit.size.y / 170.0, 1.5, 2.6) * (1.0 + 0.12 * (zoom() - 1.0))
	_hud.draw_map_on(_view, vr, k)
	_draw_grid(vr)
	_draw_orders(vr, k)
	_draw_labels(vr)
	if _mode == "box":
		var b := Rect2(_start - off, _box_to - _start).abs()
		_view.draw_rect(b, Color(HudExtra.C_EIGEN_HI, 0.12), true)
		_view.draw_rect(b, HudExtra.C_EIGEN_HI, false, 1.5)
	_hud.draw_frame(_view, Rect2(Vector2(1.0, 1.0), _map.size - Vector2(2.0, 2.0)), 1.6)


## Raster A-D (west naar oost) en 1-5 (noord naar zuid), zoals de tegels van de luchtfoto.
func _draw_grid(vr: Rect2) -> void:
	var font := UI.body(700, 0)
	var line := Color(0.92, 0.94, 0.86, 0.1)
	var lab := Color(0.92, 0.94, 0.86, 0.55)
	for i in range(1, KaartFoto.COLS):
		var x := vr.position.x + vr.size.x * float(i) / float(KaartFoto.COLS)
		_view.draw_line(Vector2(x, vr.position.y), Vector2(x, vr.end.y), line, 1.0)
	for j in range(1, KaartFoto.ROWS):
		var y := vr.position.y + vr.size.y * float(j) / float(KaartFoto.ROWS)
		_view.draw_line(Vector2(vr.position.x, y), Vector2(vr.end.x, y), line, 1.0)
	var top := maxf(vr.position.y, 0.0) + 12.0
	var left := maxf(vr.position.x, 0.0) + 4.0
	for i in KaartFoto.COLS:
		var cx := vr.position.x + vr.size.x * (float(i) + 0.5) / float(KaartFoto.COLS)
		_view.draw_string(font, Vector2(cx - 4.0, top), "ABCD"[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, lab)
	for j in KaartFoto.ROWS:
		var cy := vr.position.y + vr.size.y * (float(j) + 0.5) / float(KaartFoto.ROWS)
		_view.draw_string(font, Vector2(left, cy + 4.0), str(j + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, lab)


## Gekozen soldaten: een gestippelde lijn naar hun doel. Daarbij de markers van de laatste bevelen.
func _draw_orders(vr: Rect2, k: float) -> void:
	var ts := _sel()
	if ts == null:
		return
	for a in ts.sel:
		if not is_instance_valid(a):
			continue
		var cmd := String(a.command)
		if cmd in ["follow", "hold"]:
			continue
		var to: Vector3 = a.command_target
		if is_instance_valid(a.command_enemy):
			to = a.command_enemy.global_position
		elif is_instance_valid(a.command_node):
			to = a.command_node.global_position
		var p0: Vector2 = _hud._radar_point(a.global_position, vr)
		var p1: Vector2 = _hud._radar_point(to, vr)
		if p0.distance_to(p1) > 4.0:
			_view.draw_dashed_line(p0, p1, Color(TroepSelectie.order_color(cmd), 0.75), 1.4, 5.0, true)
	for m in ts.live_marks():
		var age := TroepSelectie.now() - float(m.t)
		var a2 := clampf(1.0 - age / TroepSelectie.MARK_TIME, 0.0, 1.0)
		var p: Vector2 = _hud._radar_point(m.pos, vr)
		var col := Color(TroepSelectie.order_color(String(m.order)), a2)
		_view.draw_arc(p, (5.0 + 6.0 * (1.0 - a2)) * k * 0.6, 0.0, TAU, 18, col, 1.6, true)
		BevelBalk._glyph(_view, "attack" if String(m.order) == "basis" else String(m.order), p, 3.2 * k * 0.6, col)


## Namen alleen bij de twee bases; "jij" staat in de legenda (vroeger viel JIJ over JOUW BASIS).
func _draw_labels(vr: Rect2) -> void:
	var font := UI.body(700, 0)
	var patch: Rect2 = _hud._base_patch(vr)
	_label(font, Vector2(patch.get_center().x, patch.position.y - 6.0), "VIJANDBASIS", Color(1.0, 0.66, 0.55), true)
	if Game.mcv_deployed:
		_label(font, _hud._radar_point(Game.base_pos, vr) + Vector2(0.0, 20.0), "JOUW BASIS", Color(1.0, 0.84, 0.5), true)
	_label(font, Vector2(_map.size.x - 22.0, 16.0), "N ▲", UI.INK)


func _label(font: Font, at: Vector2, text: String, col: Color, anchor_center := false) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	var p := at - Vector2(w * 0.5 if anchor_center else 0.0, 0.0)
	p.x = clampf(p.x, 3.0, _map.size.x - w - 3.0)
	p.y = clampf(p.y, 13.0, _map.size.y - 4.0)
	_view.draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 4, Color(0, 0, 0, 0.85))
	_view.draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)


## Legenda met de echte tekens (keuze 3A).
func _draw_legend(font: Font) -> void:
	var r := _legend
	if _portrait:
		draw_style_box(UI.box(Color(0.02, 0.03, 0.02, 0.93), Color(HudExtra.C_RAND, 0.5), 1, 5, 0), r)
	var x := r.position.x + 12.0
	var y := r.position.y + 16.0
	draw_string(UI.body(700, 2), Vector2(x - 4.0, y), "LEGENDA", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(HudExtra.C_RAND, 0.95))
	y += 20.0
	var rows := ["jij", "je soldaten", "gekozen", "je voertuigen", "je gebouwen", "voertuig vast", "vijand", "vijandelijk voertuig", "vijandbasis", "wat je ziet"]
	for row in rows:
		if y > r.end.y - 4.0:
			break
		var p := Vector2(x + 2.0, y - 4.0)
		match row:
			"jij":
				draw_colored_polygon(PackedVector2Array([p + Vector2(7, 0), p + Vector2(-4, -4.5), p + Vector2(-2, 0), p + Vector2(-4, 4.5)]), HudExtra.C_JIJ)
			"je soldaten":
				draw_circle(p, 3.6, HudExtra.C_EIGEN)
			"gekozen":
				draw_circle(p, 3.6, HudExtra.C_EIGEN_HI)
				draw_arc(p, 7.0, 0.0, TAU, 14, HudExtra.C_EIGEN_HI, 1.4, true)
			"je voertuigen":
				draw_rect(Rect2(p - Vector2(6, 4), Vector2(12, 8)), HudExtra.C_EIGEN)
			"je gebouwen":
				draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)), HudExtra.C_GEBOUW)
			"voertuig vast":
				draw_colored_polygon(PackedVector2Array([p + Vector2(0, -6), p + Vector2(6, 4.5), p + Vector2(-6, 4.5)]), HudExtra.C_VAST)
			"vijand":
				draw_colored_polygon(PackedVector2Array([p + Vector2(0, -4.5), p + Vector2(4.5, 0), p + Vector2(0, 4.5), p + Vector2(-4.5, 0)]), HudExtra.C_VIJAND)
			"vijandelijk voertuig":
				draw_rect(Rect2(p - Vector2(6, 4), Vector2(12, 8)), HudExtra.C_VIJAND)
				draw_rect(Rect2(p - Vector2(6, 4), Vector2(12, 8)), Color(1, 0.92, 0.8, 0.9), false, 1.0)
			"vijandbasis":
				draw_rect(Rect2(p - Vector2(7, 5), Vector2(14, 10)), Color(0.9, 0.16, 0.1, 0.7))
				draw_rect(Rect2(p - Vector2(7, 5), Vector2(14, 10)), Color(1.0, 0.42, 0.28), false, 1.0)
			"wat je ziet":
				draw_rect(Rect2(p - Vector2(7, 5), Vector2(14, 10)), Color(0.92, 0.94, 0.86, 0.7), false, 1.0)
		draw_string(font, Vector2(x + 18.0, y), String(row), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 34.0, 12, UI.INK_DIM)
		y += 19.0


# ---------------------------------------------------------------- invoer

func _button_at(pos: Vector2) -> String:
	if _close.grow(6.0).has_point(pos):
		return "close"
	if _portrait and _legend_btn.grow(4.0).has_point(pos):
		return "legend"
	if _btn_all.grow(3.0).has_point(pos):
		return "all"
	if _btn_none.grow(3.0).has_point(pos):
		return "none"
	if _btn_veh.grow(3.0).has_point(pos):
		return "veh"
	for i in 3:
		if (_groups[i] as Rect2).grow(3.0).has_point(pos):
			return "g%d" % i
	var b := BevelBalk.hit(_bar, pos)
	if b >= 0:
		return "bar%d" % b
	return ""


func _input(e: InputEvent) -> void:
	if not visible:
		return
	if e is InputEventKey:
		if e.pressed and not e.echo and (e.keycode == KEY_ESCAPE or e.keycode == KEY_M):
			close_map()
			get_viewport().set_input_as_handled()
		return
	if e is InputEventScreenTouch:
		if e.pressed:
			_down(e.index, e.position)
		else:
			_up(e.index, e.position)
	elif e is InputEventScreenDrag:
		_drag(e.index, e.position)
	elif e is InputEventMouseButton:
		if e.device == InputEvent.DEVICE_ID_EMULATION:   # een aanraking komt ook als muis binnen: die tellen we niet dubbel
			get_viewport().set_input_as_handled()
			return
		if e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				_down(-1, e.position)
			else:
				_up(-1, e.position)
		elif e.button_index == MOUSE_BUTTON_RIGHT and e.pressed:
			close_map()
		elif e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and _map.has_point(e.position):
			_zoom_to(zoom() * (1.2 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.2), e.position, _vr)
	elif e is InputEventMouseMotion:
		if e.device != InputEvent.DEVICE_ID_EMULATION and _touches.has(-1):
			_drag(-1, e.position)
	elif e is InputEventMagnifyGesture and _map.has_point(e.position):
		_zoom_to(zoom() * e.factor, e.position, _vr)
	else:
		return
	get_viewport().set_input_as_handled()


func _down(id: int, pos: Vector2) -> void:
	_touches[id] = pos
	if _touches.size() == 1:
		_primary = id
		_start = pos
		_box_to = pos
		_press_t = _now()
		_press_btn = _button_at(pos)
		_mode = "tap"
	elif _touches.size() == 2 and _mode in ["tap", "box", "pan"] and _map.has_point(pos):
		# tweede vinger op de kaart: knijpen en schuiven
		var pts: Array = _touches.values()
		_mode = "pinch"
		_pinch_d0 = maxf((pts[0] as Vector2).distance_to(pts[1]), 10.0)
		_pinch_mid0 = ((pts[0] as Vector2) + (pts[1] as Vector2)) * 0.5
		_pinch_vr0 = _vr


func _drag(id: int, pos: Vector2) -> void:
	if not _touches.has(id):
		return
	var before: Vector2 = _touches[id]
	_touches[id] = pos
	match _mode:
		"tap":
			if id == _primary and pos.distance_to(_start) > TAP_SLACK and _press_btn == "" and _map.has_point(_start):
				_mode = "pan" if _target else "box"
				_box_to = pos
		"box":
			if id == _primary:
				_box_to = pos
		"pan":
			if id == _primary:
				_vr.position += pos - before
				_clamp_view()
		"pinch":
			if _touches.size() >= 2:
				var pts: Array = _touches.values()
				var d := maxf((pts[0] as Vector2).distance_to(pts[1]), 10.0)
				var mid := ((pts[0] as Vector2) + (pts[1] as Vector2)) * 0.5
				var z0 := _pinch_vr0.size.x / _fit.size.x
				_zoom_to(z0 * d / _pinch_d0, _pinch_mid0, _pinch_vr0)
				_vr.position += mid - _pinch_mid0
				_clamp_view()


func _up(id: int, pos: Vector2) -> void:
	if not _touches.has(id):
		return
	_touches.erase(id)
	if id == _primary:
		match _mode:
			"tap":
				_tap(pos)
			"box":
				_finish_box()
		if _mode != "pinch":
			_mode = "klaar"
	if _touches.is_empty():
		_mode = ""
		_primary = -2


func _finish_box() -> void:
	var ts := _sel()
	if ts == null:
		return
	var box := Rect2(_start, _box_to - _start).abs().grow(4.0)
	var list: Array = []
	for a in TroepSelectie.units():
		if box.has_point(to_screen(a.global_position)):
			list.append(a)
	ts.select(list)


## Eigen soldaat onder de vinger (dichtstbij binnen PICK_PX).
func _ally_at(pos: Vector2) -> Node3D:
	var best: Node3D = null
	var bd := PICK_PX
	for a in TroepSelectie.units():
		var d := to_screen(a.global_position).distance_to(pos)
		if d < bd:
			bd = d
			best = a
	return best


## Vijand onder de vinger, alleen als hij op de kaart staat (gezien).
func _enemy_at(pos: Vector2) -> Node3D:
	var best: Node3D = null
	var bd := PICK_PX
	for ev in Game.enemies:
		if not is_instance_valid(ev) or not ev is Node3D or ev.get("dead") == true:
			continue
		if _hud._enemy_vis(ev) <= 0.0:
			continue
		var d := to_screen(ev.global_position).distance_to(pos)
		if d < bd:
			bd = d
			best = ev
	return best


func _tap(pos: Vector2) -> void:
	var ts := _sel()
	match _press_btn:
		"close":
			close_map()
			return
		"legend":
			_legend_open = not _legend_open
			return
		"all":
			if ts != null:
				ts.select_all()
			return
		"none":
			if ts != null:
				ts.clear()
			return
		"veh":
			if ts != null:
				ts.select_vehicles()
				if ts.sel.is_empty():
					Game.banner.emit("GEEN VOERTUIGEN", "Je hebt geen jeep of tank die je kunt bevelen (zit jij erin, stap dan uit).", 2.4)
			return
	if _press_btn.begins_with("g"):
		if ts != null and not ts.pick_group(int(_press_btn.substr(1))):
			Game.banner.emit("GROEP %d IS LEEG" % (int(_press_btn.substr(1)) + 1), "Kies soldaten en houd het vakje vast om ze op te slaan.", 2.0)
		return
	if _press_btn.begins_with("bar"):
		if ts != null and not _target:
			ts.bar_press(TroepSelectie.ORDERS[int(_press_btn.substr(3))])
		return
	if not _map.has_point(pos):
		if not _panel.has_point(pos):
			close_map()   # naast het paneel: terug naar het spel (een wachtend bevel blijft wachten)
		return
	if _target:
		_tap_target(pos)
		return
	if ts == null:
		close_map()
		return
	# eigen soldaat of voertuig: kiezen; dubbeltik = al je eenheden van die soort
	var own := _ally_at(pos)
	if own != null and (ts.armed != "bewaak" or ts.sel.is_empty()):
		var now := _now()
		if now - _last_tap_t < DOUBLE_TAP and is_instance_valid(_last_tap_unit) and String(_last_tap_unit.get("kind")) == String(own.get("kind")):
			ts.select_kind(String(own.get("kind")), TroepSelectie.units())
			_last_tap_t = -10.0
		else:
			ts.select([own])
			_last_tap_t = now
			_last_tap_unit = own
		return
	if ts == null or ts.sel.is_empty():
		close_map()   # overzicht zonder keuze: een tik sluit, zoals altijd
		return
	var world := to_world(pos)
	var guard: Node3D = TroepSelectie.guardable_near(get_tree(), world, PICK_PX / _px_per_m()) if ts.armed == "bewaak" else null
	ts.apply_tap(world, _enemy_at(pos), guard)


## Het oude commandowiel wacht op een doel voor je hele leger (zoals vóór de bevelstand).
func _tap_target(pos: Vector2) -> void:
	var tc := get_tree().get_first_node_in_group("team_commands")
	if tc == null:
		close_map()
		return
	var world := to_world(pos)
	var attack: bool = tc.controller.pending_order == "attack"
	var on_base: bool = attack and (_hud._base_patch(_vr).grow(10.0).has_point(pos) or VijandBasis.contains(world, 6.0))
	if not attack and VijandBasis.contains(world, 2.0):
		Game.banner.emit("VIJANDBASIS", "Daar stuur je geen soldaten heen. Kies Aanvallen om de basis aan te vallen.", 2.5)
		return   # de kaart blijft open, het bevel blijft wachten
	if tc.pick_from_map(world, on_base):
		close_map()
