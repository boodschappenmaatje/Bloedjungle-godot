class_name BuildMode
extends Control
## Bouwmodus (16d-base.js): tussen de golven kijk je van boven op de basis. Onderaan staan kaartjes
## met gebouwen en bouwstukken: sleep er een op de kaart en laat los om te bouwen, sleep een gebouw dat
## er staat om het te verschuiven, tik erop voor het paneel. Sleep de grond om te schuiven, knijp of
## gebruik + en − om te zoomen.

const CARD_H := 78.0
const GAP := 8.0
const ORDER := ["kazerne", "Garage", "Ziekenboeg", "Munitiedepot", "Werkplaats", "Radiopost", "zandzak", "muur"]
const ORDERS := {"follow": "Volgen", "hold": "Posten"}

var _ui: Control
var _btn: Button
var _info: PanelContainer
var _points: Label
var _credit: Label
var _credit_box: VBoxContainer
var _msg: Label
var _panel: PanelContainer
var _cards: Array = []
var _zoom_btns: Array = []
var _sel: Variant = null
var _sell_arm: Variant = null
var _ptrs := {}
var _drag: Dictionary = {}
var _pinch: Dictionary = {}
var _touch := false
var _ghost: MeshInstance3D
var _ring: MeshInstance3D
var _msg_t := 0.0


class Card:
	extends Control
	var kind := ""
	var title := ""
	var sub := ""
	var off := false

	func _draw() -> void:
		var f: Font = UI.body(700, 0)
		draw_style_box(UI.box(UI.PANEL, UI.PANEL_LINE if off else Color(UI.BRASS, 0.6), 1, 6, 0), Rect2(Vector2.ZERO, size))
		var r := Rect2(6, 5, size.x - 12, size.y - 40)
		draw_rect(r, Color(0, 0, 0, 0.25))
		_icon(r)
		draw_string(f, Vector2(0, size.y - 21), title.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, size.x, 11, UI.INK)
		draw_string(f, Vector2(0, size.y - 7), sub, HORIZONTAL_ALIGNMENT_CENTER, size.x, 11, UI.BRASS)
		modulate.a = 0.45 if off else 1.0

	func _p(r: Rect2, x: float, y: float) -> Vector2:
		return r.position + Vector2(x * r.size.x / 64.0, y * r.size.y / 44.0)

	func _rc(r: Rect2, x: float, y: float, w: float, h: float, c: Color) -> void:
		draw_rect(Rect2(_p(r, x, y), Vector2(w * r.size.x / 64.0, h * r.size.y / 44.0)), c)

	func _ell(r: Rect2, x: float, y: float, rx: float, ry: float, c: Color) -> void:
		var pts := PackedVector2Array()
		for i in 14:
			var a := TAU * i / 14.0
			pts.append(_p(r, x + cos(a) * rx, y + sin(a) * ry))
		draw_colored_polygon(pts, c)

	func _icon(r: Rect2) -> void:
		match kind:
			"kazerne":
				_rc(r, 4, 38, 56, 4, Color("6a6a62"))
				_rc(r, 10, 18, 40, 20, Color("56603a"))
				draw_colored_polygon(PackedVector2Array([_p(r, 6, 19), _p(r, 30, 10), _p(r, 54, 19)]), Color("7a8360"))
				_rc(r, 25, 25, 10, 13, Color("15130e"))
				_rc(r, 22, 20, 16, 4, Color("c9a227"))
				_rc(r, 51, 4, 2, 34, Color("8a8a80"))
				_rc(r, 53, 4, 9, 6, Color("3e6b2a"))
			"zandzak":
				for p in [[14, 36], [32, 36], [50, 36], [23, 27], [41, 27], [32, 18]]:
					_ell(r, p[0], p[1], 9, 5, Color("8a7a50"))
			"muur":
				_rc(r, 4, 40, 56, 3, Color("5e5e58"))
				for x in [6, 24, 42]:
					_rc(r, x, 14, 16, 26, Color("9a978c"))
				_rc(r, 6, 30, 52, 2, Color("c9a227"))
			"Garage":
				_rc(r, 6, 12, 52, 28, Color("7a786c"))
				_rc(r, 4, 9, 56, 4, Color("4a4a42"))
				_rc(r, 15, 18, 34, 22, Color("5a5f48"))
			"Ziekenboeg":
				draw_colored_polygon(PackedVector2Array([_p(r, 6, 40), _p(r, 32, 8), _p(r, 58, 40)]), Color("c9c2a8"))
				_rc(r, 28, 14, 8, 2.6, Color("c0140f"))
				_rc(r, 30.7, 11.3, 2.6, 8, Color("c0140f"))
			"Munitiedepot":
				_rc(r, 6, 22, 24, 18, Color("5a4a2a"))
				_rc(r, 34, 22, 24, 18, Color("4e4024"))
				_rc(r, 18, 6, 26, 16, Color("665530"))
			"Werkplaats":
				_ell(r, 24, 24, 12, 12, Color("9a9a90"))
				_ell(r, 24, 24, 5, 5, Color("2a2a24"))
				draw_line(_p(r, 40, 36), _p(r, 54, 10), Color("c9a227"), 4.0)
			"Radiopost":
				_rc(r, 12, 26, 26, 14, Color("4a5230"))
				_rc(r, 45, 6, 2.5, 34, Color("8a8a80"))
				_ell(r, 20, 33, 3, 3, Color("c9a227"))


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_btn = Button.new()
	_btn.add_to_group("hud_button")
	_btn.text = "BOUWEN"
	UI.style_button(_btn, "pause")
	_btn.add_theme_font_override("font", UI.display(1))
	_btn.add_theme_font_size_override("font_size", 16)
	_btn.pressed.connect(_enter)
	add_child(_btn)
	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.visible = false
	add_child(_ui)
	_make_info()
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UI.box(UI.PANEL, UI.PANEL_LINE, 1, 6, 10))
	_panel.custom_minimum_size.x = 250
	_panel.visible = false
	_ui.add_child(_panel)
	for k in ORDER:
		var c := Card.new()
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.kind = k
		c.title = Buildings.DEFS[k].name if Buildings.DEFS.has(k) else k
		_ui.add_child(c)
		_cards.append(c)
	for z in ["+", "−", "⌂"]:
		var b := Button.new()
		b.add_to_group("hud_button")
		b.text = z
		UI.style_button(b, "pause")
		b.add_theme_font_size_override("font_size", 22)
		b.size = Vector2(42, 42)
		b.pressed.connect(func(): _zoom_by({"+": 0.8, "−": 1.25, "⌂": 0.0}[z]))
		_ui.add_child(b)
		_zoom_btns.append(b)
	resized.connect(_layout)
	Game.changed.connect(_refresh)
	_layout()


func _make_info() -> void:
	_info = PanelContainer.new()
	_info.add_theme_stylebox_override("panel", UI.box(UI.PANEL, UI.PANEL_LINE, 1, 6, 8))
	_info.position = Vector2(12, 84)
	_info.custom_minimum_size.x = 204
	_ui.add_child(_info)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)
	_info.add_child(vb)
	vb.add_child(UI.label("BOUWEN", UI.display(1), 17, UI.INK))
	var hint := UI.label("Sleep een kaartje op de kaart. Sleep de grond om te schuiven, knijp of gebruik + en − om te zoomen.", UI.body(600, 0), 12, UI.INK_DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 186
	vb.add_child(hint)
	_msg = UI.label("", UI.body(700, 0), 12, Color("ff7a6a"))
	vb.add_child(_msg)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	vb.add_child(row)
	var pb := VBoxContainer.new()
	pb.add_child(UI.label("PUNTEN", UI.body(700, 1), 11, UI.INK_DIM))
	_points = UI.label("0", UI.display(0), 18, UI.BRASS)
	pb.add_child(_points)
	row.add_child(pb)
	_credit_box = VBoxContainer.new()
	_credit_box.add_child(UI.label("BOUWTEGOED", UI.body(700, 1), 11, UI.INK_DIM))
	_credit = UI.label("0", UI.display(0), 18, UI.GOOD)
	_credit_box.add_child(_credit)
	row.add_child(_credit_box)
	var done := Button.new()
	done.add_to_group("hud_button")
	done.text = "Klaar"
	UI.style_button(done, "gold")
	done.pressed.connect(_exit)
	vb.add_child(done)


# ---------------------------------------------------------------- in en uit

func _enter() -> void:
	if Game.build_mode or Game.state != "prep" or Game.player == null:
		return
	if Game.player.elev > 0.5:
		Game.banner.emit("KOM EERST VAN DE TOREN", "", 1.4)
		return
	Game.build_mode = true
	_sel = null
	_sell_arm = null
	_ptrs.clear()
	_drag = {}
	_pinch = {}
	_ui.visible = true
	Sfx.play("click")
	Game.changed.emit()


func _exit() -> void:
	if not Game.build_mode:
		return
	Game.build_mode = false
	_ui.visible = false
	_ptrs.clear()
	_drag = {}
	_pinch = {}
	_sel = null
	if _ghost:
		_ghost.visible = false
	if _ring:
		_ring.visible = false
	for b in Game.buildings:
		b.node.visible = true
	Game.changed.emit()


func _process(delta: float) -> void:
	_btn.visible = Game.state == "prep" and not Game.build_mode and Game.player != null
	_btn.size = Vector2(110, 40)
	_btn.position = Vector2(12, 128)
	if Game.build_mode and Game.state != "prep":
		_exit()
	if _msg_t > 0.0:
		_msg_t -= delta
		if _msg_t <= 0.0:
			_msg.text = ""
	if Game.build_mode:
		_panel.position = Vector2(size.x - _panel.size.x - 12.0, 76.0)


func _unhandled_key_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_B:
		if Game.build_mode:
			_exit()
		else:
			_enter()


func _say(t: String) -> void:
	_msg.text = t
	_msg_t = 2.2


# ---------------------------------------------------------------- indeling

func _layout() -> void:
	var n := _cards.size()
	var w := minf(84.0, (size.x - 24.0 - GAP * (n - 1)) / n)
	var rows := 1
	if w < 60.0:
		rows = 2
		w = minf(84.0, (size.x - 24.0 - GAP * 3.0) / 4.0)
	var per := ceili(float(n) / rows)
	var total_w := per * w + (per - 1) * GAP
	var top := size.y - 10.0 - rows * CARD_H - (rows - 1) * GAP
	for i in n:
		var c: Card = _cards[i]
		c.size = Vector2(w, CARD_H)
		c.position = Vector2((size.x - total_w) / 2.0 + (i % per) * (w + GAP), top + (i / per) * (CARD_H + GAP))
		c.queue_redraw()
	for i in _zoom_btns.size():
		var b: Button = _zoom_btns[i]
		b.position = Vector2(size.x - 12.0 - (3 - i) * 42.0 - (2 - i) * 6.0, top - 54.0)


func _refresh() -> void:
	if Game.builds == null or _ui == null:
		return
	_points.text = UI.nl(Game.points)
	_credit.text = UI.nl(Game.build_credit)
	_credit_box.visible = Game.build_credit > 0
	for c: Card in _cards:
		if Buildings.DEFS.has(c.kind):
			var d: Dictionary = Buildings.DEFS[c.kind]
			var built := Game.builds.full(c.kind)
			c.off = built or not Game.can_afford_build(d.cost)
			c.sub = ("gebouwd" if not Game.builds.is_piece(c.kind) else "max") if built else UI.nl(d.cost) + " pt"
		else:
			c.off = true
			c.sub = "binnenkort"
		c.queue_redraw()
	if not Game.build_mode:
		return
	_fill_panel()


func _fill_panel() -> void:
	for ch in _panel.get_children():
		ch.queue_free()
	var st: Variant = _sel
	_panel.visible = st != null
	if _ring:
		_ring.visible = st != null
	if st == null:
		return
	if not Game.buildings.has(st):
		_sel = null
		_panel.visible = false
		return
	var b: Dictionary = st
	var def: Dictionary = Buildings.DEFS[b.kind]
	if _sell_arm != b:
		_sell_arm = null
	_place_ring(b)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	_panel.add_child(vb)
	var head := HBoxContainer.new()
	vb.add_child(head)
	head.add_child(UI.label(def.name.to_upper(), UI.display(1), 18, UI.INK))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var status := "niveau %d" % b.lv if b.kind == "kazerne" else "%d%%" % roundi(b.hp / b.max_hp * 100.0)
	head.add_child(UI.label(status.to_upper(), UI.body(700, 0), 13, UI.BRASS))
	var x := Button.new()
	x.add_to_group("hud_button")
	x.text = "✕"
	UI.style_button(x, "pause")
	x.custom_minimum_size = Vector2(30, 30)
	x.pressed.connect(func():
		_sel = null
		_fill_panel())
	head.add_child(x)
	var info := Label.new()
	info.add_theme_font_override("font", UI.body(600, 0))
	info.add_theme_font_size_override("font_size", 13)
	info.add_theme_color_override("font_color", UI.INK_DIM)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size.x = 226
	vb.add_child(info)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	vb.add_child(row)
	var tip := ""
	if b.kind == "kazerne":
		var lv: Dictionary = Buildings.LEVELS[b.lv]
		var nx: Variant = Buildings.LEVELS[b.lv + 1] if b.lv + 1 < Buildings.LEVELS.size() else null
		info.text = "Soldaten %d / %d%s · %ds per man · sterkte %d" % [Game.builds.soldiers_alive(), lv.max, " · in training %d" % b.queue if b.queue else "", lv.time, ceili(b.hp)]
		_act(row, "Schutter", "%d pt" % Buildings.TRAIN_COST, Game.builds.room(b) > 0 and Game.points >= Buildings.TRAIN_COST, func(): Game.builds.recruit(b))
		if nx:
			_act(row, "Upgrade", "%d pt" % nx.cost, Game.can_afford_build(nx.cost), func(): Game.builds.upgrade(b))
		else:
			_act(row, "Max", "", false, func(): pass)
		_act(row, ORDERS[Game.troop_mode], "soldaten", true, func():
			Game.troop_mode = "hold" if Game.troop_mode == "follow" else "follow"
			Game.changed.emit())
		tip = ("Niveau %d: %d soldaten, %ds training, sterker." % [b.lv + 1, nx.max, nx.time] if nx else "Volledig opgewaardeerd.") + (" Je soldaten bewaken de muur." if Game.troop_mode == "hold" else " Je soldaten lopen met je mee.")
	else:
		info.text = "Sterkte %d / %d" % [ceili(b.hp), b.max_hp]
		tip = Buildings.INFO.get(b.kind, "")
	var fix: int = Game.builds.fix_cost(b)
	if fix > 0:
		_act(row, "Repareer", "%d pt" % fix, Game.can_afford_build(fix), func():
			Game.builds.repair(b)
			Game.changed.emit())
	_act(row, "Draai", "", true, func():
		if not Game.builds.turn(b):
			_say("GEEN RUIMTE")
		Game.changed.emit())
	var armed: bool = _sell_arm == b
	_act(row, "Zeker?" if armed else "Verkoop", "+%d tegoed" % Game.builds.sell_value(b), true, func():
		if armed:
			_sell_arm = null
			_sel = null
			Game.builds.sell(b)
		else:
			_sell_arm = b
			Sfx.play("click")
			Game.changed.emit())
	if tip != "":
		var t := Label.new()
		t.text = tip
		t.add_theme_font_override("font", UI.body(600, 0))
		t.add_theme_font_size_override("font_size", 12)
		t.add_theme_color_override("font_color", UI.INK_DIM)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.custom_minimum_size.x = 226
		vb.add_child(t)


func _act(row: Container, text: String, sub: String, enabled: bool, cb: Callable) -> void:
	var b := Button.new()
	b.add_to_group("hud_button")
	b.text = text if sub == "" else text + "\n" + sub
	UI.style_button(b, "buy")
	b.add_theme_font_size_override("font_size", 13)
	b.custom_minimum_size = Vector2(70, 44)
	b.disabled = not enabled
	b.pressed.connect(cb)
	row.add_child(b)


# ---------------------------------------------------------------- invoer

func _input(event: InputEvent) -> void:
	if not Game.build_mode:
		return
	if event is InputEventScreenTouch:
		_touch = true
		if event.pressed:
			_down(event.index, event.position)
		else:
			_up(event.index)
	elif event is InputEventScreenDrag:
		_move(event.index, event.position)
	elif event is InputEventMouse and event.device != InputEvent.DEVICE_ID_EMULATION:
		_touch = false
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					_down(-1, event.position)
				else:
					_up(-1)
			elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom_by(0.9)
			elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_by(1.1)
		elif event is InputEventMouseMotion and _ptrs.has(-1):
			_move(-1, event.position)


func _over_ui(p: Vector2) -> bool:
	var ctrls: Array = [_info, _panel]
	ctrls.append_array(_zoom_btns)
	for c: Control in ctrls:
		if c.is_visible_in_tree() and c.get_global_rect().has_point(p):
			return true
	return false


func _ground(p: Vector2) -> Variant:
	var cam := get_viewport().get_camera_3d()
	var hit = Plane(Vector3.UP, 0.0).intersects_ray(cam.project_ray_origin(p), cam.project_ray_normal(p))
	return hit


func _struct_at(g: Vector3) -> Variant:
	for b in Game.buildings:
		var sz: Vector3 = Buildings.DEFS[b.kind].size
		var rel: Vector3 = g - b.at
		var u := rel.dot(Vector3(cos(b.yaw), 0, -sin(b.yaw)))
		var v := rel.dot(Vector3(sin(b.yaw), 0, cos(b.yaw)))
		if absf(u) < sz.x / 2.0 + 0.3 and absf(v) < sz.z / 2.0 + 0.3:
			return b
	return null


static func _snap(v: float) -> float:
	return roundf(v * 2.0) / 2.0


func _down(id: int, pos: Vector2) -> void:
	_ptrs[id] = pos
	if _ptrs.size() == 2:  # tweede vinger: knijpen om te zoomen, wat de eerste ook deed
		_cancel_drag()
		var v: Array = _ptrs.values()
		_pinch = {"d": maxf(1.0, (v[0] - v[1]).length()), "zoom": Game.bcam.z}
		return
	if _ptrs.size() > 2:
		return
	for c: Card in _cards:
		if c.get_global_rect().has_point(pos):
			if c.off:
				Sfx.play("ping", 0.5)
				if not Buildings.DEFS.has(c.kind):
					_say(c.kind.to_upper() + " KOMT LATER")
			else:
				_drag = {"kind": c.kind, "yaw": 0.0, "ox": 0.0, "oz": 0.0, "sp": pos, "moved": false, "id": id, "st": null}
			return
	if _over_ui(pos):
		return
	var g = _ground(pos)
	if g == null:
		return
	var st = _struct_at(g)
	if st != null:
		_drag = {"kind": st.kind, "st": st, "yaw": st.yaw, "ox": st.at.x - g.x, "oz": st.at.z - g.z, "sp": pos, "moved": false, "id": id}
	else:
		_drag = {"pan": true, "last": pos, "sp": pos, "moved": false, "id": id}


func _cancel_drag() -> void:
	if _drag.has("st") and _drag.st != null:
		_drag.st.node.visible = true
	_drag = {}
	if _ghost:
		_ghost.visible = false


func _move(id: int, pos: Vector2) -> void:
	if _ptrs.has(id):
		_ptrs[id] = pos
	if not _pinch.is_empty() and _ptrs.size() >= 2:
		var v: Array = _ptrs.values()
		_set_zoom(_pinch.zoom * _pinch.d / maxf(1.0, (v[0] - v[1]).length()))
		return
	if _drag.is_empty() or id != _drag.id:
		return
	if _drag.get("pan", false):
		if not _drag.moved and pos.distance_to(_drag.sp) < 8.0:
			return
		_drag.moved = true
		var cam := get_viewport().get_camera_3d()
		var mpp := 2.0 * cam.global_position.distance_to(Vector3(Game.bcam.x, 0, Game.bcam.y)) * tan(deg_to_rad(cam.fov * 0.5)) / size.y
		var d: Vector2 = pos - _drag.last
		_drag.last = pos
		Game.bcam.x -= d.x * mpp
		Game.bcam.y -= d.y * mpp * 1.03
		_clamp_pan()
		return
	if not _drag.moved and pos.distance_to(_drag.sp) < 10.0:
		return
	_drag.moved = true
	var g = _ground(pos)
	if g == null:
		return
	_drag.x = _snap(g.x + _drag.ox)
	_drag.z = _snap(g.z + _drag.oz)
	var at := Vector3(_drag.x, 0, _drag.z)
	_drag.ok = Game.builds.can_place(_drag.kind, at, _drag.yaw, _drag.st)
	_show_ghost(_drag.kind, at, _drag.yaw, _drag.ok)
	if _drag.st != null:
		_drag.st.node.visible = false


func _up(id: int) -> void:
	_ptrs.erase(id)
	if _ptrs.size() < 2:
		_pinch = {}
	if _drag.is_empty() or id != _drag.id:
		return
	var d := _drag
	_drag = {}
	if _ghost:
		_ghost.visible = false
	if d.get("pan", false):
		if not d.moved and _sel != null:
			_sel = null
			_sell_arm = null
			_fill_panel()
		return
	if d.st != null:
		d.st.node.visible = true
		if not d.moved:
			_sel = null if _sel == d.st else d.st
		elif d.get("ok", false):
			Game.builds.move_to(d.st, Vector3(d.x, 0, d.z), d.yaw)
			_sel = d.st
		else:
			Sfx.play("click", 0.5)
	elif d.moved and d.get("ok", false) and Game.can_afford_build(Buildings.DEFS[d.kind].cost):
		_sel = Game.builds.place(d.kind, Vector3(d.x, 0, d.z), d.yaw)
	elif d.moved:
		Sfx.play("ping", 0.6)
	_sell_arm = null
	Game.changed.emit()


func _zoom_by(f: float) -> void:
	if f == 0.0:
		Game.bcam = Vector3(0, 0, 1)
	else:
		_set_zoom(Game.bcam.z * f)
	Sfx.play("click", 0.5)


func _set_zoom(z: float) -> void:
	Game.bcam.z = clampf(z, 0.35, 2.4)
	_clamp_pan()


func _clamp_pan() -> void:
	var m := Data.WORLD_R - 6.0
	var v := Vector2(Game.bcam.x, Game.bcam.y)
	if v.length() > m:
		v = v.normalized() * m
		Game.bcam.x = v.x
		Game.bcam.y = v.y


# ---------------------------------------------------------------- spookbeeld en selectiering

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	return m


func _show_ghost(kind: String, at: Vector3, yaw: float, ok: bool) -> void:
	if _ghost == null:
		_ghost = MeshInstance3D.new()
		_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_ghost.material_override = _mat(Color.WHITE)
		Game.builds.add_child(_ghost)
	var sz: Vector3 = Buildings.DEFS[kind].size
	var bm := BoxMesh.new()
	bm.size = sz
	_ghost.mesh = bm
	_ghost.visible = true
	_ghost.global_position = at + Vector3(0, sz.y * 0.5, 0)
	_ghost.rotation.y = yaw
	(_ghost.material_override as StandardMaterial3D).albedo_color = Color(0.25, 0.95, 0.35, 0.4) if ok else Color(0.95, 0.2, 0.15, 0.45)


func _place_ring(b: Dictionary) -> void:
	if _ring == null:
		_ring = MeshInstance3D.new()
		_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_ring.mesh = PlaneMesh.new()
		_ring.material_override = _mat(Color(0.84, 0.68, 0.31, 0.38))
		Game.builds.add_child(_ring)
	var sz: Vector3 = Buildings.DEFS[b.kind].size
	(_ring.mesh as PlaneMesh).size = Vector2(sz.x + 0.8, sz.z + 0.8)
	_ring.visible = true
	_ring.global_position = b.at + Vector3(0, 0.06, 0)
	_ring.rotation.y = b.yaw
