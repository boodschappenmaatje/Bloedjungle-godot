class_name StadEditor
extends Control
## Stadseditor: deel de stad achter de brug zelf in. Recht van boven kijk je op de stad; kies onderaan een wegdeel, gebouw
## of straatding en tik op de kaart. Sleep iets om het te verschuiven, tik erop om het te draaien, te kopiëren of weg te halen.
## Twee vingers schuiven en zoomen. Alles springt op een raster; rood betekent dat het daar niet past.
## Open hem tussen de golven met "Stadseditor" in het hoofdmenu of het pauzemenu (of F8). Je indeling wordt vanzelf bewaard;
## met KOPIEER krijg je een tekst die Claude in stad_data.gd zet, dan ligt de stad vast.

const FOLIAGE_GROUPS := ["foliage_palm", "foliage_bush", "foliage_fern", "foliage_grass", "foliage_rock", "treeshadow"]
const TABS := [["weg", "WEGEN"], ["gebouw", "GEBOUWEN"], ["straat", "STRAAT"], ["gum", "GUM"]]
const GOOD_COL := Color(0.3, 0.9, 0.35, 0.45)
const BAD_COL := Color(1.0, 0.25, 0.2, 0.5)
const SEL_COL := Color(1.0, 0.85, 0.3, 0.4)
const LINE_TOOLS := {"lijn": "weg_recht", "lijn_steeg": "weg_steeg"}   # wegen trek je als een lijn; het spel kiest de wegdelen
const ICON_DIR := "res://assets/stad_icons/%s.png"
const PANEL_BG := Color(18.0 / 255.0, 22.0 / 255.0, 12.0 / 255.0, 0.8)

var _stad: Stad
var _rot_btn: Button
var _ui: Control
var _top: PanelContainer
var _count: Label
var _hint: Label
var _msg: Label
var _tab_btns := {}
var _chips: HBoxContainer
var _palette: PanelContainer
var _actions: PanelContainer
var _brush_btn: Button
var _zoom_box: VBoxContainer
var _popup: PanelContainer
var _text: TextEdit
var _reset_btn: Button
var _reset_arm := false
var _hl: MeshInstance3D
var _hl_mesh: BoxMesh
var _hl_mat: StandardMaterial3D
var _marks: Array = []

var _tool := ""             # "" = niets gekozen, een soortnaam = plaatsen, "gum" = weghalen
var _cat := "weg"
var _rot := 0
var _mir := 0
var _brush := false
var _sel: Dictionary = {}
var _undo: Array = []
var _ptrs := {}
var _drag: Dictionary = {}
var _pinch: Dictionary = {}
var _touch := false
var _msg_t := 0.0
var _cand: Dictionary = {}
var _last_brush := Vector2(INF, INF)
var _hidden: Array = []
var _line_hl: Node3D
var _line_cells: Array = []   # cellen van de lijn die je trekt (Vector2i), op volgorde
var _line_plan: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group("stad_editor")
	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.visible = false
	add_child(_ui)
	_make_top()
	_make_palette()
	_make_actions()
	_make_zoom()
	_make_popup()
	_make_highlight()
	resized.connect(_layout)
	_layout()


# ---------------------------------------------------------------- opbouw van het scherm

func _panel() -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UI.box(PANEL_BG, UI.PANEL_LINE, 1, 6, 6))
	_ui.add_child(pc)
	return pc


func _btn(text: String, kind: String, cb: Callable, parent: Control) -> Button:
	var b := Button.new()
	b.add_to_group("hud_button")
	b.text = text
	UI.style_button(b, kind)
	b.add_theme_font_size_override("font_size", 12)
	b.custom_minimum_size = Vector2(0, 30)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _make_top() -> void:
	_top = _panel()
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	_top.add_child(vb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	vb.add_child(row)
	row.add_child(UI.label("STADSEDITOR", UI.display(1), 14, UI.INK))
	_count = UI.label("", UI.body(700, 0), 11, UI.BRASS)
	_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_count)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 6)
	vb.add_child(btns)
	_btn("ONGEDAAN", "buy", _do_undo, btns).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn("KOPIEER", "buy", _show_text, btns).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn("KLAAR", "gold", exit, btns).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint = UI.label("", UI.body(600, 0), 11, UI.INK_DIM)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_hint)
	_msg = UI.label("", UI.body(700, 0), 12, Color("ff7a6a"))
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_msg)


func _make_palette() -> void:
	_palette = _panel()
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	_palette.add_child(vb)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	vb.add_child(tabs)
	for t in TABS:
		var id: String = t[0]
		var b := _btn(t[1], "buy", func(): _pick_tab(id), tabs)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_tab_btns[id] = b
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(0, 70)
	vb.add_child(sc)
	_chips = HBoxContainer.new()
	_chips.add_theme_constant_override("separation", 6)
	sc.add_child(_chips)


func _make_actions() -> void:
	_actions = _panel()
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	_actions.add_child(hb)
	_rot_btn = _btn("DRAAI", "buy", _rotate, hb)
	_btn("SPIEGEL", "buy", _mirror, hb)
	_btn("KOPIE", "buy", _copy, hb)
	_btn("WIS", "buy", _delete_sel, hb)
	_brush_btn = _btn("KWAST", "buy", func():
		_brush = not _brush
		_refresh(), hb)


func _make_zoom() -> void:
	_zoom_box = VBoxContainer.new()
	_zoom_box.add_theme_constant_override("separation", 6)
	_ui.add_child(_zoom_box)
	for z in ["+", "−"]:
		var b := Button.new()
		b.add_to_group("hud_button")
		b.text = z
		UI.style_button(b, "pause")
		b.add_theme_font_size_override("font_size", 22)
		b.custom_minimum_size = Vector2(38, 38)
		b.pressed.connect(func(): _zoom_by(0.8 if z == "+" else 1.25))
		_zoom_box.add_child(b)


func _make_popup() -> void:
	_popup = _panel()
	_popup.visible = false
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_popup.add_child(vb)
	vb.add_child(UI.label("JOUW STAD", UI.display(1), 18, UI.INK))
	var info := UI.label("Kopieer deze tekst en plak hem in de chat met Claude. Dan zet Claude je indeling vast in het spel.", UI.body(600, 0), 13, UI.INK_DIM)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(info)
	_text = TextEdit.new()
	_text.custom_minimum_size = Vector2(0, 150)
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_size_override("font_size", 12)
	vb.add_child(_text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	vb.add_child(row)
	_btn("KOPIEER", "gold", _copy_text, row).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reset_btn = _btn("STANDAARD", "buy", _reset_default, row)
	_reset_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn("SLUIT", "buy", func(): _popup.visible = false, row).size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _make_highlight() -> void:
	_hl = MeshInstance3D.new()
	_hl_mesh = BoxMesh.new()
	_hl.mesh = _hl_mesh
	_hl_mat = StandardMaterial3D.new()
	_hl_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hl_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_hl_mat.no_depth_test = true
	_hl_mat.albedo_color = GOOD_COL
	_hl.material_override = _hl_mat
	_hl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hl.visible = false
	for i in 4:
		var m := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.9, 0.9, 0.9)
		m.mesh = bm
		var mm := StandardMaterial3D.new()
		mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mm.no_depth_test = true
		mm.albedo_color = Color(1.0, 0.95, 0.4)
		m.material_override = mm
		m.visible = false
		_hl.add_child(m)
		_marks.append(m)


func _layout() -> void:
	if _top == null:
		return
	var w := size.x
	_top.position = Vector2(12, 8)
	_top.size = Vector2(minf(w - 24.0, 400.0), 0)
	_hint.custom_minimum_size.x = _top.size.x - 16.0
	_msg.custom_minimum_size.x = _top.size.x - 16.0
	_palette.size = Vector2(w - 24.0, 0)
	_palette.position = Vector2(12, size.y - _palette.size.y - 10.0)
	_actions.position = Vector2(12, size.y - _palette.size.y - _actions.size.y - 18.0)
	_zoom_box.position = Vector2(w - 54.0, size.y * 0.3)
	var pw := minf(w - 24.0, 520.0)
	_popup.size = Vector2(pw, minf(size.y - 40.0, 360.0))
	_popup.position = Vector2((w - pw) / 2.0, 20.0)


# ---------------------------------------------------------------- in en uit

func enter() -> void:
	if Game.editing or Game.build_mode or Game.state != "prep" or Game.player == null:
		return
	if Game.player.elev > 0.5:
		Game.banner.emit("KOM EERST VAN DE TOREN", "", 1.4)
		return
	_stad = Stad.current
	if _stad == null:
		return
	if not is_instance_valid(_hl):
		_make_highlight()
	if _hl.get_parent() != _stad:
		if _hl.get_parent() != null:
			_hl.get_parent().remove_child(_hl)
		_stad.add_child(_hl)
	Game.editing = true
	Game.build_mode = true
	_ui.visible = true
	_popup.visible = false
	_tool = ""
	_sel = {}
	_undo.clear()
	_ptrs.clear()
	_drag = {}
	_pinch = {}
	for g in FOLIAGE_GROUPS:
		for n in get_tree().get_nodes_in_group(g):
			if n is Node3D and n.visible:
				n.visible = false
				_hidden.append(n)
	Sfx.play("click")
	Game.changed.emit()
	_refresh()
	_stats()
	call_deferred("_layout")


func exit() -> void:
	if not Game.editing:
		return
	Game.editing = false
	Game.build_mode = false
	_ui.visible = false
	_hl.visible = false
	_line_clear()
	_ptrs.clear()
	_drag = {}
	_pinch = {}
	for n in _hidden:
		if is_instance_valid(n):
			n.visible = true
	_hidden.clear()
	Game.changed.emit()


func _process(delta: float) -> void:
	if Game.editing and Game.state != "prep":
		exit()
	if _msg_t > 0.0:
		_msg_t -= delta
		if _msg_t <= 0.0:
			_msg.text = ""
	if Game.editing:
		_layout_dynamic()


func _layout_dynamic() -> void:
	# hoogtes veranderen als de tekst of de knoppen veranderen: onderaan blijven staan
	_palette.position.y = size.y - _palette.size.y - 10.0
	_actions.position.y = size.y - _palette.size.y - _actions.size.y - 18.0


func _say(t: String) -> void:
	_msg.text = t
	_msg_t = 2.6
	Sfx.play("ping", 0.5)


# ---------------------------------------------------------------- palet

func _pick_tab(id: String) -> void:
	if id == "gum":
		_tool = "gum" if _tool != "gum" else ""
	else:
		_cat = id
		if _tool == "gum" or _tool == "draai" or LINE_TOOLS.has(_tool):
			_tool = ""
	_sel = {}
	_refresh()


func _pick_kind(kind: String) -> void:
	_tool = "" if _tool == kind else kind
	_sel = {}
	_rot = 0
	_mir = 0
	_last_brush = Vector2(INF, INF)
	_refresh()


func _refresh() -> void:
	if _chips == null:
		return
	for t in TABS:
		var on: bool = (t[0] == "gum" and _tool == "gum") or (t[0] != "gum" and t[0] == _cat and _tool != "gum")
		UI.style_button(_tab_btns[t[0]], "gold" if on else "buy")
	for c in _chips.get_children():
		c.queue_free()
	if _tool != "gum":
		for kind: String in Stad.ORDER[_cat]:
			if not Stad.available(kind):
				continue
			_chip(kind, String(Stad.KINDS[kind].name), kind)
		if _cat == "weg":
			_chip("lijn", "Trek weg", "weg_recht")
			_chip("lijn_steeg", "Trek steeg", "weg_steeg")
	_line_clear()
	UI.style_button(_brush_btn, "gold" if _brush else "buy")
	UI.style_button(_rot_btn, "gold" if _tool == "draai" else "buy")
	_brush_btn.text = "KWAST AAN" if _brush else "KWAST"
	if _tool == "draai":
		_hint.text = "DRAAI: tik op een onderdeel, elke tik is een kwartslag."
	elif _tool == "gum":
		_hint.text = "GUM: tik op iets om het weg te halen." + (" Veeg eroverheen." if _brush else " Met KWAST AAN kun je vegen.")
	elif LINE_TOOLS.has(_tool):
		_hint.text = "Trek een lijn met je vinger. Het spel kiest zelf bochten, T-stukken en kruisingen."
	elif _tool != "":
		_hint.text = "%s: tik op de kaart. Schuif de kaart met je vinger." % Stad.KINDS[_tool].name
		if Stad.KINDS[_tool].cat == "straat":
			_hint.text += " KWAST AAN: slepen zet een rij."
	else:
		_hint.text = "Kies iets onderaan. Veeg over de kaart om te schuiven, sleep een onderdeel om het te verplaatsen."
	_refresh_hl()


## Knop met een plaatje van het onderdeel (assets/stad_icons, gemaakt met tools/stad_icons.gd).
func _chip(tool: String, label: String, icon_kind: String) -> void:
	var b := Button.new()
	b.add_to_group("hud_button")
	b.text = label.to_upper()
	UI.style_button(b, "gold" if _tool == tool else "buy")
	b.add_theme_font_size_override("font_size", 10)
	b.custom_minimum_size = Vector2(86, 66)
	var path := ICON_DIR % icon_kind
	if ResourceLoader.exists(path):
		b.icon = load(path)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 44)
		b.add_theme_constant_override("h_separation", 0)
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.pressed.connect(func(): _pick_kind(tool))
	_chips.add_child(b)


func _stats() -> void:
	if _stad == null:
		return
	var w := Stad.weight_of(_stad.items)
	var level := "LICHT"
	var col := UI.GOOD
	if w >= Stad.WEIGHT_MAX:
		level = "TE ZWAAR"
		col = Color("ff7a6a")
	elif w >= Stad.WEIGHT_MAX * 0.6:
		level = "MIDDEL"
		col = UI.BRASS
	var n := Stad.sloop_count(_stad.items)
	_count.text = "SLOOPBAAR %d (max %d actief) · ZWAARTE %d/%d %s" % [n, Stad.MAX_SLOOP, roundi(w), roundi(Stad.WEIGHT_MAX), level]
	_count.add_theme_color_override("font_color", col)
	_count.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_count.custom_minimum_size.x = 120.0
	_stad.save_user()


# ---------------------------------------------------------------- invoer

func _input(event: InputEvent) -> void:
	if not Game.editing:
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
			elif event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
				if event.pressed and not _over_ui(event.position):
					_ptrs[-2] = event.position
					_drag = {"pan": true, "last": event.position, "sp": event.position, "moved": true, "id": -2}
				elif not event.pressed and _drag.get("id", 0) == -2:
					_ptrs.erase(-2)
					_drag = {}
			elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom_by(0.9)
			elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_by(1.1)
		elif event is InputEventMouseMotion:
			if _ptrs.has(-1) or _ptrs.has(-2):
				_move(-2 if _ptrs.has(-2) else -1, event.position)
			elif _is_place() and not _over_ui(event.position):
				_hover(event.position)


func _unhandled_key_input(e: InputEvent) -> void:
	if not e is InputEventKey or not e.pressed or e.echo:
		return
	if e.keycode == KEY_F8:
		if Game.editing:
			exit()
		else:
			enter()
		return
	if not Game.editing:
		return
	match e.keycode:
		KEY_R:
			_rotate()
		KEY_M:
			_mirror()
		KEY_K:
			_brush = not _brush
			_refresh()
		KEY_DELETE, KEY_BACKSPACE:
			_delete_sel()
		KEY_ESCAPE:
			_tool = ""
			_sel = {}
			_refresh()
		KEY_Z:
			if e.ctrl_pressed or e.meta_pressed:
				_do_undo()


## Een gewoon onderdeel plaatsen (geen gum, draaimodus of wegenlijn)?
func _is_place() -> bool:
	return _tool != "" and _tool != "gum" and _tool != "draai" and not LINE_TOOLS.has(_tool)


func _over_ui(p: Vector2) -> bool:
	var ctrls: Array = [_top, _palette, _actions, _zoom_box]
	if _popup.visible:
		ctrls.append(_popup)
	for c: Control in ctrls:
		if c.is_visible_in_tree() and c.get_global_rect().has_point(p):
			return true
	return false


func _ground(p: Vector2) -> Variant:
	var cam := get_viewport().get_camera_3d()
	return Plane(Vector3.UP, 0.0).intersects_ray(cam.project_ray_origin(p), cam.project_ray_normal(p))


func _zoom_by(f: float) -> void:
	Game.ecam.z = clampf(Game.ecam.z * f, 0.35, 1.9)


func _clamp_cam() -> void:
	Game.ecam.x = clampf(Game.ecam.x, -Data.WORLD_X, Data.WORLD_X)
	Game.ecam.y = clampf(Game.ecam.y, -Data.WORLD_Z_N, 10.0)


## Hoeveel meter op de grond is één scherm-pixel.
func _mpp() -> float:
	var cam := get_viewport().get_camera_3d()
	return 2.0 * 62.0 * Game.ecam.z * tan(deg_to_rad(cam.fov * 0.5)) / maxf(1.0, get_viewport().get_visible_rect().size.y)


func _down(id: int, pos: Vector2) -> void:
	if _over_ui(pos):
		return
	_ptrs[id] = pos
	if _ptrs.size() == 2:
		_cancel_drag()
		var v: Array = _ptrs.values()
		_pinch = {"d": maxf(1.0, (v[0] - v[1]).length()), "zoom": Game.ecam.z, "mid": (v[0] + v[1]) * 0.5}
		return
	if _ptrs.size() > 2:
		return
	var g: Variant = _ground(pos)
	if g == null:
		return
	if _tool == "gum":
		if _brush:
			_drag = {"gum": true, "id": id, "sp": pos, "moved": false}
			_erase_at(g)
		else:
			_drag = {"tap": "gum", "g": g, "id": id, "sp": pos, "moved": false, "last": pos}   # tik = weghalen, slepen = kaart schuiven
		return
	if _tool == "draai":
		var it := _pick(g)
		if it.is_empty():
			_drag = {"pan": true, "last": pos, "sp": pos, "moved": false, "id": id}
		else:
			_sel = it
			_turn(it)
		return
	if LINE_TOOLS.has(_tool):
		_line_cells = [_cell_of(g)]
		_drag = {"line": true, "id": id, "sp": pos, "moved": false}
		_line_update()
		return
	if _tool != "":
		if _brush and Stad.KINDS[_tool].cat == "straat":
			_drag = {"place": true, "id": id, "sp": pos, "moved": false}
			_aim(g)
			_stamp()
		else:
			_drag = {"tap": "place", "g": g, "id": id, "sp": pos, "moved": false, "last": pos}   # tik = neerzetten, slepen = kaart schuiven
		return
	var it := _pick(g)
	if it.is_empty():
		_sel = {}
		_drag = {"pan": true, "last": pos, "sp": pos, "moved": false, "id": id}
		_refresh_hl()
		return
	_sel = it
	_drag = {"move": true, "d": it, "off": Vector2(it.x - g.x, it.z - g.z), "sp": pos, "moved": false, "id": id,
		"old": {"x": it.x, "z": it.z, "r": it.r, "m": it.m}}
	_refresh_hl()


func _cancel_drag() -> void:
	_drag = {}
	_cand = {}
	_refresh_hl()


func _move(id: int, pos: Vector2) -> void:
	if _ptrs.has(id):
		_ptrs[id] = pos
	if not _pinch.is_empty() and _ptrs.size() >= 2:
		var v: Array = _ptrs.values()
		_set_zoom(_pinch.zoom * _pinch.d / maxf(1.0, (v[0] - v[1]).length()))
		var mid: Vector2 = (v[0] + v[1]) * 0.5
		var dm: Vector2 = mid - _pinch.mid
		_pinch.mid = mid
		var mp := _mpp()
		Game.ecam.x -= dm.x * mp
		Game.ecam.y -= dm.y * mp
		_clamp_cam()
		return
	if _drag.is_empty() or id != _drag.id:
		return
	if _drag.has("tap"):
		if pos.distance_to(_drag.sp) < 10.0:
			return
		_drag = {"pan": true, "last": _drag.last, "sp": _drag.sp, "moved": false, "id": id}
	if _drag.has("line"):
		var gl: Variant = _ground(pos)
		if gl != null:
			_line_extend(_cell_of(gl))
		_drag.moved = true
		return
	if _drag.has("pan"):
		if not _drag.moved and pos.distance_to(_drag.sp) < 8.0:
			return
		_drag.moved = true
		var d: Vector2 = pos - _drag.last
		_drag.last = pos
		var m := _mpp()
		Game.ecam.x -= d.x * m
		Game.ecam.y -= d.y * m
		_clamp_cam()
		return
	if not _drag.moved and pos.distance_to(_drag.sp) < 6.0:
		return
	_drag.moved = true
	var g: Variant = _ground(pos)
	if g == null:
		return
	if _drag.has("gum"):
		_erase_at(g)
	elif _drag.has("place"):
		_aim(g)
		if _brush and Stad.KINDS[_tool].cat == "straat":
			var c := Vector2(_cand.x, _cand.z)
			if _last_brush.distance_to(c) >= float(Stad.KINDS[_tool].spacing):
				_stamp()
	elif _drag.has("move"):
		var it: Dictionary = _drag.d
		var k: Dictionary = Stad.KINDS[it.k]
		var s: float = k.snap
		_cand = {"k": it.k, "x": roundf((g.x + _drag.off.x) / s) * s, "z": roundf((g.z + _drag.off.y) / s) * s, "r": it.r, "m": it.m}
		_show_cand()


func _set_zoom(z: float) -> void:
	Game.ecam.z = clampf(z, 0.35, 1.9)


func _up(id: int) -> void:
	_ptrs.erase(id)
	if _ptrs.size() < 2:
		_pinch = {}
	if _drag.is_empty() or id != _drag.id:
		return
	var dr := _drag
	_drag = {}
	if dr.has("line"):
		_line_apply()
		return
	if dr.has("tap"):
		if dr.tap == "gum":
			_erase_at(dr.g)
		else:
			_aim(dr.g)
			_place_cand()
			_cand = {}
			_hl.visible = false
		_refresh_hl()
		return
	if dr.has("place"):
		if not (_brush and Stad.KINDS[_tool].cat == "straat"):
			_place_cand()
	elif dr.has("move") and dr.moved and not _cand.is_empty():
		var it: Dictionary = dr.d
		var p := Stad.problem(_cand, _stad.items, it)
		if p == "":
			it.x = _cand.x
			it.z = _cand.z
			_undo.append({"op": "move", "d": it, "old": dr.old})
			_stad.refresh(it)
			Sfx.play("click")
			_stats()
		else:
			_say(p)
	_cand = {}
	_refresh_hl()


# ---------------------------------------------------------------- plaatsen, schuiven en weghalen

## Zet de kandidaat onder de vinger, op het raster.
func _aim(g: Vector3) -> void:
	if not _is_place():
		return
	var s: float = Stad.KINDS[_tool].snap
	_cand = {"k": _tool, "x": roundf(g.x / s) * s, "z": roundf(g.z / s) * s, "r": _rot, "m": _mir}
	_show_cand()


func _hover(pos: Vector2) -> void:
	var g: Variant = _ground(pos)
	if g != null:
		_aim(g)


func _stamp() -> void:
	if _cand.is_empty():
		return
	if _place_cand():
		_last_brush = Vector2(_cand.x, _cand.z)


func _place_cand() -> bool:
	if _cand.is_empty():
		return false
	var p := Stad.problem(_cand, _stad.items)
	if p != "":
		_say(p)
		return false
	var d := _cand.duplicate()
	_stad.add_item(d)
	_undo.append({"op": "add", "d": d})
	Sfx.play("click")
	_stats()
	return true


func _pick(g: Vector3) -> Dictionary:
	var pt := Vector2(g.x, g.z)
	for cat in ["straat", "gebouw", "weg"]:
		for i in range(_stad.items.size() - 1, -1, -1):
			var d: Dictionary = _stad.items[i]
			if Stad.KINDS[d.k].cat != cat:
				continue
			var r := Stad.rect_of(d)
			if cat == "straat":
				r = r.grow_individual(maxf(0.0, 0.9 - r.size.x / 2.0), maxf(0.0, 0.9 - r.size.y / 2.0), maxf(0.0, 0.9 - r.size.x / 2.0), maxf(0.0, 0.9 - r.size.y / 2.0))
			if r.has_point(pt):
				return d
	return {}


func _erase_at(g: Vector3) -> void:
	var it := _pick(g)
	if it.is_empty():
		return
	_stad.remove_item(it)
	_undo.append({"op": "del", "d": it})
	if is_same(_sel, it):
		_sel = {}
	Sfx.play("click")
	_stats()


func _delete_sel() -> void:
	if _sel.is_empty():
		_say("TIK EERST OP IETS")
		return
	var it := _sel
	_sel = {}
	_stad.remove_item(it)
	_undo.append({"op": "del", "d": it})
	_stats()
	_refresh_hl()


## DRAAI: met een soort gekozen draait het plaatsvlak; anders zet het draaimodus aan of uit.
## In draaimodus draait elke tik op een onderdeel het een kwartslag.
func _rotate() -> void:
	if _is_place():
		_rot = (_rot + 1) % 4
		if not _cand.is_empty():
			_cand.r = _rot
			_show_cand()
		return
	_tool = "" if _tool == "draai" else "draai"
	_sel = {}
	_cand = {}
	_refresh()


func _turn(it: Dictionary) -> void:
	var cand := it.duplicate()
	cand.r = (int(it.r) + 1) % 4
	_apply_change(it, cand)


func _mirror() -> void:
	if _is_place():
		_mir = 1 - _mir
		if not _cand.is_empty():
			_cand.m = _mir
			_show_cand()
		return
	if _sel.is_empty():
		_say("TIK EERST OP IETS")
		return
	if Stad.KINDS[_sel.k].cat == "gebouw":
		_say("GEBOUWEN KUNNEN NIET SPIEGELEN")
		return
	var cand := _sel.duplicate()
	cand.m = 1 - int(_sel.m)
	_apply_change(_sel, cand)


func _apply_change(it: Dictionary, cand: Dictionary) -> void:
	var p := Stad.problem(cand, _stad.items, it)
	if p != "":
		_say(p)
		return
	_undo.append({"op": "move", "d": it, "old": {"x": it.x, "z": it.z, "r": it.r, "m": it.m}})
	it.x = cand.x
	it.z = cand.z
	it.r = cand.r
	it.m = cand.m
	_stad.refresh(it)
	Sfx.play("click")
	_stats()
	_refresh_hl()


func _copy() -> void:
	if _sel.is_empty():
		_say("TIK EERST OP IETS")
		return
	var h := Stad.half_of(_sel)
	var gap := 0.4 if Stad.KINDS[_sel.k].cat == "gebouw" else 0.5 if Stad.KINDS[_sel.k].cat == "straat" else 0.0
	var snap: float = Stad.KINDS[_sel.k].snap
	var dx := ceilf((h.x * 2.0 + gap) / snap) * snap
	var dz := ceilf((h.y * 2.0 + gap) / snap) * snap
	for off in [Vector2(dx, 0), Vector2(-dx, 0), Vector2(0, dz), Vector2(0, -dz)]:
		var cand := _sel.duplicate()
		cand.erase("node")
		cand.x = _sel.x + off.x
		cand.z = _sel.z + off.y
		if Stad.problem(cand, _stad.items) == "":
			_stad.add_item(cand)
			_undo.append({"op": "add", "d": cand})
			_sel = cand
			Sfx.play("click")
			_stats()
			_refresh_hl()
			return
	_say("GEEN PLEK ERNAAST")


func _do_undo() -> void:
	if _undo.is_empty():
		_say("NIETS OM ONGEDAAN TE MAKEN")
		return
	var u: Dictionary = _undo.pop_back()
	if u.op == "group":
		for i in range(u.ops.size() - 1, -1, -1):
			var o: Dictionary = u.ops[i]
			if o.op == "add":
				_stad.remove_item(o.d)
			else:
				_stad.add_item(o.d)
		_sel = {}
		Sfx.play("click")
		_stats()
		_refresh_hl()
		return
	var d: Dictionary = u.d
	match u.op:
		"add":
			_stad.remove_item(d)
		"del":
			_stad.add_item(d)
		"move":
			d.x = u.old.x
			d.z = u.old.z
			d.r = u.old.r
			d.m = u.old.m
			_stad.refresh(d)
	if is_same(_sel, d):
		_sel = {}
	Sfx.play("click")
	_stats()
	_refresh_hl()


# ---------------------------------------------------------------- aanwijzing op de kaart

func _show_cand() -> void:
	if _cand.is_empty():
		_hl.visible = false
		return
	var p := Stad.problem(_cand, _stad.items, _drag.d if _drag.has("move") else {})
	_set_hl(_cand, GOOD_COL if p == "" else BAD_COL)
	if p != "" and _drag.get("moved", false):
		_msg.text = p
		_msg_t = 0.6


func _refresh_hl() -> void:
	if _hl == null or _stad == null:
		return
	if not _sel.is_empty() and _drag.is_empty():
		_set_hl(_sel, SEL_COL)
	elif _cand.is_empty() or _drag.is_empty() and (_tool == "" or _tool == "gum"):
		_hl.visible = false


func _set_hl(d: Dictionary, col: Color) -> void:
	var r := Stad.rect_of(d)
	var k: Dictionary = Stad.KINDS[d.k]
	var hgt := 0.3 if k.cat == "weg" else clampf(float(k.get("h", 1.0)) * 0.25, 0.4, 2.0)
	_hl_mesh.size = Vector3(r.size.x, hgt, r.size.y)
	_hl.position = Vector3(r.get_center().x, hgt / 2.0 + 0.05, r.get_center().y)
	_hl_mat.albedo_color = col
	_hl.visible = true
	var dirs: Array = []
	if k.cat == "weg" and k.has("open"):
		for c in String(k.open):
			dirs.append(Stad.DIRS[c])
	elif k.cat != "weg":
		dirs.append(Vector2(0, 1))   # de voorkant (de deur) zit aan +z
	var yaw := Stad.yaw_of(d)
	for i in 4:
		var m: MeshInstance3D = _marks[i]
		m.visible = i < dirs.size()
		if i < dirs.size():
			var dv: Vector2 = dirs[i]
			var local := Vector3(dv.x * (-1.0 if int(d.m) == 1 else 1.0), 0, dv.y)
			var world := Basis(Vector3.UP, yaw) * local
			var reach := Stad.half_of(d) if k.cat != "weg" else Vector2(Stad.CELL / 2.0, Stad.CELL / 2.0)
			var dist := absf(world.x) * reach.x + absf(world.z) * reach.y
			m.position = world * (dist + 0.1)
			m.position.y = 0.2


# ---------------------------------------------------------------- wegen trekken als lijn

const N := 1
const E := 2
const S := 4
const W := 8
static var _mask_table := {}   # bitmasker van openingen -> [soort, kwartslagen]


## Bitmasker (N=1, E=2, S=4, W=8) van de openingen van een wegdeel, met kwartslagen r (en spiegeling).
static func open_mask(open: String, r: int, mir := 0) -> int:
	var m := 0
	for c in open:
		var v: Vector2 = Stad.DIRS[c]
		var w := Basis(Vector3.UP, r * PI / 2.0) * Vector3(v.x * (-1.0 if mir == 1 else 1.0), 0, v.y)
		if roundf(w.z) < -0.5:
			m |= N
		elif roundf(w.x) > 0.5:
			m |= E
		elif roundf(w.z) > 0.5:
			m |= S
		else:
			m |= W
	return m


static func _table() -> Dictionary:
	if _mask_table.is_empty():
		for kind in ["weg_recht", "weg_bocht", "weg_t", "weg_kruis"]:
			for r in 4:
				var m := open_mask(Stad.KINDS[kind].open, r)
				if not _mask_table.has(m):
					_mask_table[m] = [kind, r]
	return _mask_table


static func _bits(m: int) -> int:
	return ((m & N) >> 0) + ((m & E) >> 1) + ((m & S) >> 2) + ((m & W) >> 3)


## Welk wegdeel en welke kwartslag hoort bij een bitmasker; steeg = smalle versie voor rechte stukken.
static func piece_for(mask: int, narrow: bool) -> Array:
	var m := mask
	if _bits(m) <= 1:
		m = E | W if (m & (E | W)) != 0 else N | S
	var t: Array = _table()[m]
	if narrow and t[0] == "weg_recht":
		return ["weg_steeg", t[1]]
	return t


static func _dir_bit(d: Vector2i) -> int:
	if d.x > 0:
		return E
	if d.x < 0:
		return W
	return S if d.y > 0 else N


static func _opposite(bit: int) -> int:
	match bit:
		N:
			return S
		S:
			return N
		E:
			return W
	return E


static func _bit_dir(bit: int) -> Vector2i:
	match bit:
		N:
			return Vector2i(0, -1)
		S:
			return Vector2i(0, 1)
		E:
			return Vector2i(1, 0)
	return Vector2i(-1, 0)


func _cell_of(g: Vector3) -> Vector2i:
	return Vector2i(roundi(g.x / Stad.CELL), roundi(g.z / Stad.CELL))


func _cell_pos(c: Vector2i) -> Vector2:
	return Vector2(c.x, c.y) * Stad.CELL


## Voegt cel c aan de lijn toe; tussenliggende cellen worden aangevuld, teruggaan maakt het laatste stukje ongedaan.
func _line_extend(c: Vector2i) -> void:
	var cur: Vector2i = _line_cells[-1]
	var guard := 0
	while cur != c and guard < 60:
		guard += 1
		var d := c - cur
		var step := Vector2i(signi(d.x), 0) if absi(d.x) >= absi(d.y) else Vector2i(0, signi(d.y))
		var nxt := cur + step
		if _line_cells.size() >= 2 and _line_cells[-2] == nxt:
			_line_cells.pop_back()
		else:
			_line_cells.append(nxt)
		cur = nxt
	_line_update()


func _road_items() -> Dictionary:
	var out := {}
	for d in _stad.items:
		var k: Dictionary = Stad.KINDS[d.k]
		if k.cat == "weg" and k.has("open"):
			out[Vector2i(roundi(d.x / Stad.CELL), roundi(d.z / Stad.CELL))] = d
	return out


func _in_plein(c: Vector2i) -> bool:
	var p := _cell_pos(c)
	for d in _stad.items:
		if Stad.KINDS[d.k].get("plein", false) and Stad.rect_of(d).has_point(p):
			return true
	return false


## Wat moet er gebeuren voor deze lijn? {ok, problem, cells: [[pos, slecht]], remove: [items], add: [items]}
func _line_plan_for(cells: Array) -> Dictionary:
	var narrow: bool = _tool == "lijn_steeg"
	var masks := {}
	for c: Vector2i in cells:
		if not masks.has(c):
			masks[c] = 0
	for i in range(cells.size() - 1):
		var a: Vector2i = cells[i]
		var b: Vector2i = cells[i + 1]
		var bit := _dir_bit(b - a)
		masks[a] |= bit
		masks[b] |= _opposite(bit)
	var roads := _road_items()
	var remove: Array = []
	var add: Array = []
	var shown: Array = []
	var bad := ""
	var base: Array = []
	var ro := {}   # cel -> bestaand item dat vervangen wordt
	for c: Vector2i in masks:
		if roads.has(c):
			ro[c] = roads[c]
	for d in _stad.items:
		var replaced := false
		for c in ro:
			if is_same(ro[c], d):
				replaced = true
		if not replaced:
			base.append(d)
	for c: Vector2i in masks:
		if _in_plein(c):
			continue
		var m: int = masks[c]
		# sluit aan op bestaande wegen ernaast die naar deze cel wijzen
		for bit in [N, E, S, W]:
			var nb: Vector2i = c + _bit_dir(bit)
			if masks.has(nb) or not roads.has(nb):
				continue
			var nd: Dictionary = roads[nb]
			if (open_mask(Stad.KINDS[nd.k].open, int(nd.r), int(nd.m)) & _opposite(bit)) != 0:
				m |= bit
		var was_narrow := false
		var was_zebra := false
		if ro.has(c):
			var od: Dictionary = ro[c]
			m |= open_mask(Stad.KINDS[od.k].open, int(od.r), int(od.m))
			was_narrow = od.k == "weg_steeg"
			was_zebra = od.k == "weg_zebra"
		var pc := piece_for(m, (narrow and not ro.has(c)) or was_narrow)
		if was_zebra and pc[0] == "weg_recht":
			pc = ["weg_zebra", pc[1]]   # een zebrapad blijft een zebrapad zolang de weg recht blijft
		var item := {"k": pc[0], "x": float(c.x) * Stad.CELL, "z": float(c.y) * Stad.CELL, "r": pc[1], "m": 0}
		if ro.has(c):
			var od2: Dictionary = ro[c]
			if od2.k == item.k and int(od2.r) == int(item.r):
				shown.append([_cell_pos(c), false])
				continue
			remove.append(od2)
		var p := Stad.problem(item, base)
		if p != "":
			if bad == "":
				bad = p
			shown.append([_cell_pos(c), true])
			continue
		base.append(item)
		add.append(item)
		shown.append([_cell_pos(c), false])
	return {"ok": bad == "" and not (add.is_empty() and remove.is_empty()), "problem": bad, "cells": shown, "remove": remove, "add": add}


func _line_update() -> void:
	_line_plan = _line_plan_for(_line_cells)
	_line_show(_line_plan.cells)
	if _line_plan.problem != "":
		_msg.text = _line_plan.problem
		_msg_t = 0.6


func _line_show(cells: Array) -> void:
	if _line_hl == null or not is_instance_valid(_line_hl):
		_line_hl = Node3D.new()
		_stad.add_child(_line_hl)
	while _line_hl.get_child_count() < cells.size():
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(Stad.CELL - 0.3, 0.3, Stad.CELL - 0.3)
		mi.mesh = bm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_line_hl.add_child(mi)
	for i in _line_hl.get_child_count():
		var mi := _line_hl.get_child(i) as MeshInstance3D
		mi.visible = i < cells.size()
		if i < cells.size():
			var pos: Vector2 = cells[i][0]
			mi.position = Vector3(pos.x, 0.25, pos.y)
			mi.material_override = _hl_mat_for(cells[i][1])


var _good_mat: StandardMaterial3D
var _bad_mat: StandardMaterial3D


func _hl_mat_for(bad: bool) -> StandardMaterial3D:
	if _good_mat == null:
		_good_mat = _hl_mat.duplicate()
		_good_mat.albedo_color = GOOD_COL
		_bad_mat = _hl_mat.duplicate()
		_bad_mat.albedo_color = BAD_COL
	return _bad_mat if bad else _good_mat


func _line_clear() -> void:
	_line_cells = []
	_line_plan = {}
	if _line_hl != null and is_instance_valid(_line_hl):
		for c in _line_hl.get_children():
			(c as Node3D).visible = false


func _line_apply() -> void:
	var plan := _line_plan
	_line_clear()
	if plan.is_empty():
		return
	if plan.problem != "":
		_say(plan.problem)
		return
	if plan.add.is_empty() and plan.remove.is_empty():
		return
	var ops: Array = []
	for d in plan.remove:
		_stad.remove_item(d)
		ops.append({"op": "del", "d": d})
	for d in plan.add:
		_stad.add_item(d)
		ops.append({"op": "add", "d": d})
	_undo.append({"op": "group", "ops": ops})
	Sfx.play("click")
	_stats()


# ---------------------------------------------------------------- tekst voor Claude

func _show_text() -> void:
	_text.text = Stad.to_text(_stad.items)
	_reset_arm = false
	_reset_btn.text = "STANDAARD"
	_popup.visible = true


func _copy_text() -> void:
	DisplayServer.clipboard_set(_text.text)
	_msg.text = "GEKOPIEERD. PLAK HET IN DE CHAT MET CLAUDE."
	_msg_t = 3.5
	Sfx.play("buy")


## Terug naar de stad zoals die in de code staat: haalt je eigen indeling weg.
func _reset_default() -> void:
	if not _reset_arm:
		_reset_arm = true
		_reset_btn.text = "ZEKER?"
		return
	_reset_arm = false
	_reset_btn.text = "STANDAARD"
	_sel = {}
	_undo.clear()
	_stad.set_items(Stad.from_lines(StadData.ITEMS))
	Stad.clear_saved()
	_popup.visible = false
	_refresh_hl()
