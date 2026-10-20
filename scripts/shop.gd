class_name Shop
extends Control
## De wapenkamer (24-shop.js) in de stijl van de web-versie: tussen de golven punten uitgeven aan
## wapens, upgrades, basis en soldaat. Bevat ook de knoppen "Wapenkamer" (in de pauze) en "Wissel"
## (wapen wisselen, een ronde knop rechts zoals in de web-HUD).

const TABS := ["Wapens", "Upgrades", "Basis", "Soldaat"]
const TIER_COLORS := [Color(0, 0, 0, 0), Color8(111, 174, 74), Color8(74, 143, 214), Color8(154, 95, 208), Color8(224, 180, 58)]

var _tab := 0
var _open_btn: Button
var _swap_btn: Button
var _overlay: ColorRect
var _sheet: PanelContainer
var _scroll: ScrollContainer
var _body: VBoxContainer
var _head_eyebrow: Label
var _head_points: Label
var _tab_btns: Array = []
var _items: Control
var _drag_id := -2  # vinger of muis die de lijst versleept; -2 = geen
var _drag_acc := 0.0
var _drag_end := 0
var _compact := false  # liggende telefoon: alles kleiner zodat kopen zonder scrollen kan
var _sheet_sb: StyleBoxFlat
var _title: Label
var _foot_stats: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_open_btn = Button.new()
	_open_btn.text = "WAPENKAMER"
	_open_btn.add_to_group("hud_button")
	UI.style_button(_open_btn, "gold")
	_open_btn.pressed.connect(open)
	add_child(_open_btn)
	_swap_btn = Button.new()
	_swap_btn.add_to_group("hud_button")
	UI.style_button(_swap_btn, "round")
	_swap_btn.icon = load("res://assets/ui/icons/icon_switch.png")
	_swap_btn.expand_icon = true
	_swap_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_swap_btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	_swap_btn.add_theme_constant_override("icon_max_width", 24)
	_swap_btn.add_theme_color_override("icon_normal_color", UI.INK)
	_swap_btn.add_theme_color_override("icon_disabled_color", Color(UI.INK, 0.3))
	_swap_btn.add_theme_color_override("icon_hover_color", UI.INK)
	_swap_btn.add_theme_color_override("icon_pressed_color", UI.INK)
	_swap_btn.custom_minimum_size = Vector2(46, 46)
	_swap_btn.size = Vector2(46, 46)
	_swap_btn.pressed.connect(func():
		for m in get_tree().get_nodes_in_group("menus"):
			m.open_wheel())
	add_child(_swap_btn)
	_build_overlay()
	resized.connect(_layout)
	Game.changed.connect(_sync)
	_layout()
	_sync()


## Plek van de knoppen: "Wapenkamer" naast "Start nu" onder de golf-titel, "Wissel" in de boog rechts.
func _layout() -> void:
	var s := size
	_open_btn.size = Vector2(maxf(112.0, _open_btn.get_minimum_size().x), 40)
	_open_btn.position = Vector2(s.x * 0.5 + 2.0, 132)
	_swap_btn.position = Vector2(s.x - 64.0 - 68.0 - 23.0, s.y - 150.0 - 38.0 - 23.0)


## Met je vinger (of muis) de lijst met kaarten verslepen; de scrollbalk hoeft niet.
func _input(event: InputEvent) -> void:
	if not _overlay.visible:
		return
	var pos := Vector2.ZERO
	var kind := ""
	var idx := -1
	if event is InputEventScreenTouch:
		pos = event.position
		kind = "down" if event.pressed else "up"
		idx = event.index
	elif event is InputEventScreenDrag:
		pos = event.position
		kind = "move"
		idx = event.index
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION:
		pos = event.position
		kind = "down" if event.pressed else "up"
		idx = -1
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		pos = event.position
		kind = "move"
		idx = -1
	if kind == "down" and _scroll.get_global_rect().has_point(pos):
		_drag_id = idx
		_drag_acc = 0.0
	elif kind == "move" and idx == _drag_id:
		var rel: float = event.relative.y
		_drag_acc += absf(rel)
		if _drag_acc > 12.0:
			_scroll.scroll_vertical -= int(rel)
	elif kind == "up" and idx == _drag_id:
		if _drag_acc > 12.0:
			_drag_end = Time.get_ticks_msec()
		_drag_id = -2


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo:
		return
	var k: int = event.physical_keycode
	if k == KEY_B and (Game.state == "prep" or Game.state == "shop"):
		close() if Game.state == "shop" else open()
	elif k == KEY_Q and Game.state != "shop":
		cycle_weapon()
	elif k >= KEY_1 and k <= KEY_6 and Game.state != "shop":
		var id: String = Data.WEAPON_ORDER[k - KEY_1]
		if Game.owned.has(id):
			Game.cur = id


func _sync() -> void:
	_open_btn.visible = Game.state == "prep"
	_swap_btn.visible = Game.state == "play" or Game.state == "prep"
	_swap_btn.disabled = Game.owned.size() < 2


func cycle_weapon() -> void:
	var order: Array = Data.WEAPON_ORDER.filter(func(id): return Game.owned.has(id))
	if order.size() < 2:
		return
	Game.cur = order[(order.find(Game.cur) + 1) % order.size()]
	Game.changed.emit()


func open() -> void:
	if Game.state != "prep":
		return
	Game.state = "shop"
	_overlay.show()
	_scroll.scroll_vertical = 0
	_render()
	Game.changed.emit()


func close() -> void:
	_overlay.hide()
	Game.state = "prep"
	Game.changed.emit()


# ---------------------------------------------------------------- opbouw

func _build_overlay() -> void:
	_overlay = ColorRect.new()
	_overlay.color = Color(6.0 / 255.0, 8.0 / 255.0, 4.0 / 255.0, 0.72)
	_overlay.add_to_group("hud_button")
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	_overlay.hide()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(margin)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(center)
	_sheet = PanelContainer.new()
	var sb := UI.box(UI.PANEL, UI.PANEL_LINE, 1, 6, 20)
	_sheet_sb = sb
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 30
	_sheet.add_theme_stylebox_override("panel", sb)
	center.add_child(_sheet)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 0)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sheet.add_child(_body)
	# kop: eyebrow + titel links, punten rechts
	var head := HBoxContainer.new()
	_body.add_child(head)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(left)
	_head_eyebrow = UI.label("", UI.body(700, 2), 12, UI.BRASS)
	left.add_child(_head_eyebrow)
	_title = UI.label("WAPENKAMER", UI.display(1), 34, UI.INK)
	left.add_child(_title)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 0)
	head.add_child(right)
	var pl := UI.label("PUNTEN", UI.body(700, 2), 12, UI.INK_DIM)
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(pl)
	_head_points = UI.label("0", UI.display(0), 28, UI.BRASS)
	_head_points.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_head_points)
	_spacer(12)
	# tabs met een lijn eronder
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	_body.add_child(tabs)
	for i in TABS.size():
		var tb := Button.new()
		tb.text = TABS[i].to_upper()
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.custom_minimum_size.y = 36
		UI.style_button(tb, "tab")
		tb.pressed.connect(func():
			_tab = i
			_render())
		tabs.add_child(tb)
		_tab_btns.append(tb)
	var line := ColorRect.new()
	line.color = UI.PANEL_LINE
	line.custom_minimum_size.y = 1
	_body.add_child(line)
	_spacer(12)
	# alleen de kaarten scrollen; kop, tabs en voet blijven staan
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(_scroll)
	# brede balk die je met je duim kunt pakken
	var vb := _scroll.get_v_scroll_bar()
	vb.custom_minimum_size.x = 6
	for st in ["grabber", "grabber_highlight", "grabber_pressed"]:
		vb.add_theme_stylebox_override(st, UI.box(Color(UI.OLIVE_HI, 0.8), Color(0, 0, 0, 0), 0, 3, 0))
	vb.add_theme_stylebox_override("scroll", UI.box(Color(0, 0, 0, 0.3), Color(0, 0, 0, 0), 0, 6, 0))
	_items = Control.new()  # wordt bij elke render vervangen
	_scroll.add_child(_items)
	_spacer(14)
	var foot := HBoxContainer.new()
	_body.add_child(foot)
	_foot_stats = UI.label("", UI.body(600, 0), 14, UI.INK_DIM)
	_foot_stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_foot_stats.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(_foot_stats)
	var back := Button.new()
	back.text = "TERUG NAAR HET VELD ▶"
	UI.style_button(back, "primary")
	var pad := UI.box(UI.BLOOD, UI.BLOOD, 0, 4, 0)
	pad.content_margin_left = 22
	pad.content_margin_right = 22
	back.add_theme_stylebox_override("normal", pad)
	back.add_theme_stylebox_override("hover", pad)
	back.pressed.connect(close)
	foot.add_child(back)


func _spacer(h: float) -> void:
	var c := Control.new()
	c.custom_minimum_size.y = h
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(c)


func _sheet_width() -> float:
	return minf(760.0, size.x - 32.0)


func _render() -> void:
	_compact = size.y < 520.0
	_sheet_sb.set_content_margin_all(12.0 if _compact else 20.0)
	_title.add_theme_font_size_override("font_size", 24 if _compact else 34)
	var w := _sheet_width()
	_head_eyebrow.text = ("Golf %d overleefd · bonus +%d" % [Game.wave - 1, Game.bonus] if Game.bonus > 0 and Game.wave > 1 else "Voor de eerste golf").to_upper()
	_head_points.text = UI.nl(Game.points)
	_foot_stats.text = "Score %s · %d doden" % [UI.nl(Game.score), Game.kills]
	for i in _tab_btns.size():
		var tb: Button = _tab_btns[i]
		var on := i == _tab
		var sb: StyleBoxFlat = tb.get_theme_stylebox("normal").duplicate()
		sb.border_color = UI.BLOOD_HI if on else Color(0, 0, 0, 0)
		for st in ["normal", "hover", "pressed", "disabled", "focus"]:
			tb.add_theme_stylebox_override(st, sb)
		var c: Color = UI.INK if on else UI.INK_DIM
		for cn in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			tb.add_theme_color_override(cn, c)
	_items.queue_free()
	var pad := (24.0 if _compact else 40.0) + 10.0  # plus de scrollbalk
	var cols := 1 if (_compact and _tab == 1) else maxi(1, int(floor((w - pad + 10.0) / 230.0)))
	var grid := GridContainer.new()
	grid.columns = cols
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	_scroll.add_child(grid)
	_items = grid
	match _tab:
		0:
			for id in Data.WEAPON_ORDER:
				_weapon_card(id)
		1:
			for id in Data.WEAPON_ORDER:
				if Game.owned.has(id):
					_upgrade_card(id)
		2:
			_base_cards()
		3:
			_soldier_cards()
	# de kolommen delen de ruimte; het blad is hoogstens zo hoog als het scherm
	var col_w := (w - pad - 10.0 * (cols - 1)) / cols
	for c in grid.get_children():
		c.custom_minimum_size.x = col_w
	_sheet.custom_minimum_size.x = w
	_fit.call_deferred()


func _fit() -> void:
	var other := _body.get_combined_minimum_size().y - _scroll.get_combined_minimum_size().y
	var avail := size.y - 28.0 - 40.0 - other
	_scroll.custom_minimum_size.y = clampf(_items.get_combined_minimum_size().y, 120.0, maxf(120.0, avail))
	_scroll.scroll_vertical = 0


# ---------------------------------------------------------------- kaarten

func _card_box(tier := 0) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := UI.box(Color(0, 0, 0, 0.25), UI.PANEL_LINE, 1, 4, 12)
	if tier > 0:
		sb.border_color = Color(TIER_COLORS[tier], 0.7)
		sb.shadow_color = Color(TIER_COLORS[tier], 0.28)
		sb.shadow_size = 12
	pc.add_theme_stylebox_override("panel", sb)
	pc.size_flags_vertical = Control.SIZE_FILL
	_items.add_child(pc)
	return pc


func _tier(id: String) -> int:
	var s := 0
	if Game.owned.has(id):
		for k in Game.owned[id].up:
			s += int(Game.owned[id].up[k])
	return 4 if s >= 16 else 3 if s >= 10 else 2 if s >= 5 else 1 if s >= 1 else 0


func _wimg(id: String, tier: int) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(112, 56) if _compact else Vector2(0, 84)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glow := TextureRect.new()
	var g := Gradient.new()
	var gc: Color = TIER_COLORS[tier] if tier > 0 else UI.BRASS
	g.colors = PackedColorArray([Color(gc, 0.42 if tier > 0 else 0.16), Color(gc, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.72])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.6)
	gt.fill_to = Vector2(1.0, 0.6)
	gt.width = 128
	gt.height = 84
	glow.texture = gt
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(glow)
	var pic := TextureRect.new()
	pic.texture = load("res://assets/ui/weapons/weapon_%s.png" % id)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(pic)
	return holder


func _head(title: String, tag := "", tag_color := UI.GOOD) -> HBoxContainer:
	var h := HBoxContainer.new()
	var n := UI.label(title, UI.body(700, 0), 18, UI.INK)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(n)
	if tag != "":
		var t := UI.label(tag.to_upper(), UI.body(700, 1), 11, tag_color)
		t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(t)
	return h


func _pips(lvl: int, max_lvl: int) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 3)
	h.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for i in max_lvl:
		var r := ColorRect.new()
		r.custom_minimum_size = Vector2(9, 12)
		r.color = UI.BRASS if i < lvl else Color(UI.INK, 0.15)
		h.add_child(r)
	return h


func _desc(text: String) -> Label:
	var d := UI.label(text, UI.body(500, 0), 14, UI.INK_DIM)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return d


func _spec_label(pairs: Array) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_override("normal_font", UI.body(600, 0))
	r.add_theme_font_override("bold_font", UI.body(700, 0))
	r.add_theme_font_size_override("normal_font_size", 13)
	r.add_theme_font_size_override("bold_font_size", 13)
	r.add_theme_color_override("default_color", UI.INK_DIM)
	var parts := PackedStringArray()
	for p in pairs:
		parts.append("%s [color=#ebe3cc][b]%s[/b][/color]" % [p[0], p[1]])
	r.text = "    ".join(parts)
	return r


func _buy_button(text: String, enabled: bool, action: Callable, height := 40.0, min_w := 0.0, font_size := 15) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.custom_minimum_size = Vector2(min_w, height)
	UI.style_button(b, "buy")
	b.add_theme_font_size_override("font_size", font_size)
	b.pressed.connect(func():
		if Time.get_ticks_msec() - _drag_end < 200:
			return  # los laten na het slepen telt niet als koop
		action.call()
		_render()
		Game.changed.emit())
	return b


func _spec_pairs(id: String, short := false) -> Array:
	var w: Dictionary = Game.wstat(id)
	var dmg := ("%dx" % w.pellets if w.pellets > 1 else "") + str(roundi(w.dmg))
	var pairs := [["Schade", dmg], ["Tempo", "%d/min" % roundi(60.0 / w.rate)], ["Mag" if short else "Magazijn", str(w.mag)]]
	if short:
		pairs.append(["Herladen", "%.1fs" % w.reload])
	return pairs


func _weapon_card(id: String) -> void:
	var w: Dictionary = Data.WEAPONS[id]
	var own: bool = Game.owned.has(id)
	var tier := _tier(id)
	var pc := _card_box(tier)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	pc.add_child(v)
	if _compact:
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 8)
		top.add_child(_wimg(id, tier))
		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", 2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(_head(w.name, "In bezit" if own else ""))
		info.add_child(_spec_label(_spec_pairs(id, true)))
		top.add_child(info)
		v.add_child(top)
		v.add_child(_desc(w.desc))
	else:
		v.add_child(_wimg(id, tier))
		v.add_child(_head(w.name, "In bezit" if own else ""))
		v.add_child(_desc(w.desc))
		v.add_child(_spec_label(_spec_pairs(id)))
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sp)
	if own:
		var equipped: bool = Game.cur == id
		v.add_child(_buy_button("Uitgerust" if equipped else "Uitrusten", not equipped, func(): Game.cur = id))
	else:
		v.add_child(_buy_button("Koop · %s" % UI.nl(w.price), Game.points >= w.price, func():
			if Game.buy(w.price):
				Game.owned[id] = {"up": {"dmg": 0, "rate": 0, "mag": 0, "rel": 0}, "ammo": Data.WEAPONS[id].mag}
				Game.cur = id))


func _upgrade_card(id: String) -> void:
	var w: Dictionary = Data.WEAPONS[id]
	var tier := _tier(id)
	var pc := _card_box(tier)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	pc.add_child(v)
	var rows: Container = v
	if _compact:
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 8)
		top.add_child(_wimg(id, tier))
		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", 2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(_head(w.name))
		info.add_child(_spec_label(_spec_pairs(id, true)))
		top.add_child(info)
		v.add_child(top)
		var g := GridContainer.new()
		g.columns = 2
		g.add_theme_constant_override("h_separation", 14)
		g.add_theme_constant_override("v_separation", 6)
		v.add_child(g)
		rows = g
	else:
		v.add_child(_wimg(id, tier))
		v.add_child(_head(w.name))
		v.add_child(_spec_label(_spec_pairs(id, true)))
	for u in Data.UPGS:
		var lvl: int = Game.owned[id].up[u[0]]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rows.add_child(row)
		var txt := VBoxContainer.new()
		txt.add_theme_constant_override("separation", 0)
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		txt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		txt.add_child(UI.label(u[1], UI.body(600, 0), 15, UI.INK))
		txt.add_child(UI.label(u[2], UI.body(600, 0), 11, UI.INK_DIM))
		row.add_child(txt)
		row.add_child(_pips(lvl, Data.UPG_MAX))
		var key: String = u[0]
		if lvl >= Data.UPG_MAX:
			row.add_child(_buy_button("Max", false, func(): pass, 34.0, 76.0, 14))
		else:
			var cost := Data.upg_cost(id, lvl)
			row.add_child(_buy_button("+ · %d" % cost, Game.points >= cost, func():
				if Game.buy(cost):
					Game.owned[id].up[key] += 1
					Game.owned[id].ammo = Game.wstat(id).mag
					if Game.player and id == Game.cur:
						Game.player.ammo = Game.owned[id].ammo, 34.0, 76.0, 14))


## Kaart voor basis en soldaat: naam met rechts een teller of pips, uitleg en een koopknop.
func _plain_card(title: String, desc: String, tag: String, pips_lvl: int, pips_max: int, btn_text: String, enabled: bool, action: Callable) -> void:
	var pc := _card_box()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	pc.add_child(v)
	var h := _head(title, tag)
	if pips_max > 0:
		h.add_child(_pips(pips_lvl, pips_max))
	v.add_child(h)
	v.add_child(_desc(desc))
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sp)
	v.add_child(_buy_button(btn_text, enabled, action))


func _tiered(title: String, desc: String, key: String, max_lvl: int, base_cost: int, verb: String, extra: Callable) -> void:
	var lvl: int = Game.upg[key]
	var cost := base_cost * (lvl + 1)
	if lvl >= max_lvl:
		_plain_card(title, desc, "", lvl, max_lvl, "Max", false, func(): pass)
	else:
		_plain_card(title, desc, "", lvl, max_lvl, "%s · %s" % [verb, UI.nl(cost)], Game.points >= cost, func():
			if Game.buy(cost):
				Game.upg[key] += 1
				extra.call())


func _base_cards() -> void:
	var missing := Game.base_max - Game.base_hp
	_plain_card("Bunker repareren", "Herstelt 350 punten structuur.", "%d / %d" % [ceili(Game.base_hp), roundi(Game.base_max)], 0, 0, "Repareer · 250", Game.points >= 250 and missing > 0.0, func():
		if Game.buy(250):
			Game.base_hp = minf(Game.base_max, Game.base_hp + 350.0))
	_tiered("Beton versterken", "+300 maximale structuur en direct hersteld.", "fort", 5, 400, "Versterk", func():
		Game.base_max += 300.0
		Game.base_hp = Game.base_max)


func _soldier_cards() -> void:
	var p = Game.player
	var hp: float = p.hp if p else 0.0
	_plain_card("Veldhospitaal", "Volledig genezen.", "%d / %d" % [ceili(hp), roundi(Game.max_hp())], 0, 0, "Genees · 200", Game.points >= 200 and hp < Game.max_hp(), func():
		if Game.buy(200) and p:
			p.hp = Game.max_hp())
	_tiered("Taaiheid", "+25 maximale gezondheid.", "maxhp", 5, 260, "Train", func():
		if Game.player:
			Game.player.hp += 25.0)
	_tiered("Kogelvrij vest", "8% minder schade per niveau.", "armor", 5, 350, "Koop", func(): pass)
	_tiered("Conditie", "7% sneller lopen.", "speed", 4, 300, "Train", func(): pass)
